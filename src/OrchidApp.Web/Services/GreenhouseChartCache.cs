using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Options;
using OrchidApp.Web.Models;

namespace OrchidApp.Web.Services;

public sealed class GreenhouseChartCacheOptions
{
    public int Seconds { get; set; } = 120;
}

// Singleton: only successful prepared results are retained; scoped EF contexts
// belong to the calling request and are never stored in this cache.
public sealed class GreenhouseChartCache(IMemoryCache cache, IOptions<GreenhouseChartCacheOptions> options)
{
    private readonly SemaphoreSlim gate = new(1, 1);

    public static string Key(string databaseIdentity, DateTime now, IEnumerable<string> locations)
    {
        var range = GreenhouseChartService.Range(now);
        return System.Text.Json.JsonSerializer.Serialize(new {
            Version = 1, Database = databaseIdentity, Start = GreenhouseChartService.Utc(range.Start),
            End = GreenhouseChartService.Utc(range.End),
            Locations = locations.Select(n => n.ToUpperInvariant()).Distinct().OrderBy(n => n).ToArray()
        });
    }

    public async Task<IReadOnlyList<GreenhouseChart>> GetAsync(string key,
        Func<CancellationToken, Task<IReadOnlyList<GreenhouseChart>>> load, CancellationToken ct)
    {
        var seconds = Math.Clamp(options.Value.Seconds, 0, 900);
        if (seconds == 0) return await load(ct);
        if (cache.TryGetValue<IReadOnlyList<GreenhouseChart>>(key, out var result)) return result!;
        // Coalesce concurrent cold requests instead of repeating all chart queries.
        await gate.WaitAsync(ct);
        try
        {
            if (cache.TryGetValue<IReadOnlyList<GreenhouseChart>>(key, out result)) return result!;
            result = await load(ct);
            cache.Set(key, result, TimeSpan.FromSeconds(seconds));
            return result;
        }
        finally { gate.Release(); }
    }
}
