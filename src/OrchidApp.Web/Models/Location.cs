namespace OrchidApp.Web.Models;

public class Location
{
    public int LocationId { get; set; }

    public string LocationName { get; set; } = string.Empty;

    public string? LocationTypeCode { get; set; }

    public bool IsActive { get; set; }
}
