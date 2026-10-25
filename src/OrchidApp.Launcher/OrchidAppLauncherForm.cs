using System.Diagnostics;
using System.Drawing;
using System.Reflection;
using System.Linq;
using MySqlConnector;
using OrchidApp.Launcher.Infrastructure;

namespace OrchidApp.Launcher;

public static class AppVersion
{
    public static string ProductVersion =>
        Assembly
            .GetExecutingAssembly()
            .GetCustomAttribute<AssemblyInformationalVersionAttribute>()?
            .InformationalVersion
            .Split('+')[0]
        ?? "Unknown";

    public static string InformationalVersion =>
        Assembly
            .GetExecutingAssembly()
            .GetCustomAttribute<AssemblyInformationalVersionAttribute>()?
            .InformationalVersion
        ?? "Unknown";

    public static string FileVersion =>
        FileVersionInfo
            .GetVersionInfo(Assembly.GetExecutingAssembly().Location)
            .FileVersion
        ?? "Unknown";

    public static string AssemblyVersion =>
        Assembly
            .GetExecutingAssembly()
            .GetName()
            .Version?
            .ToString()
        ?? "Unknown";
}

public partial class OrchidAppLauncherForm : Form
{
    private Label statusLabel = new Label();
    private Panel statusLight = new Panel();
    private TextBox logBox = new TextBox();
    private Button openAppButton = new Button();
    private Button backupButton = new Button();
    private Button restoreButton = new Button();
    private Button configureCloudBackupButton = new Button();
    private Button closeAppButton = new Button();
    private bool _closeConfirmed = false;
    private bool _preUpgradeBackupCompletedThisStartup;
    private static readonly TimeSpan AutomaticBackupAgeThreshold = TimeSpan.FromHours(168);
    private const string CloudBackupFileName = "OrchidAppDataBackup.zip";
    private bool _backupInProgress = false;
    private bool _restoreInProgress;
    private MigrationState? _activeMigration;
    private bool _migrationStartupInProgress;

    private Process? _webAppProcess;
    private Process? _mariaDbProcess;
    private string? _webAppStartupError;

    private readonly object _logLock = new object();

    private readonly object _logFileLock = new();
    
    private readonly WindowsProgramDataPaths _programDataPaths = new();

    private string? _lastPreUpgradeBackupPath;

    private enum LauncherStatus
    {
        Red,
        Amber,
        Green
    }

    public OrchidAppLauncherForm()
    {
        InitializeComponent();

        var iconPath = Path.Combine(
            AppContext.BaseDirectory,
            "Assets",
            "OrchidApp.ico"
        );

        if (File.Exists(iconPath))
        {
            Icon = new Icon(iconPath);
        }
        
        SetWindowTitle("Starting");
        Width = 1040;
        Height = 460;

        AppendLog("OrchidApp launcher starting.");
        AppendLog($"Product version:       {AppVersion.ProductVersion}");
        AppendLog($"Assembly version:      {AppVersion.AssemblyVersion}");
        AppendLog($"File version:          {AppVersion.FileVersion}");
        AppendLog($"Informational version: {AppVersion.InformationalVersion}");

        statusLabel.Text = "Starting OrchidApp. Please keep this window open while using OrchidApp.";
        statusLabel.AutoSize = true;
        statusLabel.Left = 45;
        statusLabel.Top = 15;
        statusLabel.MaximumSize = new Size(940, 0);

        statusLight.Left = 20;
        statusLight.Top = 22;
        statusLight.Width = 18;
        statusLight.Height = 18;
        statusLight.BackColor = Color.Firebrick;
        statusLight.BorderStyle = BorderStyle.FixedSingle;

        logBox.Multiline = true;
        logBox.ScrollBars = ScrollBars.Vertical;
        logBox.Left = 20;
        logBox.Top = 95;
        logBox.Width = 980;
        logBox.Height = 235;

        openAppButton.Text = "Open OrchidApp";
        openAppButton.Left = 20;
        openAppButton.Top = 335;
        openAppButton.Width = 140;
        openAppButton.Height = 35;
        openAppButton.Enabled = false;
        openAppButton.Click += (s, e) => OpenOrchidAppInBrowser();

        backupButton.Text = "Back up now";
        backupButton.Left = 180;
        backupButton.Top = 335;
        backupButton.Width = 140;
        backupButton.Height = 35;
        backupButton.Enabled = false;
        backupButton.Click += async (s, e) => await RunBackupAsync();

        restoreButton.Text = "Restore from backup...";
        restoreButton.Left = 340;
        restoreButton.Top = 335;
        restoreButton.Width = 180;
        restoreButton.Height = 35;
        restoreButton.Enabled = false;
        restoreButton.Click += async (s, e) => await RunRestoreAsync();

        configureCloudBackupButton.Text = "Configure cloud backup...";
        configureCloudBackupButton.Left = 540;
        configureCloudBackupButton.Top = 335;
        configureCloudBackupButton.Width = 220;
        configureCloudBackupButton.Height = 35;
        configureCloudBackupButton.Enabled = true;
        configureCloudBackupButton.Click += ConfigureCloudBackupButton_Click;

        closeAppButton.Text = "Close OrchidApp";
        closeAppButton.Left = 780;
        closeAppButton.Top = 335;
        closeAppButton.Width = 180;
        closeAppButton.Height = 35;
        closeAppButton.Enabled = true;
        closeAppButton.Click += (s, e) => Close();

        Controls.Add(statusLabel);
        Controls.Add(statusLight);
        Controls.Add(logBox);
        Controls.Add(openAppButton);
        Controls.Add(backupButton);
        Controls.Add(restoreButton);
        Controls.Add(configureCloudBackupButton);
        Controls.Add(closeAppButton);
    }

    private void InitialiseLauncherLogFile()
    {
        try
        {
            Directory.CreateDirectory(_programDataPaths.Logs);

            if (!File.Exists(_programDataPaths.LauncherLogFile))
            {
                return;
            }

            var logFileInfo = new FileInfo(_programDataPaths.LauncherLogFile);

            if (logFileInfo.Length <= 1_048_576)
            {
                return;
            }

            if (File.Exists(_programDataPaths.PreviousLauncherLogFile))
            {
                File.Delete(_programDataPaths.PreviousLauncherLogFile);
            }

            File.Move(_programDataPaths.LauncherLogFile, _programDataPaths.PreviousLauncherLogFile);
        }
        catch
        {
            // Logging must never stop the launcher from starting.
        }
    }

    private void WriteLauncherLogFileLine(string line)
    {
        try
        {
            lock (_logFileLock)
            {
                Directory.CreateDirectory(_programDataPaths.Logs);
                File.AppendAllText(_programDataPaths.LauncherLogFile, line + Environment.NewLine);
            }
        }
        catch
        {
            // Logging must never stop the launcher from starting.
        }
    }

