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
            .FirstOrDefaultAsync(g => g.GrowthMediumId == GrowthMediumId);

        if (GrowthMedium == null)
            return NotFound();

        return Page();
    }

        public IActionResult OnPostToggleActive()
    {
        var current = _db.GrowthMedia
                         .AsNoTracking()
                         .FirstOrDefault(l => l.GrowthMediumId == GrowthMediumId)
                      ?? throw new InvalidOperationException("Growth medium not found.");

        _db.Database.ExecuteSqlRaw(
            "CALL spSetGrowthMediumActiveState({0},{1})",
            GrowthMediumId,
            current.IsActive ? 0 : 1
        );

        return RedirectToPage(new { growthMediumId = GrowthMediumId, ReturnUrl });
    }
}