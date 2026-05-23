namespace OrchidApp.Launcher;

public sealed class OrchidAppLegacyCandidate
{
    public required string RootPath { get; init; }

    public required string MariaDbDataPath { get; init; }

    public required string UploadsPath { get; init; }

    public required string BackupsPath { get; init; }

    public required string LogsPath { get; init; }

    public required string LauncherSettingsPath { get; init; }

    public required bool HasMariaDbData { get; init; }

    public required bool HasUploads { get; init; }

    public required bool HasBackups { get; init; }

    public required bool HasLogs { get; init; }

    public required bool HasLauncherSettings { get; init; }

    public required string DiscoverySource { get; init; }

    public required bool HasOrchidsDatabase { get; init; }

    public bool IsDataBearingLegacyCandidate =>
        HasOrchidsDatabase;
}