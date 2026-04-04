namespace OrchidApp.Web.Services;

public sealed class PhotoSaveResult
{
    public string RelativePath { get; init; } = "";
    public string ThumbnailRelativePath { get; init; } = "";
    public string MimeType { get; init; } = "";
    public int Width { get; init; }
    public int Height { get; init; }
}