using System;
using System.IO;
using System.Linq;

namespace OrchidApp.Launcher.Infrastructure;

internal sealed class LegacyDataMigrationService
{
    private readonly WindowsProgramDataPaths _programDataPaths;

    public LegacyDataMigrationService(WindowsProgramDataPaths programDataPaths)
    {
        _programDataPaths = programDataPaths;
    }

    public void MigrateFromLegacyRoot(string legacyRootPath)
    {
        if (string.IsNullOrWhiteSpace(legacyRootPath))
        {
            throw new InvalidOperationException("Legacy root path was not provided.");
        }

        var legacyMariaDbPath = Path.Combine(legacyRootPath, "data", "mariadb");
        var legacyUploadsPath = Path.Combine(legacyRootPath, "wwwroot", "uploads");
        var legacySettingsPath = Path.Combine(legacyRootPath, "launcher-settings.json");

        ValidateLegacySource(legacyMariaDbPath);
        ValidateProgramDataTargetIsSafe();

        CopyDirectory(legacyMariaDbPath, _programDataPaths.MariaDbData);

        if (Directory.Exists(legacyUploadsPath))
        {
            CopyDirectory(legacyUploadsPath, _programDataPaths.Uploads);
        }

        if (File.Exists(legacySettingsPath))
        {
            File.Copy(legacySettingsPath, _programDataPaths.LauncherSettingsFile, overwrite: false);
        }
    }

    private static void ValidateLegacySource(string legacyMariaDbPath)
    {
        var legacyOrchidsDatabasePath = Path.Combine(legacyMariaDbPath, "orchids");

        if (!Directory.Exists(legacyOrchidsDatabasePath))
        {
            throw new InvalidOperationException(
                "Legacy migration source is invalid because it does not contain data\\mariadb\\orchids.");
        }

        if (!Directory.EnumerateFileSystemEntries(legacyOrchidsDatabasePath).Any())
        {
            throw new InvalidOperationException(
                "Legacy migration source is invalid because data\\mariadb\\orchids is empty.");
        }
    }

    private void ValidateProgramDataTargetIsSafe()
    {
        var targetOrchidsDatabasePath = Path.Combine(_programDataPaths.MariaDbData, "orchids");

        if (Directory.Exists(targetOrchidsDatabasePath) &&
            Directory.EnumerateFileSystemEntries(targetOrchidsDatabasePath).Any())
        {
            throw new InvalidOperationException(
                "ProgramData already contains an orchids database. Migration has been stopped to avoid overwriting user data.");
        }

        if (Directory.Exists(_programDataPaths.Uploads) &&
            Directory.EnumerateFileSystemEntries(_programDataPaths.Uploads).Any())
        {
            throw new InvalidOperationException(
                "ProgramData uploads folder already contains files. Migration has been stopped to avoid overwriting user uploads.");
        }

        if (File.Exists(_programDataPaths.LauncherSettingsFile))
        {
            throw new InvalidOperationException(
                "ProgramData launcher settings already exist. Migration has been stopped to avoid overwriting user settings.");
        }
    }

    private static void CopyDirectory(string sourceDirectory, string targetDirectory)
    {
        Directory.CreateDirectory(targetDirectory);

        foreach (var sourcePath in Directory.EnumerateFileSystemEntries(
                     sourceDirectory,
                     "*",
                     SearchOption.AllDirectories))
        {
            var relativePath = Path.GetRelativePath(sourceDirectory, sourcePath);
            var targetPath = Path.Combine(targetDirectory, relativePath);

            if (Directory.Exists(sourcePath))
            {
                Directory.CreateDirectory(targetPath);
                continue;
            }

            var targetParentDirectory = Path.GetDirectoryName(targetPath);

            if (!string.IsNullOrWhiteSpace(targetParentDirectory))
            {
                Directory.CreateDirectory(targetParentDirectory);
            }

            File.Copy(sourcePath, targetPath, overwrite: false);
        }
    }
}