    private void AppendSupportInstructions()
    {
        AppendLog("Your OrchidApp plant database, photos, backups and settings have not been deleted by this startup failure.");
        AppendLog("Please contact support at OrchidApp@proton.me and include this log file:");
        AppendLog(_programDataPaths.LauncherLogFile);
    }

    protected override async void OnLoad(EventArgs e)
    {
        base.OnLoad(e);
        FileStream? migrationLock = null;

        try
        {
            SetLauncherStatus(LauncherStatus.Red);

            var programDataDirectoryService = new WindowsProgramDataDirectoryService(
                _programDataPaths,
                AppendLog);

            programDataDirectoryService.EnsureRequiredDirectoriesExist();

            InitialiseLauncherLogFile();

            AppendLog($"Launcher log file: {_programDataPaths.LauncherLogFile}");

            if (GetRestoreRecovery().IsPending)
            {
                ShowRestoreRecoveryState();
                return; // No migrations, web startup or automatic/cloud backups on partial data.
            }

            var layout = OrchidAppLayoutResolver.Resolve(AppContext.BaseDirectory);
            LogLayoutState(layout);

            if (layout.Status == OrchidAppLayoutStatus.LegacyAndProgramDataFound ||
                layout.Status == OrchidAppLayoutStatus.MultipleLegacyLayoutsFound)
            {
                AppendLog($"Startup stopped because layout status is {layout.Status}.");
                AppendLog("OrchidApp found more than one possible data location and stopped to avoid using or migrating the wrong data.");
                AppendLog("Do not delete or move OrchidApp folders manually unless instructed.");
                AppendSupportInstructions();

                SetLauncherStatus(LauncherStatus.Red);
                SetWindowTitle("Error");
                statusLabel.Text =
                    "Startup stopped: OrchidApp found more than one possible data location. " +
                    "Do not delete or move OrchidApp folders manually. Contact support.";

                return;
            }

            var migrationStateService = new MigrationStateService(_programDataPaths);
            var previousMigration = migrationStateService.Load();
            if (previousMigration is not null && previousMigration.MigrationStatus != MigrationStatus.Completed)
            {
                if (MessageBox.Show("A previous legacy migration did not finish. Resume the recorded copy or readiness check?\n\n" +
                    "Only matching files from the retained capture will be used. Existing changed or unrelated data will not be overwritten. Choose No to leave all files for support.",
                    "Resume interrupted migration", MessageBoxButtons.YesNo, MessageBoxIcon.Warning, MessageBoxDefaultButton.Button2) != DialogResult.Yes)
                {
                    statusLabel.Text = "Migration is paused for review. Preserve the original, capture, safety ZIP and ProgramData state; contact support.";
                    SetWindowTitle("Migration review required");
                    return;
                }
                _migrationStartupInProgress = true;
                configureCloudBackupButton.Enabled = false;
                var coordinator = new LegacyMigrationCoordinator(_programDataPaths);
                migrationLock = coordinator.AcquireLock();
                var currentMigration = migrationStateService.Load()
                    ?? throw new InvalidOperationException("Migration state changed before the operation lock was acquired. Restart for a fresh review.");
                if (currentMigration.MigrationStatus == MigrationStatus.Completed || currentMigration.OperationId != previousMigration.OperationId)
                    throw new InvalidOperationException("Another migration attempt changed the recorded operation. Close and reopen OrchidApp for a fresh review.");
                if (Directory.Exists(currentMigration.SourceLegacyRootPath))
                    coordinator.CheckPreservedSource(currentMigration, currentMigration.SourceLegacyRootPath);
                _activeMigration = currentMigration;
                await Task.Run(() => coordinator.ContinueCopy(_activeMigration));
                AppendLog("Recorded migration copy is complete; database and web readiness are still required.");
            }

            if (layout.Status == OrchidAppLayoutStatus.OldLayoutRequiresMigration)
            {
                _migrationStartupInProgress = true;
                configureCloudBackupButton.Enabled = false;
                var coordinator = new LegacyMigrationCoordinator(_programDataPaths);
                migrationLock = coordinator.AcquireLock();
                if (migrationStateService.Exists())
                    throw new InvalidOperationException("Migration state appeared before the operation lock was acquired. Restart for a fresh review.");
                AppendLog("Existing legacy OrchidApp layout detected. Mandatory pre-upgrade backup is required.");

                var legacyCandidate = layout.LegacyCandidates.Single(candidate => candidate.HasOrchidsDatabase);
                var sourceSnapshot = await Task.Run(() => LegacySourceSnapshot.Capture(legacyCandidate.RootPath,
                    Path.Combine(_programDataPaths.Root, "migration-staging")));
                var preUpgradeBackupSucceeded = await RunPreUpgradeBackupAsync(sourceSnapshot);

                if (!preUpgradeBackupSucceeded)
                {
                    AppendLog("Pre-upgrade backup failed. Startup stopped for safety.");
                    AppendLog("The required legacy migration has not been started.");
                    AppendLog("The existing legacy OrchidApp layout has not been changed.");
                    AppendSupportInstructions();

                    SetLauncherStatus(LauncherStatus.Red);
                    SetWindowTitle("Backup failed");
                    statusLabel.Text =
                        "Startup stopped: OrchidApp could not create the required safety backup. " +
                        "Your existing data has not been changed. Contact support.";

                    return;
                }

                _preUpgradeBackupCompletedThisStartup = true;
                AppendLog("Pre-upgrade backup succeeded. Startup may continue.");

                _activeMigration = coordinator.Begin(legacyCandidate.RootPath, sourceSnapshot, _lastPreUpgradeBackupPath!);
                _activeMigration.ApplicationProductVersion = AppVersion.ProductVersion;
                _activeMigration.ApplicationInformationalVersion = AppVersion.InformationalVersion;
                migrationStateService.Save(_activeMigration);
                await Task.Run(() => coordinator.ContinueCopy(_activeMigration));
                AppendLog("Legacy copy verified. Completion awaits database and web readiness.");
            }

            StartMariaDb();

            await WaitForMariaDbAsync("server=127.0.0.1;port=3308;user=root;password=;");

            await BootstrapOrchidDatabaseIfRequiredAsync();

            await WaitForMariaDbAsync(
                "server=127.0.0.1;port=3308;user=orchid;password=orchid;"
            );

            AppendLog("MariaDB startup confirmed.");
            SetLauncherStatus(LauncherStatus.Amber);

            await StartWebAppAsync();
        }
        catch (Exception ex)
        {
            if (_activeMigration is not null)
            {
                _activeMigration.MigrationStatus = MigrationStatus.Failed;
                _activeMigration.FailedAtUtc = DateTime.UtcNow;
                _activeMigration.ErrorMessage = ex.Message;
                try { new MigrationStateService(_programDataPaths).Save(_activeMigration); }
                catch (Exception stateError) { AppendLog("Unable to update failure state; retain the last atomic state: " + stateError.Message); }
                try { await StopWebAppForRestoreAsync(); StopMariaDbGracefully(); }
                catch (Exception stopError) { AppendLog("Migration startup shutdown: " + stopError.Message); }
            }
            SetLauncherStatus(LauncherStatus.Red);
            SetWindowTitle("Error");
            AppendLog("STARTUP ERROR:");
            AppendLog(ex.ToString());
            AppendSupportInstructions();

            MessageBox.Show(
                "OrchidApp could not start safely.\n\n" +
                "Your OrchidApp plant database, photos, backups and settings have not been deleted by this startup failure.\n\n" +
                "Please contact support at OrchidApp@proton.me and include this log file:\n\n" +
                _programDataPaths.LauncherLogFile,
                "OrchidApp could not start",
                MessageBoxButtons.OK,
                MessageBoxIcon.Warning
            );
        }
        finally { _migrationStartupInProgress = false; migrationLock?.Dispose(); }
    }

