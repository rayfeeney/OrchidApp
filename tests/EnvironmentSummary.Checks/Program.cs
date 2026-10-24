using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Hosting.Server;
using Microsoft.AspNetCore.Hosting.Server.Features;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.AspNetCore.DataProtection;
using System.Runtime.InteropServices;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using OrchidApp.Web.Configuration;
using OrchidApp.Web.Data;
using OrchidApp.Web.Pages;

var count = 0;
void Check(string name, bool pass) { if (!pass) throw new Exception(name); count++; }
foreach (var architecture in Enum.GetValues<Architecture>())
foreach (var linux in new[] { false, true })
foreach (var enabled in new string?[] { null, "false", "true" })
{
    var values = new Dictionary<string, string?>();
    if (enabled is not null) values["Monitoring:Enabled"] = enabled;
    var config = new ConfigurationBuilder().AddInMemoryCollection(values).Build();
    var policy = PlatformFeatures.FromConfiguration(config, linux, architecture);
    var expected = enabled == "true" && linux &&
        (architecture is Architecture.Arm or Architecture.Arm64);
    Check($"Policy {linux}/{architecture}/{enabled ?? "absent"}", policy.EnvironmentSummaryEnabled == expected);
    if (!expected)
    {
        // No provider: any accidental summary, chart or cost query must fail.
        using var db = new OrchidDbContext(new DbContextOptions<OrchidDbContext>());
        var home = new IndexModel(db, policy);
        await home.OnGetAsync();
        Check("Disabled Home completes without database", !home.EnvironmentSummaryEnabled);
        Check("No monitoring results", home.EnvironmentSummaries.Count == 0 &&
            home.GreenhouseCharts.Count == 0 && home.ChartError is null);
    }
}
// Standard configuration upgrades keep the default off; a private higher-priority
// owner setting must survive replacement of the distributed defaults.
foreach (var owner in new[] { false, true })
{
    var config = new ConfigurationBuilder()
        .AddInMemoryCollection(new Dictionary<string, string?> { ["Monitoring:Enabled"] = "false" })
        .AddInMemoryCollection(owner ? new Dictionary<string, string?> { ["Monitoring:Enabled"] = "true" } : [])
        .Build();
    Check("Upgrade configuration precedence",
        PlatformFeatures.FromConfiguration(config, true, Architecture.Arm64).EnvironmentSummaryEnabled == owner);
}
// Exercise the real compiled Razor page, including its script guards, on a
// simulated general Linux ARM64 installation with no database provider.
var builder = WebApplication.CreateBuilder(new WebApplicationOptions {
    ApplicationName = typeof(IndexModel).Assembly.FullName,
    ContentRootPath = Path.GetFullPath("src/OrchidApp.Web") });
builder.WebHost.UseUrls("http://127.0.0.1:0");
builder.Services.AddRazorPages();
builder.Services.AddDataProtection().UseEphemeralDataProtectionProvider();
builder.Services.AddScoped(_ => new OrchidDbContext(new DbContextOptions<OrchidDbContext>()));
builder.Services.AddSingleton(PlatformFeatures.FromConfiguration(new ConfigurationBuilder().Build(), true, Architecture.Arm64));
await using var app = builder.Build();
app.MapRazorPages();
await app.StartAsync();
try
{
    var address = app.Services.GetRequiredService<IServer>().Features.Get<IServerAddressesFeature>()!.Addresses.Single();
    using var client = new HttpClient();
    var html = await client.GetStringAsync(address);
    Check("Home renders", html.Contains("Plants") && html.Contains("Setup"));
    Check("Monitoring scripts absent", !html.Contains("chart.umd.min.js") && !html.Contains("greenhouse-charts.js"));
    Check("Monitoring markup absent", !html.Contains("Environment - last 7 days"));
}
finally { await app.StopAsync(); }
Console.WriteLine($"{count} monitoring isolation checks passed.");
