using System.Globalization;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;
using MySqlConnector;

namespace OrchidApp.Web.Infrastructure;

// Creation metadata travels with schema/, never with historical migration SQL.
public sealed class SchemaBaseline
{
    public int FormatVersion { get; set; }
    public string ThroughMigration { get; set; } = "";
    public List<SchemaFile> Files { get; set; } = [];
    public string Marker => "baseline:v1:" + ThroughMigration;
    public string ManifestChecksum { get; private set; } = "";

    public sealed class SchemaFile
    {
        public string Path { get; set; } = "";
        public string Sha256 { get; set; } = "";
    }

    private static readonly string[] Stages = ["tables", "constraints", "routines", "views", "triggers", "seeds"];
    public static bool IsTimestamp(string value) => Regex.IsMatch(value, "^[0-9]{12}$") &&
        DateTime.TryParseExact(value, "yyyyMMddHHmm", CultureInfo.InvariantCulture, DateTimeStyles.None, out _);
    public static string TextChecksum(string text) => Convert.ToHexString(
        SHA256.HashData(Encoding.UTF8.GetBytes(text.Replace("\r\n", "\n").Replace("\r", "\n")))).ToLowerInvariant();

    public static SchemaBaseline Load(string schemaRoot)
    {
        var text = File.ReadAllText(System.IO.Path.Combine(schemaRoot, "bootstrap.json"));
        var plan = JsonSerializer.Deserialize<SchemaBaseline>(text, new JsonSerializerOptions { PropertyNameCaseInsensitive = true })
            ?? throw new InvalidOperationException("Schema bootstrap manifest is empty.");
        if (plan.FormatVersion != 1 || !IsTimestamp(plan.ThroughMigration))
            throw new InvalidOperationException("Unsupported schema baseline format or cut-off.");
        var seen = new HashSet<string>(StringComparer.Ordinal);
        var previousStage = -1;
        foreach (var item in plan.Files)
        {
            if (!Regex.IsMatch(item.Path, @"^[a-z]+/[A-Za-z0-9_]+\.sql$"))
                throw new InvalidOperationException("Unsafe schema path: " + item.Path);
            var stage = Array.IndexOf(Stages, item.Path.Split('/')[0]);
            if (stage < previousStage || stage < 0 || !seen.Add(item.Path))
                throw new InvalidOperationException("Invalid schema order or duplicate file: " + item.Path);
            previousStage = stage;
            var file = System.IO.Path.Combine(schemaRoot, item.Path);
            if (!File.Exists(file) || !string.Equals(TextChecksum(File.ReadAllText(file)), item.Sha256, StringComparison.OrdinalIgnoreCase))
                throw new InvalidOperationException("Schema file missing or changed: " + item.Path);
        }
        var actual = Directory.GetFiles(schemaRoot, "*.sql", SearchOption.AllDirectories)
            .Select(f => System.IO.Path.GetRelativePath(schemaRoot, f).Replace('\\', '/')).ToHashSet(StringComparer.Ordinal);
        if (!actual.SetEquals(seen) || Stages.Any(s => !seen.Any(f => f.StartsWith(s + "/", StringComparison.Ordinal))))
            throw new InvalidOperationException("Schema manifest does not cover the complete schema and seeds.");
        foreach (var required in new[] { "tables/schemaversion.sql", "seeds/observationtype_records.sql", "seeds/phoneticprefix_records.sql", "seeds/propagationtype_records.sql" })
            if (!seen.Contains(required)) throw new InvalidOperationException("Required schema input missing: " + required);
        plan.ManifestChecksum = TextChecksum(text);
        return plan;
    }

    public static Dictionary<string, string> ReadHistory(MySqlConnection connection)
    {
        using var cmd = connection.CreateCommand();
        cmd.CommandText = "SELECT scriptName, checksum FROM schemaversion ORDER BY scriptName";
        using var rows = cmd.ExecuteReader();
        var result = new Dictionary<string, string>(StringComparer.Ordinal);
        while (rows.Read()) result.Add(rows.GetString(0), rows.GetString(1));
        return result;
    }

    // Returns only changes later than a fresh database's own baseline. Legacy
    // Desktop rows remain untouched and continue using their per-file checksums.
    public static IReadOnlyList<string> Pending(IEnumerable<string> files, IReadOnlyDictionary<string, string> history)
    {
        if (history.Count == 0) throw new InvalidOperationException("Database setup is incomplete: migration history is empty. Restore or recreate an explicitly disposable target.");
        var markers = history.Where(p => p.Key.StartsWith("baseline", StringComparison.OrdinalIgnoreCase)).ToArray();
        if (markers.Length > 1) throw new InvalidOperationException("Multiple database baseline markers require review.");
        string? cutoff = null;
        if (markers.Length == 1)
        {
            var marker = markers[0];
            if (marker.Key == "baseline" && marker.Value == "baseline") { /* Existing Desktop contract. */ }
            else if (marker.Key.StartsWith("baseline:v1:", StringComparison.Ordinal) &&
                IsTimestamp(marker.Key[12..]) && Regex.IsMatch(marker.Value, "^[a-fA-F0-9]{64}$")) cutoff = marker.Key[12..];
            else throw new InvalidOperationException("Unrecognised database baseline marker.");
        }
        var pending = new List<string>();
        foreach (var file in files.OrderBy(System.IO.Path.GetFileName, StringComparer.Ordinal))
        {
            var name = System.IO.Path.GetFileName(file);
            if (!Regex.IsMatch(name, @"^[0-9]{12}_[A-Za-z0-9_]+\.sql$") || !IsTimestamp(name[..12]))
                throw new InvalidOperationException("Invalid migration filename: " + name);
            if (history.TryGetValue(name, out var recorded))
            {
                var checksum = Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(file)));
                if (!string.Equals(recorded, checksum, StringComparison.OrdinalIgnoreCase))
                    throw new InvalidOperationException("Applied migration checksum changed: " + name);
            }
            else if (cutoff is null || string.CompareOrdinal(name[..12], cutoff) > 0) pending.Add(file);
        }
        return pending;
    }
}
