namespace OrchidApp.Web.Services;

public sealed class PhotoSaveResult
{
    public string FileName { get; init; } = "";
    public string ThumbnailFileName { get; init; } = "";
    public string MimeType { get; init; } = "";
    public int Width { get; init; }
    public int Height { get; init; }
}