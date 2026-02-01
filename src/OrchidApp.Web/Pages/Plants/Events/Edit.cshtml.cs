using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using OrchidApp.Web.Data;
using System;
using System.ComponentModel.DataAnnotations;
using System.Linq;

namespace OrchidApp.Web.Pages.Plants.Events;

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
    public int SourceId { get; set; } // plantEventId

    // Date-only UI, datetime stored
    [BindProperty]
    [DataType(DataType.Date)]
    public DateTime EventDate { get; set; }

    [BindProperty]
    public string EventDetails { get; set; } = string.Empty;

    public string? PlantDisplayName { get; private set; }
    public string? PlantTag { get; private set; }

    public IActionResult OnGet()
    {
        // Load context for display (optional but nice)
        var plant = _db.PlantActiveSummaries.FirstOrDefault(p => p.PlantId == PlantId);
        if (plant != null)
        {
            PlantDisplayName = plant.DisplayName;
            PlantTag = plant.PlantTag;
        }

        // Load the existing observation
        var existing = _db.PlantEvent.FirstOrDefault(e =>
            e.PlantEventId == SourceId &&
            e.PlantId == PlantId &&
            e.IsActive);

        if (existing == null)
        {
            return NotFound();
        }

        // Pre-populate the form
        EventDate = existing.EventDateTime.Date;
        EventDetails = existing.EventDetails ?? string.Empty;

        return Page();
    }
    public IActionResult OnPost()
    {
        if (!ModelState.IsValid)
        {
            return Page();
        }

        var existing = _db.PlantEvent.FirstOrDefault(e =>
            e.PlantEventId == SourceId &&
            e.PlantId == PlantId &&
            e.IsActive);

        if (existing == null)
        {
            return NotFound();
        }

        // Keep “date-only UI, datetime stored” consistent with Add
        existing.EventDateTime = EventDate.Date.Add(DateTime.Now.TimeOfDay);
        existing.EventDetails = EventDetails;
        _db.SaveChanges();

        return RedirectToPage("/Plants/Details", new { plantId = PlantId });
    }
}
