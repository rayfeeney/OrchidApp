using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using OrchidApp.Web.Data;
using OrchidApp.Web.Models;
using System;

namespace OrchidApp.Web.Pages.Plants;

public class DetailsModel : PageModel
{
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


    // Non-nullable wrapper for Razor (invariant)
    public PlantCurrentLocation PlantRequired
        => Plant ?? throw new InvalidOperationException("Plant must be loaded before rendering the page.");

    public IActionResult OnGet()
    {
        Plant = _db.PlantCurrentLocations
                .FirstOrDefault(p => p.PlantId == PlantId);

        var heroPhoto = _db.PlantPhotos
            .Where(p => p.PlantId == PlantId && p.IsHero && p.IsActive)
            .Select(p => p.FilePath)
            .FirstOrDefault();

        HeroImagePath = heroPhoto;

        if (Plant == null)
        {
            return NotFound();
        }

        LifecycleEvents = _db.PlantLifecycleHistory
            .Where(e => e.PlantId == PlantId)
            .OrderByDescending(e => e.EventDateTime)
            .ToList();

        return Page();
    }

}