    private void InitialiseMariaDbDataDirectoryIfRequired(string dataDir)
    {
        if (MariaDbSystemDatabaseExists(dataDir))
        {
            AppendLog("MariaDB system database already exists.");
            return;
        }

        AppendLog($"MariaDB system database not found. Initialising data directory: {dataDir}");

        var baseDir = AppContext.BaseDirectory;

        var installDbExe = Path.Combine(
            baseDir,
            "runtime",
            "mariadb",
            "win-x64",
            "bin",
            "mariadb-install-db.exe"
        );

        if (!File.Exists(installDbExe))
        {
            var message = $"The OrchidApp database setup tool could not be found: {installDbExe}";
            AppendLog("ERROR: " + message);
            throw new FileNotFoundException(message, installDbExe);
        }

        var process = new Process
        {
            StartInfo = new ProcessStartInfo
            {
                FileName = installDbExe,
                Arguments = $"--datadir=\"{dataDir}\"",
                WorkingDirectory = baseDir,
                UseShellExecute = false,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                CreateNoWindow = true
            }
        };

        process.OutputDataReceived += (s, e) =>
        {
            if (e.Data != null)
                AppendLog("DB INIT: " + e.Data);
        };

        process.ErrorDataReceived += (s, e) =>
        {
            if (e.Data != null)
                AppendLog("DB INIT ERR: " + e.Data);
        };

        process.Start();

        process.BeginOutputReadLine();
        process.BeginErrorReadLine();

        process.WaitForExit();

        if (process.ExitCode != 0)
        {
            var message = $"MariaDB data directory initialisation failed. ExitCode={process.ExitCode}";
            AppendLog("ERROR: " + message);
            throw new InvalidOperationException(message);
        }

        AppendLog("MariaDB data directory initialised.");
    }

    private void StartMariaDb()
    {
        if (_activeMigration is not null) RequireUnusedMigrationPort(3308);
        var baseDir = AppContext.BaseDirectory;

        var mariaDbExe = Path.Combine(
            baseDir,
            "runtime",
            "mariadb",
            "win-x64",
            "bin",
            "mariadbd.exe"
        );

        if (!File.Exists(mariaDbExe))
        {
            var message = $"The OrchidApp database engine could not be found: {mariaDbExe}";
            AppendLog("ERROR: " + message);
            throw new FileNotFoundException(message, mariaDbExe);
        }

        var dataDir = _programDataPaths.MariaDbData;

        if (!Directory.Exists(dataDir))
        {
            var message = $"The OrchidApp database folder could not be found: {dataDir}";
            AppendLog("ERROR: " + message);
            throw new DirectoryNotFoundException(message);
        }

        InitialiseMariaDbDataDirectoryIfRequired(dataDir);

        AppendLog($"MariaDB EXE: {mariaDbExe}");
        AppendLog($"MariaDB DataDir: {dataDir}");

        var process = new Process
        {
            StartInfo = new ProcessStartInfo
            {
                FileName = mariaDbExe,
                Arguments =
                    "--no-defaults " +
                    $"--basedir=\"{Path.GetDirectoryName(Path.GetDirectoryName(mariaDbExe))}\" " +
                    $"--datadir=\"{dataDir}\" " +
                    $"--port=3308 " +
                    $"--bind-address=127.0.0.1 " +
                    $"--console",
                WorkingDirectory = baseDir,
                UseShellExecute = false,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                CreateNoWindow = true
            }
        };

        process.EnableRaisingEvents = true;

        process.Exited += (s, e) =>
        {
            AppendLog($"MariaDB exited. ExitCode={process.ExitCode}");
        };

        process.OutputDataReceived += (s, e) =>
        {
            if (e.Data != null)
                AppendLog("DB: " + e.Data);
        };

        process.ErrorDataReceived += (s, e) =>
        {
            if (e.Data != null)
                AppendLog("DB ERR: " + e.Data);
        };

        process.Start();

        process.BeginOutputReadLine();
        process.BeginErrorReadLine();

        _mariaDbProcess = process;
    }

    private static void RequireUnusedMigrationPort(int port)
    {
        if (System.Net.NetworkInformation.IPGlobalProperties.GetIPGlobalProperties().GetActiveTcpListeners().Any(endpoint => endpoint.Port == port))
            throw new InvalidOperationException($"Port {port} is already in use. Close the other OrchidApp/database instance and obtain support before resuming migration readiness.");
    }

    private async Task WaitForMariaDbAsync(
        string connectionString,
        int timeoutSeconds = 30)
    {
        var start = DateTime.UtcNow;

        while (DateTime.UtcNow - start < TimeSpan.FromSeconds(timeoutSeconds))
        {
            try
            {
                using var conn = new MySqlConnection(connectionString);

                await conn.OpenAsync();

                if (_activeMigration is not null)
                {
                    using var identity = new MySqlCommand("SELECT @@datadir;", conn);
                    var directory = Convert.ToString(await identity.ExecuteScalarAsync())!;
                    if (!LegacyMigrationCoordinator.SamePath(directory, _programDataPaths.MariaDbData))
                        throw new InvalidOperationException("Migration readiness connected to a different MariaDB data directory.");
                }
                if (_mariaDbProcess is null || _mariaDbProcess.HasExited)
                    throw new InvalidOperationException("The launched MariaDB process is not running.");

                AppendLog("MariaDB is ready.");

                return;
            }
            catch (Exception ex)
            {
                AppendLog("MariaDB wait: " + ex.Message);

                if (_mariaDbProcess != null && _mariaDbProcess.HasExited)
                {
                    throw new Exception(
                        $"MariaDB process exited early. ExitCode={_mariaDbProcess.ExitCode}");
                }

                await Task.Delay(1000);
            }
        }

        throw new Exception("MariaDB did not start in time.");
    }

