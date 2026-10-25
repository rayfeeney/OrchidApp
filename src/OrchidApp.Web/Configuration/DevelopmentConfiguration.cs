using System.Text.RegularExpressions;
using Microsoft.Extensions.Configuration;
using MySqlConnector;

namespace OrchidApp.Web.Configuration;

public static class DevelopmentConfiguration
{
    public static void Apply(ConfigurationManager configuration, string environmentName, string contentRoot)
    {
        if (!string.Equals(environmentName, "Development", StringComparison.OrdinalIgnoreCase)) return;
        var repository = new DirectoryInfo(contentRoot);
        while (repository.Parent is not null && !File.Exists(Path.Combine(repository.FullName, "OrchidApp.sln")))
            repository = repository.Parent;
        var envPath = Path.Combine(File.Exists(Path.Combine(repository.FullName, "OrchidApp.sln")) ? repository.FullName : contentRoot, ".env");
        var values = ReadDotEnv(envPath);
        string? Read(string key) => configuration[key.Replace("__", ":")] ?? values.GetValueOrDefault(key);

        if (string.IsNullOrWhiteSpace(configuration.GetConnectionString("OrchidDb")))
        {
            var connection = Read("ConnectionStrings__OrchidDb");
            if (string.IsNullOrWhiteSpace(connection))
            {
                string Required(string key) => !string.IsNullOrWhiteSpace(Read(key)) ? Read(key)! :
                    throw new InvalidOperationException($"Development database setting {key} is missing. Set it in the repository .env or environment. Values are not logged.");
                if (!uint.TryParse(Required("MARIADB_PORT"), out var port) || port is < 1 or > 65535)
                    throw new InvalidOperationException("Development MARIADB_PORT must be between 1 and 65535.");
                connection = new MySqlConnectionStringBuilder
                {
                    Server = Required("MARIADB_HOST"), Port = port,
                    Database = Required("MARIADB_DATABASE"), UserID = Required("MARIADB_USER"),
                    Password = Required("MARIADB_PASSWORD")
                }.ConnectionString;
            }
            configuration["ConnectionStrings:OrchidDb"] = connection;
        }
        var uploadRoot = Read("Storage__UploadRoot");
        if (string.IsNullOrWhiteSpace(uploadRoot))
            uploadRoot = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "OrchidApp", "Development", "uploads");
        if (!Path.IsPathFullyQualified(uploadRoot))
            throw new InvalidOperationException("Development Storage__UploadRoot must be an absolute directory.");
        Directory.CreateDirectory(uploadRoot);
        configuration["Storage:UploadRoot"] = uploadRoot;

        // Direct dotnet run should find the already restored full Windows runtime.
        var nativeBin = Path.Combine(repository.FullName, "app", "runtime", "libvips", "win-x64", "bin");
        if (OperatingSystem.IsWindows() && File.Exists(Path.Combine(nativeBin, "libvips-42.dll")))
            Environment.SetEnvironmentVariable("PATH", nativeBin + Path.PathSeparator + Environment.GetEnvironmentVariable("PATH"));
    }

    public static Dictionary<string, string?> ReadDotEnv(string path)
    {
        var values = new Dictionary<string, string?>(StringComparer.OrdinalIgnoreCase);
        if (!File.Exists(path)) return values;
        var allowed = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
        {
            "MARIADB_HOST", "MARIADB_PORT", "MARIADB_DATABASE", "MARIADB_USER", "MARIADB_PASSWORD",
            "MARIADB_CHARSET", "MARIADB_COLLATION", "Storage__UploadRoot", "ConnectionStrings__OrchidDb"
        };
        var lineNumber = 0;
        foreach (var raw in File.ReadLines(path))
        {
            lineNumber++;
            var line = raw.Trim();
            if (line.Length == 0 || line.StartsWith('#')) continue;
            var match = Regex.Match(line, @"^(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=(.*)$");
            if (!match.Success || !allowed.Contains(match.Groups[1].Value)) continue;
            var value = match.Groups[2].Value.Trim();
            if (value.StartsWith('\'') || value.StartsWith('"'))
            {
                var end = value.LastIndexOf(value[0]);
                if (end == 0 || (value[(end + 1)..].Trim() is var tail && tail.Length > 0 && !tail.StartsWith('#')))
                    throw new InvalidOperationException($"Invalid quoted development .env value at line {lineNumber}. Values are not logged.");
                value = value[1..end];
            }
            // Literal values: no shell evaluation, variable expansion or escape rewriting.
            values[match.Groups[1].Value] = value;
        }
        return values;
    }
}
