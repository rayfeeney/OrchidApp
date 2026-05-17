namespace OrchidApp.Launcher;

public static class OrchidAppLayoutResolver
{
    public static OrchidAppLayoutState Resolve(string appRoot)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(appRoot);

        var programDataRoot = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData),
            "OrchidApp");

        var oldMariaDbDataPath = Path.Combine(appRoot, "data", "mariadb");
        var oldUploadsPath = Path.Combine(appRoot, "uploads", "plants");
        var oldLauncherSettingsPath = Path.Combine(appRoot, "launcher-settings.json");

        var newMariaDbDataPath = Path.Combine(programDataRoot, "data", "mariadb");
        var newUploadsPath = Path.Combine(programDataRoot, "data", "uploads", "plants");
        var newBackupsPath = Path.Combine(programDataRoot, "backups");
        var newLogsPath = Path.Combine(programDataRoot, "logs");
        var newLauncherSettingsPath = Path.Combine(programDataRoot, "launcher-settings.json");

        var oldLayoutExists =
            Directory.Exists(oldMariaDbDataPath) ||
            Directory.Exists(oldUploadsPath) ||
            File.Exists(oldLauncherSettingsPath);

        var newLayoutExists =
            Directory.Exists(newMariaDbDataPath) ||
            Directory.Exists(newUploadsPath) ||
            File.Exists(newLauncherSettingsPath);

        var status = ResolveStatus(oldLayoutExists, newLayoutExists);

        return new OrchidAppLayoutState
        {
            AppRoot = appRoot,
            ProgramDataRoot = programDataRoot,

            OldMariaDbDataPath = oldMariaDbDataPath,
            OldUploadsPath = oldUploadsPath,
            OldLauncherSettingsPath = oldLauncherSettingsPath,

            NewMariaDbDataPath = newMariaDbDataPath,
            NewUploadsPath = newUploadsPath,
            NewBackupsPath = newBackupsPath,
            NewLogsPath = newLogsPath,
            NewLauncherSettingsPath = newLauncherSettingsPath,

            OldLayoutExists = oldLayoutExists,
            NewLayoutExists = newLayoutExists,

            Status = status
        };
    }

    private static OrchidAppLayoutStatus ResolveStatus(
        bool oldLayoutExists,
        bool newLayoutExists)
    {
        if (oldLayoutExists && newLayoutExists)
        {
            return OrchidAppLayoutStatus.ConflictingLayouts;
        }

        if (oldLayoutExists)
        {
            return OrchidAppLayoutStatus.OldLayoutRequiresMigration;
        }

        if (newLayoutExists)
        {
            return OrchidAppLayoutStatus.CurrentLayout;
        }

        return OrchidAppLayoutStatus.CleanFirstInstall;
    }
}