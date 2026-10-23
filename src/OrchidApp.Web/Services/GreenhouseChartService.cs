using Microsoft.EntityFrameworkCore;
using OrchidApp.Web.Data;
using OrchidApp.Web.Models;

namespace OrchidApp.Web.Services;

public sealed class GreenhouseChartService(OrchidDbContext db)
{
    public static readonly TimeZoneInfo London = TimeZoneInfo.FindSystemTimeZoneById("Europe/London");
    public static DateTime Local(DateTime utc) => TimeZoneInfo.ConvertTimeFromUtc(DateTime.SpecifyKind(utc, DateTimeKind.Utc), London);
    public static DateTime Utc(DateTime local) => TimeZoneInfo.ConvertTimeToUtc(DateTime.SpecifyKind(local, DateTimeKind.Unspecified), London);
    public static (DateTime Start, DateTime End) Range(DateTime utcNow)
    {
        var today = Local(utcNow).Date;
        // Include yesterday's 21:00–22:00 hour, with exactly 168 elapsed hours.
        var end = today.AddDays(-1).AddHours(22);
        return (Local(Utc(end).AddHours(-168)), end);
    }

    public async Task<IReadOnlyList<GreenhouseChart>> LoadAsync(IEnumerable<string> locations, DateTime now, CancellationToken ct)
    {
        var (start, end) = Range(now);
        var from = start.Date.AddDays(-1);
        var until = end.AddDays(1);
        var localNow = Local(now);
        // Raw readings supply hourly temperatures outside configured periods too.
        var readings = await db.Database.SqlQuery<GreenhouseReading>($"""
            SELECT er.environmentReadingId AS Id, es.locationName AS LocationName,
                   er.readingDateTime AS At, er.temperatureCelsius AS Temperature
            FROM environmentreading er JOIN environmentsensor es
              ON es.sensorName = er.sensorName AND es.isActive = 1
             AND DATE(er.readingDateTime) >= es.effectiveFromDate
             AND (es.effectiveToDate IS NULL OR DATE(er.readingDateTime) < es.effectiveToDate)
            WHERE er.readingDateTime >= {from} AND er.readingDateTime < {until}
              AND er.readingDateTime <= {localNow} AND es.locationName IS NOT NULL
            """).ToListAsync(ct);
        // Preserve OrchidApp's classification, including its effective-date semantics.
        var periodReadings = await db.Database.SqlQuery<GreenhousePeriodReading>($"""
            SELECT environmentReadingId AS Id, locationName AS LocationName,
                   readingDateTime AS At, periodCode AS PeriodCode, periodDate AS PeriodDate,
                   temperatureCelsius AS Temperature
            FROM venvironmentreadingperiod
            WHERE readingDateTime >= {from} AND readingDateTime < {until}
              AND readingDateTime <= {localNow}
            """).ToListAsync(ct);
        var rules = await db.Database.SqlQueryRaw<GreenhousePeriodRule>("""
            SELECT periodCode AS PeriodCode, periodName AS PeriodName, startTime AS StartTime,
                   endTime AS EndTime, effectiveFromDate AS EffectiveFromDate,
                   effectiveToDate AS EffectiveToDate FROM environmentperiodrule WHERE isActive = 1
            """).ToListAsync(ct);
        var targets = await db.Database.SqlQueryRaw<GreenhouseTarget>("""
            SELECT locationName AS LocationName, CAST(monthNumber AS SIGNED) AS MonthNumber,
                   expectedDayTemperatureCelsius AS DayTarget, expectedNightTemperatureCelsius AS NightTarget,
                   effectiveFromDate AS EffectiveFromDate, effectiveToDate AS EffectiveToDate
            FROM environmenttargetrule WHERE isActive = 1
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
        var utcStart = Utc(start);
        var utcEnd = Utc(end);
        // Join tariffs separately: overlapping rates must never multiply energy.
        var energy = await db.Database.SqlQuery<GreenhouseEnergy>($"""
            SELECT md.MonitoringDeviceId AS DeviceId, e.HourStartUtc AS AtUtc,
                   e.EnergyWh
            FROM EnergyMonitoring.TapoEnergyHourly e JOIN EnergyMonitoring.MonitoringDevice md
              ON md.SourceSystemCode = 'Tapo' AND md.SourceDeviceId = e.TapoDeviceKey AND md.IsActive = 1
            WHERE e.HourStartUtc >= {utcStart} AND e.HourStartUtc < {utcEnd}
            """).ToListAsync(ct);
        var tariffs = await db.Database.SqlQueryRaw<GreenhouseTariff>("""
            SELECT EffectiveFromDate, EffectiveToDate, ImportRatePencePerKWh AS RatePence
            FROM EnergyMonitoring.Tariff
            """).ToListAsync(ct);
        return locations.Select(location => Build(location, now, readings, periodReadings, rules, targets, assignments, energy, tariffs)).ToList();
    }

    public static GreenhouseChart Build(string location, DateTime now,
        IReadOnlyList<GreenhouseReading> readings, IReadOnlyList<GreenhousePeriodReading> periodReadings,
        IReadOnlyList<GreenhousePeriodRule> rules, IReadOnlyList<GreenhouseTarget> targets,
        IReadOnlyList<GreenhouseAssignment> assignments, IReadOnlyList<GreenhouseEnergy> energy,
        IReadOnlyList<GreenhouseTariff> tariffs)
    {
        var (start, end) = Range(now);
        var utcStart = Utc(start);
        var utcEnd = Utc(end);
        double X(DateTime utc) => (utc - utcStart).TotalHours;
        bool Match(string name) => string.Equals(name, location, StringComparison.OrdinalIgnoreCase);
        var chart = new GreenhouseChart { LocationName = location,
            RangeLabel = $"{start:dd MMM yyyy HH:mm}–{end.AddHours(-1):dd MMM yyyy HH:mm} · Europe/London" };
        var warnings = new HashSet<string>();
        var localReadings = readings.Where(r => Match(r.LocationName)).ToList();
        var readingCounts = readings.GroupBy(r => r.Id).ToDictionary(g => g.Key, g => g.Count());
        var periodReadingCounts = periodReadings.GroupBy(r => r.Id).ToDictionary(g => g.Key, g => g.Count());
        if (readingCounts.Values.Any(count => count > 1))
            warnings.Add("Overlapping sensor mappings: affected hourly temperatures are unavailable.");
        var validReadings = localReadings.Where(r => readingCounts[r.Id] == 1).ToList();
        var hourly = validReadings.Where(r => !London.IsAmbiguousTime(r.At) && !London.IsInvalidTime(r.At))
            .GroupBy(r => (long)Math.Floor((Utc(r.At) - utcStart).TotalHours))
            .ToDictionary(g => g.Key, g => g.Average(r => r.Temperature));
        foreach (var invalid in localReadings.Where(r => readingCounts[r.Id] > 1 &&
                     !London.IsAmbiguousTime(r.At) && !London.IsInvalidTime(r.At)))
            hourly.Remove((long)Math.Floor((Utc(invalid.At) - utcStart).TotalHours));
        if (validReadings.Any(r => London.IsAmbiguousTime(r.At) || London.IsInvalidTime(r.At)))
            warnings.Add("Clock-change temperature timestamps lack offsets: affected hourly values are gaps; valid local readings remain in period averages.");
        var energyIndex = energy.GroupBy(e => (e.DeviceId, e.AtUtc)).ToDictionary(g => g.Key, g => g.ToList());
        var missingEnergy = 0; var missingTemperature = 0; var badTariff = 0; var badMapping = 0;
        for (var hour = utcStart; hour < utcEnd; hour = hour.AddHours(1))
        {
            var local = Local(hour);
            var offset = London.GetUtcOffset(DateTime.SpecifyKind(hour, DateTimeKind.Utc));
            chart.Labels.Add($"{local:dd MMM HH:mm} {(offset == TimeSpan.Zero ? "GMT" : "BST")}");
            var x = X(hour);
            var observed = hour < now;
            decimal? temperature = observed && hourly.TryGetValue((long)x, out var t) ? t : null;
            chart.Temperatures.Add(new(x + 0.5, temperature));
            if (observed && temperature is null) missingTemperature++;
            decimal? cost = null;
            // A heater meter must cover the whole interval, without assignment changes within it.
            var expected = assignments.Where(a => Match(a.LocationName) && a.Start <= local
                && (a.End is null || a.End >= Local(hour.AddHours(1)))).ToList();
            var changes = assignments.Any(a => Match(a.LocationName) &&
                ((a.Start > local && a.Start < Local(hour.AddHours(1))) ||
                 (a.End > local && a.End < Local(hour.AddHours(1)))));
            if (hour.AddHours(1) <= now)
            {
                var rates = tariffs.Where(t => local.Date >= t.EffectiveFromDate &&
                    (t.EffectiveToDate is null || local.Date <= t.EffectiveToDate)).ToList();
                var mappingValid = !changes && expected.Count == 1 &&
                    assignments.Count(a => a.DeviceId == expected[0].DeviceId && a.Start <= local &&
                        (a.End is null || local < a.End)) == 1 &&
                    !assignments.Any(a => a.DeviceId == expected[0].DeviceId && a != expected[0] &&
                        a.Start > local && a.Start < Local(hour.AddHours(1)));
                if (!mappingValid) badMapping++;
                if (rates.Count != 1 || rates[0].RatePence < 0) badTariff++;
                if (mappingValid)
                {
                    var rows = energyIndex.GetValueOrDefault((expected[0].DeviceId, hour));
                    if (rows is not { Count: 1 } || rows[0].EnergyWh is null or < 0) missingEnergy++;
                    else if (rates.Count == 1 && rates[0].RatePence >= 0)
                        cost = rows[0].EnergyWh / 1000m * rates[0].RatePence / 100m;
                }
            }
            chart.Costs.Add(new(x + 0.5, cost));
        }
        for (var date = start.Date.AddDays(-1); date < end; date = date.AddDays(1))
        foreach (var group in rules.Where(r => date >= r.EffectiveFromDate &&
                     (r.EffectiveToDate is null || date < r.EffectiveToDate)).GroupBy(r => r.PeriodCode))
        {
            if (group.Count() != 1) { warnings.Add("Overlapping period rules: affected segments are unavailable."); continue; }
            var rule = group.Single();
            var periodStart = date + rule.StartTime;
            var periodEnd = date + rule.EndTime;
            if (rule.EndTime < rule.StartTime) periodEnd = periodEnd.AddDays(1);
            if (periodEnd <= periodStart || periodStart >= end || periodEnd <= start) continue;
            if (London.IsAmbiguousTime(periodStart) || London.IsInvalidTime(periodStart) ||
                London.IsAmbiguousTime(periodEnd) || London.IsInvalidTime(periodEnd))
            { warnings.Add("A period boundary is ambiguous or invalid at a clock change; that segment is unavailable."); continue; }
            var matches = targets.Where(t => Match(t.LocationName) && t.MonthNumber == date.Month &&
                date >= t.EffectiveFromDate && (t.EffectiveToDate is null || date < t.EffectiveToDate)).ToList();
            decimal? target = matches.Count == 1 ? (rule.PeriodCode == "DAY" ? matches[0].DayTarget : matches[0].NightTarget) : null;
            if (target is null) warnings.Add("Missing or overlapping target rules: affected targets are gaps.");
            var rows = periodReadings.Where(r => Match(r.LocationName) && r.PeriodDate == date && r.PeriodCode == rule.PeriodCode).ToList();
            var ambiguous = rows.Any(r => periodReadingCounts[r.Id] != 1) ||
                rows.Any(r => r.At < periodStart || r.At >= periodEnd);
            decimal? average = rows.Count > 0 && !ambiguous ? Math.Round(rows.Average(r => r.Temperature), 1, MidpointRounding.AwayFromZero) : null;
            if (ambiguous) warnings.Add("Period rule/mapping conflicts: affected averages are unavailable.");
            var status = Utc(periodEnd) > now ? "Provisional — period in progress or upcoming" :
                rows.Count == 0 ? "Provisional — no readings" : "Provisional — sampling coverage unverified";
            chart.Periods.Add(new(X(Utc(periodStart < start ? start : periodStart)),
                X(Utc(periodEnd > end ? end : periodEnd)), average, target,
                $"{date:dd MMM} {rule.PeriodName} ({rule.StartTime:hh\\:mm}–{rule.EndTime:hh\\:mm})", rows.Count, status));
        }
        if (missingEnergy > 0) warnings.Add($"{missingEnergy} completed hours lack heater readings.");
        if (badMapping > 0) warnings.Add($"{badMapping} completed hours lack one unambiguous heater assignment.");
        if (badTariff > 0) warnings.Add($"{badTariff} completed hours have missing, overlapping or invalid tariffs.");
        if (missingTemperature > 0) warnings.Add($"{missingTemperature} elapsed hour slots lack usable temperature readings.");
        if (chart.Periods.Count == 0) warnings.Add("No valid configured periods are available.");
        chart.Notices.Add("Averages use every classified reading in the full period, including readings outside the displayed range. Period averages are provisional because expected sampling cadence is not configured. Current-hour heater cost is unavailable until the hour completes.");
        chart.Notices.AddRange(warnings);
        return chart;
    }
}
