namespace OrchidApp.Web.Models;

public class PlantCurrentLocation
{
     public int PlantId { get; set; }

    public string? PlantTag { get; set; }
    public string? PlantName { get; set; }

    public int TaxonId { get; set; }

    public string? DisplayName { get; set; }

    public int? LocationId { get; set; }
    public string? LocationName { get; set; }
    public string? LocationTypeCode { get; set; }

    public DateTime? LocationStartDateTime { get; set; }
}
