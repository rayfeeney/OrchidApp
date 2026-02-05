using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.EntityFrameworkCore;
using OrchidApp.Web.Data;
using OrchidApp.Web.Models;

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

    public List<PlantCurrentLocation> Plants { get; private set; } = new();

    public async Task OnGetAsync(int taxonId)
    {
        TaxonId = taxonId;

        Plants = await _db.PlantCurrentLocations
            .Where(p => p.TaxonId == taxonId)
            .OrderBy(p => p.LocationName)
            .ThenBy(p => p.PlantTag)
            .ToListAsync();

        DisplayName = Plants.FirstOrDefault()?.DisplayName ?? string.Empty;
    }
}
