using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using OrchidApp.Web.Data;
using OrchidApp.Web.Models;
using System.Linq;
using Microsoft.EntityFrameworkCore;
using System.Data;
using System.Data.Common;
using OrchidApp.Web.Infrastructure;

namespace OrchidApp.Web.Pages.Plants.Events;

/*
    REMOVE LIFECYCLE EVENTS — DESIGN NOTES

    Lifecycle events are removed differently depending on
    their semantic role in the system.

    Tables involved:
    - plantevent              → Observations (atomic)
    - repotting               → Repotting events (atomic)
    - flowering               → Flowering events (atomic)
    - plantlocationhistory    → Location changes (structural)
    - vplantlifecyclehistory  → Read-only UNION for display

    There are TWO categories of removal:

    1) ATOMIC EVENTS
       Tables:
       - plantevent
       - repotting
       - flowering

       Removal semantics:
       - Represents invalidating a single fact
       - No other records are affected
       - Implemented by setting isActive = 0
       - Safe to perform directly via EF Core

       These events do NOT participate in a continuous or
       exclusive timeline, so removal is local and isolated.

    2) STRUCTURAL EVENTS
       Table:
       - plantlocationhistory

       Removal semantics:
       - Represents invalidating a location history record
       - Neighbouring rows may need to be re-stitched
       - Timeline continuity and invariants must be preserved
       - Removal may reopen or adjust adjacent records

       Therefore:
       - LocationChange removal is handled exclusively
         via stored procedures
       - All validation and stitching occurs in SQL
       - The UI performs no compensation logic

    This PageModel acts as a DISPATCHER:
    - It branches by EventType (from vplantlifecyclehistory)
    - Atomic events are removed via EF Core
    - LocationChange removal is delegated to SQL

    Do NOT unify removal logic across event types.
    The difference is semantic, not accidental.
*/

public class RemoveModel : PageModel
{
    [BindProperty(SupportsGet = true)]
    public string? ReturnUrl { get; set; }

    private readonly OrchidDbContext _db;

    public RemoveModel(OrchidDbContext db)
    {
        _db = db;
    }

    [FromRoute]
    public int SourceId { get; set; }

    [FromRoute]
    public int PlantId { get; set; }

    [FromQuery]
    public string EventType { get; set; } = string.Empty;
    public bool GenusIsActive { get; private set; }
    public bool TaxonIsActive { get; private set; }
    public bool IsInactive => !GenusIsActive || !TaxonIsActive;

    public string? PlantDisplayName { get; private set; }
    public string? PlantTag { get; private set; }

    public PlantLifecycleEvent? Event { get; private set; }

    public IActionResult OnGet()
    {
        if (_db.Plants.Any(p => p.PlantId == PlantId && p.EndDate != null))
            return RedirectToPage("/Plants/Details", new { plantId = PlantId });
        // Load plant context + taxonomy state FIRST
        var plant = _db.PlantActiveSummaries
            .FirstOrDefault(p => p.PlantId == PlantId);

        if (plant != null)
        {
            PlantDisplayName = plant.DisplayName;
            PlantTag = plant.PlantTag;

            var taxon = _db.TaxonIdentities
                .Where(t => t.TaxonId == plant.TaxonId)
                .Select(t => new
                {
                    t.GenusIsActive,
                    t.TaxonIsActive
                })
                .Single();

            GenusIsActive = taxon.GenusIsActive;
            TaxonIsActive = taxon.TaxonIsActive;
        }

        // THEN load lifecycle event
        Event = EventType switch
        {
            "Observation" =>
                _db.PlantLifecycleHistory.FirstOrDefault(e =>
                    e.SourceId == SourceId &&
                    e.SourceTable == "plantevent" && e.PlantId == PlantId),

            "LocationChange" =>
                _db.PlantLifecycleHistory.FirstOrDefault(e =>
                    e.SourceId == SourceId &&
                    e.SourceTable == "plantlocationhistory" && e.PlantId == PlantId),

            "Flowering" =>
                _db.PlantLifecycleHistory.FirstOrDefault(e =>
                    e.SourceId == SourceId &&
                    e.SourceTable == "flowering" && e.PlantId == PlantId),

            "Repotting" =>
                _db.PlantLifecycleHistory.FirstOrDefault(e =>
                    e.SourceId == SourceId &&
                    e.SourceTable == "repotting" && e.PlantId == PlantId),

            _ => null
        };

        if (Event == null)
            return NotFound();

        return Page();
    }

    public async Task<IActionResult> OnPostAsync()
    {
        var plant = await _db.Plants.AsNoTracking().SingleOrDefaultAsync(p => p.PlantId == PlantId);
        if (plant == null) return NotFound();
        if (plant.EndDate != null) return BadRequest("Ended plants are read-only.");
        var table = EventType switch {
            "Observation" => "plantevent", "LocationChange" => "plantlocationhistory",
            "Flowering" => "flowering", "Repotting" => "repotting", _ => null };
        if (table == null || !await _db.PlantLifecycleHistory.AnyAsync(e =>
                e.PlantId == PlantId && e.SourceId == SourceId && e.SourceTable == table)) return NotFound();
        switch (EventType)
        {
            case "Observation":
            {
                var plantEvent = await _db.PlantEvent
                    .FirstOrDefaultAsync(e => e.PlantEventId == SourceId && e.PlantId == PlantId);

                if (plantEvent == null)
                    return NotFound();

                plantEvent.IsActive = false;
                await _db.SaveChangesAsync();
                break;
            }

            case "LocationChange":
            {
                try
                {
                    await _db.Database.ExecuteSqlRawAsync(
                        "CALL spRemovePlantLocation({0});",
                        SourceId);
                }
                catch (Exception ex) when (DatabaseErrorTranslator.TryTranslate(ex, out var msg))
                {
                    ModelState.AddModelError(string.Empty, msg);

                    Event = await _db.PlantLifecycleHistory
                        .FirstOrDefaultAsync(e =>
                            e.SourceId == SourceId &&
                            e.SourceTable == "plantlocationhistory" && e.PlantId == PlantId);

                    return Page();
                }
                break;
            }

            case "Flowering":
            {
                var flowering = await _db.Flowering
                    .FirstOrDefaultAsync(f =>
                        f.FloweringId == SourceId &&
                        f.PlantId == PlantId &&
                        f.IsActive);

                if (flowering == null)
                    return NotFound();

                flowering.IsActive = false;
                await _db.SaveChangesAsync();
                break;
            }

            case "Repotting":
            {
                var repotting = await _db.Repotting
                    .FirstOrDefaultAsync(r =>
                        r.RepottingId == SourceId &&
                        r.PlantId == PlantId && r.IsActive);

                if (repotting == null)
                    return NotFound();

                repotting.IsActive = false;
                await _db.SaveChangesAsync();
                break;
            }

            default:
                return NotFound();
        }

        return LocalRedirect(OrchidApp.Web.Services.AppNavigation.AfterSave(ReturnUrl,
            Url.Page("/Plants/Details", new { plantId = PlantId })!, Url.Page("/Plants/Index")!));
    }

}
