using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.EntityFrameworkCore;
using OrchidApp.Web.Data;
using OrchidApp.Web.Models;

namespace OrchidApp.Web.Pages.Plants;

public class TaxonModel : PageModel
{
    [BindProperty(SupportsGet = true)]
    public string? ReturnUrl { get; set; }

    private readonly OrchidDbContext _db;

    public TaxonModel(OrchidDbContext db)
    {
        _db = db;
    }

    [FromRoute]
    public int TaxonId { get; set; }

    public string DisplayName { get; private set; } = string.Empty;

    public bool GenusIsActive { get; private set; }
    public bool TaxonIsActive { get; private set; }

    public List<PlantActiveCurrentLocation> Plants { get; private set; } = new();

    public async Task OnGetAsync(int taxonId)
    {
        TaxonId = taxonId;

        var taxon = await _db.TaxonIdentities
            .Where(t => t.TaxonId == taxonId)
            .SingleAsync();

        DisplayName = taxon.DisplayName;
        GenusIsActive = taxon.GenusIsActive;
        TaxonIsActive = taxon.TaxonIsActive;

        Plants = await _db.PlantActiveCurrentLocations
            .Where(p => p.TaxonId == taxonId)
            .OrderBy(p => p.LocationName)
            .ThenBy(p => p.PlantTag)
            .ToListAsync();
    }
}