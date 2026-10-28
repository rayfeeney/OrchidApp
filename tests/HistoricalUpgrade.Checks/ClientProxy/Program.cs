using System.Diagnostics;
using System.Text.Json;
using System.Text.RegularExpressions;

// The operational runner receives a real native client executable. This proxy
// transports its unchanged SQL/stdin only into the newly owned Docker fixture.
var id = Environment.GetEnvironmentVariable("ORCHID_FIXTURE_CONTAINER_ID") ?? "";
var token = Environment.GetEnvironmentVariable("ORCHID_FIXTURE_TOKEN") ?? "";
var allowed = new HashSet<string>(StringComparer.Ordinal) {
    "--no-defaults", "--protocol=TCP", "--host=127.0.0.1", "--port=3306",
    "--user=root", "--database=orchids", "--connect-timeout=5",
    "--default-character-set=utf8mb4", "--batch", "--skip-column-names",
    "--abort-source-on-error"
};
if (!Regex.IsMatch(id, "^[a-f0-9]{64}$") || !Regex.IsMatch(token, "^[a-f0-9]{32}$") ||
    args.Any(a => !allowed.Contains(a)) || !args.Contains("--database=orchids"))
{
    Console.Error.WriteLine("Fixture client refused an unexpected identity or target argument.");
    return 64;
}
ProcessStartInfo Command(params string[] values) {
    var info = new ProcessStartInfo("docker") { UseShellExecute = false };
    foreach (var value in values) info.ArgumentList.Add(value);
    return info;
}
try {
    var inspection = Command("inspect", id);
    inspection.RedirectStandardOutput = true;
    inspection.RedirectStandardError = true;
    using var inspect = Process.Start(inspection)!;
    var output = inspect.StandardOutput.ReadToEndAsync();
    var errors = inspect.StandardError.ReadToEndAsync();
    await inspect.WaitForExitAsync();
    using var doc = JsonDocument.Parse(await output);
    await errors;
    var state = doc.RootElement[0];
    var config = state.GetProperty("HostConfig");
    var binds = config.GetProperty("Binds");
    var ports = config.GetProperty("PortBindings");
    if (inspect.ExitCode != 0 || state.GetProperty("Id").GetString() != id ||
        state.GetProperty("Config").GetProperty("Labels")
            .GetProperty("org.orchidapp.fixture-token").GetString() != token ||
        config.GetProperty("NetworkMode").GetString() != "none" ||
        (binds.ValueKind != JsonValueKind.Null && binds.GetArrayLength() != 0) ||
        (ports.ValueKind != JsonValueKind.Null && ports.EnumerateObject().Any()) ||
        state.GetProperty("Mounts").EnumerateArray().Any(m => m.GetProperty("Type").GetString() == "bind"))
        throw new InvalidOperationException();
    var client = Command("exec", "-i", "--env", "MYSQL_PWD", id, "mariadb");
    foreach (var arg in args) client.ArgumentList.Add(arg);
    client.RedirectStandardInput = true;
    using var process = Process.Start(client)!;
    try {
        await Console.OpenStandardInput().CopyToAsync(process.StandardInput.BaseStream);
        process.StandardInput.Close();
    }
    catch (IOException) { /* Preserve the actual client failure below. */ }
    await process.WaitForExitAsync();
    return process.ExitCode;
}
catch {
    Console.Error.WriteLine("Fixture client could not verify or access its owned isolated container.");
    return 65;
}
