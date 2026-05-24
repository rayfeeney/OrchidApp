using System;
using System.IO;

namespace OrchidApp.Launcher.Infrastructure;

public sealed class WindowsProgramDataPaths
{
    public WindowsProgramDataPaths()
        : this(Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData))
    {
    }

    public WindowsProgramDataPaths(string commonApplicationDataPath)
    {
        Root = Path.Combine(commonApplicationDataPath, "OrchidApp");

        Data = Path.Combine(Root, "data");
        MariaDbData = Path.Combine(Data, "mariadb");

        Uploads = Path.Combine(Root, "uploads");

        Backups = Path.Combine(Root, "backups");
        PreUpgradeBackups = Path.Combine(Backups, "pre-upgrade");

        Logs = Path.Combine(Root, "logs");

        LauncherSettingsFile = Path.Combine(Root, "launcher-settings.json");
    }

    public string Root { get; }

    public string Data { get; }

    public string MariaDbData { get; }

    public string Uploads { get; }

    public string Backups { get; }

    public string PreUpgradeBackups { get; }

    public string Logs { get; }

    public string LauncherSettingsFile { get; }

    public string LauncherLogFile => Path.Combine(Logs, "launcher.log");

    public string PreviousLauncherLogFile => Path.Combine(Logs, "launcher.previous.log");

    public string MigrationStateFile => Path.Combine(Root, "migration-state.json");

    public string[] RequiredDirectories => new[]
    {
        Root,
        Data,
        MariaDbData,
        Uploads,
        Backups,
        PreUpgradeBackups,
        Logs
    };
}