    private async Task BootstrapOrchidDatabaseIfRequiredAsync()
    {
        var rootConnectionString =
            "server=127.0.0.1;port=3308;user=root;password=;";

        AppendLog("Checking OrchidApp database bootstrap...");

        using var conn = new MySqlConnection(rootConnectionString);
        await conn.OpenAsync();

        var sql = @"
CREATE DATABASE IF NOT EXISTS orchids
CHARACTER SET utf8mb4
COLLATE utf8mb4_unicode_ci;

CREATE USER IF NOT EXISTS 'orchid'@'localhost' IDENTIFIED BY 'orchid';
CREATE USER IF NOT EXISTS 'orchid'@'127.0.0.1' IDENTIFIED BY 'orchid';

GRANT ALL PRIVILEGES ON orchids.* TO 'orchid'@'localhost';
GRANT ALL PRIVILEGES ON orchids.* TO 'orchid'@'127.0.0.1';

CREATE USER IF NOT EXISTS 'orchid_shutdown'@'localhost' IDENTIFIED BY 'orchid_shutdown';
CREATE USER IF NOT EXISTS 'orchid_shutdown'@'127.0.0.1' IDENTIFIED BY 'orchid_shutdown';

GRANT SHUTDOWN ON *.* TO 'orchid_shutdown'@'localhost';
GRANT SHUTDOWN ON *.* TO 'orchid_shutdown'@'127.0.0.1';

FLUSH PRIVILEGES;
";

        using var cmd = new MySqlCommand(sql, conn);
        await cmd.ExecuteNonQueryAsync();

        AppendLog("OrchidApp database bootstrap completed.");
    }

    private void StopMariaDbGracefully()
    {
        try
        {
            if (_mariaDbProcess == null || _mariaDbProcess.HasExited)
            {
                AppendLog("MariaDB is not running.");
                return;
            }

            var baseDir = AppContext.BaseDirectory;

            var mariadbAdminExe = Path.Combine(
                baseDir,
                "runtime",
                "mariadb",
                "win-x64",
                "bin",
                "mariadb-admin.exe"
            );

            using (var connection = new MySqlConnection("server=127.0.0.1;port=3308;user=orchid;password=orchid;Connection Timeout=5;"))
            {
                connection.Open();
                using var identity = new MySqlCommand("SELECT @@datadir;", connection);
                if (!LegacyMigrationCoordinator.SamePath(Convert.ToString(identity.ExecuteScalar())!, _programDataPaths.MariaDbData))
                {
                    AppendLog("MariaDB shutdown refused: listener data directory differs from ProgramData. Contact support.");
                    return;
                }
            }

            AppendLog($"MariaDB shutdown tool: {mariadbAdminExe}");

            if (!File.Exists(mariadbAdminExe))
            {
                AppendLog("mariadb-admin.exe not found; falling back to process kill.");
                _mariaDbProcess.Kill(true);
                return;
            }

            var shutdown = new Process
            {
                StartInfo = new ProcessStartInfo
                {
                    FileName = mariadbAdminExe,
                    Arguments = "--no-defaults --protocol=TCP --connect-timeout=5 -h 127.0.0.1 -P 3308 -u orchid_shutdown -porchid_shutdown shutdown",
                    WorkingDirectory = baseDir,
                    UseShellExecute = false,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    CreateNoWindow = true
                }
            };

            AppendLog("Requesting MariaDB shutdown...");
            SetLauncherStatus(LauncherStatus.Red);

            shutdown.Start();

            var stdout = shutdown.StandardOutput.ReadToEnd();
            var stderr = shutdown.StandardError.ReadToEnd();

            shutdown.WaitForExit(10000);

            if (!string.IsNullOrWhiteSpace(stdout))
                AppendLog("mariadb-admin OUT: " + stdout.Trim());

            if (!string.IsNullOrWhiteSpace(stderr))
                AppendLog("mariadb-admin ERR: " + stderr.Trim());

            AppendLog($"mariadb-admin ExitCode={shutdown.ExitCode}");

            if (shutdown.ExitCode != 0)
            {
                AppendLog("MariaDB shutdown command failed; falling back to process kill.");
                _mariaDbProcess.Kill(true);
                return;
            }

            AppendLog("Waiting for MariaDB process to exit...");

            if (!_mariaDbProcess.WaitForExit(30000))
            {
                AppendLog("MariaDB did not stop gracefully within 30 seconds; killing process.");
                _mariaDbProcess.Kill(true);
                return;
            }

            AppendLog("MariaDB stopped gracefully.");
        }
        catch (Exception ex)
        {
            AppendLog("MariaDB shutdown error: " + ex.Message);

            try
            {
                if (_mariaDbProcess != null && !_mariaDbProcess.HasExited)
                    _mariaDbProcess.Kill(true);
            }
            catch
            {
                // ignore cleanup errors
            }
        }
    }

