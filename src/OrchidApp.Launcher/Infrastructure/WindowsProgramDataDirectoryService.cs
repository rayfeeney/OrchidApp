using System;
using System.IO;

namespace OrchidApp.Launcher.Infrastructure;

internal sealed class WindowsProgramDataDirectoryService
{
    private readonly WindowsProgramDataPaths _paths;
    private readonly Action<string> _log;

    public WindowsProgramDataDirectoryService(
        WindowsProgramDataPaths paths,
        Action<string> log)
    {
        _paths = paths;
        _log = log;
    }

    public void EnsureRequiredDirectoriesExist()
    {
        foreach (var directory in _paths.RequiredDirectories)
        {
            Directory.CreateDirectory(directory);
        }

        _log("ProgramData folder structure verified.");
        _log($"ProgramData root: {_paths.Root}");
        _log($"MariaDB data folder: {_paths.MariaDbData}");
        _log($"Uploads folder: {_paths.Uploads}");
        _log($"Backups folder: {_paths.Backups}");
        _log($"Pre-upgrade backups folder: {_paths.PreUpgradeBackups}");
        _log($"Logs folder: {_paths.Logs}");
        _log($"Launcher settings file: {_paths.LauncherSettingsFile}");
    }
}