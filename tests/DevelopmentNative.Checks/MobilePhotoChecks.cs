using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using NetVips;
using OrchidApp.Web.Services;

internal static class MobilePhotoChecks
{
    public static async Task RunAsync(string root)
    {
        var target = new PhotoStorageTarget { EntityType = "probe", EntityId = "mobile" };
        var folder = Path.Combine(root, "probe", "mobile");
        var pipeline = new PhotoPipeline(Options.Create(new MediaIngestionOptions()), NullLogger<PhotoPipeline>.Instance);

        using var large = Image.Black(8000, 6000, bands: 3);
        using var oriented = large.Mutate(m => m.Set(NetVips.GValue.GIntType, "orientation", 6));
        var jpegBytes = oriented.JpegsaveBuffer();
        await using var jpeg = new NonSeekingStream(jpegBytes);
        var result = await pipeline.ProcessAndSaveAsync(jpeg, target, root);
        if (result.Width != 2304 || result.Height != 3072)
            throw new InvalidOperationException($"48 MP JPEG orientation failed: {result.Width} × {result.Height}");
        using var thumb = Image.NewFromFile(Path.Combine(folder, result.ThumbnailFileName));
        if (thumb.Width != 225 || thumb.Height != 300 || thumb.Avg() != 0)
            throw new InvalidOperationException("48 MP JPEG thumbnail failed.");

        await using var heic = File.OpenRead(Path.Combine(AppContext.BaseDirectory, "fixtures", "black-640x480.heic"));
        var heicResult = await pipeline.ProcessAndSaveAsync(heic, target, root);
        using var reopened = Image.NewFromFile(Path.Combine(folder, heicResult.FileName));
        if (reopened.Width != 640 || reopened.Height != 480 || reopened.Avg() > 2)
            throw new InvalidOperationException("HEVC HEIC round trip failed.");

        await using var portrait = File.OpenRead(Path.Combine(AppContext.BaseDirectory, "fixtures", "oriented-640x480.heic"));
        var portraitResult = await pipeline.ProcessAndSaveAsync(portrait, target, root);
        using var portraitImage = Image.NewFromFile(Path.Combine(folder, portraitResult.FileName));
        if (portraitImage.Width != 480 || portraitImage.Height != 640 ||
            portraitImage.Getpoint(240, 100)[0] > 35 || portraitImage.Getpoint(240, 540)[0] < 220)
            throw new InvalidOperationException($"HEIC orientation failed: {portraitImage.Width} × {portraitImage.Height}, top {portraitImage.Getpoint(240, 100)[0]}, bottom {portraitImage.Getpoint(240, 540)[0]}.");

        using var noise = Image.Gaussnoise(5000, 4000, sigma: 60, seed: 42);
        using var noisy = noise.Cast(Enums.BandFormat.Uchar);
        await using var largeFile = new MemoryStream(noisy.JpegsaveBuffer(q: 98));
        if (largeFile.Length <= 10 * 1024 * 1024)
            throw new InvalidOperationException("Large JPEG fixture did not exceed the former byte limit.");
        await pipeline.ProcessAndSaveAsync(largeFile, target, root);

        await using var tooLarge = new MemoryStream(new byte[25 * 1024 * 1024 + 1]);
        await RejectAsync(tooLarge, "25 MiB");
        using var oversized = Image.Black(10000, 6500, bands: 3);
        await using var dimensions = new MemoryStream(oversized.JpegsaveBuffer());
        await RejectAsync(dimensions, "64 megapixel");
        await using var truncated = new MemoryStream(jpegBytes, 0, jpegBytes.Length / 2);
        await RejectAsync(truncated, "could not be processed");
        Console.WriteLine("Mobile photo checks passed (48 MP EXIF JPEG from a non-seeking stream, JPEG over 10 MiB, HEVC HEIC and rotation, truncated JPEG, size and pixel limits).");

        async Task RejectAsync(Stream input, string expected)
        {
            var before = Directory.GetFiles(folder).Order().ToArray();
            try
            {
                await pipeline.ProcessAndSaveAsync(input, target, root);
                throw new Exception("Expected mobile photo rejection.");
            }
            catch (InvalidOperationException ex) when (ex.Message.Contains(expected, StringComparison.Ordinal)) { }
            if (!before.SequenceEqual(Directory.GetFiles(folder).Order()))
                throw new InvalidOperationException("A rejected upload changed published files.");
        }
    }

    private sealed class NonSeekingStream(byte[] bytes) : MemoryStream(bytes)
    {
        public override bool CanSeek => false;
        public override long Length => throw new NotSupportedException();
        public override long Position
        {
            get => throw new NotSupportedException();
            set => throw new NotSupportedException();
        }
        public override long Seek(long offset, SeekOrigin loc) => throw new NotSupportedException();
    }
}
