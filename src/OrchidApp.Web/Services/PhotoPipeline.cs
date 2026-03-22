/*
================================================================================
PHOTO INGESTION PIPELINE — CANONICAL DESIGN CONTRACT
================================================================================

This pipeline defines the ONLY supported media ingestion behaviour for OrchidApp.

This is a system invariant. Changes must be treated as architectural changes,
not implementation tweaks.

-------------------------------------------------------------------------------
CANONICAL IMAGE SPECIFICATION (LOCKED)
-------------------------------------------------------------------------------

All uploaded images are normalised to a single canonical format:

• Maximum dimension:      3072 px (longest side)
• Output format:          JPEG
• JPEG quality:           90
• Metadata:               STRIPPED
• Colour profile:         PRESERVED
• Alpha channel:          FLATTENED to white background
• Animated images:        REJECTED
• Multi-frame images:     REJECTED
• Original uploads:       NOT STORED

Only the processed canonical image is persisted.

-------------------------------------------------------------------------------
PIPELINE ARCHITECTURE
-------------------------------------------------------------------------------

Decode stage:
    ImageMagick (Magick.NET)
    - Handles HEIC, HEIF, iPhone formats, RAW edge cases
    - Performs orientation, alpha handling, metadata stripping

Processing stage:
    libvips (NetVips)
    - Performs resizing
    - Performs final JPEG encoding
    - Chosen for low memory footprint and high performance

This hybrid design is intentional.

Magick.NET provides format robustness.
libvips provides production-grade performance.

-------------------------------------------------------------------------------
ERROR HANDLING CONTRACT
-------------------------------------------------------------------------------

The pipeline MUST:

• Fail fast on invalid media
• Never produce partial files
• Never leave zero-byte files
• Never leak temporary files
• Never expose internal library errors to end users

User-visible error must always be polite and generic:
    "The photo could not be processed."

Detailed errors are logged only.

-------------------------------------------------------------------------------
OPERATIONAL CONSTRAINTS
-------------------------------------------------------------------------------

Design target:
    Small self-hosted deployments (≤ ~2000 plants)

Therefore:
    • Local filesystem storage is intentional
    • No object storage abstraction
    • No background media queues
    • No derivative image sets
    • No thumbnail pyramid
    • No CDN assumptions

-------------------------------------------------------------------------------
BACKUP MODEL
-------------------------------------------------------------------------------

Images are part of the canonical dataset.

Backup expectations:
    • Included in nightly encrypted backup
    • Restore must be filesystem-level simple
    • No reconstruction pipelines

-------------------------------------------------------------------------------
DEPENDENCIES
-------------------------------------------------------------------------------

Magick.NET
    Used for robust decode + canonicalisation
    Licence: Apache 2.0

NetVips / libvips
    Used for performant processing + encoding
    Licence: LGPL-2.1 (dynamic use)

ImageMagick (native)
    Runtime dependency of Magick.NET

These dependencies are part of the architecture.

-------------------------------------------------------------------------------
CHANGE CONTROL
-------------------------------------------------------------------------------

Any change to:

• Output format
• Quality
• Dimension rules
• Metadata policy
• Storage strategy
• Library stack

MUST be treated as an architectural decision.

Do NOT “tweak” this pipeline casually.

-------------------------------------------------------------------------------
RATIONALE
-------------------------------------------------------------------------------

This design prioritises:

• Predictable storage growth
• Low memory usage on Raspberry Pi
• Robust handling of real-world phone images
• Operational simplicity
• Long-term maintainability

================================================================================
*/

using ImageMagick;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using NetVips;

namespace OrchidApp.Web.Services;

public sealed class PhotoPipeline
{
    private const long MaxUploadBytes = 10 * 1024 * 1024;
    private const int MaxMegapixels = 40;

    private readonly MediaIngestionOptions _options;
    private readonly ILogger<PhotoPipeline> _logger;

    public PhotoPipeline(
        IOptions<MediaIngestionOptions> options,
        ILogger<PhotoPipeline> logger)
    {
        _options = options.Value;
        _logger = logger;
    }

