using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using OrchidApp.Web.Data;
using OrchidApp.Web.Models;

namespace OrchidApp.Web.Pages.Setup.Taxa.Actions;

public class EditModel : PageModel
{
    private readonly OrchidDbContext _db;

    public EditModel(OrchidDbContext db)
    {
        _db = db;
    }

    [BindProperty]
    public Taxon Taxon { get; set; } = null!;

    public IActionResult OnGet(int id)
    {
        var taxon = _db.Taxa.SingleOrDefault(t => t.TaxonId == id);

        if (taxon == null)
            return NotFound();

        Taxon = taxon;

        return Page();
    }

    public IActionResult OnPost(int id)
    {
        var existing = _db.Taxa.SingleOrDefault(t => t.TaxonId == id);

        if (existing == null)
            return NotFound();

        // Always allow descriptive fields
        existing.GrowthCode = Taxon.GrowthCode;
        existing.GrowthNotes = Taxon.GrowthNotes;
        existing.TaxonNotes = Taxon.TaxonNotes;

        // Only allow species/hybrid editing if NOT system-managed
        if (!existing.IsSystemManaged)
        {
            if (!string.IsNullOrWhiteSpace(existing.SpeciesName))
                existing.SpeciesName = Taxon.SpeciesName;

            if (!string.IsNullOrWhiteSpace(existing.HybridName))
                existing.HybridName = Taxon.HybridName;
        }

        _db.SaveChanges();

        return RedirectToPage("/Setup/Taxa/Details", new { id = existing.TaxonId });
    }
}
