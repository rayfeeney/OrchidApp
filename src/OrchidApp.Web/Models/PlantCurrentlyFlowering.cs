namespace OrchidApp.Web.Models
{
    public class PlantCurrentlyFlowering
    {
        public int PlantId { get; set; }

        public string PlantTag { get; set; } = null!;

        public string? LocationName { get; set; }

        public int GenusId { get; set; }

        public string GenusName { get; set; } = null!;

        public string DisplayName { get; set; } = null!;

        public DateTime? FloweringStartDate { get; set; }
    }
}