    private async Task StartWebAppAsync()
    {
        if (_activeMigration is not null) RequireUnusedMigrationPort(5285);
        statusLabel.Text = "Starting web application...";
        SetWindowTitle("Starting");

        var baseDir = AppContext.BaseDirectory;

        var exePath = Path.Combine(baseDir, "OrchidApp.Web.exe");

        var webAppStartInfo = new ProcessStartInfo
        {
            FileName = exePath,
            Arguments = "--urls=http://localhost:5285",
            WorkingDirectory = baseDir,
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            CreateNoWindow = true
        };

        webAppStartInfo.Environment["ORCHIDAPP_UPLOAD_ROOT"] = _programDataPaths.Uploads;

        AppendLog($"Web upload root: {_programDataPaths.Uploads}");

        _webAppProcess = new Process
        {
            StartInfo = webAppStartInfo
        };

        _webAppProcess.EnableRaisingEvents = true;
        _webAppProcess.Exited += (s, e) =>
        {
            AppendLog("Web app process exited");
        };

        _webAppProcess.StartInfo.EnvironmentVariables["ASPNETCORE_ENVIRONMENT"] = "Desktop";

        _webAppProcess.OutputDataReceived += (s, e) =>
        {
            if (e.Data != null)
            {
                AppendLog(e.Data);
            }
        };

        _webAppProcess.ErrorDataReceived += (s, e) =>
        {
            if (e.Data == null)
                return;

            AppendLog("ERR: " + e.Data);

            if (e.Data.Contains("Database updates are available", StringComparison.OrdinalIgnoreCase) ||
                e.Data.Contains("automatic backup is not implemented", StringComparison.OrdinalIgnoreCase) ||
                e.Data.Contains("Please back up the OrchidApp data folder", StringComparison.OrdinalIgnoreCase))
            {
                _webAppStartupError =
                    "Database updates are available. A backup is required before OrchidApp can apply them.";
            }
        };

        _webAppProcess.StartInfo.EnvironmentVariables["ConnectionStrings__DefaultConnection"] =
            "server=127.0.0.1;port=3308;database=orchids;user=orchid;password=orchid;";
        
        _webAppProcess.StartInfo.EnvironmentVariables["ConnectionStrings__OrchidDb"] =
                "server=127.0.0.1;port=3308;database=orchids;user=orchid;password=orchid;";

        var libVipsBin = Path.Combine(
            baseDir,
            "runtime",
            "libvips",
            "win-x64",
            "bin"
        );

        if (!Directory.Exists(libVipsBin))
        {
            throw new DirectoryNotFoundException(
                $"libvips runtime folder not found: {libVipsBin}"
            );
        }

        var currentPath = _webAppProcess.StartInfo.EnvironmentVariables["PATH"] ?? string.Empty;

        _webAppProcess.StartInfo.EnvironmentVariables["PATH"] =
            libVipsBin + Path.PathSeparator + currentPath;

        AppendLog($"libvips PATH added: {libVipsBin}");

        _webAppProcess.Start();
        AppendLog("Launcher: process started");
        
        _webAppProcess.BeginOutputReadLine();
        _webAppProcess.BeginErrorReadLine();

        await WaitForWebAppAsync("http://localhost:5285");

        if (_activeMigration is not null)
        {
            new LegacyMigrationCoordinator(_programDataPaths).CompleteAfterReadiness(_activeMigration);
            AppendLog("Legacy migration completed after database identity and web readiness verification. Original source retained.");
            _activeMigration = null;
        }

        Process.Start(new ProcessStartInfo
        {
            FileName = "http://localhost:5285",
            UseShellExecute = true
        });

        statusLabel.Text =
            "Keep this launcher window open while using OrchidApp.\n" +
            "If you close the browser tab, click Open OrchidApp.\n" +
            "If you close this launcher, OrchidApp will stop.";
        SetWindowTitle("Running");
        SetLauncherStatus(LauncherStatus.Green);
        openAppButton.Enabled = true;
        backupButton.Enabled = true;
        restoreButton.Enabled = true;

        configureCloudBackupButton.Enabled = true;
        _ = RunAutomaticBackupIfDueAsync();
    }

    private async Task WaitForWebAppAsync(
        string url,
        int timeoutSeconds = 600)
    {
        using var client = new HttpClient();

        var start = DateTime.UtcNow;

        while (DateTime.UtcNow - start < TimeSpan.FromSeconds(timeoutSeconds))
        {
            if (_webAppProcess != null && _webAppProcess.HasExited)
            {
                if (!string.IsNullOrWhiteSpace(_webAppStartupError))
                {
                    throw new Exception(_webAppStartupError);
                }

                throw new Exception(
                    $"OrchidApp could not start. ExitCode={_webAppProcess.ExitCode}");
            }

            try
            {
                var response = await client.GetAsync(
                    url,
                    HttpCompletionOption.ResponseHeadersRead);

                if (response.IsSuccessStatusCode)
                {
                    AppendLog("Opening OrchidApp...");
                    return;
                }
            }
            catch
            {
                // not ready yet
            }

            await Task.Delay(1000);
        }

        throw new Exception(
            $"Web app did not start in time after {timeoutSeconds} seconds.");
    }

    private async Task StopWebAppForRestoreAsync()
    {
        if (_webAppProcess == null || _webAppProcess.HasExited)
        {
            AppendLog("Web app is not running.");
            return;
        }

        AppendLog("Stopping web app before restore...");

        _webAppProcess.Kill(true);

        using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(10));

