namespace OrchidApp.Launcher;

public sealed class OrchidAppLayoutState
{
    public required OrchidAppLayoutStatus Status { get; init; }

    public required string AppRootPath { get; init; }

    public required string ProgramDataRootPath { get; init; }

    public required string CurrentAppLegacyMariaDbDataPath { get; init; }

    public required string CurrentAppLegacyUploadsPath { get; init; }

    public required string CurrentAppLegacyBackupsPath { get; init; }

    public required string CurrentAppLegacyLogsPath { get; init; }

    public required string CurrentAppLegacyLauncherSettingsPath { get; init; }

    public required string ProgramDataMariaDbDataPath { get; init; }

    public required string ProgramDataUploadsPath { get; init; }

    public required string ProgramDataBackupsPath { get; init; }

    public required string ProgramDataLogsPath { get; init; }

    public required string ProgramDataLauncherSettingsPath { get; init; }

    public required bool OldLayoutExists { get; init; }

    public required bool ProgramDataLayoutExists { get; init; }

    public required bool CurrentAppLegacyUploadsExists { get; init; }

    public required bool CurrentAppLegacyLauncherSettingsExists { get; init; }

    public required bool ProgramDataUploadsExists { get; init; }

    public required bool ProgramDataLauncherSettingsExists { get; init; }

    public required IReadOnlyList<OrchidAppLegacyCandidate> LegacyCandidates { get; init; }

    public required int DataBearingLegacyCandidateCount { get; init; }
}