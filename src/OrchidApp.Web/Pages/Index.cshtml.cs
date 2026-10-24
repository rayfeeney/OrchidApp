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
    private readonly PlatformFeatures _features;
    private readonly GreenhouseChartCache? _chartCache;

    public IndexModel(OrchidDbContext context, PlatformFeatures features, GreenhouseChartCache? chartCache = null)
    {
        _context = context;
        _features = features;
        _chartCache = chartCache;
    }

    public IReadOnlyList<EnvironmentLastSevenDaysSummary> EnvironmentSummaries { get; private set; }
        = [];

    public bool EnvironmentSummaryEnabled => _features.EnvironmentSummaryEnabled;
    public IReadOnlyList<GreenhouseChart> GreenhouseCharts { get; private set; } = [];
    public string? ChartError { get; private set; }
    public GreenhouseNetCosts GreenhouseCosts { get; private set; } = GreenhouseNetCosts.Unavailable("Not loaded.");

    public async Task OnGetAsync()
    {
        // Return before any monitoring access unless this installation explicitly opts in.
        if (!EnvironmentSummaryEnabled)
            return;

        var now = DateTime.UtcNow;
        EnvironmentSummaries = await _context.EnvironmentLastSevenDaysSummaries
            .FromSqlRaw(EnvironmentSummarySql.Query, GreenhouseChartService.Local(now).Date)
            .OrderBy(summary => summary.LocationName)
            .ToListAsync();
        if (EnvironmentSummaries.Count == 0) return;
        try
        {
            var locations = EnvironmentSummaries.Select(s => s.LocationName).Where(n =>
                    n.Equals("Cool side", StringComparison.OrdinalIgnoreCase) ||
                    n.Equals("Hot side", StringComparison.OrdinalIgnoreCase)).ToArray();
            var service = new GreenhouseChartService(_context);
            var connection = _context.Database.GetDbConnection();
            var key = GreenhouseChartCache.Key(connection.DataSource + "/" + connection.Database, now, locations);
            GreenhouseCharts = _chartCache is null
                ? await service.LoadAsync(locations, now, HttpContext.RequestAborted)
                : await _chartCache.GetAsync(key, ct => service.LoadAsync(locations, now, ct), HttpContext.RequestAborted);
        }
        catch (DbException error)
        {
            HttpContext.RequestServices.GetRequiredService<ILogger<IndexModel>>()
                .LogWarning(error, "Greenhouse chart data unavailable");
            ChartError = "Monitoring charts are unavailable. Check reporting database access and configuration.";
        }
        // Keep chart and cost failures independent; solar access is not required
        // for the existing temperature/cost charts to remain available.
        try
        {
            var connection = _context.Database.GetDbConnection();
            var key = "net-cost:v1:" + GreenhouseChartCache.Key(
                connection.DataSource + "/" + connection.Database, now, ["Cool side", "Hot side"]);
            var costs = new GreenhouseNetCostService(_context);
            GreenhouseCosts = _chartCache is null
                ? await costs.LoadAsync(now, HttpContext.RequestAborted)
                : await _chartCache.GetValueAsync(key, ct => costs.LoadAsync(now, ct), HttpContext.RequestAborted);
        }
        catch (DbException error)
        {
            HttpContext.RequestServices.GetRequiredService<ILogger<IndexModel>>()
                .LogWarning(error, "Greenhouse net cost data unavailable");
            GreenhouseCosts = GreenhouseNetCosts.Unavailable("Reporting data could not be read.");
        }
    }
}
