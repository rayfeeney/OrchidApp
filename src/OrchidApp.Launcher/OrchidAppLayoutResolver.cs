namespace OrchidApp.Launcher;

public static class OrchidAppLayoutResolver
{
    public static OrchidAppLayoutState Resolve(string appRoot)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(appRoot);

        var programDataRootPath = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData),
            "OrchidApp");

        var currentAppLegacyCandidate = InspectLegacyCandidate(
            appRoot,
            "Current running launcher");

        var legacyCandidates = new List<OrchidAppLegacyCandidate>
        {
            currentAppLegacyCandidate
        };

        foreach (var desktopFolder in GetDesktopOrchidAppFolders())
        {
            legacyCandidates.Add(
                InspectLegacyCandidate(
                    desktopFolder,
                    "Desktop OrchidApp folder"));
        }

        foreach (var shortcutTargetRoot in GetShortcutTargetRoots())
        {
            legacyCandidates.Add(
                InspectLegacyCandidate(
                    shortcutTargetRoot,
                    "Desktop/Start Menu shortcut"));
        }

        foreach (var commonInstallFolder in GetCommonInstallCandidateFolders())
        {
            legacyCandidates.Add(
                InspectLegacyCandidate(
                    commonInstallFolder,
                    "Common install folder"));
        }

        foreach (var backstopFolder in GetBackstopOrchidAppFolders())
        {
            legacyCandidates.Add(
                InspectLegacyCandidate(
                    backstopFolder,
                    "Backstop OrchidApp folder search"));
        }

        legacyCandidates = legacyCandidates
            .GroupBy(
                candidate => Path.GetFullPath(candidate.RootPath).TrimEnd(Path.DirectorySeparatorChar),
                StringComparer.OrdinalIgnoreCase)
            .Select(group => group.First())
            .ToList();

        var programDataMariaDbDataPath = Path.Combine(programDataRootPath, "data", "mariadb");
        var programDataUploadsPath = Path.Combine(programDataRootPath, "uploads");
        var programDataBackupsPath = Path.Combine(programDataRootPath, "backups");
        var programDataLogsPath = Path.Combine(programDataRootPath, "logs");
        var programDataLauncherSettingsPath = Path.Combine(programDataRootPath, "launcher-settings.json");

        var dataBearingLegacyCandidates = legacyCandidates
            .Where(candidate => candidate.IsDataBearingLegacyCandidate)
            .ToList();

        var oldLayoutExists =
            dataBearingLegacyCandidates.Count > 0;

        var programDataLayoutExists =
            Directory.Exists(programDataMariaDbDataPath);

        var programDataUploadsExists =
            Directory.Exists(programDataUploadsPath);

        var programDataLauncherSettingsExists =
            File.Exists(programDataLauncherSettingsPath);

        var status = ResolveStatus(
            dataBearingLegacyCandidates.Count,
            programDataLayoutExists);

        return new OrchidAppLayoutState
        {
            AppRootPath = appRoot,
            ProgramDataRootPath = programDataRootPath,

            CurrentAppLegacyMariaDbDataPath = currentAppLegacyCandidate.MariaDbDataPath,
            CurrentAppLegacyUploadsPath = currentAppLegacyCandidate.UploadsPath,
            CurrentAppLegacyBackupsPath = currentAppLegacyCandidate.BackupsPath,
            CurrentAppLegacyLogsPath = currentAppLegacyCandidate.LogsPath,
            CurrentAppLegacyLauncherSettingsPath = currentAppLegacyCandidate.LauncherSettingsPath,

            ProgramDataMariaDbDataPath = programDataMariaDbDataPath,
            ProgramDataUploadsPath = programDataUploadsPath,
            ProgramDataBackupsPath = programDataBackupsPath,
            ProgramDataLogsPath = programDataLogsPath,
            ProgramDataLauncherSettingsPath = programDataLauncherSettingsPath,

            OldLayoutExists = oldLayoutExists,
            CurrentAppLegacyUploadsExists = currentAppLegacyCandidate.HasUploads,
            CurrentAppLegacyLauncherSettingsExists = currentAppLegacyCandidate.HasLauncherSettings,

            ProgramDataLayoutExists = programDataLayoutExists,
            ProgramDataUploadsExists = programDataUploadsExists,
            ProgramDataLauncherSettingsExists = programDataLauncherSettingsExists,

            LegacyCandidates = legacyCandidates,
            DataBearingLegacyCandidateCount = dataBearingLegacyCandidates.Count,

            Status = status
        };
    }

    private static IEnumerable<string> GetDesktopOrchidAppFolders()
    {
        var candidateFolders = new List<string>();

        var userDesktop = Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory);
        var publicDesktop = Environment.GetFolderPath(Environment.SpecialFolder.CommonDesktopDirectory);

        if (!string.IsNullOrWhiteSpace(userDesktop))
        {
            candidateFolders.Add(Path.Combine(userDesktop, "OrchidApp"));
        }

        if (!string.IsNullOrWhiteSpace(publicDesktop))
        {
            candidateFolders.Add(Path.Combine(publicDesktop, "OrchidApp"));
        }

        var userProfile = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);

        if (!string.IsNullOrWhiteSpace(userProfile))
        {
            candidateFolders.Add(Path.Combine(userProfile, "OneDrive", "Desktop", "OrchidApp"));
        }

        return candidateFolders
            .Where(Directory.Exists)
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToList();
    }

    private static IEnumerable<string> GetShortcutTargetRoots()
    {
        var shortcutTargetRoots = new List<string>();

        var userDesktop = Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory);
        var publicDesktop = Environment.GetFolderPath(Environment.SpecialFolder.CommonDesktopDirectory);
        var userStartMenu = Environment.GetFolderPath(Environment.SpecialFolder.StartMenu);
        var commonStartMenu = Environment.GetFolderPath(Environment.SpecialFolder.CommonStartMenu);

        AddShortcutTargetRoots(shortcutTargetRoots, userDesktop);
        AddShortcutTargetRoots(shortcutTargetRoots, publicDesktop);
        AddShortcutTargetRoots(shortcutTargetRoots, userStartMenu);
        AddShortcutTargetRoots(shortcutTargetRoots, commonStartMenu);

        return shortcutTargetRoots
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToList();
    }

    private static void AddShortcutTargetRoots(
        List<string> shortcutTargetRoots,
        string shortcutSearchRoot)
    {
        if (string.IsNullOrWhiteSpace(shortcutSearchRoot) ||
            !Directory.Exists(shortcutSearchRoot))
        {
            return;
        }

        foreach (var shortcutPath in Directory.EnumerateFiles(
            shortcutSearchRoot,
            "*.lnk",
            SearchOption.AllDirectories))
        {
            try
            {
                var shellType = Type.GetTypeFromProgID("WScript.Shell");

                if (shellType is null)
                {
                    continue;
                }

                dynamic shell = Activator.CreateInstance(shellType)!;
                dynamic shortcut = shell.CreateShortcut(shortcutPath);

                string? targetPath = shortcut.TargetPath;

                if (string.IsNullOrWhiteSpace(targetPath))
                {
                    continue;
                }

                if (!string.Equals(
                        Path.GetFileName(targetPath),
                        "OrchidApp.Launcher.exe",
                        StringComparison.OrdinalIgnoreCase))
                {
                    continue;
                }

                var targetRoot = Path.GetDirectoryName(targetPath);

                if (!string.IsNullOrWhiteSpace(targetRoot) &&
                    Directory.Exists(targetRoot))
                {
                    shortcutTargetRoots.Add(targetRoot);
                }
            }
            catch
            {
                // Ignore unreadable shortcuts. Discovery must remain best-effort.
            }
        }
    }

    private static IEnumerable<string> GetCommonInstallCandidateFolders()
    {
        var candidateFolders = new List<string>();

        var userProfile = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);

        candidateFolders.Add(@"C:\OrchidApp");
        candidateFolders.Add(@"C:\OrchidApp\app");

        if (!string.IsNullOrWhiteSpace(userProfile))
        {
            candidateFolders.Add(Path.Combine(userProfile, "Downloads", "OrchidApp"));
            candidateFolders.Add(Path.Combine(userProfile, "Documents", "OrchidApp"));
            candidateFolders.Add(Path.Combine(userProfile, "OneDrive", "Documents", "OrchidApp"));
        }

        return candidateFolders
            .Where(Directory.Exists)
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToList();
    }

    private static IEnumerable<string> GetBackstopOrchidAppFolders()
    {
        var searchRoots = new List<string>();

        var userProfile = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);

        searchRoots.Add(@"C:\");

        if (!string.IsNullOrWhiteSpace(userProfile))
        {
            searchRoots.Add(Path.Combine(userProfile, "Desktop"));
            searchRoots.Add(Path.Combine(userProfile, "Downloads"));
            searchRoots.Add(Path.Combine(userProfile, "Documents"));
            searchRoots.Add(Path.Combine(userProfile, "OneDrive", "Desktop"));
            searchRoots.Add(Path.Combine(userProfile, "OneDrive", "Documents"));
        }

        return searchRoots
            .Where(Directory.Exists)
            .SelectMany(root => FindOrchidAppFolders(root, maxDepth: 2))
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToList();
    }

