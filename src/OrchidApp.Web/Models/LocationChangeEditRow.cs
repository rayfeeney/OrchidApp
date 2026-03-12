namespace OrchidApp.Web.Models;

public class LocationChangeEditRow
{
    public int PlantLocationHistoryId { get; set; }
    public DateTime StartDateTime { get; set; }
    public string? MoveReasonNotes { get; set; }
    public string? PlantLocationNotes { get; set; }
}