using System.Text.Json;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.EntityFrameworkCore;
using MySqlConnector;
using OrchidApp.Web.Data;
using OrchidApp.Web.Models;
using OrchidApp.Web.Services;

var checks = 0;
void Check(string name, bool ok) { if (!ok) throw new Exception(name); checks++; }
var now = new DateTime(2026, 10, 23, 12, 0, 0, DateTimeKind.Utc);
var range = GreenhouseChartService.Range(now);
Check("Seven 24-hour periods ending with yesterday 21:00", range.Start == new DateTime(2026, 10, 15, 22, 0, 0) && range.End == new DateTime(2026, 10, 22, 22, 0, 0));
var rules = new List<GreenhousePeriodRule> {
    new() { PeriodCode = "DAY", PeriodName = "Day", StartTime = TimeSpan.FromHours(10), EndTime = TimeSpan.FromHours(16), EffectiveFromDate = new(2025, 1, 1) },
    new() { PeriodCode = "NIGHT", PeriodName = "Night", StartTime = TimeSpan.FromHours(22), EndTime = TimeSpan.FromHours(4), EffectiveFromDate = new(2025, 1, 1) }
};
var targets = new List<GreenhouseTarget> { new() { LocationName = "Cool side", MonthNumber = 10, DayTarget = 20, NightTarget = 12, EffectiveFromDate = new(2025, 1, 1) } };
var readings = new List<GreenhouseReading> {
    new() { Id = 1, LocationName = "Cool side", At = new(2026, 10, 16, 10, 0, 0), Temperature = 10 },
    new() { Id = 2, LocationName = "Cool side", At = new(2026, 10, 16, 10, 30, 0), Temperature = 10 },
    new() { Id = 3, LocationName = "Cool side", At = new(2026, 10, 16, 11, 0, 0), Temperature = 40 },
    new() { Id = 4, LocationName = "Cool side", At = new(2026, 10, 16, 18, 0, 0), Temperature = 18 }
};
var periods = readings.Take(3).Select(r => new GreenhousePeriodReading { Id = r.Id, LocationName = r.LocationName, At = r.At, Temperature = r.Temperature, PeriodCode = "DAY", PeriodDate = r.At.Date }).ToList();
var assignments = new List<GreenhouseAssignment> { new() { DeviceId = 1, LocationName = "Cool side", Start = new(2025, 1, 1) } };
var energy = new List<GreenhouseEnergy> { new() { DeviceId = 1, AtUtc = GreenhouseChartService.Utc(new(2026, 10, 16, 10, 0, 0)), EnergyWh = 1000 } };
var tariffs = new List<GreenhouseTariff> { new() { EffectiveFromDate = new(2026, 1, 1), EffectiveToDate = new(2026, 10, 16), RatePence = 25 }, new() { EffectiveFromDate = new(2026, 10, 17), RatePence = 30 } };
GreenhouseChart Build(DateTime? at = null) => GreenhouseChartService.Build("Cool side", at ?? now, readings, periods, rules, targets, assignments, energy, tariffs);
var chart = Build();
Check("168 hour slots", chart.Labels.Count == 168);
var day = chart.Periods.Single(p => p.Label.StartsWith("16 Oct Day"));
Check("Reading-weighted period mean, not hourly mean", day.Average == 20m);
Check("Configured day target", day.Target == 20m);
Check("Separate configured segments", day.Start == 12 && day.End == 18);
Check("Temperature outside periods retained", chart.Temperatures[20].Y == 18);
Check("Historical tariff and GBP conversion", chart.Costs[12].Y == .25m);
energy[0].EnergyWh = 0;
Check("Observed zero stays zero", Build().Costs[12].Y == 0);
energy[0].EnergyWh = 1000;
energy.Add(new() { DeviceId = 1, AtUtc = GreenhouseChartService.Utc(new(2026, 10, 17, 10, 0, 0)), EnergyWh = 1000 });
Check("Next day's tariff selected", Build().Costs[36].Y == .30m);
energy.RemoveAt(1);
targets[0].EffectiveToDate = new(2026, 10, 18);
targets.Add(new() { LocationName = "Cool side", MonthNumber = 10, DayTarget = 21, NightTarget = 13, EffectiveFromDate = new(2026, 10, 18) });
var historicalTargets = Build();
Check("Historical target retained", historicalTargets.Periods.Single(p => p.Label.StartsWith("16 Oct Day")).Target == 20);
Check("New target begins at exclusive old end", historicalTargets.Periods.Single(p => p.Label.StartsWith("18 Oct Day")).Target == 21);
targets.RemoveAt(1);
targets[0].EffectiveToDate = null;
Check("Missing heater hour is null", chart.Costs[13].Y is null);
Check("Coverage remains provisional", day.Status.Contains("Provisional"));
tariffs.Add(new() { EffectiveFromDate = new(2026, 10, 16), RatePence = 99 });
Check("Tariff overlaps do not multiply costs", Build().Costs[12].Y is null);
tariffs.RemoveAt(2);
assignments.Add(new() { DeviceId = 1, LocationName = "Cool side", Start = new(2026, 1, 1) });
Check("Assignment overlaps unavailable", Build().Costs[12].Y is null);
assignments.RemoveAt(1);
targets.Clear();
Check("No fabricated target", Build().Periods.All(p => p.Target is null));
targets.Add(new() { LocationName = "Cool side", MonthNumber = 10, DayTarget = 20, NightTarget = 12, EffectiveFromDate = new(2025, 1, 1) });
readings.Add(readings[0]);
Check("Duplicate sensor mapping detected", Build().Temperatures[12].Y is null);
readings.RemoveAt(4);
periods.Add(new() { Id = 5, LocationName = "Cool side", At = new(2026, 10, 15, 23, 0, 0), Temperature = 10, PeriodCode = "NIGHT", PeriodDate = new(2026, 10, 15) });
periods.Add(new() { Id = 6, LocationName = "Cool side", At = new(2026, 10, 16, 2, 0, 0), Temperature = 20, PeriodCode = "NIGHT", PeriodDate = new(2026, 10, 15) });
var clipped = Build().Periods.Single(p => p.Label.StartsWith("15 Oct Night"));
Check("Full first night average", clipped.Start == 0 && clipped.End == 6 && clipped.Average == 15);
var autumn = Build(new(2026, 10, 26, 12, 0, 0, DateTimeKind.Utc));
Check("Autumn repeated hour retained for energy", autumn.Labels.Count == 168 && autumn.Labels.Contains("25 Oct 01:00 BST") && autumn.Labels.Contains("25 Oct 01:00 GMT"));
var spring = Build(new(2026, 3, 30, 12, 0, 0, DateTimeKind.Utc));
Check("Spring range remains 168 elapsed hours", spring.Labels.Count == 168);
targets.Add(new() { LocationName = "Cool side", MonthNumber = 11, DayTarget = 22, NightTarget = 14, EffectiveFromDate = new(2025, 1, 1) });
var month = Build(new(2026, 11, 3, 12, 0, 0, DateTimeKind.Utc));
Check("Night target anchored before month boundary", month.Periods.Single(p => p.Label.StartsWith("31 Oct Night")).Target == 12);
Check("Next month target selected", month.Periods.Single(p => p.Label.StartsWith("01 Nov Night")).Target == 14);
rules[0].StartTime = TimeSpan.FromHours(9);
Check("Windows read from rules", Build().Periods.Single(p => p.Label.StartsWith("16 Oct Day")).Start == 11);
rules[0].StartTime = TimeSpan.FromHours(10);
energy.Add(new() { DeviceId = 1, AtUtc = new(2026, 10, 23, 12, 0, 0), EnergyWh = 1000 });
Check("Latest displayed hour is yesterday 21:00", Build().Labels[^1] == "22 Oct 21:00 BST");
Check("No target between day and night", Build().Periods.All(p => !(p.Start < 21 && p.End > 20)));
readings.Add(new() { Id = 20, LocationName = "Cool side", At = new(2026, 10, 25, 1, 30, 0), Temperature = 99 });
var ambiguousHour = Build(new(2026, 10, 26, 12, 0, 0, DateTimeKind.Utc));
Check("Repeated-hour temperature not fabricated", ambiguousHour.Labels.Select((label, i) => (label, i))
    .Where(v => v.label.StartsWith("25 Oct 01:00")).All(v => ambiguousHour.Temperatures[v.i].Y is null));
