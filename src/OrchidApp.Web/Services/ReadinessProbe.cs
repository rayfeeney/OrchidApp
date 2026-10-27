using Microsoft.Extensions.Options;
using MySqlConnector;
using OrchidApp.Web.Configuration;
using OrchidApp.Web.Infrastructure;

namespace OrchidApp.Web.Services;

public sealed record ReadinessResult(bool Ready, IReadOnlyDictionary<string, bool> Checks);

public sealed class ReadinessProbe(IConfiguration configuration, IOptions<StorageSettings> storage,
    IPhotoNativeProbe native, PhotoRecoveryRegistry recovery, ILogger<ReadinessProbe> logger)
{
    public async Task<ReadinessResult> CheckAsync(CancellationToken ct)
    {
        var checks = new Dictionary<string, bool> { ["database"] = false, ["uploadRoot"] = false,
            ["nativePhotos"] = false, ["photoFiles"] = false, ["photoRecovery"] = false };
        var root = storage.Value.UploadRoot;
        var references = new List<(string Folder, string Main, string Thumb)>();
        try
        {
            var configured = configuration.GetConnectionString("OrchidDb");
            if (string.IsNullOrWhiteSpace(configured)) throw new InvalidOperationException("Database target is not configured.");
            var builder = new MySqlConnectionStringBuilder(configured)
                { ConnectionTimeout = 3, DefaultCommandTimeout = 3 };
            await using var connection = new MySqlConnection(builder.ConnectionString);
            await connection.OpenAsync(ct);
            await using var command = connection.CreateCommand();
            command.CommandText = "SELECT scriptName,checksum FROM schemaversion;";
            var history = new Dictionary<string, string>(StringComparer.Ordinal);
            await using (var reader = await command.ExecuteReaderAsync(ct))
                while (await reader.ReadAsync(ct)) history.Add(reader.GetString(0), reader.GetString(1));
            // Fresh baselines include this contract; upgraded databases must
            // carry the exact immutable migration, not merely an empty queue.
            bool photoSchema = PhotoSchemaContract.IsReady(history);
            command.CommandText = "SELECT plantId FROM plant LIMIT 0; SELECT taxonId FROM taxon LIMIT 0;";
            await using (var reader = await command.ExecuteReaderAsync(ct))
                while (await reader.NextResultAsync(ct)) { }
            command.CommandText = "SELECT CONCAT('plants/',plantId),fileName,COALESCE(NULLIF(thumbnailFileName,''),fileName) FROM plantphoto WHERE isActive=1 UNION ALL SELECT CONCAT('taxa/',taxonId),fileName,COALESCE(NULLIF(thumbnailFileName,''),fileName) FROM taxonphoto WHERE isActive=1;";
            await using (var reader = await command.ExecuteReaderAsync(ct))
                while (await reader.ReadAsync(ct)) references.Add((reader.GetString(0), reader.GetString(1), reader.GetString(2)));
            checks["database"] = photoSchema;
        }
        catch (Exception) { logger.LogWarning("Readiness database check failed"); }
        if (string.IsNullOrWhiteSpace(root) || !Path.IsPathFullyQualified(root) || !Directory.Exists(root))
            return new(false, checks);
        var probe = Path.Combine(root, ".readiness-" + Guid.NewGuid().ToString("N"));
        try
        {
            Directory.CreateDirectory(probe);
            var witness = Path.Combine(probe, "write-check");
            await File.WriteAllBytesAsync(witness, new byte[] { 1, 2, 3 }, ct);
            checks["uploadRoot"] = (await File.ReadAllBytesAsync(witness, ct)).SequenceEqual(new byte[] { 1, 2, 3 });
            File.Delete(witness);
            var journals = Path.Combine(root, ".photo-recovery");
            checks["photoRecovery"] = !Directory.Exists(journals) || !Directory.EnumerateFiles(journals)
                .Any(path => !recovery.IsActive(path.EndsWith(".tmp", StringComparison.Ordinal) ? path[..^4] : path));
            if (checks["database"])
                checks["photoFiles"] = references.All(item => new[] { item.Main, item.Thumb }.All(name =>
                {
                    var normalized = name.Replace('\\', '/');
                    if (string.IsNullOrWhiteSpace(name) || Path.IsPathRooted(normalized) || normalized.Split('/').Any(part => part is "." or "..")) return false;
                    var directory = Path.GetFullPath(Path.Combine(root, item.Folder)).TrimEnd(Path.DirectorySeparatorChar) + Path.DirectorySeparatorChar;
                    var full = Path.GetFullPath(Path.Combine(directory, normalized));
                    if (!full.StartsWith(directory, OperatingSystem.IsWindows() ? StringComparison.OrdinalIgnoreCase : StringComparison.Ordinal)) return false;
                    var file = new FileInfo(full);
                    return file.Exists && file.Length > 0;
                }));
            checks["nativePhotos"] = await native.CheckAsync(probe, ct);
        }
        catch (Exception) { logger.LogWarning("Readiness photo storage/native check failed"); }
        finally
        {
            try
            {
                // Only this generated, contained probe is removed.
                var prefix = Path.GetFullPath(root).TrimEnd(Path.DirectorySeparatorChar) + Path.DirectorySeparatorChar;
                if (Path.GetFullPath(probe).StartsWith(prefix, OperatingSystem.IsWindows() ? StringComparison.OrdinalIgnoreCase : StringComparison.Ordinal)
                    && Directory.Exists(probe)) Directory.Delete(probe, recursive: true);
            }
            catch (Exception) { checks["uploadRoot"] = false; logger.LogWarning("Readiness probe cleanup failed"); }
        }
        return new(checks.Values.All(value => value), checks);
    }
}
