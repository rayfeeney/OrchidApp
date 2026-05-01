namespace OrchidApp.Web.Models
{
    public class PlantSinceLastFlowered
    {
        public int PlantId { get; set; }

        public string PlantTag { get; set; } = null!;

        public DateTime? AcquisitionDate { get; set; }

        public string? LocationName { get; set; }

        public int GenusId { get; set; }

        public string GenusName { get; set; } = null!;

        public string DisplayName { get; set; } = null!;

        public DateTime? LastFlowerEndDate { get; set; }

        public int? MonthsSinceFlower { get; set; }
    }
}