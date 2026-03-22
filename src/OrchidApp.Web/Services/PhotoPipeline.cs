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