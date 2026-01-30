namespace OrchidApp.Web.Models;

public class PlantCurrentLocation
{
    public int PlantId { get; set; }

    public string? PlantTag { get; set; }
    public string DisplayName { get; set; } = string.Empty;

    public string LocationName { get; set; } = string.Empty;
}
