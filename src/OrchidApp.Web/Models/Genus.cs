namespace OrchidApp.Web.Models;

public class Genus
{
    public int GenusId { get; set; }
    public string Name { get; set; } = string.Empty;
    public string? Notes { get; set; }
    public bool IsActive { get; set; }
}
