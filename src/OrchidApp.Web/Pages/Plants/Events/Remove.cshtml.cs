using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using OrchidApp.Web.Data;
using OrchidApp.Web.Models;
using System.Linq;

namespace OrchidApp.Web.Pages.Plants.Events;

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

    public PlantLifecycleEvent? Event { get; private set; }

    public IActionResult OnGet()
    {
        Event = _db.PlantLifecycleHistory
                   .FirstOrDefault(e =>
                        e.SourceId == SourceId &&
                        e.SourceTable == "plantevent");

        if (Event == null)
        {
            return NotFound();
        }

        return Page();
    }

    public IActionResult OnPost()
    {
        var plantEvent = _db.PlantEvent
                            .FirstOrDefault(e => e.PlantEventId == SourceId);

        if (plantEvent == null)
        {
            return NotFound();
        }

        plantEvent.IsActive = false;
        _db.SaveChanges();

        return RedirectToPage("/Plants/Details", new { plantId = PlantId });
    }
}
