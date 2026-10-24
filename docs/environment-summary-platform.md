# Bespoke monitoring installation boundary

Environmental summary, greenhouse charts, energy/solar costs and related importers are bespoke to the owner's one local installation. No other installation must need these data feeds, grants, database objects or settings. Do not enable them merely because a server is a Raspberry Pi.

## Current implementation versus requirement

PlatformFeatures currently enables the feature on Linux ARM/ARM64 and disables it on Windows, Linux x86/x64 and other hosts. The home handler returns before monitoring queries on an unsupported host; the browser OS is irrelevant. That host check does not identify the owner's installation and therefore does not satisfy the requirement.

[Code item C03](code-change-backlog.md#c03) requires an explicit installation-level opt-in, default off, applied to all summary/chart/net-cost paths and assets. The actual setting name is not implemented yet. Do not document a fictitious switch or provision the owner's feeds on general installs as a workaround. Until fixed, a general Linux ARM Home request can still attempt bespoke queries and fail; this is a known code limitation, not a general installation prerequisite.

The [owner's monitoring guide](local-installation/greenhouse-monitoring.md) defines local data/permission requirements separately. General schema creation remains governed by the [schema-only contract](database-creation.md), independent of external EnergyMonitoring data.

## Validate the fix

Existing tests/EnvironmentSummary.Checks exercise host architecture policy and unsupported-host query avoidance. Extend them for a default-off general Linux ARM installation with zero monitoring queries, explicit owner opt-in, supported/unsupported hosts and no Chart.js load when disabled. Validate the owner installation using isolated fixtures and then an approved device smoke check. Existing host tests do not prove installation isolation.
