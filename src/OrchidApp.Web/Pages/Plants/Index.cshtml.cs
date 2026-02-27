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
            (from p in _db.PlantActiveSummaries
             join t in _db.Taxa on p.TaxonId equals t.TaxonId
             join g in _db.Genera on t.GenusId equals g.GenusId
             group p by new
             {
                 p.TaxonId,
                 p.DisplayName,
                 GenusName = g.Name
             }
             into grp
             select new TaxonPlantCount
             {
                 TaxonId = grp.Key.TaxonId,
                 DisplayName = grp.Key.DisplayName,
                 GenusName = grp.Key.GenusName,
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
        public int PlantCount { get; set; }
    }
}