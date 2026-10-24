# Greenhouse home-page charts

## Whole-period Cost / Saved boxes

Two combined greenhouse boxes sit above the location cards, alongside the
Environment heading. One covers the last seven complete Europe/London calendar
days; the other covers 1 January through yesterday. Today is excluded. These
calendar-day ranges are independent of the charts' existing 22:00-to-22:00 window.

For EACH entire period, sum both heaters' kWh, subtract solar production once,
then multiply that signed energy difference by the import tariff applicable
yesterday (pence/kWh divided by 100). Positive results show Cost; negative results
show Saved with an absolute amount. Zero shows Cost £0.00. Amounts are estimates,
not actual grid expenditure or export income. There is no daily MAX/shortfall,
no daily clamp, and no daily tariff weighting. Surplus generation on one day can
offset heating on any other day in the same reporting period. Historical tariffs
on the hourly chart remain unchanged.

Production is read from the existing EnergyMonitoring.EnphaseInterval table.
The current collector calls telemetry/production_meter, whose default interval
is 15 minutes ([Enphase API FAQ](https://developer-v4.enphase.com/docs/faq)). Totals
sum the recorded production values without requiring a particular sample count.
Interval ends belong to the preceding hour/day. NULL production values and absent
intervals are skipped. Genuine zero readings are included. London boundaries
handle 23-hour and 25-hour days; no MariaDB timezone tables are needed.

Each period uses the available readings for the two assigned heaters and solar
production. Missing/null readings are ignored; zero values are valid. Gaps are
not interpolated or extrapolated, and there is no completeness threshold. Both
feeds absent means recorded totals of zero, provided a tariff is available.
Negative values are excluded. A missing/ambiguous tariff, conflicting mappings,
duplicate readings or database access failures can still leave a dash. Internal
diagnostics remain available without coverage warnings in the chart. Both boxes use the existing 120-second cache configuration. A solar
read failure leaves the original charts working independently.

The date range above each chart and the reading-count/provisional messages in
chart tooltips are removed. Tooltips show values and the period only. The cost
boxes retain the small word Estimated to describe what their amounts represent.

### Additional read permission

No EnergyMonitoring code, collectors, tables, views or indexes are changed.
The app account does need SELECT on the existing solar table. As a database
administrator, grant it to the applicable existing OrchidApp accounts:

    GRANT SELECT ON EnergyMonitoring.EnphaseInterval
    TO 'orchidapp'@'localhost', 'orchidapp'@'127.0.0.1';

This statement is also supplied as docs/grant-greenhouse-solar-read.sql. It has
not been executed against the user's database. All other grants are unchanged.

Current verification: 61 calculation/cache checks without a database, 79 including
MariaDB integration, 25 existing platform checks, successful application build,
and desktop/phone rendering checks for both boxes and the simplified tooltips.
Generated solar/heater fixtures were rolled back; live data was not accessed.

## Performance update

Chart temperature aggregation now runs in MariaDB. The hourly query returns one
row per location/hour, and the period query returns exact temperature sums and
reading counts per location/period/date. Period means are calculated from those
sums/counts and rounded once; no averaging of hourly means is introduced.

Both queries start with a bounded range scan using the existing
ixEnvironmentReading_ReadingDateTime index. The period query drives the unchanged
venvironmentreadingperiod view by the bounded reading IDs. This prevents an
unfavourable sensor-first plan from walking the entire sensor history. Existing
mapping/rule conflicts are still detected before the requested locations are
filtered. No index, stored view, schema, permission or EnergyMonitoring changes.

Prepared charts have a shared in-process cache, default 120 seconds. Concurrent
misses coalesce into one refresh. Successful results only are cached; failures and
cancelled loads are not cached. Cache keys include database identity, locations
and the exact chart range, so London midnight immediately switches to a new key.
Late imports and configuration/tariff corrections appear after at most the cache
lifetime. Restarting OrchidApp clears this in-process cache.

Optional configuration (defaults require no appsettings change):

    "GreenhouseCharts": { "Cache": { "Seconds": 120 } }

The equivalent environment setting is GreenhouseCharts__Cache__Seconds. Zero
disables caching for diagnostics; the maximum accepted lifetime is 900 seconds.
The original summary query still runs on each request, as it did before charts.

Verified on isolated MariaDB 10.11.16: 1,140,000 generated older readings for the
same sensors plus 20,160 recent minute readings. EXPLAIN confirmed timestamp-index
range access for both aggregate queries, followed by primary-key lookup into the
classification view. The queries returned 336 hourly rows and 29 period rows.
The uncached chart load took approximately 150 ms on this test machine. This is
not a timing guarantee for the deployed Raspberry Pi. A cache hit issued zero
chart database commands. The generated readings were rolled back afterwards.

Verification at the performance-only stage: 36 calculation/cache checks without a database; 49 checks including
MariaDB integration; 52 with the optional million-row benchmark. All pass, along
with the 25 existing platform-gate checks. The application builds successfully.
To reproduce the optional benchmark, set GREENHOUSE_BENCHMARK=1 along with the
disposable GREENHOUSE_TEST_CONNECTION described below. Never target a live DB.

## Latest chart presentation update

The charts now contain exactly 168 elapsed hours, ending after yesterday's
21:00–22:00 Europe/London hour (22:00 exclusive). For a request on 23 October
2026 the first hour starts 15 October at 22:00 and the last starts 22 October
at 21:00. Across a clock change, 168 hours is retained; the first London wall-clock
hour may shift. Existing summary calculations retain their previous boundaries.

Legend labels are Average (°C), Actual temperature (°C), Target (°C), and Cost (£).
Descriptive text and expandable data tables have been removed. Full period values
remain in tooltips; technical coverage messages and the date-range heading are removed. Only a rendering failure shows a message
beneath a chart.

## Scope and installation

This change adds two charts beneath the existing Cool side and Hot side summaries.
It also includes the combined whole-period Cost / Saved boxes described above. No date selector or collector changes are included.

The accompanying updated-files archive contains only added/changed OrchidApp files.
Apply its paths at the OrchidApp repository root, review the diff, then build and deploy
using the existing process. No database migration or EnergyMonitoring modification is
required. Existing environment feature gating remains Linux ARM/ARM64 only; Windows
and Linux x64 do not query monitoring data or load Chart.js on the home page.

The current OrchidApp database connection must have SELECT access to:
- OrchidApp: environmentreading, environmentsensor, environmentperiodrule,
  environmenttargetrule and venvironmentreadingperiod.
- EnergyMonitoring: TapoEnergyHourly, MonitoringDevice,
  MonitoringDeviceLocationHistory, GreenhouseTargetLocationMap, Tariff and EnphaseInterval.

Verify existing access before deployment. This change does not alter users or grants.
The cross-schema name EnergyMonitoring is the same name used by the supplied SQL.

Existing MonitoringDeviceLocationHistory and GreenhouseTargetLocationMap identify
which Tapo meter belongs to each target-rule location. There must be exactly one
unambiguous heater assignment per side per hour. The schema does not have a heater
role flag: additional Tapo meters mapped to the same side are reported as ambiguous,
rather than silently included. Location names must match Cool side / Hot side
(case insensitive), as in the requested summaries.

## Data definitions

- Chart boundaries use yesterday at 22:00 Europe/London, exclusive, and a start
  exactly 168 elapsed hours earlier. No date-range heading is displayed. Summary boundaries remain the existing eight calendar dates.
- Summary SQL retains the existing reading-weighted calculation but uses the same
  explicit London current date, rather than depending on MariaDB CURDATE().
  Missing or overlapping current target rules leave summary targets unavailable,
  instead of hiding/duplicating an entire location card. No stored view is changed.
- Hourly temperatures average all underlying readings in MariaDB using the existing
  effective sensor assignments, including readings outside day/night periods.
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
  Only the completed historical hours in the chart window are displayed.
- Full-interval effective device history is checked. Assignment changes during an
  hour, conflicting mappings, missing/negative energy, and missing/overlapping or
  negative tariffs yield gaps, not fabricated zeroes. An observed zero stays zero.
- Temperature timestamps are local DATETIME values with no offset. Repeated autumn
  hours cannot be reconstructed reliably; ambiguous/invalid hourly temperatures
  are gaps with a notice. Period averages preserve the existing local reading logic.
- Period averages retain internal provisional status, reading counts and coverage
  diagnostics. Expected temperature sampling cadence is not configured, so no average
  is claimed complete. Ongoing/unobserved periods are also identified.
- Read/query errors leave the summaries available with a chart-unavailable message.
  Technical coverage messages and data listings are omitted from the end-user UI.

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

The greenhouse check program has 28 deterministic calculation assertions plus eight cache checks. It covers
reading weighting, gaps, tariff/mapping conflicts, configurable windows, month
boundaries, full-night clipping and both daylight-saving transitions.

For integration verification use an EMPTY, disposable MariaDB instance bound to
127.0.0.1:33317. The test creates orchids and EnergyMonitoring databases, reproduces
the relevant supplied definitions and inserts deterministic fixtures. It must never
be pointed at a deployed database. Set GREENHOUSE_TEST_CONNECTION to its connection
string with Database=orchids, then run the greenhouse checks. Thirteen additional checks
exercise the real EF Core/MariaDB queries and cached data-loading path. Clear the variable afterwards.

An optional local preview renders the actual Razor chart partial with generated
readings (not production data):

    dotnet run --project tests/GreenhouseCharts.Checks -- --serve <absolute-path-to-src/OrchidApp.Web>

Open http://127.0.0.1:5318/. The preview does not bypass the production feature gate.

Verified in this workspace:
- .NET build succeeds; 25 existing platform checks pass.
- 28 calculation checks, eight cache checks and thirteen integration checks pass on MariaDB 10.11.16; three additional benchmark checks also pass.
- Headless browser renders two actual Razor partials at 1400px and 390px widths,
  with no horizontal page overflow, no browser errors, distinct period segments,
  both value axes and a working grouped legend toggle.
- Desktop and phone preview images use generated data, not live greenhouse readings.

The hosted application/database was not accessed or deployed. NuGet's vulnerability
feed was unavailable in the restricted build environment (NU1900); package restore
and compilation succeeded using available dependencies.

