using Microsoft.AspNetCore.Mvc.RazorPages;
using OrchidApp.Web.Data;
using Microsoft.AspNetCore.Mvc;
using System.Linq;

namespace OrchidApp.Web.Pages.Plants;

public class IndexModel : PageModel
{
    [BindProperty(SupportsGet = true)]
    public string? ReturnUrl { get; set; }

    private readonly OrchidDbContext _db;

    public IndexModel(OrchidDbContext db)
    {
        _db = db;
    }

    public List<TaxonPlantCount> Taxa { get; private set; } = [];

    public void OnGet()
    {
        Taxa =
            _db.PlantActiveSummaries
            .GroupBy(p => new
            {
                p.TaxonId,
                p.DisplayName,
                p.GenusName,
                p.GenusIsActive,
                p.TaxonIsActive
            })
            .Select(grp => new TaxonPlantCount
            {
                TaxonId = grp.Key.TaxonId,
                DisplayName = grp.Key.DisplayName,
                GenusName = grp.Key.GenusName,
                GenusIsActive = grp.Key.GenusIsActive,
                TaxonIsActive = grp.Key.TaxonIsActive,
                PlantCount = grp.Count()
            })
            .OrderBy(x => x.GenusName)
            .ThenBy(x => x.DisplayName)
            .ToList();
    }

    public class TaxonPlantCount
    {
        public int TaxonId { get; set; }
        public string DisplayName { get; set; } = string.Empty;
        public string GenusName { get; set; } = string.Empty;
        public bool GenusIsActive { get; set; }
        public bool TaxonIsActive { get; set; }
        public int PlantCount { get; set; }
    }

}