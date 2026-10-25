using Microsoft.Extensions.Configuration;
using MySqlConnector;
using OrchidApp.Web.Configuration;

var root = Path.Combine(Path.GetTempPath(), "orchids-dev-config-" + Guid.NewGuid().ToString("N"));
var contentRoot = Path.Combine(root, "src", "OrchidApp.Web");
Directory.CreateDirectory(contentRoot);
File.WriteAllText(Path.Combine(root, "OrchidApp.sln"), "fixture");
var file = Path.Combine(root, ".env");
var checks = 0;
void Check(string name, bool passed) { if (!passed) throw new Exception(name); checks++; }
void Reject(string name, Action action) { try { action(); } catch (InvalidOperationException e) { Check(name, !e.Message.Contains("private")); return; } throw new Exception("Did not reject: " + name); }
ConfigurationManager Config() => new();
var originalPath = Environment.GetEnvironmentVariable("PATH");
try
{
    File.WriteAllText(file, """
        # private fixture only
        export MARIADB_HOST=127.0.0.1
        MARIADB_PORT=53321
        MARIADB_DATABASE=orchids_fixture
        MARIADB_USER=fixture
        MARIADB_PASSWORD='private#;$=with spaces'
        IGNORED_KEY=ignored
        """);
    var config = Config();
    DevelopmentConfiguration.Apply(config, "Development", contentRoot);
    var connection = new MySqlConnectionStringBuilder(config.GetConnectionString("OrchidDb")!);
    Check("Repository env found above web project", connection.Database == "orchids_fixture");
    Check("Host and non-default port", connection.Server == "127.0.0.1" && connection.Port == 53321);
    Check("Account and literal password survive", connection.UserID == "fixture" && connection.Password == "private#;$=with spaces");
    Check("Default upload root absolute and writable directory exists", Path.IsPathFullyQualified(config["Storage:UploadRoot"]!) && Directory.Exists(config["Storage:UploadRoot"]));
    Check("Unrelated env keys ignored", !DevelopmentConfiguration.ReadDotEnv(file).ContainsKey("IGNORED_KEY"));
    var supplied = Config(); supplied["MARIADB_DATABASE"] = "explicit_database";
    supplied["Storage:UploadRoot"] = Path.Combine(root, "custom uploads");
    DevelopmentConfiguration.Apply(supplied, "Development", contentRoot);
    Check("Existing settings override env file", new MySqlConnectionStringBuilder(supplied.GetConnectionString("OrchidDb")!).Database == "explicit_database");
    Check("Explicit upload directory preserved", supplied["Storage:UploadRoot"] == Path.Combine(root, "custom uploads"));
    var direct = Config(); direct["ConnectionStrings:OrchidDb"] = "Server=direct;Database=direct;User ID=fixture;Password=test";
    DevelopmentConfiguration.Apply(direct, "Development", contentRoot);
    Check("Existing complete connection preserved", new MySqlConnectionStringBuilder(direct.GetConnectionString("OrchidDb")!).Server == "direct");
    File.WriteAllText(file, "MARIADB_PASSWORD='private\n");
    foreach (var environment in new[] { "Production", "Desktop" }) {
        var other = Config(); DevelopmentConfiguration.Apply(other, environment, contentRoot);
        Check(environment + " ignores development file/defaults", other.GetConnectionString("OrchidDb") is null && other["Storage:UploadRoot"] is null);
    }
    Reject("Malformed quote rejected without secret", () => DevelopmentConfiguration.Apply(Config(), "Development", contentRoot));
    File.Delete(file);
    Reject("Missing credentials rejected without guessing target", () => DevelopmentConfiguration.Apply(Config(), "Development", contentRoot));
    var environmentOnly = Config();
    foreach (var pair in new Dictionary<string,string> { ["MARIADB_HOST"]="localhost", ["MARIADB_PORT"]="3306", ["MARIADB_DATABASE"]="explicit", ["MARIADB_USER"]="fixture", ["MARIADB_PASSWORD"]="private" }) environmentOnly[pair.Key] = pair.Value;
    DevelopmentConfiguration.Apply(environmentOnly, "Development", contentRoot);
    Check("Environment-only configuration still supported", new MySqlConnectionStringBuilder(environmentOnly.GetConnectionString("OrchidDb")!).Database == "explicit");
    environmentOnly["ConnectionStrings:OrchidDb"] = null; environmentOnly["MARIADB_PORT"] = "0";
    Reject("Invalid port rejected", () => DevelopmentConfiguration.Apply(environmentOnly, "Development", contentRoot));
    Console.WriteLine($"{checks} development startup configuration checks passed.");
}
finally { Environment.SetEnvironmentVariable("PATH", originalPath); Directory.Delete(root, recursive: true); }
