using System.Diagnostics;
using System.Drawing;
using MySqlConnector;

namespace OrchidApp.Launcher;

public partial class OrchidAppLauncherForm : Form
{
    private Label statusLabel = new Label();
    private Panel statusLight = new Panel();
    private TextBox logBox = new TextBox();
    private Button backupButton = new Button();
    private Button restoreButton = new Button();

    private static readonly TimeSpan AutomaticBackupAgeThreshold = TimeSpan.FromHours(168);
    private bool _backupInProgress = false;

    private Process? _webAppProcess;
    private Process? _mariaDbProcess;
    private string? _webAppStartupError;

    private readonly object _logLock = new object();

    private readonly string _logFilePath =
        Path.Combine(AppContext.BaseDirectory, "launcher.log");

    private enum LauncherStatus
    {
        Red,
        Amber,
        Green
    }

    public OrchidAppLauncherForm()
    {
        InitializeComponent();

        Text = "OrchidApp Launcher";
        Width = 680;
        Height = 460;

        try
        {
            File.WriteAllText(_logFilePath, string.Empty);
        }
        catch
        {
            // ignore log reset errors
        }


        statusLabel.Text = "Starting OrchidApp. Please keep this window open while using OrchidApp.";
        statusLabel.AutoSize = true;
        statusLabel.Left = 45;
        statusLabel.Top = 20;

        statusLight.Left = 20;
        statusLight.Top = 22;
        statusLight.Width = 18;
        statusLight.Height = 18;
        statusLight.BackColor = Color.Firebrick;
        statusLight.BorderStyle = BorderStyle.FixedSingle;

        logBox.Multiline = true;
        logBox.ScrollBars = ScrollBars.Vertical;
        logBox.Left = 20;
        logBox.Top = 70;
        logBox.Width = 600;
        logBox.Height = 260;

        backupButton.Text = "Back up now";
        backupButton.Left = 20;
        backupButton.Top = 335;
        backupButton.Width = 140;
        backupButton.Height = 35;
        backupButton.Enabled = false;
        backupButton.Click += async (s, e) => await RunBackupAsync();

        restoreButton.Text = "Restore from backup...";
        restoreButton.Left = 180;
        restoreButton.Top = 335;
        restoreButton.Width = 180;
        restoreButton.Height = 35;
        restoreButton.Enabled = false;
        restoreButton.Click += async (s, e) => await RunRestoreAsync();

        Controls.Add(statusLabel);
        Controls.Add(statusLight);
        Controls.Add(logBox);
        Controls.Add(backupButton);
        Controls.Add(restoreButton);
    }

    protected override async void OnLoad(EventArgs e)
    {
        base.OnLoad(e);

        try
        {
            SetLauncherStatus(LauncherStatus.Red);
            StartMariaDb();

            await WaitForMariaDbAsync(
                "server=127.0.0.1;port=3308;user=orchid;password=orchid;"
            );

            AppendLog("MariaDB startup confirmed.");
            SetLauncherStatus(LauncherStatus.Amber);

            await StartWebAppAsync();
        }
        catch (Exception ex)
        {
            SetLauncherStatus(LauncherStatus.Red);
            AppendLog("STARTUP ERROR: " + ex.Message);

            MessageBox.Show(
                ex.Message,
                "OrchidApp could not start",
                MessageBoxButtons.OK,
                MessageBoxIcon.Warning
            );
        }
    }

