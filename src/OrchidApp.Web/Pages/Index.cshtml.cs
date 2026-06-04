using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.EntityFrameworkCore;
using OrchidApp.Web.Data;
using OrchidApp.Web.Models;

namespace OrchidApp.Web.Pages;

public class IndexModel : PageModel
{
    private readonly OrchidDbContext _context;

    public IndexModel(OrchidDbContext context)
    {
        _context = context;
    }

    public IReadOnlyList<EnvironmentLastSevenDaysSummary> EnvironmentSummaries { get; private set; }
        = [];

    public async Task OnGetAsync()
    {
        EnvironmentSummaries = await _context.EnvironmentLastSevenDaysSummaries
            .OrderBy(summary => summary.LocationName)
            .ToListAsync();
    }
}