using System.ComponentModel.DataAnnotations;

namespace OrchidApp.Web.Models;

public class PlantCurrentLocation
{
    public int PlantId { get; set; }
    public int TaxonId { get; set; }
    
    [Display(Name = "Tag")]
    public string? PlantTag { get; set; } = string.Empty;
    [Display(Name = "Name")]
    public string? PlantName { get; set; }
    public string DisplayName { get; set; } = string.Empty;
    public DateTime? PlantEndDate { get; set; }

    public int? LocationId { get; set; }
    public int? PlantLocationHistoryId { get; set; }
    
    [Display(Name = "Location")]
    public string? LocationName { get; set; } = string.Empty;
    public string? LocationTypeCode { get; set; } = string.Empty;
    public DateTime? LocationStartDateTime { get; set; }
}

