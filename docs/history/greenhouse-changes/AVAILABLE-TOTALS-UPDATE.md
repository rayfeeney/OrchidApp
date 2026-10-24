# Totals from available readings

Apply the three included files over the previous net-cost update at the OrchidApp repository root. Rebuild/publish and restart the deployed app using the existing process. Only GreenhouseNetCostService.cs is a production code change; the other files are tests and documentation.

Missing or NULL heater/solar readings are ignored. Recorded zeroes remain valid. No minimum count per hour, full-day coverage, or full-period coverage is required. Available readings are summed directly; gaps are not filled. The whole-period difference is still valued at yesterday's tariff, with Cost or Saved labels. Both feeds absent sums to zero when the tariff is available.

Tariff conflicts, duplicate/ambiguous data or query/permission failures remain distinct from missing readings. Those can still leave a dash. The existing short cache and all other display/calculation settings are unchanged.

Verified: application build, 79 calculation/cache/MariaDB checks and 25 platform checks. Tests include incomplete solar hours, NULL production, missing heater hours, true zeroes and fully absent feeds. No database changes, additional grants or EnergyMonitoring changes are required.
