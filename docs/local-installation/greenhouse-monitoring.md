# Owner local greenhouse monitoring

This bespoke functionality is only for the owner's local OrchidApp installation. It is not part of general developer setup or another user's install. It consumes local environmental readings and an externally maintained EnergyMonitoring schema. Do not provision those systems for general users.

## Activation boundary and prerequisites

Current source gates by Linux ARM/ARM64, which is too broad. [C03](../code-change-backlog.md#c03) must add explicit installation opt-in defaulting off; no such setting name is implemented yet. All summary/chart/net-cost paths and assets need that gate. Until corrected, other Linux ARM installs can query the bespoke objects unexpectedly.

For the owner's configured host, verify actual connections, compatible table/view definitions, effective sensor/device/location mappings, period rules, tariffs and available readings. OrchidApp consumes EnergyMonitoring; its production collector/provisioning source was not supplied in this repo. Obtain that contract from its owner rather than using disposable test fixtures as production setup.

The current account needs read access to OrchidApp environmentreading, environmentsensor, environmentperiodrule, environmenttargetrule and venvironmentreadingperiod, plus the summary's required mapped objects. EnergyMonitoring reads use TapoEnergyHourly, MonitoringDevice, MonitoringDeviceLocationHistory, GreenhouseTargetLocationMap, Tariff and EnphaseInterval. Check actual query permissions and exact case on the target MariaDB host.

Net-cost reporting additionally needs SELECT on the existing EnergyMonitoring.EnphaseInterval. The [grant companion](../grant-greenhouse-solar-read.sql) names localhost and 127.0.0.1 account identities; an administrator must select the applicable existing account(s), confirm the target and verify access. No grant is executed automatically by these docs, and no changes to the external collectors/schema are included. “No automatic grant changes” does not mean no deployment permission is required.

## Current display and calculations

The owner summary retains its reading-weighted eight-calendar-date logic using an explicit London date. Current target rule ambiguity can leave targets unavailable rather than hide the location. Charts for Cool side and Hot side contain exactly 168 elapsed hours ending yesterday at 22:00 Europe/London, exclusive (last hour starts at 21:00). Clock changes can shift the first local wall-clock hour. Temperature means use underlying sums/counts, configured day/night windows and effective assignments, not averages of hourly means. UTC energy hour starts stay distinct across clock changes; local temperature DATETIME cannot reconstruct repeated autumn hours reliably.

Hourly chart cost uses recorded heater energy and the applicable historical import tariff; it excludes standing charges and solar credits. Missing/ambiguous readings, mappings or tariffs produce gaps rather than invented measurements. Target segments follow configured periods, with the night assigned to its starting date. Labels and tooltips show values/periods; technical coverage counts, date headings and data listings are not presented. Internal diagnostics remain available.

The two combined boxes use seven complete London calendar days through yesterday, and 1 January through yesterday. Today is excluded. For each whole period, sum both assigned heaters' available kWh, subtract solar production once, and multiply the signed difference by yesterday's applicable import rate. Positive is Cost; negative is Saved, displayed as an absolute amount; zero is Cost £0.00. These are estimates at an agreed tariff, not actual grid spending or export income. There is no daily clamp or daily tariff weighting.

Missing/null readings are skipped without interpolation, extrapolation or a completeness threshold. True zeroes count. Negative readings are excluded. Both feeds absent can therefore yield a zero available-data total if a tariff exists; this does not establish complete measurement. Solar interval ends belong to the preceding hour/day. The old four-samples-per-hour threshold is superseded. Duplicate/ambiguous mappings/readings or missing/overlapping tariffs can leave a dash. Solar access failures do not invalidate the original charts; the summary query has its own dependencies.

## Cache and native/browser assets

GreenhouseCharts__Cache__Seconds controls the in-process cache: default 120, zero disables, values clamped to at most 900. Concurrent misses coalesce. Keys include database/range/locations; the London midnight range change switches the key. Restart clears cache. Thrown/cancelled loads are not stored, but normally returned domain-unavailable results can be cached until expiry. Late/corrected data may take the configured lifetime to appear. The original summary runs on each enabled request.

Chart.js 4.5.1 and @kurkle/color 0.3.2 are bundled locally with their notices. They are not fetched from a CDN at runtime. Check actual assets/licence packaging when updating dependencies.

## Developer validation

Run the isolated executable checks from the repo root:

```powershell
dotnet run --project tests/EnvironmentSummary.Checks/EnvironmentSummary.Checks.csproj
dotnet run --project tests/GreenhouseCharts.Checks/GreenhouseCharts.Checks.csproj
```

Optional integration requires an EMPTY disposable MariaDB instance bound to 127.0.0.1:33317. GREENHOUSE_TEST_CONNECTION selects it; fixture setup creates orchids and EnergyMonitoring and changes test data. Never aim at live data. GREENHOUSE_BENCHMARK=1 additionally enables the synthetic large-history benchmark. Clear both variables afterward. Follow source guards; a loopback port alone is not proof an instance is disposable.

Optional generated-data Razor preview:

```powershell
dotnet run --project tests/GreenhouseCharts.Checks -- --serve <absolute-path-to-src/OrchidApp.Web>
```

Open http://127.0.0.1:5318/. This does not bypass the production feature gate. Record actual commands, revision, runtime/database version, fixture state and outcomes. Check complete/incomplete feeds, zeros, duplicates, mapping/tariff conflicts, clock changes, calendar/year boundaries, cache invalidation and desktop/mobile presentation. Run physical-device checks where relevant. No tests, benchmark or device deployment were performed by this documentation change.

Recent stage-specific results and fixed delivery hashes remain in [history](../history/greenhouse-changes/index.md). They are not current acceptance counts, a production collector certificate or a Pi performance guarantee. The earlier guide and changes are superseded as operating instructions by this document. Relevant pending implementation/validation items are [C03 and C20](../code-change-backlog.md).
