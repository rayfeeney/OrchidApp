namespace OrchidApp.Web.Models;

public class PlantActiveSummary
{
    public int PlantId { get; set; }

    public string? PlantTag { get; set; }
    public string? PlantName { get; set; }

    public DateOnly? AcquisitionDate { get; set; }
    public string? AcquisitionSource { get; set; }

    public string GenusName { get; set; } = string.Empty;
    public string? SpeciesName { get; set; }
    public string? HybridName { get; set; }

    public string DisplayName { get; set; } = string.Empty;
}
