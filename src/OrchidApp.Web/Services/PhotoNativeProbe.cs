using Microsoft.Extensions.Options;
using Microsoft.Extensions.Logging.Abstractions;
using NetVips;

namespace OrchidApp.Web.Services;

public interface IPhotoNativeProbe
{
    Task<bool> CheckAsync(string root, CancellationToken ct);
}

public sealed class PhotoNativeProbe(IOptions<MediaIngestionOptions> media) : IPhotoNativeProbe
{
    public async Task<bool> CheckAsync(string root, CancellationToken ct)
    {
        using var image = Image.Black(64, 48, bands: 3);
        await using var input = new MemoryStream(image.WriteToBuffer(".png"));
        var pipeline = new PhotoPipeline(media, NullLogger<PhotoPipeline>.Instance);
        var saved = await pipeline.ProcessAndSaveAsync(input, new PhotoStorageTarget { EntityType = "probe", EntityId = "native" }, root, ct);
        using var main = Image.NewFromFile(Path.Combine(root, "probe", "native", saved.FileName));
        using var thumb = Image.NewFromFile(Path.Combine(root, "probe", "native", saved.ThumbnailFileName));
        return main.Width == 64 && thumb.Width == 64 && main.Avg() == 0 && thumb.Avg() == 0;
    }
}
