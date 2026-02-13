namespace OrchidApp.Web.Models;

public class PlantLifecycleEvent
{
    public int PlantId { get; set; }
    public DateTime EventDateTime { get; set; }
    public string? EventType { get; set; }
    public string? EventSummary { get; set; }
    public string? SourceTable { get; set; }
    public int SourceId { get; set; }
}
