using Microsoft.AspNetCore.Mvc.RazorPages;
using OrchidApp.Web.Data;
using OrchidApp.Web.Models;
using Microsoft.AspNetCore.Mvc;

namespace OrchidApp.Web.Pages.Setup.Taxa;

public class IndexModel : PageModel
{
    [BindProperty(SupportsGet = true)]
    public string? ReturnUrl { get; set; }

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
