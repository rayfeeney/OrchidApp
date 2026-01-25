namespace OrchidApp.Web.Models;

public class TaxonIdentity
{
    public int TaxonId { get; set; }
    public int GenusId { get; set; }

    public string GenusName { get; set; } = string.Empty;

    public string? SpeciesName { get; set; }
    public string? HybridName { get; set; }

    public string DisplayName { get; set; } = string.Empty;

    public string? TaxonNotes { get; set; }

    public bool IsActive { get; set; }
}
