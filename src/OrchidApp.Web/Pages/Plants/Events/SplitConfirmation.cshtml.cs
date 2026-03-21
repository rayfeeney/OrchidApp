using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.EntityFrameworkCore;
using OrchidApp.Web.Data;
using OrchidApp.Web.Models;
using System.Text.Json;

namespace OrchidApp.Web.Pages.Plants.Events;

public class SplitConfirmationModel : PageModel
{
    private readonly OrchidDbContext _db;

    public SplitConfirmationModel(OrchidDbContext db)
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

        var childIdsJson = TempData["SplitChildIdsJson"] as string;
        var childTagsJson = TempData["SplitChildTagsJson"] as string;

        if (string.IsNullOrWhiteSpace(childIdsJson) || string.IsNullOrWhiteSpace(childTagsJson))
            return RedirectToPage("/Plants/Details", new { plantId = PlantId });

        var ids = JsonSerializer.Deserialize<List<int>>(childIdsJson) ?? new();
        var tags = JsonSerializer.Deserialize<List<string>>(childTagsJson) ?? new();

        for (int i = 0; i < Math.Min(ids.Count, tags.Count); i++)
        {
            Children.Add(new SplitChildResult
            {
                ChildPlantId = ids[i],
                ChildPlantTag = tags[i]
            });
        }

        TempData.Keep("SplitChildIdsJson");
        TempData.Keep("SplitChildTagsJson");

        return Page();
    }

    public IActionResult OnPostContinue()
    {
        var childIdsJson = TempData["SplitChildIdsJson"] as string;

        if (string.IsNullOrWhiteSpace(childIdsJson))
            return RedirectToPage("/Plants/Details", new { plantId = PlantId });

        var ids = JsonSerializer.Deserialize<List<int>>(childIdsJson) ?? new();

        if (ids.Count == 0)
            return RedirectToPage("/Plants/Details", new { plantId = PlantId });

        return RedirectToPage("/Plants/Details", new { plantId = ids[0] });
    }
}