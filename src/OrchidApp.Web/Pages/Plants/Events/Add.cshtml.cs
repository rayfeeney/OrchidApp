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
                    pStartDateTime.ParameterName = "pStartDateTime";
                    pStartDateTime.Value = EventDate;
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
                throw new NotImplementedException($"{EventType} not wired yet.");

            case "Repotting":
                throw new NotImplementedException($"{EventType} not wired yet.");

            default:
                return NotFound();
        }

        return RedirectToPage("/Plants/Details", new { plantId = PlantId });
    }

}
