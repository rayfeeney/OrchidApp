namespace OrchidApp.Web.Models;

public class PlantLifecycleEvent
{
    public int PlantId { get; set; }
    public DateTime EventDateTime { get; set; }
    public string EventType { get; set; } = string.Empty;
    public string EventSummary { get; set; } = string.Empty;
    public string SourceTable { get; set; } = string.Empty;
    public int SourceId { get; set; }
}
