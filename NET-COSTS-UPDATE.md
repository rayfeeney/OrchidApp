# OrchidApp net cost update

Apply the included source files at the OrchidApp repository root over the existing chart-performance update. Review the changes, rebuild/publish, stop OrchidApp, replace the deployed build, then start it again. The separate patch is an alternative to copying files.

As a MariaDB administrator, run docs/grant-greenhouse-solar-read.sql if the app accounts do not already have SELECT on EnergyMonitoring.EnphaseInterval. That is the only additional access required. No grants or changes have been applied to the user's database. No collectors, EnergyMonitoring code, tables, indexes or views are changed.

The two boxes appear above the location summaries. For each WHOLE period: (Cool heater kWh + Hot heater kWh - solar generation kWh) * yesterday's import tariff. A positive amount is Cost; a negative amount is Saved. Both are estimates at the same agreed tariff, not actual grid expenditure or export income. Solar is counted once and surpluses can offset heating on other days within the period. There is no daily shortfall/MAX calculation.

Last 7 days means seven complete London calendar days through yesterday. YTD means 1 January through yesterday. Today is excluded. The charts retain their existing 168-hour window ending with yesterday's 21:00 hour. Chart date headings and technical tooltip warnings/counts have been removed.

A dash means the period cannot be reliably calculated because of missing heater/solar readings, ambiguous assignments, or a missing/overlapping tariff. This does not assume missing data is zero. Production-meter coverage requires four valid 15-minute readings per real UTC hour, matching the existing collector. Late imports and corrections appear after the existing 120-second cache expires. Both periods are checked independently.

Verified: clean application build; 72 calculation/cache/MariaDB checks; 25 platform-gate checks; desktop and phone browser checks for the two boxes, no date heading, no technical tooltip messages and no horizontal overflow. Preview screenshots use generated example data.
