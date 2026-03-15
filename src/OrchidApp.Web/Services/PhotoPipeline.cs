using SkiaSharp;

namespace OrchidApp.Web.Services;

public sealed class PhotoPipeline
{
    private const int MaxUploadBytes = 10 * 1024 * 1024; // 10MB
    private const int MaxMegapixels = 40; // safety guard
    private const int MaxDimension = 2000; // max width or height
    private const int JpegQuality = 85;

    public async Task<string> ProcessAndSaveAsync(
        Stream uploadStream,
        int plantId,
        string uploadsRootPath,
        CancellationToken ct = default)
    {
        if (uploadStream.Length == 0)
            throw new InvalidOperationException("Empty file.");

        if (uploadStream.Length > MaxUploadBytes)
            throw new InvalidOperationException("File exceeds maximum size.");

        using var managedStream = new MemoryStream();
        await uploadStream.CopyToAsync(managedStream, ct);
managedStream.Position = 0;

Console.WriteLine($"UPLOAD SIZE: {managedStream.Length}");

using var codec = SKCodec.Create(managedStream);
Console.WriteLine(codec == null ? "SKCodec: NULL" : "SKCodec: OK");

if (codec == null)
    throw new InvalidOperationException("Invalid image format.");

        var info = codec.Info;

        if ((long)info.Width * info.Height > MaxMegapixels * 1_000_000)
            throw new InvalidOperationException("Image dimensions too large.");

        using var bitmap = SKBitmap.Decode(codec);
        if (bitmap == null)
            throw new InvalidOperationException("Unable to decode image.");

        using var oriented = ApplyOrientation(bitmap, codec.EncodedOrigin);
        using var resized = ResizeIfNeeded(oriented);

        using var image = SKImage.FromBitmap(resized);
        using var data = image.Encode(SKEncodedImageFormat.Jpeg, JpegQuality);

        var plantFolder = Path.Combine(uploadsRootPath, "plants", plantId.ToString());
        Directory.CreateDirectory(plantFolder);

        var fileName = $"{Guid.NewGuid():N}.jpg";
        var fullPath = Path.Combine(plantFolder, fileName);

        await using (var fileStream = File.Create(fullPath))
        {
            data.SaveTo(fileStream);
        }

        return Path.Combine("uploads", "plants", plantId.ToString(), fileName)
            .Replace("\\", "/");
    }

    private static SKBitmap ApplyOrientation(SKBitmap source, SKEncodedOrigin origin)
    {
        switch (origin)
        {
            case SKEncodedOrigin.RightTop:
                return Rotate(source, 90);
            case SKEncodedOrigin.LeftBottom:
                return Rotate(source, 270);
            case SKEncodedOrigin.BottomRight:
                return Rotate(source, 180);
            default:
                return source.Copy();
        }
    }

    private static SKBitmap Rotate(SKBitmap source, float degrees)
    {
        var radians = degrees * (float)Math.PI / 180f;

        var rotated = new SKBitmap(source.Height, source.Width);
        using var canvas = new SKCanvas(rotated);

        canvas.Clear(SKColors.Transparent);
        canvas.Translate(rotated.Width / 2f, rotated.Height / 2f);
        canvas.RotateDegrees(degrees);
        canvas.Translate(-source.Width / 2f, -source.Height / 2f);
        canvas.DrawBitmap(source, 0, 0);

        return rotated;
    }

    private static SKBitmap ResizeIfNeeded(SKBitmap source)
    {
        var maxSide = Math.Max(source.Width, source.Height);

        if (maxSide <= MaxDimension)
            return source.Copy();

        var scale = (float)MaxDimension / maxSide;
        var newWidth = (int)(source.Width * scale);
        var newHeight = (int)(source.Height * scale);

        var resized = new SKBitmap(newWidth, newHeight);

        var sampling = new SKSamplingOptions(SKFilterMode.Linear, SKMipmapMode.Linear);

        source.ScalePixels(resized, sampling);

        return resized;
    }
}