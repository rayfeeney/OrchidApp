using System.Diagnostics;


namespace OrchidApp.Launcher;

public partial class Form1 : Form
{
    private Label statusLabel = new Label();
    private TextBox logBox = new TextBox();

    private Process? _webAppProcess;
    private Process? _mariaDbProcess;

    public Form1()
    {
        InitializeComponent();

        statusLabel.Text = "Starting OrchidApp...";
        statusLabel.AutoSize = true;
        statusLabel.Left = 20;
        statusLabel.Top = 20;

        logBox.Multiline = true;
        logBox.ScrollBars = ScrollBars.Vertical;
        logBox.Left = 20;
        logBox.Top = 60;
        logBox.Width = 600;
        logBox.Height = 300;

        Controls.Add(statusLabel);
        Controls.Add(logBox);
    }

    protected override async void OnLoad(EventArgs e)
    {
        base.OnLoad(e);

        StartMariaDb();

        await Task.Delay(2000); // give MariaDB time to start

        StartWebApp();
    }

    private async void StartWebApp()
    {
        statusLabel.Text = "Starting web application...";

        var projectPath = Path.GetFullPath(
            Path.Combine(
                AppDomain.CurrentDomain.BaseDirectory,
                "..", "..", "..", "..",
                "OrchidApp.Web",
                "OrchidApp.Web.csproj"
            )
        );

        _webAppProcess = new Process
        {
            StartInfo = new ProcessStartInfo
            {
                FileName = "dotnet",
                Arguments = $"run --project \"{projectPath}\" --no-launch-profile --urls=http://localhost:5285",
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
            if (e.Data != null)
                AppendLog("ERR: " + e.Data);
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

        statusLabel.Text = "OrchidApp is running";
    }

    private void StartMariaDb()
    {
        var repoRoot = Path.GetFullPath(
            Path.Combine(
                AppContext.BaseDirectory,
                "..", "..", "..", "..", ".."
            )
        );

        var mariaDbExe = Path.Combine(
            repoRoot,
            "app",
            "runtime",
            "mariadb",
            "win-x64",
            "bin",
            "mariadbd.exe"
        );

        var dataDir = Path.Combine(
            repoRoot,
            "app",
            "data",
            "mariadb"
        );

        _mariaDbProcess = new Process
        {
            StartInfo = new ProcessStartInfo
            {
                FileName = mariaDbExe,
                Arguments = $"--datadir=\"{dataDir}\" --port=3308",
                UseShellExecute = false,
                CreateNoWindow = true
            }
        };

        _mariaDbProcess.Start();
    }

    private async Task WaitForWebAppAsync(string url)
    {
        using var client = new HttpClient();

        for (int i = 0; i < 30; i++) // ~15 seconds
        {
            try
            {
                var response = await client.GetAsync(url, HttpCompletionOption.ResponseHeadersRead);
                if (response.IsSuccessStatusCode)
                    return;
            }
            catch
            {
                // not ready yet
            }

            await Task.Delay(500);
        }

        throw new Exception("Web app did not start in time");
    }

    private void AppendLog(string text)
    {
        if (InvokeRequired)
        {
            Invoke(new Action<string>(AppendLog), text);
            return;
        }

        logBox.AppendText(text + Environment.NewLine);
    }

    protected override void OnFormClosing(FormClosingEventArgs e)
    {
        try
        {
            if (_webAppProcess != null && !_webAppProcess.HasExited)
            {
                _webAppProcess.Kill(true);
            }

            if (_mariaDbProcess != null && !_mariaDbProcess.HasExited)
            {
                _mariaDbProcess.Kill(true);
            }
        }
        catch
        {
            // ignore cleanup errors
        }

        base.OnFormClosing(e);
    }
}