using System;

namespace OrchidApp.Web.Models
{
    public class PlantPhoto
    {
        public int PlantPhotoId { get; set; }

        public int PlantEventId { get; set; }
        public int PlantId { get; set; }

        public string FileName { get; set; } = default!;
        public string FilePath { get; set; } = default!;
        public string MimeType { get; set; } = default!;

        public bool IsHero { get; set; }
        public bool IsActive { get; set; }

        public DateTime CreatedDateTime { get; set; }
        public DateTime? UpdatedDateTime { get; set; }
    }
}
