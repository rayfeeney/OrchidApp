namespace OrchidApp.Web.Models;

public class PlantEvent
{
    public int PlantEventId { get; set; }
    public int PlantId { get; set; }

    public int ObservationTypeId { get; set; }
    public DateTime EventDateTime { get; set; }
    public string? EventDetails { get; set; }
    public DateTime UpdatedDateTime { get; set; }


    public bool IsActive { get; set; }
}
