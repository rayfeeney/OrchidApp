using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.EntityFrameworkCore;
using OrchidApp.Web.Data;
using OrchidApp.Web.Models;

namespace OrchidApp.Web.Pages.Setup.GrowthMedia;

public class DetailsModel : PageModel
{
    private readonly OrchidDbContext _db;

    public DetailsModel(OrchidDbContext db)
    {
        _db = db;
    }

    [FromRoute]
    public int GrowthMediumId { get; set; }

    public GrowthMedium? GrowthMedium { get; private set; }

    [BindProperty(SupportsGet = true)]
    public string? ReturnUrl { get; set; }

    public async Task<IActionResult> OnGetAsync()
    {
        GrowthMedium = await _db.GrowthMedia
            .AsNoTracking()
            .FirstOrDefaultAsync(g => g.GrowthMediumId == GrowthMediumId);

        if (GrowthMedium == null)
            return NotFound();

        return Page();
    }

    public async Task<IActionResult> OnPostToggleActiveAsync()
    {
        var current = await _db.GrowthMedia
            .AsNoTracking()
            .Where(g => g.GrowthMediumId == GrowthMediumId)
            .Select(g => g.IsActive)
            .SingleOrDefaultAsync();

        if (current == default)
            return NotFound();

        await _db.Database.ExecuteSqlRawAsync(
            "CALL spSetGrowthMediumActiveState({0},{1})",
            GrowthMediumId,
            current ? 0 : 1
        );

        return RedirectToPage(new { growthMediumId = GrowthMediumId, ReturnUrl });
    }
}