    public async Task<PhotoSaveResult> ProcessAndSaveAsync(
        Stream uploadStream,
        int plantId,
        string uploadsRootPath,
        CancellationToken ct = default)
    {
        _logger.LogInformation("Photo ingestion started for plant {PlantId}", plantId);

        await using var buffered = new MemoryStream();
        await CopyWithLimitAsync(uploadStream, buffered, MaxUploadBytes, ct);
        buffered.Position = 0;

        if (buffered.Length == 0)
            throw new InvalidOperationException("Empty file.");

        _logger.LogInformation("Upload size {Bytes} bytes", buffered.Length);

        string? canonicalTempFile = null;

        try
        {
            canonicalTempFile = await CreateCanonicalTempJpegAsync(buffered, ct);

            using var original = Image.NewFromFile(canonicalTempFile);

            _logger.LogInformation(
                "Canonical image loaded. Width={Width}, Height={Height}",
                original.Width,
                original.Height);

            if ((long)original.Width * original.Height > MaxMegapixels * 1_000_000L)
                throw new InvalidOperationException("Image dimensions too large.");

            using var resized = ResizeIfNeeded(original, _options.MaxImageDimension);

            var plantFolder = Path.Combine(uploadsRootPath, "plants", plantId.ToString());
            Directory.CreateDirectory(plantFolder);

            var fileName = $"{Guid.NewGuid():N}.jpg";
            var finalPath = Path.Combine(plantFolder, fileName);
            var tempOutputPath = finalPath + ".tmp";

            SaveProcessedJpeg(resized, tempOutputPath);

            File.Move(tempOutputPath, finalPath, overwrite: true);

            _logger.LogInformation(
                "Photo saved. PlantId={PlantId}, Width={Width}, Height={Height}, Path={Path}",
                plantId,
                resized.Width,
                resized.Height,
                finalPath);

            return new PhotoSaveResult
            {
                RelativePath = Path.Combine("uploads", "plants", plantId.ToString(), fileName)
                    .Replace("\\", "/"),
                MimeType = "image/jpeg",
                Width = resized.Width,
                Height = resized.Height
            };
        }
        catch (InvalidOperationException)
        {
            throw;
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Photo ingestion failed for plant {PlantId}", plantId);
            throw new InvalidOperationException("The photo could not be processed.");
        }
        finally
        {
            CleanupTemp(canonicalTempFile);
        }
    }

    private async Task<string> CreateCanonicalTempJpegAsync(Stream stream, CancellationToken ct)
    {
        stream.Position = 0;

        using var copy = new MemoryStream();
        await stream.CopyToAsync(copy, ct);
        var bytes = copy.ToArray();

        using var collection = new MagickImageCollection(bytes);

        if (collection.Count == 0)
            throw new InvalidOperationException("Invalid image format.");

        if (collection.Count > 1)
            throw new InvalidOperationException("Animated or multi-frame images are not supported.");

        using var image = (MagickImage)collection[0];

        _logger.LogInformation(
            "Magick decoded image. Format={Format}, Width={Width}, Height={Height}",
            image.Format,
            image.Width,
            image.Height);

        var colourProfile = image.GetColorProfile();

        image.AutoOrient();

        if (image.Width <= 0 || image.Height <= 0)
            throw new InvalidOperationException("Invalid image dimensions.");

        if ((long)image.Width * image.Height > MaxMegapixels * 1_000_000L)
            throw new InvalidOperationException("Image dimensions too large.");

        image.BackgroundColor = MagickColors.White;
        image.Alpha(AlphaOption.Remove);

        image.Strip();

        if (colourProfile != null)
            image.SetProfile(colourProfile);

        image.Format = MagickFormat.Jpeg;
        image.Quality = ClampQualityMagick(_options.JpegQuality);

        var tempPath = Path.ChangeExtension(Path.GetTempFileName(), ".jpg");
        await image.WriteAsync(tempPath, MagickFormat.Jpeg, ct);

        return tempPath;
    }

    private static Image ResizeIfNeeded(Image source, int maxDimension)
    {
        var longest = Math.Max(source.Width, source.Height);

        if (longest <= maxDimension)
            return source.Copy();

        var scale = (double)maxDimension / longest;
        return source.Resize(scale, kernel: Enums.Kernel.Lanczos3);
    }

    private void SaveProcessedJpeg(Image image, string path)
    {
        image.Jpegsave(
            path,
            q: ClampQualityVips(_options.JpegQuality),
            optimizeCoding: true,
            interlace: false);
    }

    private static void CleanupTemp(string? path)
    {
        if (!string.IsNullOrWhiteSpace(path) && File.Exists(path))
            File.Delete(path);
    }

    private static uint ClampQualityMagick(int quality)
    {
        if (quality < 1) return 1;
        if (quality > 100) return 100;
        return (uint)quality;
    }

    private static int ClampQualityVips(int quality)
    {
        if (quality < 1) return 1;
        if (quality > 100) return 100;
        return quality;
    }

    private static async Task CopyWithLimitAsync(
        Stream src,
        Stream dest,
        long maxBytes,
        CancellationToken ct)
    {
        var buffer = new byte[81920];
        long total = 0;

        while (true)
        {
            var read = await src.ReadAsync(buffer.AsMemory(0, buffer.Length), ct);
            if (read == 0)
                break;

            total += read;
            if (total > maxBytes)
                throw new InvalidOperationException("File exceeds maximum size.");

            await dest.WriteAsync(buffer.AsMemory(0, read), ct);
        }

        dest.Position = 0;
    }
}