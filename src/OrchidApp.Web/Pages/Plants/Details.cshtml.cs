using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using OrchidApp.Web.Data;
using OrchidApp.Web.Models;
using System.Linq;

namespace OrchidApp.Web.Pages.Plants;

public class DetailsModel : PageModel
{
    private readonly OrchidDbContext _db;

    public DetailsModel(OrchidDbContext db)
    {
        _db = db;
    }

    [FromRoute]
    public int PlantId { get; set; }

    public PlantCurrentLocation Plant { get; private set; } = null!;

    public IActionResult OnGet()
    {
        Plant = _db.PlantCurrentLocations.FirstOrDefault(p => p.PlantId == PlantId);

        if (Plant == null)
        {
            return NotFound();
        }

        return Page();
    }
}
