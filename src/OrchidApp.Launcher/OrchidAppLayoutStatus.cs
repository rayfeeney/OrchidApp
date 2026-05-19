namespace OrchidApp.Launcher;

public enum OrchidAppLayoutStatus
{
    Unknown = 0,

    NewInstall,
    OldLayoutRequiresMigration,
    ProgramDataLayoutInPlace,

    MultipleLegacyLayoutsFound,
    LegacyAndProgramDataFound,

    InvalidLegacyLayout,
    InvalidProgramDataLayout
}