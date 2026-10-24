# OrchidApp chart performance update

Apply these files at the OrchidApp repository root over the previous 168-hour chart update, review the diff, rebuild and deploy using your existing process. The accompanying patch is an alternative to copying the files. No database/index/permission changes or EnergyMonitoring changes are required.

The update moves temperature aggregation into MariaDB and directs both queries through the existing timestamp index. Period means retain their exact reading weighting. Prepared charts are cached for 120 seconds by default, with concurrent refreshes coalesced and a new key at London midnight. Configuration or late-reading corrections can take up to two minutes to appear. The original summary query still executes on each home-page request.

Program.cs has only three new registration lines for the cache; retain any other local changes in that file. Optional configuration: GreenhouseCharts__Cache__Seconds=120 (zero disables caching; maximum 900).

Verified: application build; 49 calculation, cache and MariaDB checks; 52 checks including the optional 1.14-million-history-row benchmark; 25 existing platform checks. The benchmark returned 336 hourly aggregates plus 29 period aggregates, with an uncached load of about 150 ms on the test machine. Warm cache hits executed no chart queries. Actual server timings may differ. See docs/greenhouse-charts.md and the synthetic query-plan report.

EnergyMonitoring and live databases were not modified. This package is source code, not a deployed build.
