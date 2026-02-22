using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using OrchidApp.Web.Data;
using OrchidApp.Web.Models;

namespace OrchidApp.Web.Pages.Setup.Taxa.Actions;

public class RemoveModel : PageModel
{
    [BindProperty(SupportsGet = true)]
    public string? ReturnUrl { get; set; }

    private readonly OrchidDbContext _db;

    public RemoveModel(OrchidDbContext db)
    {
        _db = db;
    }

    public TaxonIdentity? Taxon { get; private set; }

    public IActionResult OnGet(int id)
    {
        Taxon = _db.TaxonIdentities
                   .SingleOrDefault(t => t.TaxonId == id);

        if (Taxon == null)
            return NotFound();

        return Page();
    }

    public IActionResult OnPost(int id)
    {
        var taxon = _db.Taxa.SingleOrDefault(t => t.TaxonId == id);

        if (taxon == null)
            return NotFound();

        taxon.IsActive = false;

        _db.SaveChanges();

        if (!string.IsNullOrWhiteSpace(ReturnUrl))
            return LocalRedirect(ReturnUrl);

        return RedirectToPage("/Setup/Taxa/Details", new { id });
    }
}
