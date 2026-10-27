using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using NetVips;
using OrchidApp.Web.Services;

var root = Environment.GetEnvironmentVariable("Storage__UploadRoot");
if (string.IsNullOrWhiteSpace(root) || !Path.IsPathFullyQualified(root))
    throw new InvalidOperationException("Set an explicit absolute Storage__UploadRoot for development checks.");
// Create and remove only this unique probe directory, never existing photographs.
var probe = Path.Combine(root, "development-probe-" + Guid.NewGuid().ToString("N"));
Directory.CreateDirectory(probe);
try
{
    using var source = Image.Black(640, 480, bands: 3);
    await using var input = new MemoryStream(source.WriteToBuffer(".png"));
    var pipeline = new PhotoPipeline(Options.Create(new MediaIngestionOptions()), NullLogger<PhotoPipeline>.Instance);
    var saved = await pipeline.ProcessAndSaveAsync(input,
        new PhotoStorageTarget { EntityType = "probe", EntityId = "isolated" }, probe);
    var folder = Path.Combine(probe, "probe", "isolated");
    using var reopened = Image.NewFromFile(Path.Combine(folder, saved.FileName));
    using var thumbnail = Image.NewFromFile(Path.Combine(folder, saved.ThumbnailFileName));
    if (reopened.Width != 640 || reopened.Height != 480 || thumbnail.Width != 300 || thumbnail.Height != 225 || saved.FileName == saved.ThumbnailFileName)
        throw new InvalidOperationException("Photo or thumbnail dimensions/fallback check failed.");
    // Force lazy native decoding to read all pixels, not just file headers.
    _ = reopened.Avg();
    _ = thumbnail.Avg();
    await PhotoPolicyChecks.RunAsync(probe);
    await PhotoRecoveryChecks.RunAsync(probe);
    Console.WriteLine($"Native photo and thumbnail save/reopen passed (libvips {NetVips.NetVips.Version(0)}.{NetVips.NetVips.Version(1)}.{NetVips.NetVips.Version(2)}).");
}
finally { Directory.Delete(probe, recursive: true); }
