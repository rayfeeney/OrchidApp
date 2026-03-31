using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using OrchidApp.Web.Data;
using System;
using System.ComponentModel.DataAnnotations;
using System.Data;
using System.Data.Common;
using System.Linq;
using Microsoft.EntityFrameworkCore;
using OrchidApp.Web.Models;
using System.Threading.Tasks;
using OrchidApp.Web.Infrastructure;

namespace OrchidApp.Web.Pages.Plants.Events;

/*
    EDIT LIFECYCLE EVENTS — DESIGN NOTES

    Lifecycle events in OrchidApp are intentionally stored in
    DIFFERENT TABLES based on their semantics.

    Tables involved:
    - plantevent              → Observations (atomic)
    - repotting               → Repotting events (atomic)
    - flowering               → Flowering events (atomic, bounded)
    - plantlocationhistory    → Location changes (structural)
    - vplantlifecyclehistory  → Read-only UNION of all lifecycle events

    There are TWO categories of events:

    1) ATOMIC EVENTS
       Tables:
       - plantevent
       - repotting
       - flowering

       Characteristics:
       - Stand-alone facts
       - Editing affects only the row itself
       - No temporal stitching
       - No exclusivity invariants
       - Safe to edit via EF Core
       - Remove = mark isActive = 0

       Notes:
       - Atomic events may have multiple fields (e.g. repotting notes,
         flowering counts and date ranges) but do not participate in
         a continuous or exclusive timeline.

    2) STRUCTURAL EVENTS
       Table:
       - plantlocationhistory

       Characteristics:
       - Participates in an exclusive, continuous timeline per plant
       - Zero or one "current" row allowed
       - Neighbouring rows matter
       - Invariants must be preserved
       - All persistence handled via stored procedures
       - Edit semantics are constrained and local by design

    This PageModel acts as a DISPATCHER:
    - It branches by EventType (from vplantlifecyclehistory)
    - Each case owns its own persistence semantics
    - EF Core is used only for atomic tables
    - Stored procedures are mandatory for location changes

    Do NOT attempt to unify edit logic across event types.
    The separation is intentional and reflects the domain.
*/

public class EditModel : PageModel
{
    [BindProperty(SupportsGet = true)]
    public string? ReturnUrl { get; set; }

    private readonly OrchidDbContext _db;

    public EditModel(OrchidDbContext db)
    {
        _db = db;
    }

    [FromRoute]
    public int PlantId { get; set; }

    [FromRoute]
    public int SourceId { get; set; }

    [BindProperty(SupportsGet = true)]
    public string EventType { get; set; } = string.Empty;

    [BindProperty]
    public DateTime EventDate { get; set; }

    [BindProperty]
    public string? EventDetails { get; set; } // = string.Empty;

    // Location change-specific fields
    [BindProperty]
    public string? PlantLocationNotes { get; set; }

    // Flowering-specific fields

    [BindProperty]
    [DataType(DataType.Date)]
    public DateTime? EndDate { get; set; }

    [BindProperty]
    public int? SpikeCount { get; set; }

    [BindProperty]
    public int? FlowerCount { get; set; }

    // Repotting-specific fields
    [BindProperty] public int? OldGrowthMediumId { get; set; }
    [BindProperty] public int? NewGrowthMediumId { get; set; }
    [BindProperty] public string? OldMediumNotes { get; set; }
    [BindProperty] public string? NewMediumNotes { get; set; }
    [BindProperty] public string? PotSize { get; set; }
    [BindProperty] public string? RepotReasonNotes { get; set; }
    [BindProperty] public string? RepottingNotes { get; set; }

    public string? PlantDisplayName { get; private set; }
    public string? PlantTag { get; private set; }
    public bool GenusIsActive { get; private set; }
    public bool TaxonIsActive { get; private set; }
    public bool IsInactive => !GenusIsActive || !TaxonIsActive;
    public List<GrowthMedium> GrowthMedia { get; private set; } = new();

    private IActionResult ReloadPage()
    {
        var plant = _db.PlantActiveSummaries.FirstOrDefault(p => p.PlantId == PlantId);
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

        if (EventType == "Repotting")
        {
            GrowthMedia = _db.GrowthMedia
                .Where(g => g.IsActive
                    || g.GrowthMediumId == OldGrowthMediumId
                    || g.GrowthMediumId == NewGrowthMediumId)
                .OrderBy(g => g.Name)
                .ToList();
        }

        return Page();
    }

