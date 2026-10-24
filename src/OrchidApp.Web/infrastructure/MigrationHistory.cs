using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;

namespace OrchidApp.Web.Infrastructure;

public sealed record MigrationFile(string Path, string Name, string Timestamp, string Checksum, string Sql);

public static class MigrationHistory
{
    public const string PendingMarker = "migration:pending";
    private static bool IsChecksum(string value) => Regex.IsMatch(value, "^[a-fA-F0-9]{64}$");
    public static string Checksum(string path) => Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(path))).ToLowerInvariant();

    public static string Timestamp(string name)
    {
        if (name.Length > 255 || !Regex.IsMatch(name, @"^[0-9]{12}_[A-Za-z0-9_]+\.sql$") || !SchemaBaseline.IsTimestamp(name[..12]))
            throw new InvalidOperationException("Invalid migration filename: " + name);
        return name[..12];
    }

    public static string? Cutoff(IReadOnlyDictionary<string, string> history)
    {
        if (history.Count == 0) throw new InvalidOperationException("Database setup is incomplete: migration history is empty.");
        var incomplete = history.FirstOrDefault(p => p.Key.StartsWith("migration:", StringComparison.OrdinalIgnoreCase));
        if (incomplete.Key is not null)
            throw new InvalidOperationException($"An incomplete or running migration requires review ({incomplete.Key}, checksum {incomplete.Value}). SQL may be partially applied. Do not automatically retry; inspect the earlier error and restore a verified pre-migration backup when needed.");
        var markers = history.Where(p => p.Key.StartsWith("baseline", StringComparison.OrdinalIgnoreCase)).ToArray();
        if (markers.Length > 1) throw new InvalidOperationException("Multiple database baseline markers require review.");
        if (markers.Length == 0) return null;
        var marker = markers[0];
        if (marker.Key == "baseline" && marker.Value == "baseline") return null;
        if (!marker.Key.StartsWith("baseline:v1:", StringComparison.Ordinal) || !SchemaBaseline.IsTimestamp(marker.Key[12..]) || !IsChecksum(marker.Value))
            throw new InvalidOperationException("Unrecognised database baseline marker.");
        return marker.Key[12..];
    }

    // Full preflight: reject every invalid history/file before returning any SQL.
    public static IReadOnlyList<MigrationFile> Plan(IEnumerable<string> files, IReadOnlyDictionary<string, string> history)
    {
        var cutoff = Cutoff(history);
        var byName = new Dictionary<string, string>(StringComparer.Ordinal);
        var timestamps = new Dictionary<string, string>(StringComparer.Ordinal);
        void Register(string name)
        {
            var stamp = Timestamp(name);
            if (timestamps.TryGetValue(stamp, out var other) && other != name)
                throw new InvalidOperationException($"Duplicate migration timestamp {stamp}: {other} / {name}");
            timestamps[stamp] = name;
        }
        foreach (var path in files)
        {
            var name = Path.GetFileName(path);
            Register(name);
            if (!byName.TryAdd(name, path)) throw new InvalidOperationException("Duplicate migration file: " + name);
        }
        var applied = history.Where(p => !p.Key.StartsWith("baseline", StringComparison.OrdinalIgnoreCase)).ToArray();
        if (history.ContainsKey("baseline") && applied.Length == 0 && byName.Count > 0)
            throw new InvalidOperationException("Legacy baseline has no recorded migration ledger; review compatibility before upgrading.");
        string? latest = cutoff;
        foreach (var row in applied)
        {
            Register(row.Key);
            var stamp = Timestamp(row.Key);
            if (!IsChecksum(row.Value)) throw new InvalidOperationException("Invalid recorded migration checksum: " + row.Key);
            if (byName.TryGetValue(row.Key, out var path))
            {
                if (!string.Equals(Checksum(path), row.Value, StringComparison.OrdinalIgnoreCase))
                    throw new InvalidOperationException("Applied migration checksum changed: " + row.Key);
            }
            else if (cutoff is null || string.CompareOrdinal(stamp, cutoff) > 0)
                throw new InvalidOperationException("Applied migration file is missing: " + row.Key);
            if (latest is null || string.CompareOrdinal(stamp, latest) > 0) latest = stamp;
        }
        var pending = new List<MigrationFile>();
        foreach (var (name, path) in byName.OrderBy(p => p.Key, StringComparer.Ordinal))
        {
            var stamp = Timestamp(name);
            if (history.ContainsKey(name) || (cutoff is not null && string.CompareOrdinal(stamp, cutoff) <= 0)) continue;
            if (latest is not null && string.CompareOrdinal(stamp, latest) <= 0)
                throw new InvalidOperationException("Backdated or out-of-order pending migration: " + name);
            var bytes = File.ReadAllBytes(path);
            var sql = new UTF8Encoding(false, true).GetString(bytes).TrimStart('\uFEFF');
            pending.Add(new(path, name, stamp, Convert.ToHexString(SHA256.HashData(bytes)).ToLowerInvariant(), sql));
        }
        return pending;
    }
}
