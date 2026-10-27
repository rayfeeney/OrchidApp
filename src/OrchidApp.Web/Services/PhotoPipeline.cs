using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using NetVips;
using System.Text.RegularExpressions;

namespace OrchidApp.Web.Services;

public sealed class PhotoPipeline(IOptions<MediaIngestionOptions> options,
    ILogger<PhotoPipeline> logger, PhotoWriteBatch? batch = null, PhotoFilePublisher? publisher = null)
{
    private const long MaxUploadBytes = 10 * 1024 * 1024;
    public async Task<PhotoSaveResult> ProcessAndSaveAsync(Stream uploadStream,
        PhotoStorageTarget target, string uploadsRootPath, CancellationToken ct = default)
    {
        if (!Path.IsPathFullyQualified(uploadsRootPath) ||
            !Regex.IsMatch(target.EntityType, @"\A[a-zA-Z0-9_-]+\z") ||
            !Regex.IsMatch(target.EntityId, @"\A[a-zA-Z0-9_-]+\z"))
            throw new InvalidOperationException("The photo storage target is invalid.");
        var folder = Path.Combine(uploadsRootPath, target.EntityType, target.EntityId);
        var main = Guid.NewGuid().ToString("N") + ".jpg";
        var thumb = Guid.NewGuid().ToString("N") + "_thumb.jpg";
        var paths = new[] { Path.Combine(folder, main), Path.Combine(folder, thumb) };
        var owned = paths.Concat(paths.Select(p => p + ".tmp")).ToArray();
        try
        {
            await using var buffer = new MemoryStream();
            var bytes = new byte[81920];
            int read;
            while ((read = await uploadStream.ReadAsync(bytes, ct)) != 0)
            {
                if (buffer.Length + read > MaxUploadBytes) throw new InvalidOperationException("File exceeds maximum size.");
                await buffer.WriteAsync(bytes.AsMemory(0, read), ct);
            }
            if (buffer.Length == 0) throw new InvalidOperationException("Empty file.");
            using var original = Image.NewFromBuffer(buffer.ToArray(), access: Enums.Access.Sequential);
            if ((original.GetTypeOf("n-pages") != 0 && (int)original.Get("n-pages") > 1) ||
                (original.GetTypeOf("page-height") != 0 && (int)original.Get("page-height") > 0 &&
                 (int)original.Get("page-height") < original.Height))
                throw new InvalidOperationException("Animated or multi-frame images are not supported.");
            if ((long)original.Width * original.Height > 40_000_000L)
                throw new InvalidOperationException("Image dimensions too large.");
            // Share normalized materialized pixels, not a sequential decoder.
            using var upright = original.Autorot().CopyMemory();
            using var flattened = upright.HasAlpha()
                ? upright.Flatten(background: new[] { 255.0, 255.0, 255.0 }) : upright.Copy();
            using var resized = Resize(flattened, Math.Max(1, options.Value.MaxImageDimension));
            using var thumbnail = Resize(flattened, 300);
            Directory.CreateDirectory(folder);
            batch?.Track(owned);
            ct.ThrowIfCancellationRequested();
            Save(resized, paths[0] + ".tmp");
            ct.ThrowIfCancellationRequested();
            Save(thumbnail, paths[1] + ".tmp");
            ct.ThrowIfCancellationRequested();
            (publisher ?? new PhotoFilePublisher()).Publish(paths[0] + ".tmp", paths[0]);
            (publisher ?? new PhotoFilePublisher()).Publish(paths[1] + ".tmp", paths[1]);
            return new PhotoSaveResult { FileName = main, ThumbnailFileName = thumb,
                MimeType = "image/jpeg", Width = resized.Width, Height = resized.Height };
        }
        catch (Exception ex)
        {
            foreach (var path in owned)
                try { File.Delete(path); }
                catch (Exception cleanup) { logger.LogError(cleanup, "Photo cleanup requires review"); }
            if (ex is OperationCanceledException) throw;
            logger.LogWarning(ex, "Photo processing failed for {Type} {Id}", target.EntityType, target.EntityId);
            throw new InvalidOperationException(ex is InvalidOperationException ? ex.Message :
                "The photo could not be processed. Please try another image.", ex);
        }
    }
    private static Image Resize(Image image, int maximum)
    {
        var size = Math.Max(image.Width, image.Height);
        return size <= maximum ? image.Copy() : image.Resize((double)maximum / size, kernel: Enums.Kernel.Lanczos3);
    }
    private void Save(Image image, string path)
    {
        using var output = image.Mutate(mutable =>
        {
            if (!options.Value.StripGpsMetadata) return;
            // Keep ICC and intrinsic headers, remove source EXIF/GPS/XMP/IPTC
            // and comments. Compatible with native versions before 'keep'.
            var retained = new HashSet<string>(StringComparer.Ordinal) {
                "width", "height", "bands", "format", "coding", "interpretation",
                "xoffset", "yoffset", "xres", "yres", "filename", "icc-profile-data" };
            foreach (var field in image.GetFields())
                if (!retained.Contains(field)) mutable.Remove(field);
        });
        output.Jpegsave(path, q: Math.Clamp(options.Value.JpegQuality, 1, 100), optimizeCoding: true, interlace: false);
    }
}

public class PhotoFilePublisher
{
    public virtual void Publish(string source, string destination) => File.Move(source, destination);
}
