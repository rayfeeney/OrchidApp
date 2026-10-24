using Microsoft.EntityFrameworkCore;
using MySqlConnector;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Options;
using OrchidApp.Web.Data;
using OrchidApp.Web.Models;
using OrchidApp.Web.Services;

internal static class NetCostChecks
{
    public static void Run(Action<string, bool> check)
    {
        var now = new DateTime(2026, 1, 8, 12, 0, 0, DateTimeKind.Utc);
        var data = Fixture(now);
        var result = Evaluate(now, data);
        check("Combined heaters counted once each", result.LastSevenDays.HeaterKwh == 336);
        check("Solar counted once for the greenhouse", result.LastSevenDays.SolarKwh == 168);
        check("Whole-period net cost", result.LastSevenDays.SignedAmount == 42 && result.LastSevenDays.Label == "Cost");
        check("Currency formatting", result.LastSevenDays.DisplayAmount == "£42.00");
        check("YTD uses complete days only", result.YearToDate.SignedAmount == 42);
        var surplus = Fixture(now, 3000);
        check("Whole-period surplus labelled Saved", Evaluate(now, surplus).LastSevenDays is { SignedAmount: -42, Label: "Saved", DisplayAmount: "£42.00" });
        var offsets = Fixture(now, 2000);
        foreach (var hour in offsets.Solar)
        {
            var day = GreenhouseChartService.Local(hour.AtUtc).Day;
            hour.ProducedWh = day == 1 ? 4000 : day == 2 ? 0 : 2000;
        }
        check("Surplus days offset deficit days across whole period", Evaluate(now, offsets).LastSevenDays.SignedAmount == 0);
        var yesterdayRate = new List<GreenhouseTariff> {
            new() { EffectiveFromDate = new(2026,1,1), EffectiveToDate = new(2026,1,6), RatePence = 10 },
            new() { EffectiveFromDate = new(2026,1,7), EffectiveToDate = new(2026,1,7), RatePence = 40 },
            new() { EffectiveFromDate = new(2026,1,8), RatePence = 99 }
        };
        check("Yesterday's tariff prices the entire period", GreenhouseNetCostService.Build(now, data.Energy, data.Assignments, data.Solar, yesterdayRate).LastSevenDays.SignedAmount == 67.20m);
        check("Missing tariff yields no invented price", GreenhouseNetCostService.Build(now, data.Energy, data.Assignments, data.Solar, []).LastSevenDays.SignedAmount is null);
        yesterdayRate.Add(new() { EffectiveFromDate = new(2026,1,7), RatePence = 20 });
        check("Overlapping tariffs are unavailable", GreenhouseNetCostService.Build(now, data.Energy, data.Assignments, data.Solar, yesterdayRate).LastSevenDays.SignedAmount is null);
        data.Energy.RemoveAt(0);
        check("Missing heater reading is not zero", Evaluate(now, data).LastSevenDays.SignedAmount is null);
        data = Fixture(now);
        data.Solar[0].ReadingCount = 3;
        check("Missing quarter-hour solar coverage is not zero", Evaluate(now, data).LastSevenDays.SignedAmount is null);
        data = Fixture(now);
        data.Solar[0].InvalidCount = 1;
        check("Invalid solar timestamps are rejected", Evaluate(now, data).LastSevenDays.SignedAmount is null);
        data = Fixture(now);
        data.Assignments.Add(data.Assignments[0]);
        check("Duplicate assignment cannot inflate combined cost", Evaluate(now, data).LastSevenDays.SignedAmount is null);
        data = Fixture(new(2026,1,20,12,0,0,DateTimeKind.Utc));
        data.Energy.RemoveAt(0);
        var partial = Evaluate(new(2026,1,20,12,0,0,DateTimeKind.Utc), data);
        check("Weekly total remains available when only earlier YTD data is missing", partial.LastSevenDays.SignedAmount is not null && partial.YearToDate.SignedAmount is null);
        var january = Evaluate(new(2026,1,3,12,0,0,DateTimeKind.Utc), Fixture(new(2026,1,3,12,0,0,DateTimeKind.Utc)));
        check("Seven-day range can cross New Year", january.LastSevenDays.HeaterKwh == 336);
        check("YTD starts at January midnight", january.YearToDate.HeaterKwh == 96);
        var springNow = new DateTime(2026,3,30,12,0,0,DateTimeKind.Utc);
        check("Spring 23-hour day is complete", Evaluate(springNow, Fixture(springNow)).LastSevenDays.SignedAmount == 167 * .25m);
        var autumnNow = new DateTime(2026,10,26,12,0,0,DateTimeKind.Utc);
        check("Autumn 25-hour day is complete", Evaluate(autumnNow, Fixture(autumnNow)).LastSevenDays.SignedAmount == 169 * .25m);
    }