Check("Repeated-hour warning present", ambiguousHour.Notices.Any(n => n.Contains("lack offsets")));
readings.RemoveAt(readings.Count - 1);
periods.Add(periods[0]);
Check("Duplicate classified reading does not bias mean", Build().Periods.Single(p => p.Label.StartsWith("16 Oct Day")).Average is null);
periods.RemoveAt(periods.Count - 1);

// Optional disposable MariaDB integration. Never point this at an existing instance.
await PerformanceChecks.CacheAsync(Check);
if (Environment.GetEnvironmentVariable("GREENHOUSE_TEST_CONNECTION") is { Length: > 0 } connection)
{
    var settings = new MySqlConnectionStringBuilder(connection);
    if (settings.Server != "127.0.0.1" || settings.Port != 33317)
        throw new Exception("Integration fixtures require the disposable loopback database on port 33317.");
    await using var sql = new MySqlConnection(connection);
    await sql.OpenAsync();
    var fixture = await File.ReadAllTextAsync(Path.Combine(AppContext.BaseDirectory, "Fixtures", "setup.sql"));
    await using (var command = new MySqlCommand(fixture, sql)) await command.ExecuteNonQueryAsync();
    var options = new DbContextOptionsBuilder<OrchidDbContext>().UseMySql(connection, new MariaDbServerVersion(new Version(10, 11, 16))).Options;
    await using var db = new OrchidDbContext(options);
    var loaded = await new GreenhouseChartService(db).LoadAsync(["Cool side", "Hot side"], now, default);
    Check("MariaDB queries load both charts", loaded.Count == 2);
    Check("MariaDB raw reading-weighted mean", loaded[0].Periods.Single(p => p.Label.StartsWith("16 Oct Day")).Average == 20);
    Check("MariaDB configured 16:00 exclusion", loaded[0].Temperatures[18].Y == 50);
    Check("MariaDB historical cost", loaded[0].Costs[12].Y == .25m);
    Check("MariaDB other location uses its own heater", loaded[1].Costs[12].Y == .5m);
    Check("MariaDB night assigned to start date", loaded[0].Periods.Single(p => p.Label.StartsWith("15 Oct Night")).Average == 15);
    var summaries = await db.EnvironmentLastSevenDaysSummaries.FromSqlRaw(EnvironmentSummarySql.Query, GreenhouseChartService.Local(now).Date).ToListAsync();
    Check("Parameterized summary query executes", summaries.Count == 2);
    Check("Summary remains weighted over classified readings", summaries.Single(s => s.LocationName == "Cool side").AverageDayTemperatureCelsius == 20);
    Check("Summary uses the exact eight-date boundaries", summaries.Single(s => s.LocationName == "Cool side") is
        { ReadingCount: 5, FirstReadingDateTime: var first, LastReadingDateTime: var last } &&
        first == new DateTime(2026, 10, 16, 2, 0, 0) && last == new DateTime(2026, 10, 23, 12, 0, 0));
    await using (var command = new MySqlCommand("UPDATE orchids.environmenttargetrule SET isActive=0 WHERE environmentTargetRuleId=1", sql))
        await command.ExecuteNonQueryAsync();
    var missingTarget = await db.EnvironmentLastSevenDaysSummaries.FromSqlRaw(EnvironmentSummarySql.Query, GreenhouseChartService.Local(now).Date).AsNoTracking().ToListAsync();
    Check("Missing targets retain the location summary", missingTarget.Count == 2 && missingTarget.Single(s => s.LocationName == "Cool side").ExpectedDayTemperatureCelsius is null);
    await using (var command = new MySqlCommand("UPDATE orchids.environmenttargetrule SET isActive=1 WHERE environmentTargetRuleId=1", sql))
        await command.ExecuteNonQueryAsync();
    await PerformanceChecks.DatabaseAsync(connection, now, Check);
}

