using Microsoft.AspNetCore.Mvc.RazorPages;
using OrchidApp.Web.Data;
using OrchidApp.Web.Models;
using Microsoft.EntityFrameworkCore;

namespace OrchidApp.Web.Pages.Plants.Add;

public class IndexModel : PageModel
{
    private readonly OrchidDbContext _db;

    public IndexModel(OrchidDbContext db)
    {
        _db = db;
    }

    public IList<TaxonIdentity> Taxa { get; private set; } = new List<TaxonIdentity>();

    public async Task OnGetAsync()
    {
        Taxa = await _db.TaxonIdentities
            .Where(t => t.IsActive)
            .OrderBy(t => t.GenusName)
            .ThenBy(t => t.SpeciesName)
            .ThenBy(t => t.HybridName)
            .ToListAsync();
    }
}
