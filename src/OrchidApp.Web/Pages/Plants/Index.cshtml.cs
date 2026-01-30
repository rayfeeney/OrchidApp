using Microsoft.AspNetCore.Mvc.RazorPages;
using OrchidApp.Web.Data;
using System.Linq;

namespace OrchidApp.Web.Pages.Plants;

public class IndexModel : PageModel
{
    private readonly OrchidDbContext _db;

    public IndexModel(OrchidDbContext db)
    {
        _db = db;
    }

    public List<TaxonPlantCount> Taxa { get; private set; } = [];

    public void OnGet()
    {
        Taxa = _db.PlantActiveSummaries
                  .GroupBy(p => new
                  {
                      p.TaxonId,
                      p.DisplayName
                  })
                  .Select(g => new TaxonPlantCount
                  {
                      TaxonId = g.Key.TaxonId,
                      DisplayName = g.Key.DisplayName,
                      PlantCount = g.Count()
                  })
                  .OrderBy(t => t.DisplayName)
                  .ToList();
    }

    public class TaxonPlantCount
    {
        public int TaxonId { get; set; }
        public string DisplayName { get; set; } = string.Empty;
        public int PlantCount { get; set; }
    }
}
