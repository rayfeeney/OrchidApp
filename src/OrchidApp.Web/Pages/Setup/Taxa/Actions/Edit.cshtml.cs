using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.EntityFrameworkCore;
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

    [BindProperty(SupportsGet = true)]
    public string? ReturnUrl { get; set; }

    [BindProperty]
    public Taxon Taxon { get; set; } = null!;

    public string GenusName { get; private set; } = string.Empty;

    public async Task<IActionResult> OnGetAsync(int id)
    {
        var result = await _db.Taxa
            .AsNoTracking()
            .Where(t => t.TaxonId == id)
            .Join(
                _db.Genera,
                t => t.GenusId,
                g => g.GenusId,
                (t, g) => new
                {
                    Taxon = t,
                    GenusName = g.Name
                }
            )
            .SingleOrDefaultAsync();

        if (result == null)
            return NotFound();

        Taxon = result.Taxon;
        GenusName = result.GenusName;

        return Page();
    }

    public async Task<IActionResult> OnPostAsync(int id)
    {
        if (!ModelState.IsValid)
        {
            await ReloadGenusNameAsync();
            return Page();
        }

        try
        {
            await _db.Database.ExecuteSqlRawAsync(
                "CALL spUpdateTaxonDetails({0}, {1}, {2}, {3}, {4}, {5})",
                id,
                (object?)Taxon.SpeciesName ?? DBNull.Value,
                (object?)Taxon.HybridName ?? DBNull.Value,
                (object?)Taxon.GrowthCode ?? DBNull.Value,
                (object?)Taxon.GrowthNotes ?? DBNull.Value,
                (object?)Taxon.TaxonNotes ?? DBNull.Value
            );
        }
        catch (Exception ex)
        {
            ModelState.AddModelError(string.Empty, ex.Message);
            await ReloadGenusNameAsync();
            return Page();
        }

        return Redirect(ReturnUrl ?? Url.Page("/Setup/Taxa/Details", new { id })!);
    }

    private async Task ReloadGenusNameAsync()
    {
        GenusName = await _db.Genera
            .Where(g => g.GenusId == Taxon.GenusId)
            .Select(g => g.Name)
            .SingleAsync();
    }
}