private static IEnumerable<string> FindOrchidAppFolders(
    string rootPath,
    int maxDepth)
{
    if (maxDepth < 0 ||
        string.IsNullOrWhiteSpace(rootPath) ||
        !Directory.Exists(rootPath))
    {
        yield break;
    }

    IEnumerable<string> childDirectories;

    try
    {
        childDirectories = Directory.EnumerateDirectories(rootPath);
    }
    catch
    {
        yield break;
    }

    foreach (var childDirectory in childDirectories)
    {
        var directoryName = Path.GetFileName(childDirectory);

        if (string.Equals(
                directoryName,
                "OrchidApp",
                StringComparison.OrdinalIgnoreCase))
        {
            yield return childDirectory;
        }

        if (maxDepth == 0)
        {
            continue;
        }

        foreach (var match in FindOrchidAppFolders(childDirectory, maxDepth - 1))
        {
            yield return match;
        }
    }
}

    private static OrchidAppLegacyCandidate InspectLegacyCandidate(string rootPath, string discoverySource)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(rootPath);

        var mariaDbDataPath = Path.Combine(rootPath, "data", "mariadb");
        var uploadsPath = Path.Combine(rootPath, "wwwroot", "uploads");
        var backupsPath = Path.Combine(rootPath, "backups");
        var logsPath = Path.Combine(rootPath, "logs");
        var launcherSettingsPath = Path.Combine(rootPath, "launcher-settings.json");

        return new OrchidAppLegacyCandidate
        {
            RootPath = rootPath,

            MariaDbDataPath = mariaDbDataPath,
            UploadsPath = uploadsPath,
            BackupsPath = backupsPath,
            LogsPath = logsPath,
            LauncherSettingsPath = launcherSettingsPath,
            DiscoverySource = discoverySource,

            HasMariaDbData = Directory.Exists(mariaDbDataPath),
            HasUploads = Directory.Exists(uploadsPath),
            HasBackups = Directory.Exists(backupsPath),
            HasLogs = Directory.Exists(logsPath),
            HasLauncherSettings = File.Exists(launcherSettingsPath)
        };
    }

    private static OrchidAppLayoutStatus ResolveStatus(
        int dataBearingLegacyCandidateCount,
        bool programDataLayoutExists)
    {
        if (dataBearingLegacyCandidateCount > 1)
        {
            return OrchidAppLayoutStatus.MultipleLegacyLayoutsFound;
        }

        if (dataBearingLegacyCandidateCount == 1 && programDataLayoutExists)
        {
            return OrchidAppLayoutStatus.LegacyAndProgramDataFound;
        }

        if (dataBearingLegacyCandidateCount == 1)
        {
            return OrchidAppLayoutStatus.OldLayoutRequiresMigration;
        }

        if (programDataLayoutExists)
        {
            return OrchidAppLayoutStatus.ProgramDataLayoutInPlace;
        }

        return OrchidAppLayoutStatus.NewInstall;
    }
}