using System.Runtime.InteropServices;
using Microsoft.EntityFrameworkCore;
using OrchidApp.Web.Configuration;
using OrchidApp.Web.Data;
using OrchidApp.Web.Pages;

var count = 0;
void Check(string name, bool pass) { if (!pass) throw new Exception(name); count++; }
foreach (var architecture in Enum.GetValues<Architecture>())
{
    Check($"Non-Linux {architecture} disabled", !PlatformFeatures.SupportsEnvironmentSummary(false, architecture));
    Check($"Linux {architecture} policy", PlatformFeatures.SupportsEnvironmentSummary(true, architecture)
        == (architecture is Architecture.Arm or Architecture.Arm64));
}
Check("Linux ARM32 enabled", PlatformFeatures.SupportsEnvironmentSummary(true, Architecture.Arm));
Check("Linux ARM64 enabled", PlatformFeatures.SupportsEnvironmentSummary(true, Architecture.Arm64));
Check("Linux x64 disabled", !PlatformFeatures.SupportsEnvironmentSummary(true, Architecture.X64));
Check("Windows ARM64 disabled", !PlatformFeatures.SupportsEnvironmentSummary(false, Architecture.Arm64));
Check("Current host policy", PlatformFeatures.EnvironmentSummaryEnabled ==
    PlatformFeatures.SupportsEnvironmentSummary(OperatingSystem.IsLinux(), RuntimeInformation.OSArchitecture));

if (!PlatformFeatures.EnvironmentSummaryEnabled)
{
    // A context with no provider cannot query any table or view. The actual page
    // handler must still complete, proving unsupported hosts skip DB access.
    using var db = new OrchidDbContext(new DbContextOptions<OrchidDbContext>());
    var home = new IndexModel(db);
    await home.OnGetAsync();
    Check("Home completes without a database provider", !home.EnvironmentSummaryEnabled);
    Check("Unsupported host has no environment rows", home.EnvironmentSummaries.Count == 0);
}
else
{
    Console.WriteLine("Home no-database check applies only to unsupported hosts; Linux ARM database query is intentionally retained.");
}
Console.WriteLine($"{count} environment-platform checks passed.");