    public static async Task DatabaseAsync(string connection, Action<string, bool> check)
    {
        await using var sql = new MySqlConnection(new MySqlConnectionStringBuilder(connection) {
            AllowUserVariables = true, UseAffectedRows = false }.ConnectionString);
        await sql.OpenAsync();
        await using var transaction = await sql.BeginTransactionAsync();
        try
        {
            await using (var seed = new MySqlCommand("""
                INSERT INTO EnergyMonitoring.TapoEnergyHourly(TapoDeviceKey,HourStartUtc,EnergyWh)
                WITH RECURSIVE ticks(n) AS (SELECT 0 UNION ALL SELECT n+1 FROM ticks WHERE n<167)
                SELECT devices.id,DATE_ADD('2026-01-01',INTERVAL n HOUR),1000
                FROM ticks CROSS JOIN (SELECT 1 AS id UNION ALL SELECT 2) devices;
                INSERT INTO EnergyMonitoring.EnphaseInterval(IntervalEndUtc,ProducedWh)
                WITH RECURSIVE ticks(n) AS (SELECT 1 UNION ALL SELECT n+1 FROM ticks WHERE n<672)
                SELECT DATE_ADD('2026-01-01',INTERVAL n*15 MINUTE),250 FROM ticks;
                """, sql, transaction)) await seed.ExecuteNonQueryAsync();
            var options = new DbContextOptionsBuilder<OrchidDbContext>().UseMySql(sql,
                new MariaDbServerVersion(new Version(10,11,16))).Options;
            await using var db = new OrchidDbContext(options);
            await db.Database.UseTransactionAsync(transaction);
            var service = new GreenhouseNetCostService(db);
            var now = new DateTime(2026,1,8,12,0,0,DateTimeKind.Utc);
            var result = await service.LoadAsync(now, default);
            check("MariaDB solar quarter-hours and both heaters yield net cost", result.LastSevenDays.SignedAmount == 42 && result.YearToDate.SignedAmount == 42);
            check("Midnight solar interval belongs to prior day", result.LastSevenDays.SolarKwh == 168);
            using var memory = new MemoryCache(new MemoryCacheOptions());
            var cache = new GreenhouseChartCache(memory, Options.Create(new GreenhouseChartCacheOptions()));
            var loads = 0;
            async Task<GreenhouseNetCosts> Load(CancellationToken ct) { loads++; return await service.LoadAsync(now, ct); }
            var first = await cache.GetValueAsync("costs", Load, default);
            var second = await cache.GetValueAsync("costs", Load, default);
            check("Net cost cache reuses a complete calculated result", loads == 1 && ReferenceEquals(first, second) && second.LastSevenDays.SignedAmount == 42);
            await using (var gap = new MySqlCommand("UPDATE EnergyMonitoring.EnphaseInterval SET ProducedWh=NULL WHERE IntervalEndUtc='2026-01-07 00:00:00'", sql, transaction)) await gap.ExecuteNonQueryAsync();
            check("MariaDB missing solar reading leaves amount unavailable", (await service.LoadAsync(now, default)).LastSevenDays.SignedAmount is null);
        }
        finally { await transaction.RollbackAsync(); }
    }

    private sealed record Data(List<GreenhouseEnergy> Energy, List<GreenhouseAssignment> Assignments,
        List<GreenhouseSolarHour> Solar);

    private static Data Fixture(DateTime now, decimal solarWh = 1000)
    {
        var (week, year, end) = GreenhouseNetCostService.Range(now);
        var start = week < year ? week : year;
        var energy = new List<GreenhouseEnergy>();
        var solar = new List<GreenhouseSolarHour>();
        for (var hour = GreenhouseChartService.Utc(start); hour < GreenhouseChartService.Utc(end); hour = hour.AddHours(1))
        {
            energy.Add(new() { DeviceId=1,AtUtc=hour,EnergyWh=1000 });
            energy.Add(new() { DeviceId=2,AtUtc=hour,EnergyWh=1000 });
            solar.Add(new() { AtUtc=hour, ProducedWh=solarWh,ReadingCount=4 });
        }
        return new(energy, [new() {DeviceId=1,LocationName="Cool side",Start=new(2020,1,1)},
            new() {DeviceId=2,LocationName="Hot side",Start=new(2020,1,1)}], solar);
    }

    private static GreenhouseNetCosts Evaluate(DateTime now, Data data) => GreenhouseNetCostService.Build(now,
        data.Energy, data.Assignments, data.Solar,
        [new() {EffectiveFromDate=new(2020,1,1),RatePence=25}]);
}
