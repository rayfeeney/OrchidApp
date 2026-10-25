namespace OrchidApp.Launcher.Infrastructure;

public sealed class MigrationState
{
    public int SchemaVersion { get; set; } = 1;

    public string MigrationStatus { get; set; } = string.Empty;

    public DateTime MigrationStartedAtUtc { get; set; }

    public DateTime? MigrationCompletedAtUtc { get; set; }

    public DateTime? FailedAtUtc { get; set; }

    public string SourceLegacyRootPath { get; set; } = string.Empty;

    public string TargetProgramDataRootPath { get; set; } = string.Empty;

    public string? ApplicationProductVersion { get; set; }

    public string? ApplicationInformationalVersion { get; set; }

    public string? PreUpgradeBackupPath { get; set; }

    public bool MigratedMariaDbData { get; set; }

    public bool MigratedUploads { get; set; }

    public bool MigratedLauncherSettings { get; set; }

    public string? ErrorMessage { get; set; }
    public string? Phase { get; set; }
    public string? OperationId { get; set; }
    public string? SnapshotRootPath { get; set; }
    public string? SourceFingerprint { get; set; }
    public List<MigrationFileEntry>? CopyManifest { get; set; }
}
