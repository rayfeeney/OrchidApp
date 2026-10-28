using System.Data.Common;
using System.Diagnostics;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Options;
using MySqlConnector;
using OrchidApp.Web.Data;
using OrchidApp.Web.Models;
using OrchidApp.Web.Services;

internal static class PerformanceChecks
{
    public static async Task CacheAsync(Action<string, bool> check)
    {
        var clock = new TestClock();
        using var memory = new MemoryCache(new MemoryCacheOptions { Clock = clock });
        var cache = new GreenhouseChartCache(memory, Options.Create(new GreenhouseChartCacheOptions()));
        var now = new DateTime(2026, 10, 23, 12, 0, 0, DateTimeKind.Utc);
        var key = GreenhouseChartCache.Key("test", now, ["Cool side", "Hot side"]);
        var loads = 0;
        async Task<IReadOnlyList<GreenhouseChart>> Load(CancellationToken ct)
        {
            Interlocked.Increment(ref loads);
            await Task.Delay(20, ct);
            return [new() { LocationName = "Cool side" }];
        }
        var results = await Task.WhenAll(Enumerable.Range(0, 12).Select(_ => cache.GetAsync(key, Load, default)));
        check("Concurrent misses perform one load", loads == 1);
        check("Cache hit reuses prepared charts", ReferenceEquals(results[0], await cache.GetAsync(key, Load, default)) && loads == 1);
        clock.UtcNow = clock.UtcNow.AddSeconds(121);
        await cache.GetAsync(key, Load, default);
        check("Absolute expiry refreshes charts", loads == 2);
        check("Cache key is location-order independent", key == GreenhouseChartCache.Key("test", now, ["hot SIDE", "cool SIDE"]));
        check("Different database cannot reuse cached chart", key != GreenhouseChartCache.Key("other", now, ["Cool side", "Hot side"]));
        var midnight = new DateTime(2026, 10, 23, 23, 0, 0, DateTimeKind.Utc);
        check("London midnight changes cache key", GreenhouseChartCache.Key("test", midnight.AddMinutes(-1), ["Cool side"]) != GreenhouseChartCache.Key("test", midnight, ["Cool side"]));
        var propagated = false;
        try { await cache.GetAsync("failure", _ => throw new IOException("fixture"), default); }
        catch (IOException) { propagated = true; }
        check("Loader exception is propagated rather than cached as unavailable", propagated);
        await cache.GetAsync("failure", Load, default);
        check("Failures do not poison the cache", loads == 3);
        var unavailableLoads = 0;
        var unavailable = GreenhouseChartService.Build("Cool side", now, [], [], [], [], [], [], []);
        Task<IReadOnlyList<GreenhouseChart>> LoadUnavailable(CancellationToken ct)
        {
            unavailableLoads++;
            return Task.FromResult<IReadOnlyList<GreenhouseChart>>([unavailable]);
        }
        var missing = await cache.GetAsync("domain-unavailable", LoadUnavailable, default);
        var cachedMissing = await cache.GetAsync("domain-unavailable", LoadUnavailable, default);
        check("Successful domain-unavailable result is cached", unavailableLoads == 1 && ReferenceEquals(missing, cachedMissing));
        check("Cached missing readings and costs remain null", cachedMissing[0].Temperatures.All(p => p.Y is null)
            && cachedMissing[0].Costs.All(p => p.Y is null) && cachedMissing[0].Periods.All(p => p.Target is null));
        clock.UtcNow = clock.UtcNow.AddSeconds(121);
        var recovered = await cache.GetAsync("domain-unavailable", Load, default);
        check("Unavailable result expires and can recover", !ReferenceEquals(missing, recovered) && loads == 4);
        using var disabledMemory = new MemoryCache(new MemoryCacheOptions());
        var disabled = new GreenhouseChartCache(disabledMemory, Options.Create(new GreenhouseChartCacheOptions { Seconds = 0 }));
        await disabled.GetAsync(key, Load, default);
        await disabled.GetAsync(key, Load, default);
        check("Zero seconds disables caching", loads == 6);
    }

