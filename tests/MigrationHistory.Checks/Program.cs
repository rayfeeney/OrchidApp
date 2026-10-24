using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using OrchidApp.Web.Infrastructure;

var fixturePath = args.Length == 1 ? args[0] : "tests/MigrationHistory.Checks/Fixtures/policy.json";
var scenarios = JsonDocument.Parse(File.ReadAllText(fixturePath)).RootElement;
var temporary = Path.Combine(Path.GetTempPath(), "orchids-migration-policy-" + Guid.NewGuid().ToString("N"));
Directory.CreateDirectory(temporary);
var count = 0;
try
{
    foreach (var test in scenarios.EnumerateArray())
    {
        var name = test.GetProperty("name").GetString()!;
        var folder = Path.Combine(temporary, count.ToString());
        Directory.CreateDirectory(folder);
        var files = new List<string>();
        foreach (var file in test.GetProperty("files").EnumerateArray())
        {
            var path = Path.Combine(folder, file.GetProperty("name").GetString()!);
            File.WriteAllText(path, file.GetProperty("sql").GetString(), new UTF8Encoding(false));
            files.Add(path);
        }
        var history = new Dictionary<string, string>(StringComparer.Ordinal);
        foreach (var row in test.GetProperty("history").EnumerateArray())
        {
            var checksum = row.TryGetProperty("checksum", out var literal) ? literal.GetString()! :
                Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(row.GetProperty("sql").GetString()!))).ToLowerInvariant();
            history.Add(row.GetProperty("name").GetString()!, checksum);
        }
        var expectedError = test.TryGetProperty("error", out var error) ? error.GetString() : null;
        IReadOnlyList<MigrationFile>? plan = null;
        Exception? failure = null;
        try { plan = MigrationHistory.Plan(files, history); } catch (InvalidOperationException ex) { failure = ex; }
        if (expectedError is not null)
        {
            if (failure is null || !failure.Message.Contains(expectedError, StringComparison.OrdinalIgnoreCase))
                throw new Exception($"{name}: expected '{expectedError}', got '{failure?.Message ?? "success"}'");
        }
        else
        {
            if (failure is not null) throw new Exception(name, failure);
            var validatedPlan = plan ?? throw new Exception(name + ": no plan returned");
            var expected = test.GetProperty("pending").EnumerateArray().Select(v => v.GetString());
            if (!validatedPlan.Select(file => file.Name).SequenceEqual(expected)) throw new Exception(name + ": incorrect pending order");
            foreach (var item in validatedPlan)
                if (item.Checksum != MigrationHistory.Checksum(item.Path) || item.Sql != File.ReadAllText(item.Path))
                    throw new Exception(name + ": SQL/checksum snapshot differs");
        }
        count++;
    }
}
finally
{
    var parent = Path.GetFullPath(Path.GetTempPath()).TrimEnd(Path.DirectorySeparatorChar);
    if (!string.Equals(Directory.GetParent(Path.GetFullPath(temporary))!.FullName.TrimEnd(Path.DirectorySeparatorChar), parent, StringComparison.OrdinalIgnoreCase) ||
        !Path.GetFileName(temporary).StartsWith("orchids-migration-policy-", StringComparison.Ordinal)) throw new Exception("Unsafe cleanup path.");
    Directory.Delete(temporary, true);
}
var repo = Path.GetFullPath(Path.Combine(Path.GetDirectoryName(fixturePath)!, "../../.."));
var packageFiles = Directory.GetFiles(Path.Combine(repo, "database", "migrations"))
    .Where(path => Path.GetExtension(path).Equals(".sql", StringComparison.OrdinalIgnoreCase)).ToArray();
var packageHistory = packageFiles.ToDictionary(path => Path.GetFileName(path), path => MigrationHistory.Checksum(path), StringComparer.Ordinal);
packageHistory.Add("baseline", "baseline");
if (MigrationHistory.Plan(packageFiles, packageHistory).Count != 0) throw new Exception("Package inventory validation failed.");
Console.WriteLine($"{count} Desktop migration policy scenarios passed; {packageFiles.Length} packaged migrations validated.");
