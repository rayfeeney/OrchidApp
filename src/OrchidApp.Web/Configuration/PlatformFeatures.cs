using System.Runtime.InteropServices;
using Microsoft.Extensions.Configuration;

namespace OrchidApp.Web.Configuration;

// Immutable installation policy, resolved once from the host configuration.
public sealed record PlatformFeatures(bool EnvironmentSummaryEnabled)
{
    public static PlatformFeatures FromConfiguration(IConfiguration configuration,
        bool isLinux, Architecture osArchitecture) => new(
            configuration.GetValue<bool>("Monitoring:Enabled") &&
            SupportsEnvironmentSummary(isLinux, osArchitecture));

    public static bool SupportsEnvironmentSummary(bool isLinux, Architecture osArchitecture) =>
        isLinux && (osArchitecture is Architecture.Arm or Architecture.Arm64);
}
