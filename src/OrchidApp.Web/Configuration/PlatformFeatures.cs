using System.Runtime.InteropServices;

namespace OrchidApp.Web.Configuration;

public static class PlatformFeatures
{
    // Check the server hosting OrchidApp, not the browser accessing it.
    // Environmental monitoring belongs to the Linux ARM Raspberry Pi deployment.
    public static bool EnvironmentSummaryEnabled => SupportsEnvironmentSummary(
        OperatingSystem.IsLinux(), RuntimeInformation.OSArchitecture);

    public static bool SupportsEnvironmentSummary(bool isLinux, Architecture osArchitecture) =>
        isLinux && (osArchitecture is Architecture.Arm or Architecture.Arm64);
}
