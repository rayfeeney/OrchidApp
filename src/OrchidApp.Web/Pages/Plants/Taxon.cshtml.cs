using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.EntityFrameworkCore;
using OrchidApp.Web.Data;
using OrchidApp.Web.Models;
using OrchidApp.Web.Services;

namespace OrchidApp.Web.Pages.Plants;

public class TaxonModel : PageModel
{
    [BindProperty(SupportsGet = true)]
    public string? ReturnUrl { get; set; }
    [BindProperty(SupportsGet = true)]
    public int? SelectedPlantId { get; set; }

    private readonly OrchidDbContext _db;
    private readonly PhotoUrlService _photoUrlService;
    public TaxonModel(OrchidDbContext db, PhotoUrlService photoUrlService)
    {
        _db = db;
        _photoUrlService = photoUrlService;
    }

    [FromRoute]
    public int TaxonId { get; set; }

    public string DisplayName { get; private set; } = string.Empty;

    public bool GenusIsActive { get; private set; }
    public bool TaxonIsActive { get; private set; }
    public PhotoUrlService PhotoUrlService => _photoUrlService;
    public bool IsInactive => !GenusIsActive || !TaxonIsActive;

    public List<PlantActiveCurrentLocation> Plants { get; private set; } = new();

    public async Task OnGetAsync(int taxonId)
    {
        TaxonId = taxonId;

        var taxon = await _db.TaxonIdentities
            .Where(t => t.TaxonId == taxonId)
            .Select(t => new
            {
                t.DisplayName,
                t.TaxonIsActive,
                t.GenusIsActive
            })
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