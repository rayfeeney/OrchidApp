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

    public async Task<IActionResult> OnGetAsync(int id)
    {
        Taxon = await _db.TaxonIdentities
            .AsNoTracking()
            .SingleOrDefaultAsync(t => t.TaxonId == id);

        if (Taxon == null)
            return NotFound();

        return Page();
    }

    public async Task<IActionResult> OnPostToggleActiveAsync(int id)
    {
        var taxon = await _db.TaxonIdentities
            .Where(t => t.TaxonId == id)
            .Select(t => new
            {
                t.TaxonIsActive,
                t.IsSystemManaged,
                t.GenusIsActive
            })
            .SingleOrDefaultAsync();

        if (taxon == null)
            return NotFound();

        if (taxon.IsSystemManaged)
            return BadRequest("System-managed taxa cannot be manually activated or deactivated.");

        if (!taxon.GenusIsActive)
            return BadRequest("This species / hybrid cannot be changed because its genus is inactive.");

        await _db.Database.ExecuteSqlRawAsync(
            "CALL spSetTaxonActiveState({0},{1})",
            id,
            !taxon.TaxonIsActive);

        return RedirectToPage(new { id, ReturnUrl });
    }
}