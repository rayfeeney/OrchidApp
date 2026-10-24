# C03 - Monitoring isolation

Delivery date: 24 October 2026. Changes only, relative to OrchidApp-documentation-updated.zip.

## Apply this ZIP

1. Close any source editors/builds that could overwrite these files. Keep a copy of your current repository or commit your current work.
2. Open the ZIP and extract its contents directly into the repository root: the folder containing OrchidApp.sln. The ZIP has no enclosing OrchidApp folder.
3. Allow replacement of the 15 modified files below. One source documentation file is new. If you have independently edited any listed file since the documentation baseline, merge those edits before replacing it.
4. CHANGELOG.md is this delivery manifest; it is additional to the 16 repository changes.
5. No files require deletion or moving. No SQL, database schema or migration changes are included.

## Behaviour and configuration

Monitoring:Enabled defaults false, including when absent. Explicit true additionally requires a Linux ARM/ARM64 server. Disabled Home skips monitoring queries and omits monitoring markup/scripts.

For the owner installation, preserve Monitoring__Enabled=true in private service configuration outside replaceable application files, then restart. Other installations leave it absent or false. This ZIP does not change the live service or install external feeds, grants or importers.

## Files

| Status | Repository path | Change |
| --- | --- | --- |
| Modified | `CONTRIBUTING.md` | Updates contributor guidance for default-off monitoring. |
| Modified | `RELEASE_NOTES.md` | Records the C03 behaviour change and pending device acceptance. |
| Modified | `docs/architecture.md` | Documents the installation policy and Home query guard. |
| Modified | `docs/code-change-backlog.md` | Records the agreed six-phase order and C03 local implementation status. |
| Modified | `docs/development-setup.md` | Removes the obsolete monitoring blocker; general development leaves monitoring off. |
| Modified | `docs/environment-summary-platform.md` | Defines the setting, supported hosts, activation and upgrade preservation. |
| Modified | `docs/index.md` | Updates the monitoring documentation entry. |
| Modified | `docs/local-installation/greenhouse-monitoring.md` | Explains private owner opt-in and service restart. |
| Added | `docs/maintenance/c03-monitoring-isolation.md` | Adds the implementation report, validation evidence and remaining device acceptance. |
| Modified | `docs/user-guides/linux/OrchidApp-MariaDB-Backup-and-Restore-Runbook.md` | Updates owner monitoring activation wording. |
| Modified | `docs/user-guides/linux/installation-upgrade.md` | Updates general Linux installation guidance for default-off monitoring. |
| Modified | `src/OrchidApp.Web/Configuration/PlatformFeatures.cs` | Resolves explicit installation opt-in combined with Linux ARM/ARM64 compatibility. |
| Modified | `src/OrchidApp.Web/Pages/Index.cshtml.cs` | Injects the policy and skips summary, chart and net-cost queries when disabled. |
| Modified | `src/OrchidApp.Web/Program.cs` | Registers the resolved installation policy at startup. |
| Modified | `src/OrchidApp.Web/appsettings.json` | Adds Monitoring:Enabled with a false default. |
| Modified | `tests/EnvironmentSummary.Checks/Program.cs` | Adds configuration/host checks, providerless query avoidance, override precedence and actual Home rendering checks. |

## Validation already completed

- 163 monitoring isolation checks passed, including compiled Home rendering with a simulated general Linux ARM64 policy and no database provider.
- 61 greenhouse calculation checks passed.
- The build used by these checks succeeded. NuGet vulnerability lookup was unavailable (NU1900).
- Repackaging validation: archive file list and file contents checked against the full C03 delivery; extraction paths are relative to the repository root.

## Still pending

Owner Raspberry Pi acceptance: verify private opt-in, live summaries/charts/net costs, restart and preservation of the service setting through an application upgrade. Host combinations and configuration precedence were tested locally; actual installed upgrade behaviour has not been verified. C03 remains pending that acceptance.

## Optional local verification

Run from the repository root:

```powershell
dotnet run --configuration Release --project tests/EnvironmentSummary.Checks/EnvironmentSummary.Checks.csproj
dotnet run --configuration Release --project tests/GreenhouseCharts.Checks/GreenhouseCharts.Checks.csproj
```
