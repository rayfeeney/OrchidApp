namespace OrchidApp.Web.Models;

public class PlantEvent
{
    public int PlantEventId { get; set; }
    public int PlantId { get; set; }

    public string? EventCode { get; set; }   // unused for now
    public DateTime EventDateTime { get; set; }
    public string? EventDetails { get; set; }

    public bool IsActive { get; set; }
}
