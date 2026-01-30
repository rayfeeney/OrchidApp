using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using OrchidApp.Web.Data;
using OrchidApp.Web.Models;
using System.Linq;

namespace OrchidApp.Web.Pages.Plants;

public class TaxonModel : PageModel
{
    private readonly OrchidDbContext _db;

    public TaxonModel(OrchidDbContext db)
    {
        _db = db;
    }

    [FromRoute]
    public int TaxonId { get; set; }

    public string DisplayName { get; private set; } = string.Empty;

    public List<PlantActiveSummary> Plants { get; private set; } = [];

    public IActionResult OnGet()
    {
        Plants = _db.PlantActiveSummaries
                    .Where(p => p.TaxonId == TaxonId)
                    .OrderBy(p => p.PlantTag)
                    .ToList();

        if (Plants.Count == 0)
        {
            return NotFound();
        }

        DisplayName = Plants.First().DisplayName;

        return Page();
    }
}
