using System.ComponentModel.DataAnnotations;

namespace OrchidApp.Web.Models;

public class TaxonIdentity
{
    public int TaxonId { get; set; }
    public int GenusId { get; set; }

    [Display(Name = "Genus")]
    public string GenusName { get; set; } = string.Empty;

    [Display(Name = "Species name")]
    public string? SpeciesName { get; set; }
    [Display(Name = "Hybrid name")]
    public string? HybridName { get; set; }

    public string DisplayName { get; set; } = string.Empty;

    [Display(Name = "Notes")]
    public string? TaxonNotes { get; set; }

    public bool TaxonIsActive { get; set; }

    public bool GenusIsActive { get; set; }

    public string? GrowthCode { get; set; }

    [Display(Name = "Growth notes")]
    public string? GrowthNotes { get; set; }

    public bool IsSystemManaged { get; set; }
}
