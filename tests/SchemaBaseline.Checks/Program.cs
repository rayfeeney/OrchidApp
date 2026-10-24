using System.Security.Cryptography;
using System.Text.Json;
using OrchidApp.Web.Infrastructure;

var count = 0;
void Check(string name, bool passed) { if (!passed) throw new Exception(name); count++; }
void Reject(string name, Action action)
{
    try { action(); } catch (InvalidOperationException) { count++; return; }
    throw new Exception("Did not reject: " + name);
}
var root = Path.GetFullPath(args.Length == 1 ? args[0] : "database/schema");
var manifest = SchemaBaseline.Load(root);
Check("All required schema inputs", manifest.Files.Count >= 87);
var ordered = manifest.Files.Select(f => f.Path).ToList();
Check("View dependencies ordered", ordered.IndexOf("views/venvironmentreadingperiod.sql") < ordered.IndexOf("views/venvironmentdailyperiodsummary.sql") &&
    ordered.IndexOf("views/venvironmentreadingperiod.sql") < ordered.IndexOf("views/venvironmentlastsevendayssummary.sql"));
Check("Manifest digest", manifest.ManifestChecksum.Length == 64);
Check("Line ending independent", SchemaBaseline.TextChecksum("a\r\nb\r\n") == SchemaBaseline.TextChecksum("a\nb\n"));
Reject("Invalid cut-off date", () => SchemaBaseline.Pending([], new Dictionary<string, string> { ["baseline:v1:202602300000"] = new('a', 64) }));
Reject("Empty history", () => SchemaBaseline.Pending([], new Dictionary<string, string>()));
Reject("Unknown marker", () => SchemaBaseline.Pending([], new Dictionary<string, string> { ["baseline:v2:202606041820"] = new('a', 64) }));
Reject("Ambiguous markers", () => SchemaBaseline.Pending([], new Dictionary<string, string> { ["baseline"] = "baseline", [manifest.Marker] = manifest.ManifestChecksum }));

var temporary = Path.Combine(Path.GetTempPath(), "orchids-baseline-" + Guid.NewGuid().ToString("N"));
Directory.CreateDirectory(temporary);
try
{
    var old = Path.Combine(temporary, "202604010000_Historic.sql");
    var sameTimestamp = Path.Combine(temporary, manifest.ThroughMigration + "_AlreadyInSchema.sql");
    var later = Path.Combine(temporary, "209901010000_Future.sql");
    File.WriteAllText(old, "SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Historical SQL must never run';");
    File.WriteAllText(sameTimestamp, "SELECT 1;");
    File.WriteAllText(later, "SELECT 2;");
    var history = new Dictionary<string, string> { [manifest.Marker] = manifest.ManifestChecksum };
    Check("Absent migration directory is unnecessary", SchemaBaseline.Pending([], history).Count == 0);
    Check("Only future change pending", SchemaBaseline.Pending([old, sameTimestamp, later], history).SequenceEqual([later]));
    history[Path.GetFileName(later)] = Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(later)));
    Check("Future change applies once", SchemaBaseline.Pending([old, sameTimestamp, later], history).Count == 0);
    File.AppendAllText(later, "-- tampered");
    Reject("Changed applied SQL", () => SchemaBaseline.Pending([later], history));
    var legacy = new Dictionary<string, string> { ["baseline"] = "baseline", [Path.GetFileName(old)] = Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(old))) };
    Check("Legacy Desktop history preserved", SchemaBaseline.Pending([old, sameTimestamp], legacy).SequenceEqual([sameTimestamp]));
    Check("History not rewritten", legacy.Count == 2 && legacy["baseline"] == "baseline");
    Reject("Invalid migration name", () => SchemaBaseline.Pending([Path.Combine(temporary, "not-a-migration.sql")], history));

    var copiedSchema = Path.Combine(temporary, "schema");
    foreach (var file in Directory.GetFiles(root, "*", SearchOption.AllDirectories))
    {
        var target = Path.Combine(copiedSchema, Path.GetRelativePath(root, file));
        Directory.CreateDirectory(Path.GetDirectoryName(target)!);
        File.Copy(file, target);
    }
    var changed = Path.Combine(copiedSchema, manifest.Files[0].Path);
    File.AppendAllText(changed, "-- drift");
    Reject("Changed creation input", () => SchemaBaseline.Load(copiedSchema));
    File.Copy(Path.Combine(root, manifest.Files[0].Path), changed, true);
    var extra = Path.Combine(copiedSchema, "tables", "unexpected.sql");
    File.WriteAllText(extra, "SELECT 1;");
    Reject("Unlisted SQL", () => SchemaBaseline.Load(copiedSchema));
    File.Delete(extra);
    var invalid = JsonSerializer.Deserialize<SchemaBaseline>(File.ReadAllText(Path.Combine(root, "bootstrap.json")), new JsonSerializerOptions { PropertyNameCaseInsensitive = true })!;
    invalid.Files[0].Path = "../outside.sql";
    File.WriteAllText(Path.Combine(copiedSchema, "bootstrap.json"), JsonSerializer.Serialize(invalid));
    Reject("Path traversal", () => SchemaBaseline.Load(copiedSchema));
}
finally
{
    // Delete only the unique test directory created above, never a caller path.
    var expectedParent = Path.GetFullPath(Path.GetTempPath()).TrimEnd(Path.DirectorySeparatorChar);
    if (!string.Equals(Directory.GetParent(Path.GetFullPath(temporary))!.FullName.TrimEnd(Path.DirectorySeparatorChar),
        expectedParent, StringComparison.OrdinalIgnoreCase) || !Path.GetFileName(temporary).StartsWith("orchids-baseline-", StringComparison.Ordinal))
        throw new InvalidOperationException("Unsafe test cleanup path.");
    Directory.Delete(temporary, true);
}
Console.WriteLine($"{count} schema baseline checks passed.");
