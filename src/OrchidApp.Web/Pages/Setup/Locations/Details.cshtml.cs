using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.EntityFrameworkCore;
using OrchidApp.Web.Data;
using OrchidApp.Web.Models;
using OrchidApp.Web.Infrastructure;

namespace OrchidApp.Web.Pages.Setup.Locations;

public class DetailsModel : PageModel
{
    private readonly OrchidDbContext _db;

    public DetailsModel(OrchidDbContext db)
    {
        _db = db;
    }

    [FromRoute]
    public int LocationId { get; set; }

    [BindProperty(SupportsGet = true)]
    public string? ReturnUrl { get; set; }

    public Location Location { get; private set; } = null!;

    public async Task<IActionResult> OnGetAsync(CancellationToken ct)
    {
        Location = await _db.Locations
            .AsNoTracking()
            .FirstOrDefaultAsync(l => l.LocationId == LocationId, ct)
            ?? throw new InvalidOperationException("Location not found.");

        return Page();
    }

    public async Task<IActionResult> OnPostToggleActiveAsync(CancellationToken ct)
    {
        var current = await _db.Locations
            .AsNoTracking()
            .FirstOrDefaultAsync(l => l.LocationId == LocationId, ct);

        if (current == null)
            return NotFound();

        try
        {
            await _db.Database.ExecuteSqlRawAsync(
                "CALL spSetLocationActiveState({0},{1})",
                LocationId,
                current.IsActive ? 0 : 1
            );
        }
        catch (Exception ex)
        {
            if (DatabaseErrorTranslator.TryTranslate(ex, out var message))
            {
                ModelState.AddModelError(string.Empty, message);
                return await OnGetAsync(ct);
            }

            throw;
        }

        return RedirectToPage(new { locationId = LocationId, ReturnUrl });
    }
}
