using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using OrchidApp.Web.Data;
using OrchidApp.Web.Models;

namespace OrchidApp.Web.Pages.Setup.Taxa;

public class DetailsModel : PageModel
{
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
}
