using Microsoft.AspNetCore.Mvc.RazorPages;
using OrchidApp.Web.Data;
using OrchidApp.Web.Models;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace OrchidApp.Web.Pages.Setup.Locations;

public class IndexModel : PageModel
{
    [BindProperty(SupportsGet = true)]
    public string? ReturnUrl { get; set; }

    private readonly OrchidDbContext _db;

    public IndexModel(OrchidDbContext db)
    {
        _db = db;
    }

    public IReadOnlyList<Location> Locations { get; private set; } = [];

    public async Task OnGetAsync(CancellationToken ct)
    {
        Locations = await _db.Locations
            .AsNoTracking()
            .OrderBy(l => l.LocationName)
            .ThenBy(l => l.LocationId)
            .ToListAsync(ct);
    }
}
