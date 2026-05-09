using System.Diagnostics;
using MySqlConnector;

namespace OrchidApp.Launcher;

public partial class OrchidAppLauncherForm : Form
{
    private Label statusLabel = new Label();
    private TextBox logBox = new TextBox();
    private Button backupButton = new Button();

    private Process? _webAppProcess;
    private Process? _mariaDbProcess;
    private string? _webAppStartupError;

    private readonly object _logLock = new object();

    private readonly string _logFilePath =
        Path.Combine(AppContext.BaseDirectory, "launcher.log");

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
        statusLabel.Left = 20;
        statusLabel.Top = 20;

        logBox.Multiline = true;
        logBox.ScrollBars = ScrollBars.Vertical;
        logBox.Left = 20;
        logBox.Top = 60;
        logBox.Width = 600;
        logBox.Height = 260;

        backupButton.Text = "Back up now";
        backupButton.Left = 20;
        backupButton.Top = 335;
        backupButton.Width = 140;
        backupButton.Height = 35;
        backupButton.Enabled = false;
        backupButton.Click += async (s, e) => await RunBackupAsync();

        Controls.Add(statusLabel);
        Controls.Add(logBox);
        Controls.Add(backupButton);
    }

    protected override async void OnLoad(EventArgs e)
    {
        base.OnLoad(e);

        try
        {
            StartMariaDb();

            await WaitForMariaDbAsync(
                "server=127.0.0.1;port=3308;user=orchid;password=orchid;"
            );

            AppendLog("MariaDB startup confirmed.");

            await StartWebAppAsync();
        }
        catch (Exception ex)
        {
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

        statusLabel.Text = "O. Keep this window open while using OrchidApp.";
        backupButton.Enabled = true;
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

    private async Task RunBackupAsync()
    {
        backupButton.Enabled = false;

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

            MessageBox.Show(
                "Backup completed successfully.",
                "Backup Complete",
                MessageBoxButtons.OK,
                MessageBoxIcon.Information
            );
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
            if (_webAppProcess != null && !_webAppProcess.HasExited)
            {
                backupButton.Enabled = true;
            }
        }
    }

    protected override void OnFormClosing(FormClosingEventArgs e)
    {
        try
        {
            AppendLog("Launcher closing...");
            backupButton.Enabled = false;

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