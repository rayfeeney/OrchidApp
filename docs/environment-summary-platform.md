# Bespoke monitoring installation boundary

Monitoring:Enabled defaults false, including when absent from older configuration. Explicit true additionally requires a Linux ARM/ARM64 server. Home skips all monitoring queries and omits monitoring markup and Chart.js/greenhouse script references when disabled. Browser architecture is irrelevant.

Only on the owner host, set Monitoring__Enabled=true in the private service environment and restart. Preserve that private service setting across application upgrades, outside replaceable application files. General installations leave it absent or false. No importer, grant or external schema is installed by this switch.

Cache registration performs no queries. Static assets remain public files, but disabled Home does not request them.

See the [owner guide](local-installation/greenhouse-monitoring.md), [schema creation contract](database-creation.md) and [C03 evidence](maintenance/c03-monitoring-isolation.md).
