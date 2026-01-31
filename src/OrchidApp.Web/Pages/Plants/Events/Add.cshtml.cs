using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using OrchidApp.Web.Data;
using OrchidApp.Web.Models;
using System;
using System.ComponentModel.DataAnnotations;

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
    public string? PlantDisplayName { get; private set; }
    public string? PlantTag { get; private set; }


    [BindProperty]
    [DataType(DataType.Date)]
    public DateTime EventDate { get; set; } = DateTime.Today;


    [BindProperty]
    public string EventDetails { get; set; } = string.Empty;

    public void OnGet()
    {
        var plant = _db.PlantActiveSummaries
                    .FirstOrDefault(p => p.PlantId == PlantId);

        if (plant != null)
        {
            PlantDisplayName = plant.DisplayName;
            PlantTag = plant.PlantTag;
        }
    }

    public IActionResult OnPost()
    {
        if (!ModelState.IsValid)
        {
            return Page();
        }

        var observation = new PlantEvent
        {
            PlantId = PlantId,
            EventDateTime = EventDate,
            EventDetails = EventDetails,
            IsActive = true
        };

        _db.PlantEvent.Add(observation);
        _db.SaveChanges();

        return RedirectToPage("/Plants/Details", new { plantId = PlantId });
    }
}
