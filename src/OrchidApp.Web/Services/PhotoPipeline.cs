using ImageMagick;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using NetVips;
using System.Text.RegularExpressions;

namespace OrchidApp.Web.Services;

public sealed class PhotoPipeline(IOptions<MediaIngestionOptions> options,
    ILogger<PhotoPipeline> logger, PhotoWriteBatch? batch = null, PhotoFilePublisher? publisher = null)
{
    private const long MaxUploadBytes = 25 * 1024 * 1024;
    private const long MaxPixels = 64_000_000L;
    private const int MaxOutputDimension = 4096;
    private const int ThumbnailDimension = 300;
    private const string HeifLoader = "VipsForeignLoadHeifFile";
    private const string JpegLoader = "VipsForeignLoadJpegFile";
    private static readonly SemaphoreSlim DecodeSlot = new(1);

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
        await DecodeSlot.WaitAsync(ct);
        string? staging = null;
        try
        {
            staging = Directory.CreateTempSubdirectory("orchid-photo-").FullName;
            var input = Path.Combine(staging, "input");
            await using (var file = File.Create(input))
            {
                var bytes = new byte[81920];
                int read;
                while ((read = await uploadStream.ReadAsync(bytes, ct)) != 0)
                {
                    if (file.Length + read > MaxUploadBytes)
                        throw new InvalidOperationException("File exceeds the 25 MiB limit.");
                    await file.WriteAsync(bytes.AsMemory(0, read), ct);
                }
                if (file.Length == 0) throw new InvalidOperationException("Empty file.");
            }

            ct.ThrowIfCancellationRequested();
            var loader = Image.FindLoad(input);
            if (string.IsNullOrEmpty(loader))
                throw new InvalidOperationException("The photo format is invalid or its decoder is unavailable. Try exporting the photo as JPEG.");
            using var original = Image.NewFromFile(input, access: Enums.Access.Sequential, failOn: Enums.FailOn.Truncated);
            if ((original.GetTypeOf("n-pages") != 0 && (int)original.Get("n-pages") > 1) ||
                (original.GetTypeOf("page-height") != 0 && (int)original.Get("page-height") > 0 &&
                 (int)original.Get("page-height") < original.Height))
                throw new InvalidOperationException("Animated or multi-frame images are not supported.");
            if ((long)original.Width * original.Height > MaxPixels)
                throw new InvalidOperationException("Image exceeds the 64 megapixel limit.");

            var maximum = Math.Clamp(options.Value.MaxImageDimension, 1, MaxOutputDimension);
            var workingSize = Math.Max(maximum, ThumbnailDimension);
            using var source = PrepareSource(input, loader, original, workingSize);
            using var reduced = Resize(source, workingSize);
            // Finish reading the sequential decoder before rotation and the two output branches.
            using var decoded = reduced.CopyMemory();
            using var upright = decoded.Autorot();
            using var flattened = upright.HasAlpha()
                ? upright.Flatten(background: new[] { 255.0, 255.0, 255.0 }) : upright.Copy();
            using var resized = Resize(flattened, maximum);
            using var thumbnail = Resize(flattened, ThumbnailDimension);
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
                catch (DirectoryNotFoundException) { }
                catch (Exception cleanup) { logger.LogError(cleanup, "Photo cleanup requires review"); }
            if (ex is OperationCanceledException) throw;
            logger.LogWarning(ex, "Photo processing failed for {Type} {Id}", target.EntityType, target.EntityId);
            throw new InvalidOperationException(ex is InvalidOperationException ? ex.Message :
                "The photo could not be processed. Please try another image.", ex);
        }
        finally
        {
            try
            {
                if (staging is not null) Directory.Delete(staging, recursive: true);
            }
            catch (Exception cleanup) { logger.LogError(cleanup, "Photo input cleanup requires review"); }
            finally { DecodeSlot.Release(); }
        }
    }

    private static Image PrepareSource(string input, string loader, Image original, int workingSize)
    {
        if (OperatingSystem.IsWindows() && loader == HeifLoader &&
            (original.GetTypeOf("heif-compression") == 0 || (string)original.Get("heif-compression") != "av1"))
            return DecodeWindowsHeif(input, workingSize);

        if (loader != JpegLoader) return original.Copy();

        var longestSide = Math.Max(original.Width, original.Height);
        var shrink = 1;
        while (shrink < 8 && longestSide / (shrink * 2) >= workingSize)
            shrink *= 2;
        return shrink == 1
            ? original.Copy()
            : Image.Jpegload(input, shrink: shrink, access: Enums.Access.Sequential, failOn: Enums.FailOn.Truncated);
    }

    private static Image DecodeWindowsHeif(string input, int workingSize)
    {
        // The pinned Windows libvips can identify HEIF but does not ship an HEVC decoder.
        // Magick.NET is used only for this input type, after libvips checks its header.
        ResourceLimits.Thread = 2;
        ResourceLimits.ListLength = 4;
        ResourceLimits.Memory = 512UL * 1024 * 1024;
        ResourceLimits.Disk = 512UL * 1024 * 1024;
        using var file = File.OpenRead(input);
        using var photo = new MagickImage(file, new MagickReadSettings { Format = MagickFormat.Heic });
        photo.AutoOrient();
        if (Math.Max(photo.Width, photo.Height) > workingSize)
            photo.Resize((uint)workingSize, (uint)workingSize);

        var normalized = input + ".png";
        photo.Write(normalized, MagickFormat.Png);
        return Image.NewFromFile(normalized, access: Enums.Access.Sequential);
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
