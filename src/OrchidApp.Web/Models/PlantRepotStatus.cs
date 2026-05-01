using System;

namespace OrchidApp.Web.Models
{
    public class PlantRepotStatus
    {
        public int PlantId { get; set; }

        public string PlantTag { get; set; } = null!;

        public string? LocationName { get; set; }

        public int GenusId { get; set; }

        public string GenusName { get; set; } = null!;

        public string DisplayName { get; set; } = null!;

        public DateTime? AcquisitionDate { get; set; }

        public DateTime? LastRepotDate { get; set; }

        public int? MonthsSinceRepot { get; set; }

        public string RepotStatus { get; set; } = null!;

        public string RepotSummary { get; set; } = null!;
    }
}