        try
        {
            await _webAppProcess.WaitForExitAsync(timeout.Token);
            AppendLog("Web app stopped.");
        }
        catch (OperationCanceledException)
        {
            AppendLog("Web app did not stop within 10 seconds.");
            throw;
        }
    }

    private async Task RunAutomaticBackupIfDueAsync()
    {
        if (_preUpgradeBackupCompletedThisStartup)
        {
            AppendLog("Pre-upgrade backup was completed during this startup. Skipping automatic safety backup.");
            return;
        }

        if (!IsAutomaticBackupDue())
        {
            AppendLog("Automatic backup not required.");
            return;
        }

        AppendLog("A safety backup has not been made in the last 7 days. Creating one now...");

        await RunBackupAsync(showSuccessMessage: false);

        AppendLog("Automatic safety backup completed.");
    }


    private async Task<bool> RunPreUpgradeBackupAsync(string sourceSnapshot)
    {
        _lastPreUpgradeBackupPath = null;
        bool nextOutputLineIsBackupPath = false;

        AppendLog("Starting mandatory pre-upgrade backup...");

        var baseDir = AppContext.BaseDirectory;

        var backupScript = Path.Combine(
            baseDir,
            "tools",
            "backup-orchidapp.ps1"
        );

        if (!File.Exists(backupScript))
        {
            AppendLog($"PRE-UPGRADE BACKUP ERROR: Backup script not found: {backupScript}");
            return false;
        }

        var programDataPaths = new WindowsProgramDataPaths();

        var preUpgradeBackupsRoot = programDataPaths.PreUpgradeBackups;

        var process = new Process
        {
            StartInfo = new ProcessStartInfo
            {
                FileName = "powershell.exe",
                WorkingDirectory = baseDir,
                UseShellExecute = false,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                CreateNoWindow = true
            }
        };
        foreach (var argument in new[] { "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", backupScript,
            "-BackupType", "PreUpgrade", "-LegacySourceRoot", sourceSnapshot,
            "-BackupsRoot", preUpgradeBackupsRoot, "-SkipOldBackupPruning" })
            process.StartInfo.ArgumentList.Add(argument);

        process.OutputDataReceived += (s, e) =>
        {
            if (string.IsNullOrWhiteSpace(e.Data))
            {
                return;
            }

            var line = e.Data.Trim();

            AppendLog("PRE-UPGRADE BACKUP: " + line);

            if (nextOutputLineIsBackupPath)
            {
                _lastPreUpgradeBackupPath = line;
                nextOutputLineIsBackupPath = false;
                return;
            }

            if (line.Equals("Backup created:", StringComparison.OrdinalIgnoreCase))
            {
                nextOutputLineIsBackupPath = true;
            }
        };

        process.ErrorDataReceived += (s, e) =>
        {
            if (!string.IsNullOrWhiteSpace(e.Data))
            {
                AppendLog("PRE-UPGRADE BACKUP ERR: " + e.Data);
            }
        };

        try
        {
            process.Start();

            process.BeginOutputReadLine();
            process.BeginErrorReadLine();

            await process.WaitForExitAsync();

            if (process.ExitCode != 0)
            {
                AppendLog($"PRE-UPGRADE BACKUP ERROR: Backup failed. ExitCode={process.ExitCode}");
                return false;
            }

            if (string.IsNullOrWhiteSpace(_lastPreUpgradeBackupPath) || !File.Exists(_lastPreUpgradeBackupPath))
            {
                AppendLog("PRE-UPGRADE BACKUP ERROR: No completed backup ZIP was returned.");
                return false;
            }
            AppendLog("Mandatory pre-upgrade backup completed successfully.");
            return true;
        }
        catch (Exception ex)
        {
            AppendLog("PRE-UPGRADE BACKUP ERROR: " + ex.Message);
            return false;
        }
    }

    private async Task RunBackupAsync(bool showSuccessMessage = true)
    {
        if (_backupInProgress)
        {
            AppendLog("Backup is already running.");
            return;
        }

        _backupInProgress = true;

        SetWindowTitle("Backing up");
        backupButton.Enabled = false;
        restoreButton.Enabled = false;
        openAppButton.Enabled = false;
        SetLauncherStatus(LauncherStatus.Amber);

        try
        {
            AppendLog("Starting backup...");

            var baseDir = AppContext.BaseDirectory;

            var backupScript = Path.Combine(
                baseDir,
                "tools",
                "backup-orchidapp.ps1"
            );

            if (!File.Exists(backupScript))
            {
                throw new FileNotFoundException(
                    "Backup script not found.",
                    backupScript
                );
            }

            var process = new Process
            {
                StartInfo = new ProcessStartInfo
                {
                    FileName = "powershell.exe",
                    Arguments =
                        "-NoProfile -ExecutionPolicy Bypass " +
                        $"-File \"{backupScript}\"",
                    WorkingDirectory = baseDir,
                    UseShellExecute = false,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    CreateNoWindow = true
                }
            };

            process.OutputDataReceived += (s, e) =>
            {
                if (!string.IsNullOrWhiteSpace(e.Data))
                    AppendLog("BACKUP: " + e.Data);
            };

            process.ErrorDataReceived += (s, e) =>
            {
                if (!string.IsNullOrWhiteSpace(e.Data))
                    AppendLog("BACKUP ERR: " + e.Data);
            };

            process.Start();

            process.BeginOutputReadLine();
            process.BeginErrorReadLine();

            await process.WaitForExitAsync();

            if (process.ExitCode != 0)
            {
                throw new Exception($"Backup failed. ExitCode={process.ExitCode}");
            }

            AppendLog("Backup completed successfully.");

            CopyLatestBackupToCloudFolder();

            if (showSuccessMessage)
            {
                MessageBox.Show(
                    "Backup completed successfully.",
                    "Backup Complete",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Information
                );
            }
        }
        catch (Exception ex)
        {
            AppendLog("BACKUP ERROR: " + ex.Message);

            MessageBox.Show(
                ex.Message,
                "Backup Failed",
                MessageBoxButtons.OK,
                MessageBoxIcon.Error
            );
        }
        finally
        {
            _backupInProgress = false;
            
            if (_webAppProcess != null && !_webAppProcess.HasExited)
            {
                SetLauncherStatus(LauncherStatus.Green);
                SetWindowTitle("Running");
                openAppButton.Enabled = true;
                backupButton.Enabled = true;
                restoreButton.Enabled = true;
            }
        }
    }

    private async Task RunRestoreAsync()
    {
        _restoreInProgress = true;
        openAppButton.Enabled = false;
        backupButton.Enabled = false;
        restoreButton.Enabled = false;
        configureCloudBackupButton.Enabled = false;
        closeAppButton.Enabled = false;
        bool shutdownAttempted = false;
        SetWindowTitle("Restoring");
        SetLauncherStatus(LauncherStatus.Red);

        try
        {
            AppendLog("Restore requested.");

            string? backupZip = null;
            string? recoveryAction = null;
            var recovery = GetRestoreRecovery();
            if (recovery.IsPending)
            {
                var choice = MessageBox.Show(
                    recovery.DescribePending() + "\n\nChoose Yes to restore the retained recovery input.\n" +
                    "Choose No to restore the safety backup from before the original attempt.\n" +
                    "Choose Cancel to leave all recovery files for support.\n\n" +
                    "Either restore replaces the database, photos and settings. Close any other OrchidApp instances first.",
                    "Recover interrupted restore", MessageBoxButtons.YesNoCancel, MessageBoxIcon.Warning,
                    MessageBoxDefaultButton.Button3);
                if (choice == DialogResult.Cancel) return;
                recoveryAction = choice == DialogResult.Yes ? "RestoreInput" : "RestoreSafety";
            }
            else
            {
            using var dialog = new OpenFileDialog
            {
                Title = "Select OrchidApp backup ZIP",
                Filter = "OrchidApp backup ZIP (*.zip)|*.zip",
                CheckFileExists = true,
                Multiselect = false
            };

            if (dialog.ShowDialog(this) != DialogResult.OK)
            {
                AppendLog("Restore cancelled. No backup selected.");
                return;
            }

            backupZip = dialog.FileName;

            var confirm = MessageBox.Show(
                "Restoring a backup will replace the current OrchidApp database and uploaded files.\n\n" +
                "A verified safety backup of the current collection and a retained copy of the selected ZIP will be made first. If that fails, replacement will stop.\n\n" +
                "Only continue if you are recovering from a backup or intentionally reverting OrchidApp to a previous backup.\n\n" +
                "Do you want to continue?",
                "Confirm Restore from Backup",
                MessageBoxButtons.YesNo,
                MessageBoxIcon.Warning,
                MessageBoxDefaultButton.Button2
            );

            if (confirm != DialogResult.Yes)
            {
                AppendLog("Restore cancelled by user.");
                return;
            }

            AppendLog($"Restore confirmed. Backup selected: {backupZip}");
            }

            shutdownAttempted = true;
            await StopWebAppForRestoreAsync();

            AppendLog("Starting restore...");

            var baseDir = AppContext.BaseDirectory;

            var restoreScript = Path.Combine(
                baseDir,
                "tools",
                "restore-orchidapp.ps1"
            );

            if (!File.Exists(restoreScript))
            {
                throw new FileNotFoundException(
                    "Restore script not found.",
                    restoreScript
                );
            }

            using var process = new Process
            {
                StartInfo = new ProcessStartInfo
                {
                    FileName = "powershell.exe",
                    WorkingDirectory = baseDir,
                    UseShellExecute = false,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    CreateNoWindow = true
                }
            };
            foreach (var argument in new[] { "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", restoreScript })
                process.StartInfo.ArgumentList.Add(argument);
            process.StartInfo.ArgumentList.Add(recoveryAction is null ? "-BackupZip" : "-RecoveryAction");
            process.StartInfo.ArgumentList.Add(recoveryAction ?? backupZip!);

            process.OutputDataReceived += (s, e) =>
            {
                if (!string.IsNullOrWhiteSpace(e.Data))
                    AppendLog("RESTORE: " + e.Data);
            };

            process.ErrorDataReceived += (s, e) =>
            {
                if (!string.IsNullOrWhiteSpace(e.Data))
                    AppendLog("RESTORE ERR: " + e.Data);
            };

            process.Start();

            process.BeginOutputReadLine();
            process.BeginErrorReadLine();

            await process.WaitForExitAsync();

            if (process.ExitCode != 0)
            {
                throw new Exception($"Restore failed. ExitCode={process.ExitCode}");
            }

            AppendLog("Restore completed successfully.");

            MessageBox.Show(
                "Restore completed successfully.\n\nPlease close and reopen OrchidApp.",
                "Restore Complete",
                MessageBoxButtons.OK,
                MessageBoxIcon.Information
            );

            _closeConfirmed = true;
            Close();
        }
        catch (Exception ex)
        {
            AppendLog("RESTORE ERROR: " + ex.Message);
            SetLauncherStatus(LauncherStatus.Red);

            MessageBox.Show(
                ex.Message,
                "Restore Failed",
                MessageBoxButtons.OK,
                MessageBoxIcon.Error
            );
        }
        finally
        {
            _restoreInProgress = false;
            if (!IsDisposed && !Disposing)
            {
                closeAppButton.Enabled = true;
                RestoreLauncherControls(shutdownAttempted);
            }
        }
    }

    private void RestoreLauncherControls(bool shutdownAttempted)
    {
        if (GetRestoreRecovery().IsPending)
        {
            ShowRestoreRecoveryState();
        }
        else if (_webAppProcess != null && !_webAppProcess.HasExited)
        {
            SetLauncherStatus(shutdownAttempted ? LauncherStatus.Red : LauncherStatus.Green);
            SetWindowTitle(shutdownAttempted ? "Restore stopped" : "Running");
            statusLabel.Text = shutdownAttempted ? "The web app could not be stopped. No restore was started. Close OrchidApp before trying again." : "OrchidApp is running.";
            openAppButton.Enabled = true;
            backupButton.Enabled = true;
            restoreButton.Enabled = true;
            configureCloudBackupButton.Enabled = true;
        }
        else
        {
            SetLauncherStatus(LauncherStatus.Red);
            SetWindowTitle("Stopped");
            statusLabel.Text = "The web app is stopped. Restore is available; close and reopen OrchidApp to resume normal startup.";
            openAppButton.Enabled = false;
            backupButton.Enabled = false;
            restoreButton.Enabled = true;
            configureCloudBackupButton.Enabled = false;
        }
    }

    private RestoreRecovery GetRestoreRecovery() => new(_programDataPaths.Root);

    private void ShowRestoreRecoveryState()
    {
        SetLauncherStatus(LauncherStatus.Red);
        SetWindowTitle("Recovery required");
        statusLabel.Text = "An interrupted restore needs recovery. Select Restore from backup, or close OrchidApp and contact support. Normal startup and backups are blocked.";
        openAppButton.Enabled = false;
        backupButton.Enabled = false;
        restoreButton.Enabled = true;
        configureCloudBackupButton.Enabled = false;
        AppendLog("Restore recovery required. Do not remove restore-pending.json. Use the retained input or original safety copy.");
    }

    private FileInfo? GetLatestBackupFile()
    {
        var backupsDir = _programDataPaths.Backups;

        if (!Directory.Exists(backupsDir))
        {
            AppendLog($"Backup folder does not exist: {backupsDir}");
            return null;
        }

        try
        {
            return new DirectoryInfo(backupsDir)
                .GetFiles("OrchidAppBackup_*.zip")
                .OrderByDescending(file => file.LastWriteTimeUtc)
                .FirstOrDefault();
        }
        catch (Exception ex)
        {
            AppendLog($"BACKUP ERROR: Unable to read backup folder: {ex.Message}");
            throw new InvalidOperationException(
                $"OrchidApp could not access the backup folder:\n{backupsDir}\n\n" +
                "A safety backup could not be created.",
                ex);
        }
    }

    private void CopyLatestBackupToCloudFolder()
    {
        var settingsService = new LauncherSettingsService(_programDataPaths.LauncherSettingsFile);
        var settings = settingsService.Load();

        if (string.IsNullOrWhiteSpace(settings.CloudBackupFolderPath))
        {
            AppendLog("Cloud backup folder is not configured. Skipping cloud backup copy.");
            return;
        }

        if (!settingsService.TryValidateCloudBackupFolder(
                settings.CloudBackupFolderPath,
                out var validationMessage))
        {
            AppendLog("Cloud backup copy skipped: " + validationMessage);
            return;
        }

        var latestBackup = GetLatestBackupFile();

        if (latestBackup == null)
        {
            AppendLog("Cloud backup copy skipped: no local backup file found.");
            return;
        }

        var cloudBackupPath = Path.Combine(
            settings.CloudBackupFolderPath,
            CloudBackupFileName);

        try
        {
            if (GetRestoreRecovery().ProtectsCloudDestination(cloudBackupPath))
            {
                AppendLog("Cloud backup copy skipped to preserve a selected restore input. Choose a different cloud backup folder after verifying recovery.");
                return;
            }
            File.Copy(
                latestBackup.FullName,
                cloudBackupPath,
                overwrite: true);

            AppendLog($"Cloud backup copy completed: {cloudBackupPath}");
        }
        catch (Exception ex)
        {
            AppendLog("Cloud backup copy failed: " + ex.Message);
        }
    }

    private bool IsAutomaticBackupDue()
    {
        var latestBackup = GetLatestBackupFile();

        if (latestBackup == null)
        {
            AppendLog("No previous backup found.");
            return true;
        }

        var backupAge = DateTime.UtcNow - latestBackup.LastWriteTimeUtc;

        AppendLog(
            $"Latest backup: {latestBackup.Name}, age: {backupAge.TotalHours:N1} hours."
        );

        return backupAge > AutomaticBackupAgeThreshold;
    }

    private void ConfigureCloudBackupButton_Click(object? sender, EventArgs e)
    {
        var settingsService = new LauncherSettingsService(_programDataPaths.LauncherSettingsFile);
        var settings = settingsService.Load();

        using var dialog = new FolderBrowserDialog
        {
            Description = "Choose a folder synced by OneDrive, Google Drive, iCloud Drive or another cloud provider.",
            ShowNewFolderButton = true
        };

        if (!string.IsNullOrWhiteSpace(settings.CloudBackupFolderPath) &&
            Directory.Exists(settings.CloudBackupFolderPath))
        {
            dialog.SelectedPath = settings.CloudBackupFolderPath;
        }

        if (dialog.ShowDialog(this) != DialogResult.OK)
        {
            AppendLog("Cloud backup folder configuration cancelled.");
            return;
        }

        if (!settingsService.TryValidateCloudBackupFolder(
                dialog.SelectedPath,
                out var validationMessage))
        {
            MessageBox.Show(
                this,
                validationMessage,
                "Cloud backup folder",
                MessageBoxButtons.OK,
                MessageBoxIcon.Warning);

            return;
        }

        settings.CloudBackupFolderPath = dialog.SelectedPath;
        settingsService.Save(settings);

        AppendLog($"Cloud backup folder configured: {settings.CloudBackupFolderPath}");

        MessageBox.Show(
            this,
            "Cloud backup folder saved.",
            "Cloud backup folder",
            MessageBoxButtons.OK,
            MessageBoxIcon.Information);
    }

    private void OpenOrchidAppInBrowser()
    {
        Process.Start(new ProcessStartInfo
        {
            FileName = "http://localhost:5285",
            UseShellExecute = true
        });
    }

    private void LogLayoutState(OrchidAppLayoutState layout)
    {
        AppendLog("Windows layout detection:");
        AppendLog($"  Status: {layout.Status}");
        AppendLog($"  Legacy candidates found: {layout.LegacyCandidates.Count}");
        AppendLog($"  Data-bearing legacy candidates found: {layout.DataBearingLegacyCandidateCount}");

        foreach (var candidate in layout.LegacyCandidates)
        {
            AppendLog($"  Legacy candidate: {candidate.RootPath}");
            AppendLog($"    Source: {candidate.DiscoverySource}");
            AppendLog($"    Has orchids database: {candidate.HasOrchidsDatabase}");
            AppendLog($"    Has uploads: {candidate.HasUploads}");
            AppendLog($"    Has backups: {candidate.HasBackups}");
            AppendLog($"    Has logs: {candidate.HasLogs}");
            AppendLog($"    Has launcher settings: {candidate.HasLauncherSettings}");
        }

        AppendLog($"  Old layout exists: {layout.OldLayoutExists}");
        AppendLog($"  Current app legacy uploads exist: {layout.CurrentAppLegacyUploadsExists}");
        AppendLog($"  Current app legacy launcher settings exist: {layout.CurrentAppLegacyLauncherSettingsExists}");

        AppendLog($"  ProgramData layout exists: {layout.ProgramDataLayoutExists}");
        AppendLog($"  ProgramData uploads exist: {layout.ProgramDataUploadsExists}");
        AppendLog($"  ProgramData launcher settings exist: {layout.ProgramDataLauncherSettingsExists}");

        AppendLog($"  App root: {layout.AppRootPath}");
        AppendLog($"  ProgramData root: {layout.ProgramDataRootPath}");

        AppendLog($"  Current app legacy MariaDB data: {layout.CurrentAppLegacyMariaDbDataPath}");
        AppendLog($"  Current app legacy uploads: {layout.CurrentAppLegacyUploadsPath}");
        AppendLog($"  Current app legacy backups: {layout.CurrentAppLegacyBackupsPath}");
        AppendLog($"  Current app legacy logs: {layout.CurrentAppLegacyLogsPath}");
        AppendLog($"  Current app legacy settings: {layout.CurrentAppLegacyLauncherSettingsPath}");

        AppendLog($"  ProgramData MariaDB data: {layout.ProgramDataMariaDbDataPath}");
        AppendLog($"  ProgramData uploads: {layout.ProgramDataUploadsPath}");
        AppendLog($"  ProgramData backups: {layout.ProgramDataBackupsPath}");
        AppendLog($"  ProgramData logs: {layout.ProgramDataLogsPath}");
        AppendLog($"  ProgramData launcher settings: {layout.ProgramDataLauncherSettingsPath}");
    }

    private void AppendLog(string text)
    {
        if (InvokeRequired)
        {
            BeginInvoke(new Action<string>(AppendLog), text);
            return;
        }

        var line = $"[{DateTime.Now:yyyy-MM-dd HH:mm:ss}] {text}";

        WriteLauncherLogFileLine(line);

        lock (_logLock)
        {
            logBox.AppendText(line + Environment.NewLine);
        }
    }

    private bool MariaDbSystemDatabaseExists(string dataDir)
    {
        return Directory.Exists(Path.Combine(dataDir, "mysql"));
    }

    private void SetWindowTitle(string status)
    {
        if (InvokeRequired)
        {
            BeginInvoke(new Action<string>(SetWindowTitle), status);
            return;
        }

        Text = $"OrchidApp Launcher - {status}";
    }

    private void SetLauncherStatus(LauncherStatus status)
    {
        if (InvokeRequired)
        {
            BeginInvoke(new Action<LauncherStatus>(SetLauncherStatus), status);
            return;
        }

        statusLight.BackColor = status switch
        {
            LauncherStatus.Red => Color.Firebrick,
            LauncherStatus.Amber => Color.Goldenrod,
            LauncherStatus.Green => Color.ForestGreen,
            _ => Color.Firebrick
        };
    }

    protected override void OnFormClosing(FormClosingEventArgs e)
    {
        if (_migrationStartupInProgress)
        {
            e.Cancel = true;
            AppendLog("Migration/startup verification is running. Wait for completion or a reported failure before closing.");
            return;
        }
        if (_restoreInProgress && !_closeConfirmed)
        {
            e.Cancel = true;
            AppendLog("Restore is running. Keep this launcher open until it completes or reports a failure.");
            return;
        }
        if (!_closeConfirmed)
        {
            var confirm = MessageBox.Show(
                "Closing this window will stop OrchidApp.\n\n" +
                "Any open browser tabs will no longer work until you start OrchidApp again.\n\n" +
                "Do you want to close OrchidApp?",
                "Close OrchidApp?",
                MessageBoxButtons.YesNo,
                MessageBoxIcon.Warning,
                MessageBoxDefaultButton.Button2
            );

            if (confirm != DialogResult.Yes)
            {
                e.Cancel = true;
                return;
            }

            _closeConfirmed = true;
        }
        
        try
        {
            AppendLog("Launcher closing...");
            SetLauncherStatus(LauncherStatus.Amber);
            SetWindowTitle("Closing");
            openAppButton.Enabled = false;
            backupButton.Enabled = false;
            restoreButton.Enabled = false;
            closeAppButton.Enabled = false;

            if (_webAppProcess != null && !_webAppProcess.HasExited)
            {
                AppendLog("Stopping web app process...");
                _webAppProcess.Kill(true);
                _webAppProcess.WaitForExit(10000);
                AppendLog("Web app process stopped.");
            }

            StopMariaDbGracefully();
        }
        catch (Exception ex)
        {
            AppendLog("Shutdown error: " + ex.Message);
        }

        base.OnFormClosing(e);
    }
}
