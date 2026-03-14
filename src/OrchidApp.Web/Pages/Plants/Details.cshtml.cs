using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using OrchidApp.Web.Data;
using OrchidApp.Web.Models;
using System;

namespace OrchidApp.Web.Pages.Plants;

public class DetailsModel : PageModel
{
    [BindProperty(SupportsGet = true)]
    public string? ReturnUrl { get; set; }

    private readonly OrchidDbContext _db;

    public DetailsModel(OrchidDbContext db)
    {
        _db = db;
    }

    [FromRoute]
    public int PlantId { get; set; }

    // Nullable backing property (truthful)
    public PlantCurrentLocation? Plant { get; private set; }
    public List<PlantLifecycleEvent> LifecycleEvents { get; private set; } = [];
    public string? HeroImagePath { get; private set; }
    public bool GenusIsActive { get; private set; }
    public bool TaxonIsActive { get; private set; }

    public bool IsInactive => !GenusIsActive || !TaxonIsActive;

    // Non-nullable wrapper for Razor (invariant)
    public PlantCurrentLocation PlantRequired
        => Plant ?? throw new InvalidOperationException("Plant must be loaded before rendering the page.");

    public IActionResult OnGet()
    {
        Plant = _db.PlantCurrentLocations
                .FirstOrDefault(p => p.PlantId == PlantId);

        if (Plant == null)
            return NotFound();

        var taxon = _db.TaxonIdentities
            .Where(t => t.TaxonId == Plant.TaxonId)
            .Select(t => new
            {
                t.GenusIsActive,
                t.TaxonIsActive
            })
            .Single();

        GenusIsActive = taxon.GenusIsActive;
        TaxonIsActive = taxon.TaxonIsActive;

        var heroPhoto = _db.PlantPhotos
            .Where(p => p.PlantId == PlantId && p.IsHero && p.IsActive)
            .Select(p => p.FilePath)
            .FirstOrDefault();

        HeroImagePath = heroPhoto;

        LifecycleEvents = _db.PlantLifecycleHistory
            .Where(e => e.PlantId == PlantId)
            .OrderByDescending(e => e.EventDateTime)
            .ThenByDescending(e => e.SourceId)
            .ToList();

        return Page();
    }

}
