namespace OrchidApp.Web.Models;

public class PlantCurrentGrowthMedium
{
    public int PlantId { get; set; }
    public int GrowthMediumId { get; set; }
    public string? GrowthMediumName { get; set; }
    public int PotSize { get; set; }
    public string? RepottingNotes { get; set; }
    public DateTime RepotDate { get; set; }
}