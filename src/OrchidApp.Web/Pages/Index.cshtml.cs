using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.EntityFrameworkCore;
using OrchidApp.Web.Data;
using OrchidApp.Web.Models;
using OrchidApp.Web.Configuration;
using OrchidApp.Web.Services;
using System.Data.Common;

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
    public IReadOnlyList<GreenhouseChart> GreenhouseCharts { get; private set; } = [];
    public string? ChartError { get; private set; }

    public async Task OnGetAsync()
    {
        // Environmental views/tables are required only on Linux ARM/ARM64 servers.
        if (!EnvironmentSummaryEnabled)
            return;

        var now = DateTime.UtcNow;
        EnvironmentSummaries = await _context.EnvironmentLastSevenDaysSummaries
            .FromSqlRaw(EnvironmentSummarySql.Query, GreenhouseChartService.Local(now).Date)
            .OrderBy(summary => summary.LocationName)
            .ToListAsync();
        try
        {
            GreenhouseCharts = await new GreenhouseChartService(_context).LoadAsync(
                EnvironmentSummaries.Select(s => s.LocationName).Where(n =>
                    n.Equals("Cool side", StringComparison.OrdinalIgnoreCase) ||
                    n.Equals("Hot side", StringComparison.OrdinalIgnoreCase)),
                now, HttpContext.RequestAborted);
        }
        catch (DbException error)
        {
            HttpContext.RequestServices.GetRequiredService<ILogger<IndexModel>>()
                .LogWarning(error, "Greenhouse chart data unavailable");
            ChartError = "Monitoring charts are unavailable. Check reporting database access and configuration.";
        }
    }
}
