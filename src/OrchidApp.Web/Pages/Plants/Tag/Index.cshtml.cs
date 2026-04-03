using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.EntityFrameworkCore;
using OrchidApp.Web.Data;
using OrchidApp.Web.Infrastructure.PlantTag;

namespace OrchidApp.Web.Pages.Plants.Tag;

public class IndexModel : PageModel
{
    private readonly OrchidDbContext _db;

    public IndexModel(OrchidDbContext db)
    {
        _db = db;
    }

    [BindProperty(SupportsGet = true)]
    public string? PlantTag { get; set; }

    public async Task<IActionResult> OnGetAsync()
    {
        // 1. Normalise
        var normalised = PlantTagNormaliser.Normalise(PlantTag);

        if (normalised is null)
        {
            ModelState.AddModelError(string.Empty, "Enter a valid plant tag.");
            return Page();
        }

        // 2. Validate (structure + checksum)
        if (!PlantTagValidator.IsChecksumValid(normalised))
        {
            ModelState.AddModelError(string.Empty, "Invalid plant tag.");
            return Page();
        }

        // 3. Lookup (index-friendly exact match)
        var plantId = await _db.Plants
            .AsNoTracking()
            .Where(p => p.PlantTag == normalised && p.IsActive)
            .Select(p => (int?)p.PlantId)
            .FirstOrDefaultAsync();

        if (plantId is null)
        {
            ModelState.AddModelError(string.Empty, "Plant not found.");
            return Page();
        }

        // 4. Redirect to canonical route
        return RedirectToPage("/Plants/Details", new { plantId });
    }
}