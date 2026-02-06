using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using OrchidApp.Web.Data;
using OrchidApp.Web.Models;
using System.Linq;
using Microsoft.EntityFrameworkCore;
using System.Data;
using System.Data.Common;

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


    public PlantLifecycleEvent? Event { get; private set; }

    public IActionResult OnGet()
    {
        Event = EventType switch
        {
            "Observation" =>
                _db.PlantLifecycleHistory.FirstOrDefault(e =>
                    e.SourceId == SourceId &&
                    e.SourceTable == "plantevent"),

            "LocationChange" =>
                _db.PlantLifecycleHistory.FirstOrDefault(e =>
                    e.SourceId == SourceId &&
                    e.SourceTable == "plantlocationhistory"),

            "Flowering" =>
                _db.PlantLifecycleHistory.FirstOrDefault(e =>
                    e.SourceId == SourceId &&
                    e.SourceTable == "flowering"),

            "Repotting" =>
                _db.PlantLifecycleHistory.FirstOrDefault(e =>
                    e.SourceId == SourceId &&
                    e.SourceTable == "repotting"),

            _ => null
        };

        if (Event == null)
        {
            return NotFound();
        }

        return Page();
    }

    public IActionResult OnPost()
    {
        switch (EventType)
        {
            case "Observation":
            {
                var plantEvent = _db.PlantEvent
                                    .FirstOrDefault(e => e.PlantEventId == SourceId);

                if (plantEvent == null)
                {
                    return NotFound();
                }

                plantEvent.IsActive = false;
                _db.SaveChanges();
                break;
            }

            case "LocationChange":
            {
                try
                {
                    var conn = _db.Database.GetDbConnection();
                    using var cmd = conn.CreateCommand();

                    cmd.CommandText = "spRemovePlantLocation";
                    cmd.CommandType = System.Data.CommandType.StoredProcedure;

                    var pId = cmd.CreateParameter();
                    pId.ParameterName = "pPlantLocationHistoryId";
                    pId.Value = SourceId;
                    cmd.Parameters.Add(pId);

                    if (conn.State != System.Data.ConnectionState.Open)
                    {
                        conn.Open();
                    }

                    cmd.ExecuteNonQuery();
                }
                catch (System.Data.Common.DbException)
                {
                    ModelState.AddModelError(
                        string.Empty,
                        "This location record cannot be removed."
                    );

                    // Reload the event for redisplay
                    Event = _db.PlantLifecycleHistory
                            .FirstOrDefault(e =>
                                e.SourceId == SourceId &&
                                e.SourceTable == "plantlocationhistory");

                    return Page();
                }
                break;
            }

            case "Flowering":

                var flowering = _db.Flowering
                    .FirstOrDefault(f => f.FloweringId == SourceId
                                    && f.PlantId == PlantId
                                    && f.IsActive);

                if (flowering == null)
                    return NotFound();

                flowering.IsActive = false;

                _db.SaveChanges();
                break;

            case "Repotting":

                var repotting = _db.Repotting
                    .FirstOrDefault(r => r.RepottingId == SourceId && r.IsActive);

                if (repotting == null)
                {
                    return NotFound();
                }

                repotting.IsActive = false;

                _db.SaveChanges();
                break;

            default:
                return NotFound();
        }

        return RedirectToPage("/Plants/Details", new { plantId = PlantId });
    }

}
