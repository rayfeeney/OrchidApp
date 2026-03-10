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

    public string GenusName { get; set; } = string.Empty;

    public IActionResult OnGet(int id)
    {
        var taxon = _db.Taxa.SingleOrDefault(t => t.TaxonId == id);

        if (taxon == null)
            return NotFound();

        Taxon = taxon;

        GenusName = _db.Genera
            .Where(g => g.GenusId == taxon.GenusId)
            .Select(g => g.Name)
            .Single();

        return Page();
    }

    public IActionResult OnPost(int id)
    {
        if (!ModelState.IsValid)
        {
            ReloadGenusName();
            return Page();
        }

        try
        {
            _db.Database.ExecuteSqlRaw(
                "CALL spUpdateTaxonDetails({0}, {1}, {2}, {3}, {4}, {5})",
                id,
                Taxon.SpeciesName,
                Taxon.HybridName,
                Taxon.GrowthCode,
                Taxon.GrowthNotes,
                Taxon.TaxonNotes
            );
        }
        catch (DbUpdateException ex)
        {
            ModelState.AddModelError(string.Empty, ex.InnerException?.Message ?? ex.Message);
            ReloadGenusName();
            return Page();
        }
        catch (Exception ex)
        {
            ModelState.AddModelError(string.Empty, ex.Message);
            ReloadGenusName();
            return Page();
        }

        return Redirect(ReturnUrl ?? Url.Page("/Setup/Taxa/Details", new { id })!);
    }

    private void ReloadGenusName()
    {
        GenusName = _db.Genera
            .Where(g => g.GenusId == Taxon.GenusId)
            .Select(g => g.Name)
            .Single();
    }
}