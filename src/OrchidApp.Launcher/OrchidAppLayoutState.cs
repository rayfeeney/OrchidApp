namespace OrchidApp.Launcher;

public sealed class OrchidAppLayoutState
{
    public required string AppRoot { get; init; }
    public required string ProgramDataRoot { get; init; }

    public required string OldMariaDbDataPath { get; init; }
    public required string OldUploadsPath { get; init; }
    public required string OldLauncherSettingsPath { get; init; }

    public required string NewMariaDbDataPath { get; init; }
    public required string NewUploadsPath { get; init; }
    public required string NewBackupsPath { get; init; }
    public required string NewLogsPath { get; init; }
    public required string NewLauncherSettingsPath { get; init; }

    public required bool OldLayoutExists { get; init; }
    public required bool NewLayoutExists { get; init; }

    public required OrchidAppLayoutStatus Status { get; init; }
}