# Greenhouse home-page charts

## Scope and installation

This change adds two charts beneath the existing Cool side and Hot side summaries.
It includes no heating-cost totals, solar accounting, date selector or collector changes.

The accompanying updated-files archive contains only added/changed OrchidApp files.
Apply its paths at the OrchidApp repository root, review the diff, then build and deploy
using the existing process. No database migration or EnergyMonitoring modification is
required. Existing environment feature gating remains Linux ARM/ARM64 only; Windows
and Linux x64 do not query monitoring data or load Chart.js on the home page.

The current OrchidApp database connection must have SELECT access to:
- OrchidApp: environmentreading, environmentsensor, environmentperiodrule,
  environmenttargetrule and venvironmentreadingperiod.
- EnergyMonitoring: TapoEnergyHourly, MonitoringDevice,
  MonitoringDeviceLocationHistory, GreenhouseTargetLocationMap and Tariff.

Verify existing access before deployment. This change does not alter users or grants.
The cross-schema name EnergyMonitoring is the same name used by the supplied SQL.

Existing MonitoringDeviceLocationHistory and GreenhouseTargetLocationMap identify
which Tapo meter belongs to each target-rule location. There must be exactly one
unambiguous heater assignment per side per hour. The schema does not have a heater
role flag: additional Tapo meters mapped to the same side are reported as ambiguous,
rather than silently included. Location names must match Cool side / Hot side
(case insensitive), as in the requested summaries.

## Data definitions

- Boundaries are computed once per request from the Europe/London calendar:
  midnight seven days ago inclusive to tomorrow's midnight exclusive (eight dates).
  The printed date range makes this explicit while retaining the existing heading.
- Summary SQL retains the existing reading-weighted calculation but uses the same
  explicit London date as the charts, rather than depending on MariaDB CURDATE().
  Missing or overlapping current target rules leave summary targets unavailable,
  instead of hiding/duplicating an entire location card. No stored view is changed.
- Hourly temperatures average all underlying readings using the existing effective
  sensor assignments, including readings outside configured day/night periods.
- Period averages aggregate every row classified by venvironmentreadingperiod,
  weighted by reading count, rounded once to one decimal as in the daily view.
  They are not averages of hourly averages. A full period is fetched even when its
  displayed segment is clipped at the left/right chart boundary.
- Active effective-dated environmentperiodrule rows supply all period times.
  The end is exclusive. Night belongs to its starting date. Target location, month
  and effective date are matched against that starting date; a night spanning a
  month or rule-date boundary keeps that date's target.
- Each average and target is an independent horizontal line dataset. No target is
  inferred between configured windows. Overlapping configuration yields warnings.
- Tapo UTC hour starts are kept distinct across daylight-saving changes. Labels
  are prepared in C# with London dates and BST/GMT; there is no browser date parser,
  Luxon, time adapter or dependence on the browser's timezone.
- Cost = EnergyWh / 1000 * historical ImportRatePencePerKWh / 100. Tariff start and
  end dates are inclusive, matching EnergyMonitoring's existing hourly view.
  The date is the London date of the hour. No standing charges or solar credits.
  Current/future hour costs are withheld until the hour ends, matching the collector.
- Full-interval effective device history is checked. Assignment changes during an
  hour, conflicting mappings, missing/negative energy, and missing/overlapping or
  negative tariffs yield gaps, not fabricated zeroes. An observed zero stays zero.
- Temperature timestamps are local DATETIME values with no offset. Repeated autumn
  hours cannot be reconstructed reliably; ambiguous/invalid hourly temperatures
  are gaps with a notice. Period averages preserve the existing local reading logic.
- Period averages are explicitly provisional, with counts and detailed coverage
  status. Expected temperature sampling cadence is not configured, so no average
  is claimed complete. Ongoing/unobserved periods are also identified.
- Read/query errors leave the summaries available with a chart-unavailable message.
  Expandable tables provide the hourly values and per-period coverage without canvas.

## Frontend dependency

Chart.js 4.5.1 is pinned and bundled at wwwroot/lib/chartjs/chart.umd.min.js.
The official npm tarball was verified against its published SHA-512 integrity.
Bundled @kurkle/color is version 0.3.2. Both MIT licences are included in the static
folder and Legal/chartjs, and displayed on the application's Licences page.
No external chart assets are loaded at runtime.

## Verification

Run from the OrchidApp repository root:

    dotnet build src/OrchidApp.Web/OrchidApp.Web.csproj
    dotnet run --project tests/EnvironmentSummary.Checks
    dotnet run --project tests/GreenhouseCharts.Checks

The greenhouse check program has 28 deterministic calculation assertions. It covers
reading weighting, gaps, tariff/mapping conflicts, configurable windows, month
boundaries, full-night clipping and both daylight-saving transitions.

For integration verification use an EMPTY, disposable MariaDB instance bound to
127.0.0.1:33317. The test creates orchids and EnergyMonitoring databases, reproduces
the relevant supplied definitions and inserts deterministic fixtures. It must never
be pointed at a deployed database. Set GREENHOUSE_TEST_CONNECTION to its connection
string with Database=orchids, then run the greenhouse checks. Ten additional checks
exercise the real EF Core/MariaDB queries. Clear the variable afterwards.

An optional local preview renders the actual Razor chart partial with generated
readings (not production data):

    dotnet run --project tests/GreenhouseCharts.Checks -- --serve <absolute-path-to-src/OrchidApp.Web>

Open http://127.0.0.1:5318/. The preview does not bypass the production feature gate.

Verified in this workspace:
- .NET build succeeds; 25 existing platform checks pass.
- 28 calculation checks plus 10 integration checks pass on MariaDB 10.11.16.
- Headless browser renders two actual Razor partials at 1400px and 390px widths,
  with no horizontal page overflow, no browser errors, distinct period segments,
  both value axes and a working grouped legend toggle.
- Desktop and phone preview images use generated data, not live greenhouse readings.

The hosted application/database was not accessed or deployed. NuGet's vulnerability
feed was unavailable in the restricted build environment (NU1900); package restore
and compilation succeeded using available dependencies.

