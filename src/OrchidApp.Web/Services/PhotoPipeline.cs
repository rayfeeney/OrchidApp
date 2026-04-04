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
        PhotoStorageTarget target,
        string uploadsRootPath,
        CancellationToken ct = default)
    {
        _logger.LogInformation(
            "Photo ingestion started for {EntityType} {EntityId}",
            target.EntityType,
            target.EntityId);

        await using var buffered = new MemoryStream();
        await CopyWithLimitAsync(uploadStream, buffered, MaxUploadBytes, ct);
        buffered.Position = 0;

        if (buffered.Length == 0)
            throw new InvalidOperationException("Empty file.");

        _logger.LogInformation("Upload size {Bytes} bytes", buffered.Length);

        try
        {
            using var original = Image.NewFromBuffer(
                buffered.ToArray(),
                access: Enums.Access.Sequential);

            RejectAnimatedOrMultipage(original);

            _logger.LogInformation(
                "Decoded image via libvips. Width={Width}, Height={Height}",
                original.Width,
                original.Height);

            if ((long)original.Width * original.Height > MaxMegapixels * 1_000_000L)
                throw new InvalidOperationException("Image dimensions too large.");

            using var flattened = original.HasAlpha()
                ? original.Flatten(background: new[] { 255.0, 255.0, 255.0 })
                : original.Copy();

            using var resized = ResizeIfNeeded(flattened, _options.MaxImageDimension).Copy();
            using var thumbnail = ResizeIfNeeded(resized, 300);

            var entityFolder = Path.Combine(
                uploadsRootPath,
                target.EntityType,
                target.EntityId);

            Directory.CreateDirectory(entityFolder);

            var fileName = $"{Guid.NewGuid():N}.jpg";
            var finalPath = Path.Combine(entityFolder, fileName);
            var tempOutputPath = finalPath + ".tmp";

            SaveProcessedJpeg(resized, tempOutputPath);

            File.Move(tempOutputPath, finalPath, overwrite: true);

            // Create thumbnail file
            var thumbFileName = $"{Guid.NewGuid():N}_thumb.jpg";
            var thumbPath = Path.Combine(entityFolder, thumbFileName);
            var tempThumbPath = thumbPath + ".tmp";

            SaveProcessedJpeg(thumbnail, tempThumbPath);
            File.Move(tempThumbPath, thumbPath, overwrite: true);

            _logger.LogInformation(
                "Photo saved. EntityType={EntityType}, EntityId={EntityId}, Width={Width}, Height={Height}, Path={Path}",
                target.EntityType,
                target.EntityId,
                resized.Width,
                resized.Height,
                finalPath);

            return new PhotoSaveResult
            {
                RelativePath = Path.Combine(
                    "uploads",
                    target.EntityType,
                    target.EntityId,
                    fileName
                ).Replace("\\", "/"),

                ThumbnailRelativePath = Path.Combine(
                    "uploads",
                    target.EntityType,
                    target.EntityId,
                    thumbFileName
                ).Replace("\\", "/"),

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
            _logger.LogWarning(
                ex,
                "Photo ingestion failed for {EntityType} {EntityId}",
                target.EntityType,
                target.EntityId);
            throw new InvalidOperationException("The photo could not be processed.");
        }
    }

    private static void RejectAnimatedOrMultipage(Image image)
    {
        if (image.GetTypeOf("n-pages") != 0)
        {
            var pages = (int)image.Get("n-pages");
            if (pages > 1)
                throw new InvalidOperationException("Animated or multi-frame images are not supported.");
        }

        if (image.GetTypeOf("page-height") != 0)
        {
            var pageHeight = (int)image.Get("page-height");
            if (pageHeight > 0 && pageHeight < image.Height)
                throw new InvalidOperationException("Animated or multi-frame images are not supported.");
        }
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
            q: ClampQuality(_options.JpegQuality),
            optimizeCoding: true,
            interlace: false);
    }

    private static int ClampQuality(int quality)
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