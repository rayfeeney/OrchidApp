using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using OrchidApp.Web.Data;
using OrchidApp.Web.Models;
using Microsoft.EntityFrameworkCore;

namespace OrchidApp.Web.Pages.Setup.Taxa;

public class DetailsModel : PageModel
{
    [BindProperty(SupportsGet = true)]
    public string? ReturnUrl { get; set; }

    private readonly OrchidDbContext _db;

    public DetailsModel(OrchidDbContext db)
    {
        _db = db;
    }

    public TaxonIdentity? Taxon { get; private set; }

    public IActionResult OnGet(int id)
    {
        Taxon = _db.TaxonIdentities
                   .SingleOrDefault(t => t.TaxonId == id);

        if (Taxon == null)
        {
            return NotFound();
        }

        return Page();
    }

    public async Task<IActionResult> OnPostToggleActiveAsync(int taxonId)
    {
        var taxon = await _db.Taxa
            .Where(t => t.TaxonId == taxonId)
            .Select(t => new { t.IsActive })
            .FirstAsync();

        await _db.Database.ExecuteSqlRawAsync(
            "CALL spSetTaxonActiveState({0},{1})",
            taxonId,
            !taxon.IsActive);

        return RedirectToPage(new { id = taxonId });
    }
}
