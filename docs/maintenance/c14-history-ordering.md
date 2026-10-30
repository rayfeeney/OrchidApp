# C14 history ordering

> Status reconciliation, 30 October 2026: this article preserves the original implementation/test record. Its earlier next-step, merge and CI-pending statements describe that delivery stage. See [current status and scope](../current-state.md) for confirmed later CI, the remaining machine acceptance, and the v1.4.0 Windows baseline decision. Original results and limitations below are retained.

The agreed display order is newest stored date/time first. When those values
match, the event type decides the order: Flowering, LocationChange (shown as Move),
Observation, Repotting. Records within the same timestamp and type use descending
record ID. Event type takes precedence over cross-table record IDs.

## Implementation

The Details page already selects `vplantlifecyclehistory` through EF Core. Its
outer query now applies `EventDateTime DESC, EventType ASC, SourceId DESC`.
The four current event types map to separate source tables, each with a unique
primary key, making that tuple unique for the visible events. No insertion-order
or union/view scan-order assumption is needed.

The view itself has no display-order contract for arbitrary callers. Adding an
ORDER BY inside a view would not replace the outer page query's responsibility.
The current view/model already expose all required fields, so no SQL migration,
schema/checksum/bootstrap export or historical data change is needed. All existing
database assets remain byte-for-byte unchanged.

Date corrections can move a card. Existing correction handlers retain its time
of day; changing the date back to a tied timestamp restores its type/ID position.
Records on the same date with different times still sort by time before type.
This behavior applies to ended/read-only history as well as unended plants.
Inactive records and other plants remain excluded by the existing view/query.

This is stable display, not measured event chronology or insertion order.
DATETIME stores no timezone offset or daylight-saving fold. Equal stored values
from a repeated clock hour use the same type/ID tie-breakers. C14 does not infer
UTC order, reinterpret dates, rewrite timestamps or introduce manual reordering.
The existing [temporal policy](../temporal-design.md#ordering-and-same-day-events)
and clock limitations apply.

## Upgrade actions for Windows and Linux

Deploy the updated app. C14 adds no migration, settings/default change, historical
conversion or special database-update command on either platform. Preserve the
already required C13 app/procedure pairing and normal backup/upgrade process.
The [upgrade checklist](../upgrade-checklist.md) records both platform actions.

Use disposable history to verify tied cards appear as Flowering, Move,
Observation, Repotting; confirm refresh retains their order and correcting an
unended observation date repositions it. Do not alter valuable historical records
to construct test ties. Installed Desktop/Linux/Pi UI acceptance remains pending.

## Validation

`tests/LifecycleClosure.Checks/HistoryOrdering.Checks.py` is part of the existing
disposable lifecycle runner and Linux CI job:

```powershell
pwsh ./tests/LifecycleClosure.Checks/Database.Checks.ps1
```

The runner requires explicit credentials for a separate disposable MariaDB
server, Python 3 and .NET 8. It restores genuine preceding procedure definitions
for the upgrade fixture, applies the existing migration package, then also tests
a fresh database created from schema/seeds alone without migration replay. It
starts only a loopback Release host and drops its generated fixture databases.
The C13 cache-aware revision remains `c13-lock-cache-v3`; the new ordering suite
also prints `c14-event-type-v1`.

The ten C14 scenarios test the rendered Details HTML through the actual EF/MariaDB
query, rather than duplicating the sort in Python:

- Equal timestamps and equal IDs across all four source tables.
- Type precedence even when a different type has a higher ID.
- Newer timestamps and different times on the same date preceding type order.
- Descending IDs within a tied event type.
- Stable repeated reads with unchanged scoped database rows.
- Real HTTP date correction, restored tie position and preserved time of day.
- Repeated local clock-hour values, without timestamp conversion or mutation.
- The same order for ended history; inactive and other-plant rows excluded.

Local native Windows MariaDB 10.11.16 and actual Release HTTP results are recorded
in the delivery: ten C14 scenarios on each upgraded/fresh fixture, alongside
16 closure, 16 C12 and 23 C13 scenarios per fixture, 130 executions in total.
Release build, workflow/PowerShell syntax, Python syntax and documentation links
are checked. Previous unrelated creation/migration-policy results remain prior
evidence and are not presented as newly rerun.

Both platform plant-management guides state the new history rule. All 44 embedded
media files are preserved; no action/form layout or screenshot was changed.
Both guides remain 17 pages, with the changed bullet on page 5. All 34 rendered
pages are visually checked before delivery. The architecture, temporal reference,
backlog, documentation index/map, release notes, contributor checks and platform
upgrade checklist are updated together.

Linux CI and installed-machine acceptance remain pending. No owner's `.env`,
collection/development database or live photos were used or changed.
