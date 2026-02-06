namespace OrchidApp.Web.Models;

public class PlantCurrentLocation
{
    public int PlantId { get; set; }
    public int TaxonId { get; set; }

    public string PlantTag { get; set; } = string.Empty;

    public string? PlantName { get; set; }

    public string DisplayName { get; set; } = string.Empty;

    public int? LocationId { get; set; }
    public int? PlantLocationHistoryId { get; set; }

    public string? LocationName { get; set; } = string.Empty;

    public string? LocationTypeCode { get; set; } = string.Empty;

    public DateTime? LocationStartDateTime { get; set; }
}

