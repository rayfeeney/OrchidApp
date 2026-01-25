using Microsoft.AspNetCore.Mvc.RazorPages;
using OrchidApp.Web.Data;
using OrchidApp.Web.Models;

namespace OrchidApp.Web.Pages.Taxa;

public class IndexModel : PageModel
{
    private readonly OrchidDbContext _db;

    public IndexModel(OrchidDbContext db)
    {
        _db = db;
    }

    public IReadOnlyList<TaxonIdentity> Taxa { get; private set; } = [];

    public void OnGet()
    {
        Taxa = _db.TaxonIdentities
                  .OrderBy(t => t.GenusName)
                  .ThenBy(t => t.DisplayName)
                  .ToList();
    }
}