    public static async Task DatabaseAsync(string connection, DateTime now, Action<string, bool> check)
    {
        var recorder = new CommandRecorder();
        var options = new DbContextOptionsBuilder<OrchidDbContext>().UseMySql(connection,
            new MariaDbServerVersion(new Version(10, 11, 16))).AddInterceptors(recorder).Options;
        await using var db = new OrchidDbContext(options);
        var service = new GreenhouseChartService(db);
        var charts = await service.LoadAsync(["Cool side", "Hot side"], now, default);
        check("Two SQL aggregate queries replace raw reading loads", recorder.Queries.Count(q => q.Sql.Contains("WITH mapped") || q.Sql.Contains("WITH classified")) == 2);
        using var memory = new MemoryCache(new MemoryCacheOptions());
        var cache = new GreenhouseChartCache(memory, Options.Create(new GreenhouseChartCacheOptions()));
        var key = GreenhouseChartCache.Key("integration", now, ["Cool side", "Hot side"]);
        await cache.GetAsync(key, ct => service.LoadAsync(["Cool side", "Hot side"], now, ct), default);
        var afterFirst = recorder.Queries.Count;
        await cache.GetAsync(key, ct => service.LoadAsync(["Cool side", "Hot side"], now, ct), default);
        check("Warm chart cache executes no database commands", recorder.Queries.Count == afterFirst);

        await using var sql = new MySqlConnection(new MySqlConnectionStringBuilder(connection) { AllowUserVariables = true, UseAffectedRows = false }.ConnectionString);
        await sql.OpenAsync();
        await using (var command = new MySqlCommand("INSERT INTO orchids.environmentsensor (environmentSensorId,sensorName,locationName,effectiveFromDate) VALUES (900,'cool','Hot side','2025-02-01')", sql))
            await command.ExecuteNonQueryAsync();
        try
        {
            var conflict = await service.LoadAsync(["Cool side"], now, default);
            check("SQL detects a conflicting mapping outside requested location", conflict[0].Temperatures[12].Y is null &&
                conflict[0].Periods.Single(p => p.Label.StartsWith("16 Oct Day")).Average is null);
        }
        finally
        {
            await using var command = new MySqlCommand("DELETE FROM orchids.environmentsensor WHERE environmentSensorId=900", sql);
            await command.ExecuteNonQueryAsync();
        }
        if (Environment.GetEnvironmentVariable("GREENHOUSE_BENCHMARK") != "1") return;

        // This connection points only at the explicitly guarded disposable test instance.
        // Roll back synthetic readings so ordinary integration fixtures remain unchanged.
        await using (var digits = new MySqlCommand("CREATE TEMPORARY TABLE digits(n INT); INSERT INTO digits VALUES(0),(1),(2),(3),(4),(5),(6),(7),(8),(9)", sql))
            await digits.ExecuteNonQueryAsync();
        await using var transaction = await sql.BeginTransactionAsync();
        try
        {
            const string sequence = "SELECT a.n+10*b.n+100*c.n+1000*d.n+10000*e.n+100000*f.n+1000000*g.n AS n FROM digits a CROSS JOIN digits b CROSS JOIN digits c CROSS JOIN digits d CROSS JOIN digits e CROSS JOIN digits f CROSS JOIN digits g";
            await using (var seed = new MySqlCommand($"""
                INSERT INTO orchids.environmentreading(sensorName,readingDateTime,temperatureCelsius,relativeHumidity)
                SELECT CASE WHEN MOD(n,2)=0 THEN 'cool' ELSE 'hot' END, DATE_ADD('2022-01-01',INTERVAL n MINUTE),15,70
                FROM ({sequence}) seq WHERE n < 1140000;
                INSERT IGNORE INTO orchids.environmentreading(sensorName,readingDateTime,temperatureCelsius,relativeHumidity)
                SELECT sensors.name,DATE_ADD('2026-10-15 22:00:00',INTERVAL n MINUTE),10+MOD(n,15),70
                FROM ({sequence}) seq CROSS JOIN (SELECT 'cool' AS name UNION ALL SELECT 'hot') sensors WHERE n < 10080;
                """, sql, transaction) { CommandTimeout = 180 })
                await seed.ExecuteNonQueryAsync();
            // Use this connection/transaction to observe the uncommitted generated data.
            var benchmarkOptions = new DbContextOptionsBuilder<OrchidDbContext>().UseMySql(sql,
                new MariaDbServerVersion(new Version(10, 11, 16))).AddInterceptors(recorder).Options;
            await using var benchmarkDb = new OrchidDbContext(benchmarkOptions);
            await benchmarkDb.Database.UseTransactionAsync(transaction);
            var benchmarkService = new GreenhouseChartService(benchmarkDb);
            recorder.Queries.Clear();
            var watch = Stopwatch.StartNew();
            var dense = await benchmarkService.LoadAsync(["Cool side", "Hot side"], now, default);
            watch.Stop();
            Console.WriteLine($"Synthetic benchmark: 1,140,000 historical rows plus 20,160 recent minute readings; uncached chart load {watch.ElapsedMilliseconds} ms.");
            foreach (var query in recorder.Queries.Where(q => q.Sql.Contains("WITH mapped") || q.Sql.Contains("WITH classified")).ToArray())
            {
                await using var explain = new MySqlCommand("EXPLAIN FORMAT=JSON " + query.Sql, sql, transaction);
                foreach (var (name, value) in query.Parameters) explain.Parameters.AddWithValue(name, value);
                var plan = (string)(await explain.ExecuteScalarAsync())!;
                Console.WriteLine(query.Sql.Contains("WITH mapped") ? "Hourly query plan:" : "Period query plan:");
                Console.WriteLine(plan);
                check("Aggregate query plan uses timestamp range index", plan.Contains("ixEnvironmentReading_ReadingDateTime") && plan.Contains("\"range\""));
                await using var count = new MySqlCommand("SELECT COUNT(*) FROM (" + query.Sql + ") aggregate_rows", sql, transaction);
                foreach (var (name, value) in query.Parameters) count.Parameters.AddWithValue(name, value);
                Console.WriteLine("Aggregate rows transferred: " + await count.ExecuteScalarAsync());
            }
            await using var direct = new MySqlCommand("SELECT ROUND(AVG(temperatureCelsius),1) FROM orchids.environmentreading WHERE sensorName='cool' AND readingDateTime >= '2026-10-16 10:00' AND readingDateTime < '2026-10-16 16:00'", sql, transaction);
            var expected = Convert.ToDecimal(await direct.ExecuteScalarAsync());
            check("Dense SQL period mean equals direct underlying-reading AVG", dense[0].Periods.Single(p => p.Label.StartsWith("16 Oct Day")).Average == expected);
        }
        finally { await transaction.RollbackAsync(); }
    }

    private sealed class TestClock : Microsoft.Extensions.Internal.ISystemClock
    {
        public DateTimeOffset UtcNow { get; set; } = DateTimeOffset.UtcNow;
    }

    private sealed class CommandRecorder : DbCommandInterceptor
    {
        public List<(string Sql, List<(string Name, object Value)> Parameters)> Queries { get; } = [];
        public override ValueTask<InterceptionResult<DbDataReader>> ReaderExecutingAsync(DbCommand command,
            CommandEventData eventData, InterceptionResult<DbDataReader> result, CancellationToken cancellationToken = default)
        {
            Queries.Add((command.CommandText, command.Parameters.Cast<DbParameter>().Select(p => (p.ParameterName, p.Value!)).ToList()));
            return ValueTask.FromResult(result);
        }
    }
}


