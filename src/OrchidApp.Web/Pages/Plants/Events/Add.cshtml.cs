using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using OrchidApp.Web.Data;
using OrchidApp.Web.Models;
using System;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Data;
using System.Data.Common;
using Microsoft.EntityFrameworkCore;

namespace OrchidApp.Web.Pages.Plants.Events;

/*
    ADD LIFECYCLE EVENTS — DESIGN NOTES

    Lifecycle events are stored in separate tables according
    to their semantic behaviour.

    Tables involved:
    - plantevent              → Observations
    - repotting               → Repotting events
    - flowering               → Flowering events
    - plantlocationhistory    → Location changes
    - vplantlifecyclehistory  → Read-only UNION for display

    ATOMIC EVENTS
    Tables:
    - plantevent
    - repotting
    - flowering

    Characteristics:
    - Represent discrete facts in time
    - Adding them does not affect other records
    - Created directly via EF Core
    - Validation is local to the row

    STRUCTURAL EVENTS
    Table:
    - plantlocationhistory

    Characteristics:
    - Participates in an exclusive, continuous timeline
    - Adding a location change must:
        - Close the previous location (if any)
        - Prevent overlaps and backdating
        - Enforce invariants

    Therefore:
    - LocationChange creation is handled exclusively
      via stored procedures
    - The UI collects input only
    - All validation and stitching happens in SQL

    This PageModel intentionally branches by EventType.
    This is not duplication — it is semantic separation.
*/

public class AddModel : PageModel
{
    private readonly OrchidDbContext _db;

    public AddModel(OrchidDbContext db)
    {
        _db = db;
    }

    [FromRoute]
    public int PlantId { get; set; }

    [FromRoute]
    public string EventType { get; set; } = "Observation";

    public string? PlantDisplayName { get; private set; }
    public string? PlantTag { get; private set; }

    // Two common properties for all event types
    [BindProperty]
    [DataType(DataType.Date)]
    public DateTime EventDate { get; set; } = DateTime.Today;

    [BindProperty]
    public string? EventDetails { get; set; }

    // LocationChange specific properties
    [BindProperty]
    public int LocationId { get; set; }

    // Flowering specific
    [BindProperty]
    [DataType(DataType.Date)]
    public DateTime StartDate { get; set; } = DateTime.Today;

    [BindProperty]
    [DataType(DataType.Date)]
    public DateTime? EndDate { get; set; }

    [BindProperty]
    public int? SpikeCount { get; set; }

    [BindProperty]
    public int? FlowerCount { get; set; }

    // Not used for now
    //[BindProperty]
    //public string? MoveReasonCode { get; set; }

    [BindProperty]
    public string? PlantLocationNotes { get; set; }

    // For populating Location dropdown
    public List<Location> Locations { get; private set; } = new();
    private void LoadLookups()
    {
        Locations = _db.Location
                    .Where(l => l.IsActive)
                    .OrderBy(l => l.LocationName)
                    .ToList();
    }


    public IActionResult OnGet()
    {
        if (EventType is not (
            "Observation" or
            "LocationChange" or
            "Flowering" or
            "Repotting"))
        {
            return NotFound();
        }
        
        var plant = _db.PlantActiveSummaries
                       .FirstOrDefault(p => p.PlantId == PlantId);

        if (plant != null)
        {
            PlantDisplayName = plant.DisplayName;
            PlantTag = plant.PlantTag;
        }

        LoadLookups();
        return Page();
    }

    public IActionResult OnPost()
    {
        if (!ModelState.IsValid)
        {
            LoadLookups();
            return Page();
        }

        // Dispatch by EventType: each case owns its own persistence semantics
        switch (EventType)
        {
            case "Observation":
                var observation = new PlantEvent
                {
                    PlantId = PlantId,
                    EventDateTime = EventDate,
                    EventDetails = EventDetails,
                    IsActive = true
                };

                _db.PlantEvent.Add(observation);
                _db.SaveChanges();
                break;

            case "LocationChange":
                try
                {
                    var conn = _db.Database.GetDbConnection();
                    using var cmd = conn.CreateCommand();

                    cmd.CommandText = "spMovePlantToLocation";
                    cmd.CommandType = CommandType.StoredProcedure;

                    var pPlantId = cmd.CreateParameter();
                    pPlantId.ParameterName = "pPlantId";
                    pPlantId.Value = PlantId;
                    cmd.Parameters.Add(pPlantId);

                    var pLocationId = cmd.CreateParameter();
                    pLocationId.ParameterName = "pLocationId";
                    pLocationId.Value = LocationId;
                    cmd.Parameters.Add(pLocationId);

                    // Not used for now 
                    //var pMoveReasonCode = cmd.CreateParameter(); 
                    //pMoveReasonCode.ParameterName = "pMoveReasonCode"; 
                    //pMoveReasonCode.Value = (object?)MoveReasonCode ?? DBNull.Value; 
                    //cmd.Parameters.Add(pMoveReasonCode);
                    
                    var pStartDateTime = cmd.CreateParameter();
                    pStartDateTime.ParameterName = "pStartDate";
                    pStartDateTime.Value = EventDate.Date;
                    cmd.Parameters.Add(pStartDateTime);

                    var pMoveReasonNotes = cmd.CreateParameter();
                    pMoveReasonNotes.ParameterName = "pMoveReasonNotes";
                    pMoveReasonNotes.Value = string.IsNullOrWhiteSpace(EventDetails)
                                                ? DBNull.Value : EventDetails;
                    cmd.Parameters.Add(pMoveReasonNotes);

                    var pPlantLocationNotes = cmd.CreateParameter();
                    pPlantLocationNotes.ParameterName = "pPlantLocationNotes";
                    pPlantLocationNotes.Value = string.IsNullOrWhiteSpace(PlantLocationNotes)
                                                    ? DBNull.Value : PlantLocationNotes;
                    cmd.Parameters.Add(pPlantLocationNotes);

                    if (conn.State != ConnectionState.Open)
                    {
                        conn.Open();
                    }

                    cmd.ExecuteNonQuery();
                }
                catch (DbException)
                {
                    ModelState.AddModelError(
                        string.Empty,
                        "The plant is already in this location."
                    );

                    LoadLookups();
                    return Page();
                }
                break;

            case "Flowering":

                if (EndDate.HasValue && EndDate < StartDate)
                {
                    ModelState.AddModelError(
                        string.Empty,
                        "End date cannot be before start date."
                    );
                    LoadLookups();
                    return Page();
                }

                var flowering = new Flowering
                {
                    PlantId = PlantId,
                    StartDate = StartDate.Date,
                    EndDate = EndDate?.Date,
                    SpikeCount = SpikeCount,
                    FlowerCount = FlowerCount,
                    FloweringNotes = string.IsNullOrWhiteSpace(EventDetails)
                                        ? null
                                        : EventDetails,
                    IsActive = true
                };

                _db.Flowering.Add(flowering);
                _db.SaveChanges();

                break;

            case "Repotting":
                throw new NotImplementedException($"{EventType} not wired yet.");

            default:
                return NotFound();
        }

        return RedirectToPage("/Plants/Details", new { plantId = PlantId });
    }

}
