using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.EntityFrameworkCore;
using OrchidApp.Web.Data;
using OrchidApp.Web.Models;

namespace OrchidApp.Web.Pages.Setup.GrowthMedia;

public class IndexModel : PageModel
{
    private readonly OrchidDbContext _db;

    public IndexModel(OrchidDbContext db)
    {
        _db = db;
    }

    public List<GrowthMedium> GrowthMedia { get; private set; } = new();

    public async Task OnGetAsync()
    {
        GrowthMedia = await _db.GrowthMedia
            .OrderBy(g => g.Name)
            .ToListAsync();
    }
}