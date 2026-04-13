using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.EntityFrameworkCore;
using OrchidApp.Web.Data;
using OrchidApp.Web.Models;

namespace OrchidApp.Web.Pages.Plants;

public class LineageModel : PageModel
{
    private readonly OrchidDbContext _db;

    public LineageModel(OrchidDbContext db)
    {
        _db = db;
    }

    [FromRoute]
    public int PlantId { get; set; }
    public PlantStatus? CurrentPlant { get; private set; }
    public PlantStatus CurrentPlantRequired
        => CurrentPlant ?? throw new InvalidOperationException("Plant must be loaded.");
    public bool IsInactive => !CurrentPlantRequired.GenusIsActive || !CurrentPlantRequired.TaxonIsActive;
    public bool IsEnded => CurrentPlantRequired.EndDate != null;

    public List<LineageItem> Lineage { get; private set; } = [];

    [BindProperty(SupportsGet = true)]
    public string? ReturnUrl { get; set; }

    public async Task<IActionResult> OnGetAsync()
    {
        Lineage = await _db.LineageItems
            .FromSqlRaw("CALL spGetPlantLineage({0})", PlantId)
            .ToListAsync();

        if (!Lineage.Any())
            return NotFound();

        CurrentPlant = await _db.PlantStatuses
            .FirstOrDefaultAsync(p => p.PlantId == PlantId);

        if (CurrentPlant == null)
            return NotFound();

        var allChildren = await _db.PlantSplitChildren
            .ToListAsync();

        for (int i = 0; i < Lineage.Count - 1; i++)
        {
            var current = Lineage[i];        // child in lineage
            var parent = Lineage[i + 1];     // where split occurred

            current.Children = allChildren
                .Where(c => c.ParentPlantId == parent.PlantId)
                .Select(c => new ChildPlantLink
                {
                    PlantId = c.ChildPlantId,
                    PlantTag = c.PlantTag ?? ""
                })
                .ToList();
        }

        return Page();
    }
}