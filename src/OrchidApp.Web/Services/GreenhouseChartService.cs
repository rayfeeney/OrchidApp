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
        var requested = locations.Distinct(StringComparer.OrdinalIgnoreCase).OrderBy(n => n).ToArray();
        if (requested.Length == 0) return [];
        var (start, end) = Range(now);
        // Padding is only needed by periods crossing the display boundary. Hourly data
        // uses exactly the displayed range; all date predicates remain indexable.
        var from = start.Date.AddDays(-1);
        var until = end.Date.AddDays(1);
        var localNow = Local(now);
        var hourlyArguments = new object[] { start, end, localNow }.Concat(requested.Cast<object>()).ToArray();
        var periodArguments = new object[] { from, until, localNow }.Concat(requested.Cast<object>()).ToArray();
        var locationParameters = string.Join(", ", requested.Select((_, i) => "{" + (i + 3) + "}"));
        // The location filter is after the window function so conflicting assignments
        // to another location cannot silently turn a duplicate reading into valid data.
        // Start with the existing timestamp range index. Joining small configuration
        // tables first can otherwise make MariaDB walk a sensor's entire history.
        // For periods the bounded IDs drive the unchanged classification view by PK.
        var hourlySql = """
            WITH mapped AS (
                SELECT er.environmentReadingId AS Id, es.locationName AS LocationName,
                       er.readingDateTime AS At, er.temperatureCelsius AS Temperature,
                       COUNT(*) OVER (PARTITION BY er.environmentReadingId) AS MappingCount
                FROM environmentreading er FORCE INDEX (ixEnvironmentReading_ReadingDateTime)
                STRAIGHT_JOIN environmentsensor es
                  ON es.sensorName = er.sensorName AND es.isActive = 1
                 AND DATE(er.readingDateTime) >= es.effectiveFromDate
                 AND (es.effectiveToDate IS NULL OR DATE(er.readingDateTime) < es.effectiveToDate)
                WHERE er.readingDateTime >= {0} AND er.readingDateTime < {1}
                  AND er.readingDateTime <= {2} AND es.locationName IS NOT NULL
            )
            SELECT LocationName, CAST(DATE_FORMAT(At, '%Y-%m-%d %H:00:00') AS DATETIME) AS At,
                   CASE WHEN MAX(MappingCount) = 1 THEN AVG(Temperature) END AS Average,
                   COUNT(*) AS ReadingCount,
                   CAST(SUM(CASE WHEN MappingCount > 1 THEN 1 ELSE 0 END) AS SIGNED) AS ConflictCount
            FROM mapped WHERE LocationName IN (__LOCATIONS__)
            GROUP BY LocationName, CAST(DATE_FORMAT(At, '%Y-%m-%d %H:00:00') AS DATETIME)
            """;
        var periodSql = """
            WITH classified AS (
                SELECT p.environmentReadingId AS Id, p.locationName AS LocationName,
                       p.readingDateTime AS At, p.periodCode AS PeriodCode, p.periodDate AS PeriodDate,
                       p.temperatureCelsius AS Temperature,
                       COUNT(*) OVER (PARTITION BY p.environmentReadingId) AS ClassificationCount
                FROM environmentreading bounded FORCE INDEX (ixEnvironmentReading_ReadingDateTime)
                STRAIGHT_JOIN venvironmentreadingperiod p ON p.environmentReadingId = bounded.environmentReadingId
                WHERE bounded.readingDateTime >= {0} AND bounded.readingDateTime < {1}
                  AND bounded.readingDateTime <= {2}
            )
            SELECT LocationName, PeriodCode, PeriodDate, SUM(Temperature) AS TemperatureSum,
                   COUNT(*) AS ReadingCount, MIN(At) AS FirstReading, MAX(At) AS LastReading,
                   CAST(SUM(CASE WHEN ClassificationCount > 1 THEN 1 ELSE 0 END) AS SIGNED) AS ConflictCount
            FROM classified WHERE LocationName IN (__LOCATIONS__)
            GROUP BY LocationName, PeriodCode, PeriodDate
            """;
        var readings = await db.Database.SqlQuery<GreenhouseHour>(
            System.Runtime.CompilerServices.FormattableStringFactory.Create(
                hourlySql.Replace("__LOCATIONS__", locationParameters), hourlyArguments)).ToListAsync(ct);
        var periodReadings = await db.Database.SqlQuery<GreenhousePeriodAggregate>(
            System.Runtime.CompilerServices.FormattableStringFactory.Create(
                periodSql.Replace("__LOCATIONS__", locationParameters), periodArguments)).ToListAsync(ct);
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
        return requested.Select(location => BuildAggregated(location, now, readings, periodReadings, rules, targets, assignments, energy, tariffs)).ToList();
    }

    public static GreenhouseChart Build(string location, DateTime now,
        IReadOnlyList<GreenhouseReading> readings, IReadOnlyList<GreenhousePeriodReading> periodReadings,
        IReadOnlyList<GreenhousePeriodRule> rules, IReadOnlyList<GreenhouseTarget> targets,
        IReadOnlyList<GreenhouseAssignment> assignments, IReadOnlyList<GreenhouseEnergy> energy,
        IReadOnlyList<GreenhouseTariff> tariffs)
    {
        // Reference adapter for calculation fixtures; production reads SQL aggregates.
        var counts = readings.GroupBy(r => r.Id).ToDictionary(g => g.Key, g => g.Count());
        var periodCounts = periodReadings.GroupBy(r => r.Id).ToDictionary(g => g.Key, g => g.Count());
        var hours = readings.GroupBy(r => (r.LocationName, Hour: new DateTime(r.At.Year, r.At.Month, r.At.Day, r.At.Hour, 0, 0)))
            .Select(g => new GreenhouseHour { LocationName = g.Key.LocationName, At = g.Key.Hour,
                Average = g.Any(r => counts[r.Id] > 1) ? null : g.Average(r => r.Temperature),
                ReadingCount = g.Count(), ConflictCount = g.Count(r => counts[r.Id] > 1) }).ToList();
        var periods = periodReadings.GroupBy(r => (r.LocationName, r.PeriodCode, r.PeriodDate))
            .Select(g => new GreenhousePeriodAggregate { LocationName = g.Key.LocationName,
                PeriodCode = g.Key.PeriodCode, PeriodDate = g.Key.PeriodDate,
                TemperatureSum = g.Sum(r => r.Temperature), ReadingCount = g.Count(),
                FirstReading = g.Min(r => r.At), LastReading = g.Max(r => r.At),
                ConflictCount = g.Count(r => periodCounts[r.Id] > 1) }).ToList();
        return BuildAggregated(location, now, hours, periods, rules, targets, assignments, energy, tariffs);
    }

    public static GreenhouseChart BuildAggregated(string location, DateTime now,
        IReadOnlyList<GreenhouseHour> readings, IReadOnlyList<GreenhousePeriodAggregate> periodReadings,
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
        if (localReadings.Any(r => r.ConflictCount > 0))
            warnings.Add("Overlapping sensor mappings: affected hourly temperatures are unavailable.");
        var hourly = localReadings.Where(r => r.ConflictCount == 0 &&
                    !London.IsAmbiguousTime(r.At) && !London.IsInvalidTime(r.At))
            .ToDictionary(r => (long)Math.Floor((Utc(r.At) - utcStart).TotalHours), r => r.Average);
        if (localReadings.Any(r => London.IsAmbiguousTime(r.At) || London.IsInvalidTime(r.At)))
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
            var count = rows.Sum(r => r.ReadingCount);
            var ambiguous = rows.Any(r => r.ConflictCount > 0 || r.FirstReading < periodStart || r.LastReading >= periodEnd);
            decimal? average = count > 0 && !ambiguous ? Math.Round(rows.Sum(r => r.TemperatureSum) / count, 1, MidpointRounding.AwayFromZero) : null;
            if (ambiguous) warnings.Add("Period rule/mapping conflicts: affected averages are unavailable.");
            var status = Utc(periodEnd) > now ? "Provisional — period in progress or upcoming" :
                count == 0 ? "Provisional — no readings" : "Provisional — sampling coverage unverified";
            chart.Periods.Add(new(X(Utc(periodStart < start ? start : periodStart)),
                X(Utc(periodEnd > end ? end : periodEnd)), average, target,
                $"{date:dd MMM} {rule.PeriodName} ({rule.StartTime:hh\\:mm}–{rule.EndTime:hh\\:mm})", count, status));
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
