namespace OrchidApp.Web.Models;
using System.ComponentModel.DataAnnotations;

public class Taxon
{
    public int TaxonId { get; set; }
    public int GenusId { get; set; }

    [Display(Name = "Species name")]
    public string? SpeciesName { get; set; }
    [Display(Name = "Hybrid name")]
    public string? HybridName { get; set; }

    public string? GrowthCode { get; set; }
    [Display(Name = "Growth notes")]
    public string? GrowthNotes { get; set; }
    [Display(Name = "Notes")]
    public string? TaxonNotes { get; set; }

    public bool IsActive { get; set; }
    public bool IsSystemManaged { get; set; }

    public DateTime CreatedDateTime { get; set; }
    public DateTime UpdatedDateTime { get; set; }
}
