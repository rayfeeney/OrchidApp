namespace OrchidApp.Web.Services;

public sealed class MediaIngestionOptions
{
    public int MaxImageDimension { get; init; } = 3072;
    public int JpegQuality { get; init; } = 90;
    public bool StripGpsMetadata { get; init; } = true;
}