    public async Task<IActionResult> OnGetAsync()
    {
        // Plant context
        var plant = _db.PlantActiveSummaries.FirstOrDefault(p => p.PlantId == PlantId);
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

        // Identify lifecycle event
        if (string.IsNullOrWhiteSpace(EventType))
            return NotFound();

        // Dispatch by EventType: each case owns its own persistence semantics
        switch (EventType)
        {
            case "Observation":
                var observation = _db.PlantEvent
                    .FirstOrDefault(e => e.PlantEventId == SourceId && e.IsActive);

                if (observation == null)
                    return NotFound();

                EventDate = observation.EventDateTime.Date;
                EventDetails = observation.EventDetails ?? string.Empty;
                break;

            case "LocationChange":
            {
                var row = await _db.LocationChangeEditRows
                    .FromSqlRaw(
                        @"SELECT 
                            plantLocationHistoryId,
                            startDateTime,
                            moveReasonNotes,
                            plantLocationNotes
                        FROM plantlocationhistory
                        WHERE plantLocationHistoryId = {0}
                            AND isActive = 1",
                        SourceId)
                    .AsNoTracking()
                    .SingleOrDefaultAsync();

                if (row == null)
                    return NotFound();

                EventDate = row.StartDateTime;
                EventDetails = row.MoveReasonNotes ?? string.Empty;
                PlantLocationNotes = row.PlantLocationNotes ?? string.Empty;

                break;
            }

            case "Flowering":

                var flowering = _db.Flowering
                    .FirstOrDefault(f =>
                        f.FloweringId == SourceId &&
                        f.PlantId == PlantId &&
                        f.IsActive);

                if (flowering == null)
                    return NotFound();

                EventDate   = flowering.StartDate;
                EndDate     = flowering.EndDate;
                SpikeCount  = flowering.SpikeCount;
                FlowerCount = flowering.FlowerCount;
                EventDetails = flowering.FloweringNotes;

                break;

            case "Repotting":

                var repotting = _db.Repotting
                    .FirstOrDefault(r => r.RepottingId == SourceId && r.IsActive);

                if (repotting == null)
                {
                    return NotFound();
                }

                EventDate = repotting.RepotDate;
                OldGrowthMediumId = repotting.OldGrowthMediumId;
                NewGrowthMediumId = repotting.NewGrowthMediumId;
                OldMediumNotes = repotting.OldMediumNotes;
                NewMediumNotes = repotting.NewMediumNotes;
                PotSize = repotting.PotSize;
                RepotReasonNotes = repotting.RepotReasonNotes;
                RepottingNotes = repotting.RepottingNotes;

                GrowthMedia = _db.GrowthMedia
                    .Where(g => g.IsActive
                        || g.GrowthMediumId == OldGrowthMediumId
                        || g.GrowthMediumId == NewGrowthMediumId)
                    .OrderBy(g => g.Name)
                    .ToList();

                break;

                default:
                    return NotFound();
        
        }

        return Page();
    }

