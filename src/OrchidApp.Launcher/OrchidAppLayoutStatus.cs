namespace OrchidApp.Launcher;

public enum OrchidAppLayoutStatus
{
    CleanFirstInstall,
    CurrentLayout,
    OldLayoutRequiresMigration,
    ConflictingLayouts
}