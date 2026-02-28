namespace OrchidApp.Web.Models;
using System.ComponentModel.DataAnnotations;

public class Genus
{
    public int GenusId { get; set; }
     public bool IsActive { get; set; }

    [Display(Name = "Genus name")]
    public string Name { get; set; } = string.Empty;
    [Display(Name = "Notes")]
    public string? Notes { get; set; }

}
