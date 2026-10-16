using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.EntityFrameworkCore;
using OrchidApp.Web.Data;
using OrchidApp.Web.Models;
using OrchidApp.Web.Configuration;

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

    public bool EnvironmentSummaryEnabled => PlatformFeatures.EnvironmentSummaryEnabled;

    public async Task OnGetAsync()
    {
        // Environmental views/tables are required only on Linux ARM/ARM64 servers.
        if (!EnvironmentSummaryEnabled)
            return;

        EnvironmentSummaries = await _context.EnvironmentLastSevenDaysSummaries
            .OrderBy(summary => summary.LocationName)
            .ToListAsync();
    }
}