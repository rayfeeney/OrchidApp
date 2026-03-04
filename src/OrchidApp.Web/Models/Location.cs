using System.ComponentModel.DataAnnotations;

namespace OrchidApp.Web.Models;

public class Location
{
    public int LocationId { get; set; }

    [Display(Name = "Location")]
    public string LocationName { get; set; } = string.Empty;

     [Display(Name = "Location type")]
    public string? LocationTypeCode { get; set; }

    [Display(Name = "Location notes")]
    public string? LocationNotes { get; set; }

    [Display(Name = "Climate")]
    public string? ClimateCode { get; set; }

    [Display(Name = "Climate notes")]
    public string? ClimateNotes { get; set; }

    [Display(Name = "General notes")]
    public string? LocationGeneralNotes { get; set; }

    public bool IsActive { get; set; }

    public DateTime CreatedDateTime { get; set; }

    public DateTime UpdatedDateTime { get; set; }

    // UI helper
    public string DisplayName => LocationName;
}

