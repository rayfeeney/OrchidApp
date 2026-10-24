using Microsoft.EntityFrameworkCore;
using OrchidApp.Web.Data;
using OrchidApp.Web.Models;

namespace OrchidApp.Web.Services;

public sealed class GreenhouseNetCostService(OrchidDbContext db)
{
    public static (DateTime WeekStart, DateTime YearStart, DateTime End) Range(DateTime now)
    {
        var end = GreenhouseChartService.Local(now).Date;
        return (end.AddDays(-7), new DateTime(end.Year, 1, 1), end);
    }

    public async Task<GreenhouseNetCosts> LoadAsync(DateTime now, CancellationToken ct)
    {
        var (weekStart, yearStart, end) = Range(now);
        var from = weekStart < yearStart ? weekStart : yearStart;
        var utcStart = GreenhouseChartService.Utc(from);
        var utcEnd = GreenhouseChartService.Utc(end);
        // Tapo is already hourly. Use bounded rows, retaining effective assignment
        // checks in C#; no minute temperature data is required for these totals.
        var energy = await db.Database.SqlQuery<GreenhouseEnergy>($"""
            SELECT md.MonitoringDeviceId AS DeviceId, e.HourStartUtc AS AtUtc, e.EnergyWh
            FROM EnergyMonitoring.TapoEnergyHourly e
            JOIN EnergyMonitoring.MonitoringDevice md
              ON md.SourceSystemCode = 'Tapo' AND md.SourceDeviceId = e.TapoDeviceKey AND md.IsActive = 1
            WHERE e.HourStartUtc >= {utcStart} AND e.HourStartUtc < {utcEnd}
            """).ToListAsync(ct);
        var assignments = await db.Database.SqlQueryRaw<GreenhouseAssignment>("""
            SELECT md.MonitoringDeviceId AS DeviceId, m.TargetRuleLocationName AS LocationName,
                   h.StartDateTime AS Start, h.EndDateTime AS End
            FROM EnergyMonitoring.MonitoringDevice md
            JOIN EnergyMonitoring.MonitoringDeviceLocationHistory h
              ON h.MonitoringDeviceId = md.MonitoringDeviceId AND h.IsActive = 1
            JOIN EnergyMonitoring.GreenhouseTargetLocationMap m ON m.LocationId = h.LocationId
            WHERE md.SourceSystemCode = 'Tapo' AND md.IsActive = 1
            """).ToListAsync(ct);
        // Sum available production values, including zero; omit null/negative data.
        // Missing intervals do not invalidate totals. The interval end
        // belongs to the preceding hour/day. Solar is aggregated once, independently
        // of the heater joins, so it cannot be credited separately to each location.
        var solar = await db.Database.SqlQuery<GreenhouseSolarHour>($"""
            SELECT CAST(DATE_FORMAT(IntervalEndUtc - INTERVAL 1 SECOND, '%Y-%m-%d %H:00:00') AS DATETIME) AS AtUtc,
                   SUM(ProducedWh) AS ProducedWh, COUNT(*) AS ReadingCount,
                   CAST(0 AS SIGNED) AS InvalidCount
            FROM EnergyMonitoring.EnphaseInterval
            WHERE IntervalEndUtc > {utcStart} AND IntervalEndUtc <= {utcEnd} AND ProducedWh IS NOT NULL AND ProducedWh >= 0
            GROUP BY CAST(DATE_FORMAT(IntervalEndUtc - INTERVAL 1 SECOND, '%Y-%m-%d %H:00:00') AS DATETIME)
            """).ToListAsync(ct);
        var yesterday = end.AddDays(-1);
        var tariffs = await db.Database.SqlQuery<GreenhouseTariff>($"""
            SELECT EffectiveFromDate, EffectiveToDate, ImportRatePencePerKWh AS RatePence
            FROM EnergyMonitoring.Tariff
            WHERE EffectiveFromDate <= {yesterday} AND (EffectiveToDate IS NULL OR EffectiveToDate >= {yesterday})
            """).ToListAsync(ct);
        return Build(now, energy, assignments, solar, tariffs);
    }