    private async Task StartWebAppAsync()
    {
        statusLabel.Text = "Starting web application...";

        var baseDir = AppContext.BaseDirectory;

        var exePath = Path.Combine(baseDir, "OrchidApp.Web.exe");

        _webAppProcess = new Process
        {
            StartInfo = new ProcessStartInfo
            {
                FileName = exePath,
                Arguments = "--urls=http://localhost:5285",
                WorkingDirectory = baseDir,
                UseShellExecute = false,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                CreateNoWindow = true
            }
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

        Process.Start(new ProcessStartInfo
        {
            FileName = "http://localhost:5285",
            UseShellExecute = true
        });

        statusLabel.Text = "OrchidApp is running. Keep this window open while using OrchidApp.";
        SetLauncherStatus(LauncherStatus.Green);
        backupButton.Enabled = true;
        restoreButton.Enabled = true;

        _ = RunAutomaticBackupIfDueAsync();
    }

    private void StartMariaDb()
    {
        var baseDir = AppContext.BaseDirectory;

        var mariaDbExe = Path.Combine(
            baseDir,
            "runtime",
            "mariadb",
            "win-x64",
            "bin",
            "mariadbd.exe"
        );

        var dataDir = Path.Combine(
            baseDir,
            "data",
            "mariadb"
        );

        AppendLog($"MariaDB EXE: {mariaDbExe}");
        AppendLog($"MariaDB DataDir: {dataDir}");

        var process = new Process
        {
            StartInfo = new ProcessStartInfo
            {
                FileName = mariaDbExe,
                Arguments =
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

    private void AppendLog(string text)
    {
        if (InvokeRequired)
        {
            BeginInvoke(new Action<string>(AppendLog), text);
            return;
        }

        var line = $"[{DateTime.Now:yyyy-MM-dd HH:mm:ss}] {text}";

        lock (_logLock)
        {
            try
            {
                using var stream = new FileStream(
                    _logFilePath,
                    FileMode.Append,
                    FileAccess.Write,
                    FileShare.ReadWrite);

                using var writer = new StreamWriter(stream);
                writer.WriteLine(line);
            }
            catch
            {
                // ignore file logging errors
            }

            logBox.AppendText(line + Environment.NewLine);
        }
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
                    Arguments = "-h 127.0.0.1 -P 3308 -u orchid_shutdown -porchid_shutdown shutdown",
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

    private FileInfo? GetLatestBackupFile()
    {
        var backupsDir = Path.Combine(
            AppContext.BaseDirectory,
            "backups"
        );

        if (!Directory.Exists(backupsDir))
        {
            return null;
        }

        return new DirectoryInfo(backupsDir)
            .GetFiles("OrchidAppBackup_*.zip")
            .OrderByDescending(file => file.LastWriteTimeUtc)
            .FirstOrDefault();
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

    private async Task RunAutomaticBackupIfDueAsync()
    {
        if (!IsAutomaticBackupDue())
        {
            AppendLog("Automatic backup not required.");
            return;
        }

        AppendLog("A safety backup has not been made in the last 7 days. Creating one now...");

        await RunBackupAsync(showSuccessMessage: false);

        AppendLog("Automatic safety backup completed.");
    }

    private async Task RunBackupAsync(bool showSuccessMessage = true)
    {
        if (_backupInProgress)
        {
            AppendLog("Backup is already running.");
            return;
        }

        _backupInProgress = true;

        backupButton.Enabled = false;
        restoreButton.Enabled = false;
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
                backupButton.Enabled = true;
                restoreButton.Enabled = true;
            }
        }
    }

    private async Task RunRestoreAsync()
    {
        backupButton.Enabled = false;
        restoreButton.Enabled = false;
        SetLauncherStatus(LauncherStatus.Red);

        try
        {
            AppendLog("Restore requested.");

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

            var backupZip = dialog.FileName;

            var confirm = MessageBox.Show(
                "Restoring a backup will replace the current OrchidApp database and uploaded files.\n\n" +
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

            var process = new Process
            {
                StartInfo = new ProcessStartInfo
                {
                    FileName = "powershell.exe",
                    Arguments =
                        "-NoProfile -ExecutionPolicy Bypass " +
                        $"-File \"{restoreScript}\" " +
                        $"-BackupZip \"{backupZip}\"",
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
            if (_webAppProcess != null && !_webAppProcess.HasExited)
            {
                SetLauncherStatus(LauncherStatus.Green);
                backupButton.Enabled = true;
                restoreButton.Enabled = true;
            }
        }
    }

    protected override void OnFormClosing(FormClosingEventArgs e)
    {
        try
        {
            AppendLog("Launcher closing...");
            SetLauncherStatus(LauncherStatus.Amber);
            backupButton.Enabled = false;
            restoreButton.Enabled = false;

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