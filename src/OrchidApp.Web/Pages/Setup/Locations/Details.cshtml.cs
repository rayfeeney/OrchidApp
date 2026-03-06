using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using OrchidApp.Web.Data;
using OrchidApp.Web.Models;
using Microsoft.EntityFrameworkCore;

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

    public IActionResult OnGet()
    {
        Location = _db.Locations
                      .AsNoTracking()
                      .FirstOrDefault(l => l.LocationId == LocationId)
                   ?? throw new InvalidOperationException("Location not found.");

        return Page();
    }

    public IActionResult OnPostToggleActive()
    {
        var current = _db.Locations
                         .AsNoTracking()
                         .FirstOrDefault(l => l.LocationId == LocationId)
                      ?? throw new InvalidOperationException("Location not found.");

        _db.Database.ExecuteSqlRaw(
            "CALL spSetLocationActiveState({0},{1})",
            LocationId,
            current.IsActive ? 0 : 1
        );

        return RedirectToPage(new { locationId = LocationId, ReturnUrl });
    }
}