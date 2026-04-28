using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.EntityFrameworkCore;
using OrchidApp.Web.Data;
using OrchidApp.Web.Models;

namespace OrchidApp.Web.Pages.Plants.Events;

public class PropagateConfirmationModel : PageModel
{
    private readonly OrchidDbContext _db;

    public PropagateConfirmationModel(OrchidDbContext db)
    {
        _db = db;
    }

    [FromRoute]
    public int PlantId { get; set; }

    public PlantCurrentLocation? ParentPlant { get; private set; }

    public List<SplitChildResult> Children { get; private set; } = new();

    public async Task<IActionResult> OnGetAsync()
    {
        ParentPlant = await _db.PlantCurrentLocations
            .FirstOrDefaultAsync(p => p.PlantId == PlantId);

        if (ParentPlant == null)
            return NotFound();

        var childId = TempData["PropagationChildId"] as string;
        var childTag = TempData["PropagationChildTag"] as string;

        if (string.IsNullOrWhiteSpace(childId) || string.IsNullOrWhiteSpace(childTag))
            return RedirectToPage("/Plants/Details", new { plantId = PlantId });

        Children.Add(new SplitChildResult
        {
            ChildPlantId = int.Parse(childId),
            ChildPlantTag = childTag
        });

        TempData.Keep("PropagationChildId");
        TempData.Keep("PropagationChildTag");

        return Page();
    }

    public IActionResult OnPostContinue()
    {
        var childId = TempData["PropagationChildId"] as string;

        if (string.IsNullOrWhiteSpace(childId))
            return RedirectToPage("/Plants/Details", new { plantId = PlantId });

        return RedirectToPage("/Plants/Details", new { plantId = int.Parse(childId) });
    }
}