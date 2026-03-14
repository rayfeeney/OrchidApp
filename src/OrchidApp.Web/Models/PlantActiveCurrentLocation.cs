namespace OrchidApp.Web.Models;

public class PlantActiveCurrentLocation
{
    public int PlantId { get; set; }
    public int TaxonId { get; set; }

    public string? PlantTag { get; set; }
    public string? PlantName { get; set; }

    public bool TaxonIsActive { get; set; }
    public bool GenusIsActive { get; set; }

    public int? LocationId { get; set; }
    public string? LocationName { get; set; }
    public string? LocationTypeCode { get; set; }

    public DateTime? LocationStartDateTime { get; set; }

    public string DisplayName { get; set; } = string.Empty;
    public string? HeroFilePath { get; set; }
}
