using System.Security.Cryptography;
using System.Text.Json;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using NetVips;
using OrchidApp.Web.Services;

internal static class PhotoPolicyChecks
{
    public static async Task RunAsync(string root)
    {
        var fixtures = Path.Combine(AppContext.BaseDirectory, "fixtures");
        using var manifest = JsonDocument.Parse(File.ReadAllText(Path.Combine(fixtures, "manifest.json")));
        var profile = manifest.RootElement.GetProperty("iccSha256").GetString();
        int count = 0;
        void Check(bool pass, string name) { if (!pass) throw new InvalidOperationException("Photo check failed: " + name); count++; }
        foreach (var strip in new[] { true, false })
        foreach (var item in manifest.RootElement.GetProperty("images").EnumerateArray())
        {
            var id = item.GetProperty("orientation").GetInt32();
            var pipeline = new PhotoPipeline(Options.Create(new MediaIngestionOptions { StripGpsMetadata = strip }), NullLogger<PhotoPipeline>.Instance);
            await using var input = File.OpenRead(Path.Combine(fixtures, item.GetProperty("file").GetString()!));
            var target = new PhotoStorageTarget { EntityType = "policy", EntityId = $"o{id}-{strip}" };
            var saved = await pipeline.ProcessAndSaveAsync(input, target, root);
            foreach (var (name, isThumb) in new[] { (saved.FileName, false), (saved.ThumbnailFileName, true) })
            {
                var path = Path.Combine(root, target.EntityType, target.EntityId, name);
                using var image = Image.NewFromFile(path);
                int width = item.GetProperty("width").GetInt32(), height = item.GetProperty("height").GetInt32();
                if (isThumb) { var ratio = 300.0 / Math.Max(width, height); width = (int)Math.Round(width * ratio); height = (int)Math.Round(height * ratio); }
                Check(image.Width == width && image.Height == height, $"orientation {id} dimensions, strip={strip}");
                var corners = item.GetProperty("corners").EnumerateArray().ToArray();
                for (int i = 0; i < 4; i++)
                {
                    var pixel = image.Getpoint(i % 2 == 0 ? image.Width / 10 : image.Width * 9 / 10,
                        i < 2 ? image.Height / 10 : image.Height * 9 / 10);
                    for (int band = 0; band < 3; band++)
                        Check(Math.Abs(pixel[band] - corners[i][band].GetDouble()) < 35, $"orientation {id} pixels");
                }
                var fields = image.GetFields();
                Check(fields.Any(f => f.Contains("GPSLatitude", StringComparison.OrdinalIgnoreCase)) == !strip, "GPS option");
                Check((image.GetTypeOf("xmp-data") != 0) == !strip, "XMP option");
                Check(image.GetTypeOf("icc-profile-data") != 0 && Convert.ToHexString(SHA256.HashData((byte[])image.Get("icc-profile-data"))) == profile, "ICC bytes preserved");
                Check(image.GetTypeOf("orientation") == 0 || (int)image.Get("orientation") == 1, "orientation normalized");
                Check(!strip || !System.Text.Encoding.Latin1.GetString(File.ReadAllBytes(path)).Contains("C15 Synthetic"), "artist removed");
                using var displayed = image.Autorot();
                Check(displayed.Width == image.Width && displayed.Height == image.Height, "no second rotation");
            }
        }
        var normal = new PhotoPipeline(Options.Create(new MediaIngestionOptions()), NullLogger<PhotoPipeline>.Instance);
        await using (var alpha = File.OpenRead(Path.Combine(fixtures, "transparent.png")))
        {
            var saved = await normal.ProcessAndSaveAsync(alpha, new PhotoStorageTarget { EntityType = "policy", EntityId = "alpha" }, root);
            using var image = Image.NewFromFile(Path.Combine(root, "policy", "alpha", saved.FileName));
            Check(image.Avg() > 250, "transparent image flattened white");
        }
        foreach (var file in new[] { "animated.gif", "manifest.json" })
        {
            await using var input = File.OpenRead(Path.Combine(fixtures, file));
            bool refused = false;
            try { await normal.ProcessAndSaveAsync(input, new PhotoStorageTarget { EntityType = "policy", EntityId = "rejected" }, root); }
            catch (InvalidOperationException) { refused = true; }
            Check(refused && !Directory.Exists(Path.Combine(root, "policy", "rejected")), "invalid/multipage input leaves no files");
        }
        Console.WriteLine($"{count} native metadata/orientation/colour checks passed.");
    }
}
