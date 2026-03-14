namespace OrchidApp.Web.Models;

public class TaxonEditDto
{
    public int TaxonId { get; set; }
    public int GenusId { get; set; }
    public bool IsSystemManaged { get; set; }

    public string? SpeciesName { get; set; }
    public string? HybridName { get; set; }
    public string? GrowthCode { get; set; }
    public string? GrowthNotes { get; set; }
    public string? TaxonNotes { get; set; }
}