using System;

namespace OrchidApp.Web.Models;

public class TaxonPhoto
{
    public int TaxonPhotoId { get; set; }

    public int TaxonId { get; set; }

    public string FileName { get; set; } = default!;
    public string ThumbnailFileName { get; set; } = default!;
    public string MimeType { get; set; } = default!;

    public bool IsPrimary { get; set; }
    public bool IsActive { get; set; }

    public DateTime CreatedDateTime { get; set; }
    public DateTime UpdatedDateTime { get; set; }
}