    public static GreenhouseNetCosts Build(DateTime now, IReadOnlyList<GreenhouseEnergy> energy,
        IReadOnlyList<GreenhouseAssignment> assignments, IReadOnlyList<GreenhouseSolarHour> solar,
        IReadOnlyList<GreenhouseTariff> tariffs)
    {
        var (weekStart, yearStart, end) = Range(now);
        var yesterday = end.AddDays(-1);
        var applicable = tariffs.Where(t => t.EffectiveFromDate <= yesterday &&
            (t.EffectiveToDate is null || t.EffectiveToDate >= yesterday)).ToList();
        if (applicable.Count != 1 || applicable[0].RatePence < 0)
            return GreenhouseNetCosts.Unavailable("Yesterday's import tariff is missing or ambiguous.");
        var rate = applicable[0].RatePence / 100m;
        var readings = energy.GroupBy(e => (e.DeviceId, e.AtUtc)).ToDictionary(g => g.Key, g => g.ToList());
        var production = solar.GroupBy(s => s.AtUtc).ToDictionary(g => g.Key, g => g.ToList());
        var from = weekStart < yearStart ? weekStart : yearStart;
        // Totals use recorded data only. Missing/null readings are skipped, without
        // interpolating gaps or enforcing a particular number of samples per hour.
        var days = new Dictionary<DateTime, (decimal Heater, decimal Solar, bool Ambiguous)>();
        for (var day = from; day < end; day = day.AddDays(1))
        {
            decimal heaterWh = 0, solarWh = 0;
            var ambiguous = false;
            var dayEndUtc = GreenhouseChartService.Utc(day.AddDays(1));
            for (var hour = GreenhouseChartService.Utc(day); hour < dayEndUtc; hour = hour.AddHours(1))
            {
                var local = GreenhouseChartService.Local(hour);
                var localEnd = GreenhouseChartService.Local(hour.AddHours(1));
                var usedDevices = new HashSet<int>();
                foreach (var side in new[] { "Cool side", "Hot side" })
                {
                    var expected = assignments.Where(a => a.LocationName.Equals(side, StringComparison.OrdinalIgnoreCase)
                        && a.Start <= local && (a.End is null || a.End >= localEnd)).ToList();
                    if (expected.Count == 0) continue;
                    if (expected.Count > 1) { ambiguous = true; continue; }
                    var device = expected[0].DeviceId;
                    if (!usedDevices.Add(device) || assignments.Count(a => a.DeviceId == device && a.Start <= local &&
                            (a.End is null || local < a.End)) != 1 ||
                        assignments.Any(a => a.DeviceId == device &&
                            ((a.Start > local && a.Start < localEnd) || (a.End > local && a.End < localEnd))))
                    { ambiguous = true; continue; }
                    var rows = readings.GetValueOrDefault((device, hour));
                    if (rows is { Count: > 1 }) ambiguous = true;
                    else if (rows is { Count: 1 } && rows[0].EnergyWh is >= 0)
                        heaterWh += rows[0].EnergyWh!.Value;
                }
                var generated = production.GetValueOrDefault(hour);
                if (generated is { Count: > 1 }) ambiguous = true;
                else if (generated is { Count: 1 } && generated[0].ProducedWh >= 0)
                    solarWh += generated[0].ProducedWh;
            }
            days[day] = (heaterWh / 1000m, solarWh / 1000m, ambiguous);
        }
        GreenhouseNetCost Summarise(string label, DateTime start)
        {
            var selected = days.Where(d => d.Key >= start && d.Key < end).Select(d => d.Value).ToList();
            var heater = selected.Sum(d => d.Heater);
            var generated = selected.Sum(d => d.Solar);
            if (selected.Any(d => d.Ambiguous))
                return new(label, null, heater, generated, "Heater assignments or readings are ambiguous.");
            // Net across the ENTIRE reporting period, then apply yesterday's rate.
            // No daily MAX/shortfall, export rate, standing charge or grid-cost claim.
            return new(label, (heater - generated) * rate, heater, generated);
        }
        return new(Summarise("Last 7 days", weekStart), Summarise("Year to date", yearStart));
    }
}
