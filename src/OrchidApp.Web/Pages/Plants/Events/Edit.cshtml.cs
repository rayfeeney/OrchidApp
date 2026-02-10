using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using OrchidApp.Web.Data;
using System;
using System.ComponentModel.DataAnnotations;
using System.Data;
using System.Data.Common;
using System.Linq;
using Microsoft.EntityFrameworkCore;

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
    [BindProperty] public string? OldMediumNotes { get; set; }
    [BindProperty] public string? NewMediumNotes { get; set; }
    [BindProperty] public string? PotSize { get; set; }
    [BindProperty] public string? RepotReasonNotes { get; set; }
    [BindProperty] public string? RepottingNotes { get; set; }

    public string? PlantDisplayName { get; private set; }
    public string? PlantTag { get; private set; }

    public IActionResult OnGet()
    {
        // Plant context
        var plant = _db.PlantActiveSummaries.FirstOrDefault(p => p.PlantId == PlantId);
        if (plant != null)
        {
            PlantDisplayName = plant.DisplayName;
            PlantTag = plant.PlantTag;
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
                using var conn = _db.Database.GetDbConnection();
                using var cmd = conn.CreateCommand();

                cmd.CommandText = @"
                    SELECT startDateTime, moveReasonNotes, plantLocationNotes
                    FROM plantlocationhistory
                    WHERE plantLocationHistoryId = @id
                    AND isActive = 1";

                var pId = cmd.CreateParameter();
                pId.ParameterName = "@id";
                pId.Value = SourceId;
                cmd.Parameters.Add(pId);

                if (conn.State != ConnectionState.Open)
                    conn.Open();

                using var reader = cmd.ExecuteReader();

                if (!reader.Read())
                    return NotFound();

                EventDate = reader.GetDateTime(0);

                EventDetails = reader.IsDBNull(1)
                    ? string.Empty
                    : reader.GetString(1);

                PlantLocationNotes = reader.IsDBNull(2)
                    ? string.Empty
                    : reader.GetString(2);

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
                OldMediumNotes = repotting.OldMediumNotes;
                NewMediumNotes = repotting.NewMediumNotes;
                PotSize = repotting.PotSize;
                RepotReasonNotes = repotting.RepotReasonNotes;
                RepottingNotes = repotting.RepottingNotes;

                break;

                default:
                    return NotFound();
        
        }

        return Page();
    }

    public IActionResult OnPost()
    {
        
        if (!ModelState.IsValid)
            return Page();

        switch (EventType)
        {
            case "Observation":
                var observation = _db.PlantEvent
                    .FirstOrDefault(e => e.PlantEventId == SourceId && e.IsActive);

                if (observation == null)
                    return NotFound();

                observation.EventDateTime = EventDate.Date.Add(DateTime.Now.TimeOfDay);
                observation.EventDetails = EventDetails;
                _db.SaveChanges();
                break;

            case "LocationChange":
                try
                {
                    var conn = _db.Database.GetDbConnection();
                    using var cmd = conn.CreateCommand();

                    cmd.CommandText = "spEditPlantLocation";
                    cmd.CommandType = CommandType.StoredProcedure;

                    var pId = cmd.CreateParameter();
                    pId.ParameterName = "pPlantLocationHistoryId";
                    pId.Value = SourceId;
                    cmd.Parameters.Add(pId);

                    var pStart = cmd.CreateParameter();
                    pStart.ParameterName = "pNewStartDateTime";
                    pStart.Value = EventDate;
                    cmd.Parameters.Add(pStart);

                    var pReason = cmd.CreateParameter();
                    pReason.ParameterName = "pMoveReasonNotes";
                    pReason.Value = (object?)EventDetails ?? DBNull.Value;
                    cmd.Parameters.Add(pReason);

                    var pNotes = cmd.CreateParameter();
                    pNotes.ParameterName = "pPlantLocationNotes";
                    pNotes.Value = string.IsNullOrWhiteSpace(PlantLocationNotes)
                        ? DBNull.Value
                        : PlantLocationNotes;
                    cmd.Parameters.Add(pNotes);

                    if (conn.State != ConnectionState.Open)
                        conn.Open();

                    cmd.ExecuteNonQuery();
                }
                catch (DbException ex)
                {
                    ModelState.AddModelError(string.Empty, ex.Message);
                    return Page();
                }
                break;

            case "Flowering":

                if (EndDate.HasValue && EndDate < EventDate)
                {
                    ModelState.AddModelError(
                        string.Empty,
                        "End date cannot be before start date."
                    );
                    return Page();
                }

                var flowering = _db.Flowering
                    .FirstOrDefault(f =>
                        f.FloweringId == SourceId &&
                        f.PlantId == PlantId &&
                        f.IsActive);

                if (flowering == null)
                    return NotFound();

                flowering.StartDate   = EventDate.Date;
                flowering.EndDate     = EndDate?.Date;
                flowering.SpikeCount  = SpikeCount;
                flowering.FlowerCount = FlowerCount;
                flowering.FloweringNotes =
                    string.IsNullOrWhiteSpace(EventDetails)
                        ? null
                        : EventDetails;

                _db.SaveChanges();

                break;

            case "Repotting":

                var repotting = _db.Repotting
                    .FirstOrDefault(r => r.RepottingId == SourceId && r.IsActive);

                if (repotting == null)
                {
                    return NotFound();
                }

                repotting.RepotDate = EventDate.Date;
                repotting.OldMediumNotes = string.IsNullOrWhiteSpace(OldMediumNotes) ? null : OldMediumNotes;
                repotting.NewMediumNotes = string.IsNullOrWhiteSpace(NewMediumNotes) ? null : NewMediumNotes;
                repotting.PotSize = string.IsNullOrWhiteSpace(PotSize) ? null : PotSize;
                repotting.RepotReasonNotes = string.IsNullOrWhiteSpace(RepotReasonNotes) ? null : RepotReasonNotes;
                repotting.RepottingNotes = string.IsNullOrWhiteSpace(RepottingNotes) ? null : RepottingNotes;

                _db.SaveChanges();
                break;

            default:
                return NotFound();
        }

        return RedirectToPage("/Plants/Details", new { plantId = PlantId });
    }
}
