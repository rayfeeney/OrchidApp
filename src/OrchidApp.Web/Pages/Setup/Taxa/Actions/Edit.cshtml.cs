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
    public TaxonEditDto Taxon { get; set; } = new();

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
                    Taxon = new TaxonEditDto
                    {
                        TaxonId = t.TaxonId,
                        GenusId = t.GenusId,
                        IsSystemManaged = t.IsSystemManaged,
                        SpeciesName = t.SpeciesName,
                        HybridName = t.HybridName,
                        GrowthCode = t.GrowthCode,
                        GrowthNotes = t.GrowthNotes,
                        TaxonNotes = t.TaxonNotes
                    },
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
            await ReloadGenusNameAsync(id);
            return Page();
        }

        try
        {
            await _db.Database.ExecuteSqlRawAsync(
                "CALL spUpdateTaxonDetails({0},{1},{2},{3},{4},{5})",
                id,
                (object?)Taxon.SpeciesName!,
                (object?)Taxon.HybridName!,
                (object?)Taxon.GrowthCode!,
                (object?)Taxon.GrowthNotes!,
                (object?)Taxon.TaxonNotes!
            );
        }
        catch (Exception ex)
        {
            ModelState.AddModelError(string.Empty, ex.Message);
            await ReloadGenusNameAsync(id);
            return Page();
        }

        return Redirect(ReturnUrl ?? Url.Page("/Setup/Taxa/Details", new { id })!);
    }

    private async Task ReloadGenusNameAsync(int taxonId)
    {
        GenusName = await _db.Taxa
            .Where(t => t.TaxonId == taxonId)
            .Join(
                _db.Genera,
                t => t.GenusId,
                g => g.GenusId,
                (t, g) => g.Name
            )
            .SingleOrDefaultAsync()
            ?? "(unknown genus)";
    }
}