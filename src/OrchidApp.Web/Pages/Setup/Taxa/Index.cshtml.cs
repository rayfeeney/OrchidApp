using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.EntityFrameworkCore;
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

    public IReadOnlyList<TaxonIdentity> Taxa { get; private set; }
        = new List<TaxonIdentity>();

    public async Task OnGetAsync()
    {
        Taxa = await (
            from t in _db.TaxonIdentities.AsNoTracking()

            join p in _db.TaxonPhotos
                .Where(p => p.IsActive && p.IsPrimary)
                on t.TaxonId equals p.TaxonId into photoGroup

            from p in photoGroup.DefaultIfEmpty()

            orderby t.GenusName, t.DisplayName

            select new TaxonIdentity
            {
                TaxonId = t.TaxonId,
                DisplayName = t.DisplayName,
                GenusName = t.GenusName,
                SpeciesName = t.SpeciesName,
                HybridName = t.HybridName,
                GenusIsActive = t.GenusIsActive,
                TaxonIsActive = t.TaxonIsActive,
                IsSystemManaged = t.IsSystemManaged,
                ThumbnailFileName = p != null ? p.ThumbnailFileName : null
            }
        ).ToListAsync();
    }
}