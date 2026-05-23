namespace OrchidApp.Launcher.Infrastructure;

public sealed class PreUpgradeBackupResult
{
    public bool Succeeded { get; init; }

    public string? BackupPath { get; init; }

    public static PreUpgradeBackupResult Success(string? backupPath)
    {
        return new PreUpgradeBackupResult
        {
            Succeeded = true,
            BackupPath = backupPath
        };
    }

    public static PreUpgradeBackupResult Failure()
    {
        return new PreUpgradeBackupResult
        {
            Succeeded = false,
            BackupPath = null
        };
    }
}