if (args.Length == 2 && args[0] == "--fixture-output")
    await File.WriteAllTextAsync(args[1], JsonSerializer.Serialize(Build(), new JsonSerializerOptions { PropertyNamingPolicy = JsonNamingPolicy.CamelCase }));
Console.WriteLine($"{checks} greenhouse chart checks passed.");

if (args.Length == 2 && args[0] == "--serve")
{
    var builder = Microsoft.AspNetCore.Builder.WebApplication.CreateBuilder(new Microsoft.AspNetCore.Builder.WebApplicationOptions {
        ApplicationName = typeof(OrchidApp.Web.Pages.IndexModel).Assembly.FullName,
        ContentRootPath = Path.GetFullPath(args[1]), WebRootPath = "wwwroot" });
    Microsoft.Extensions.DependencyInjection.MvcServiceCollectionExtensions.AddRazorPages(builder.Services);
    builder.Services.AddDataProtection().UseEphemeralDataProtectionProvider();
    builder.WebHost.UseUrls("http://127.0.0.1:5318");
    var app = builder.Build();
    app.UseStaticFiles();
    app.MapGet("/", async (Microsoft.AspNetCore.Http.HttpContext http) => {
        var action = new Microsoft.AspNetCore.Mvc.ActionContext(http, new Microsoft.AspNetCore.Routing.RouteData(), new Microsoft.AspNetCore.Mvc.Abstractions.ActionDescriptor());
        var engine = app.Services.GetRequiredService<Microsoft.AspNetCore.Mvc.ViewEngines.ICompositeViewEngine>();
        var view = engine.GetView(null, "/Pages/Shared/_GreenhouseChart.cshtml", false);
        if (!view.Success) throw new Exception(string.Join(",", view.SearchedLocations));
        using var output = new StringWriter();
        foreach (var name in new[] { "Cool side", "Hot side" })
        {
            var previewReadings = new List<GreenhouseReading>();
            var previewPeriods = new List<GreenhousePeriodReading>();
            var previewEnergy = new List<GreenhouseEnergy>();
            for (var utc = GreenhouseChartService.Utc(range.Start); utc < now; utc = utc.AddHours(1))
            {
                var at = GreenhouseChartService.Local(utc);
                var id = (long)(utc - GreenhouseChartService.Utc(range.Start)).TotalHours + 1;
                var previewTemperature = (decimal)(15 + 4 * Math.Sin((at.Hour - 8) * Math.PI / 12)) + (name == "Hot side" ? 4 : 0);
                if (id % 39 == 0) continue;
                previewReadings.Add(new() { Id = id, At = at, LocationName = name, Temperature = previewTemperature });
                previewEnergy.Add(new() { DeviceId = 1, AtUtc = utc, EnergyWh = at.Hour < 9 || at.Hour >= 20 ? 800 : 120 });
                var rule = rules.FirstOrDefault(r => r.EndTime > r.StartTime ? at.TimeOfDay >= r.StartTime && at.TimeOfDay < r.EndTime : at.TimeOfDay >= r.StartTime || at.TimeOfDay < r.EndTime);
                if (rule is not null) previewPeriods.Add(new() { Id = id, At = at, LocationName = name, Temperature = previewTemperature, PeriodCode = rule.PeriodCode, PeriodDate = rule.StartTime > rule.EndTime && at.TimeOfDay < rule.EndTime ? at.Date.AddDays(-1) : at.Date });
            }
            var model = GreenhouseChartService.Build(name, now, previewReadings, previewPeriods, rules,
                [new() { LocationName = name, MonthNumber = 10, DayTarget = name == "Hot side" ? 24 : 20, NightTarget = name == "Hot side" ? 15 : 12, EffectiveFromDate = new(2025, 1, 1) }],
                [new() { DeviceId = 1, LocationName = name, Start = new(2025, 1, 1) }], previewEnergy, tariffs);
            output.Write($"<div class='col-12 col-md-6'><div class='card h-100'><div class='card-body'><h3>{name}</h3><p>Day temperature: 20°C / 20°C</p>");
            var data = new Microsoft.AspNetCore.Mvc.ViewFeatures.ViewDataDictionary<GreenhouseChart>(
                new Microsoft.AspNetCore.Mvc.ModelBinding.EmptyModelMetadataProvider(), new Microsoft.AspNetCore.Mvc.ModelBinding.ModelStateDictionary()) { Model = model };
            var temp = new Microsoft.AspNetCore.Mvc.ViewFeatures.TempDataDictionary(http, app.Services.GetRequiredService<Microsoft.AspNetCore.Mvc.ViewFeatures.ITempDataProvider>());
            await view.View.RenderAsync(new Microsoft.AspNetCore.Mvc.Rendering.ViewContext(action, view.View, data, temp, output, new Microsoft.AspNetCore.Mvc.ViewFeatures.HtmlHelperOptions()));
            output.Write("</div></div></div>");
        }
        return Microsoft.AspNetCore.Http.Results.Content("<!DOCTYPE html><html><head><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'><link rel='stylesheet' href='/lib/bootstrap/dist/css/bootstrap.min.css'></head><body><main class='container py-4'><h1>Environment - last 7 days</h1><p>Preview — generated test data</p><div class='row g-3'>" + output + "</div></main><script src='/lib/chartjs/chart.umd.min.js'></script><script src='/js/greenhouse-charts.js'></script></body></html>", "text/html; charset=utf-8");
    });
    await app.RunAsync();
}

