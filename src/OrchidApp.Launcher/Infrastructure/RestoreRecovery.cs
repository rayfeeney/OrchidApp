using System.Text.Json;

namespace OrchidApp.Launcher.Infrastructure;

internal sealed class RestoreRecovery(string programDataRoot)
{
    public string PendingPath => Path.Combine(programDataRoot, "restore-pending.json");
    public bool IsPending => File.Exists(PendingPath);

    public string DescribePending()
    {
        using var record = JsonDocument.Parse(File.ReadAllText(PendingPath));
        return $"Restore stopped during {record.RootElement.GetProperty("phase").GetString()}. " +
            $"Recovery input: {record.RootElement.GetProperty("preservedInput").GetString()}\n" +
            $"Safety backup: {record.RootElement.GetProperty("safetyBackup").GetString()}";
    }

    public bool ProtectsCloudDestination(string destination)
    {
        // Keep protecting selected recovery files even after a successful restore/restart.
        if (IsPending) return true;
        var history = Path.Combine(programDataRoot, "restore-recovery");
        if (!Directory.Exists(history)) return false;
        foreach (var path in Directory.EnumerateDirectories(history))
        {
            var recordPath = Path.Combine(path, "recovery.json");
            if (!File.Exists(recordPath)) continue; // Preflight validation failed before replacement.
            using var record = JsonDocument.Parse(File.ReadAllText(recordPath));
            foreach (var property in new[] { "originalInput", "preservedInput", "safetyBackup" })
            {
                var protectedPath = record.RootElement.GetProperty(property).GetString();
                if (property == "safetyBackup" && protectedPath is null) continue; // Preflight can fail before a safety ZIP exists.
                if (string.IsNullOrWhiteSpace(protectedPath)) throw new InvalidDataException("Incomplete restore recovery record.");
                if (string.Equals(Path.GetFullPath(destination), Path.GetFullPath(protectedPath), StringComparison.OrdinalIgnoreCase))
                    return true;
            }
        }
        return false;
    }
}