    public async Task<IActionResult> OnPostAsync()
    {
        var plant = await _db.Plants
            .AsNoTracking()
            .Where(p => p.PlantId == PlantId)
            .Select(p => new { p.AcquisitionDate, p.EndDate })
            .SingleAsync();

        var eventDate = EventDate.Date;

        switch (EventType)
        {
            case "Observation":
                var observation = _db.PlantEvent
                    .FirstOrDefault(e => e.PlantEventId == SourceId && e.IsActive);

                if (observation == null)
                    return NotFound();

                // future
                if (eventDate > DateTime.Today)
                {
                    ModelState.AddModelError(nameof(EventDate),
                        "Observation date cannot be in the future.");
                }

                // before acquisition
                if (plant.AcquisitionDate.HasValue &&
                    eventDate < plant.AcquisitionDate.Value.Date)
                {
                    ModelState.AddModelError(nameof(EventDate),
                        "Observation date cannot be before the plant was acquired.");
                }

                // after end
                if (plant.EndDate.HasValue &&
                    eventDate > plant.EndDate.Value.Date)
                {
                    ModelState.AddModelError(nameof(EventDate),
                        "Observation date cannot be after the plant has ended.");
                }

                if (!ModelState.IsValid)
                    return ReloadPage();

                observation.EventDateTime = EventDate.Date.Add(observation.EventDateTime.TimeOfDay);
                observation.EventDetails = EventDetails;
                await _db.SaveChangesAsync();
                break;

            case "LocationChange":

                // =========================
                // Lifecycle validation (same as Add)
                // =========================

                // future
                if (eventDate > DateTime.Today)
                {
                    ModelState.AddModelError(nameof(EventDate),
                        "Move date cannot be in the future.");
                }

                // before acquisition
                if (plant.AcquisitionDate.HasValue &&
                    eventDate < plant.AcquisitionDate.Value.Date)
                {
                    ModelState.AddModelError(nameof(EventDate),
                        "Move date cannot be before the plant was acquired.");
                }

                // after end
                if (plant.EndDate.HasValue &&
                    eventDate > plant.EndDate.Value.Date)
                {
                    ModelState.AddModelError(nameof(EventDate),
                        "Move date cannot be after the plant has ended.");
                }

                if (!ModelState.IsValid)
                    return ReloadPage();

                // =========================
                // Call stored procedure
                // =========================

                try
                {
                    var parameters = new object?[]
                    {
                        SourceId,
                        eventDate,
                        string.IsNullOrWhiteSpace(EventDetails) ? null : EventDetails,
                        string.IsNullOrWhiteSpace(PlantLocationNotes) ? null : PlantLocationNotes
                    };

                    await _db.Database.ExecuteSqlRawAsync(
                        @"CALL spEditPlantLocation({0}, {1}, {2}, {3})",
                        parameters!);
                }
                catch (Exception ex) when (DatabaseErrorTranslator.TryTranslate(ex, out var msg))
                {
                    ModelState.AddModelError(string.Empty, msg);
                    return ReloadPage();
                }

                break;

            case "Flowering":

                var flowering = _db.Flowering
                    .FirstOrDefault(f =>
                        f.FloweringId == SourceId &&
                        f.PlantId == PlantId &&
                        f.IsActive);

                if (flowering == null)
                    return NotFound();

                flowering.StartDate   = new DateTime(
												EventDate.Year,
												EventDate.Month,
												EventDate.Day,
												DateTime.Now.Hour,
												DateTime.Now.Minute,
												DateTime.Now.Second);
                flowering.EndDate     = EndDate.HasValue
												? new DateTime(
													EndDate.Value.Year,
													EndDate.Value.Month,
													EndDate.Value.Day,
													DateTime.Now.Hour,
													DateTime.Now.Minute,
													DateTime.Now.Second)
												: null;
                flowering.SpikeCount  = SpikeCount;
                flowering.FlowerCount = FlowerCount;
                flowering.FloweringNotes =
                    string.IsNullOrWhiteSpace(EventDetails)
                        ? null
                        : EventDetails;

                await _db.SaveChangesAsync();

                break;

            case "Repotting":

                var repotting = _db.Repotting
                    .FirstOrDefault(r => r.RepottingId == SourceId && r.IsActive);

                if (repotting == null)
                {
                    return NotFound();
                }

                repotting.RepotDate = new DateTime(
												EventDate.Year,
												EventDate.Month,
												EventDate.Day,
												DateTime.Now.Hour,
												DateTime.Now.Minute,
												DateTime.Now.Second);
                repotting.OldGrowthMediumId = OldGrowthMediumId;
                repotting.NewGrowthMediumId = NewGrowthMediumId;
                repotting.OldMediumNotes = string.IsNullOrWhiteSpace(OldMediumNotes) ? null : OldMediumNotes;
                repotting.NewMediumNotes = string.IsNullOrWhiteSpace(NewMediumNotes) ? null : NewMediumNotes;
                repotting.PotSize = string.IsNullOrWhiteSpace(PotSize) ? null : PotSize;
                repotting.RepotReasonNotes = string.IsNullOrWhiteSpace(RepotReasonNotes) ? null : RepotReasonNotes;
                repotting.RepottingNotes = string.IsNullOrWhiteSpace(RepottingNotes) ? null : RepottingNotes;

                await _db.SaveChangesAsync();
                break;

            default:
                return NotFound();
        }

        return RedirectToPage("/Plants/Details", new { plantId = PlantId });
    }
}
