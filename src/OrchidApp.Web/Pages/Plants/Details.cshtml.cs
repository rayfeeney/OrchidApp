using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using OrchidApp.Web.Data;
using OrchidApp.Web.Models;
using System;
using OrchidApp.Web.Services;

namespace OrchidApp.Web.Pages.Plants;

public class DetailsModel : PageModel
{
    [BindProperty(SupportsGet = true)]
    public string? ReturnUrl { get; set; }

    private readonly OrchidDbContext _db;

    public DetailsModel(OrchidDbContext db, PhotoUrlService photoUrlService)
    {
        _db = db;
        _photoUrlService = photoUrlService;
    }

    [FromRoute]
    public int PlantId { get; set; }

    public PlantStatus? Status { get; private set; }
    public List<PlantLifecycleEvent> LifecycleEvents { get; private set; } = [];
    public string? HeroFileName { get; private set; }
    public bool GenusIsActive { get; private set; }
    public bool TaxonIsActive { get; private set; }
    public PhotoUrlService PhotoUrlService => _photoUrlService;
    public bool IsInactive => !GenusIsActive || !TaxonIsActive;
    public bool IsEnded => StatusRequired.EndDate != null;

    public List<PlantSplitChildren> ChildPlants { get; private set; } = [];
    public PlantStatus StatusRequired
        => Status ?? throw new InvalidOperationException("Plant status must be loaded before rendering the page.");
    private readonly PhotoUrlService _photoUrlService;

    public class ChildPlantLink
    {
        public int ParentPlantId { get; set; }
        public int ChildPlantId { get; set; }
        public string ChildPlantTag { get; set; } = "";
    }

    public IActionResult OnGet()
    {
        Status = _db.PlantStatuses
            .FirstOrDefault(p => p.PlantId == PlantId);

        if (Status == null)
            return NotFound();

        GenusIsActive = StatusRequired.GenusIsActive;
        TaxonIsActive = StatusRequired.TaxonIsActive;

        HeroFileName = _db.PlantPhotos
            .Where(p => p.PlantId == PlantId && p.IsHero && p.IsActive)
            .Select(p => p.FileName)
            .FirstOrDefault();

        LifecycleEvents = _db.PlantLifecycleHistory
            .Where(e => e.PlantId == PlantId)
            .OrderByDescending(e => e.EventDateTime)
            .ThenByDescending(e => e.SourceId)
            .ToList();

        ChildPlants = _db.PlantSplitChildren
            .Where(c => c.ParentPlantId == PlantId)
            .ToList();

        return Page();
    }
}