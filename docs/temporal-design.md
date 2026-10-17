# Temporal design

This reference describes the temporal behaviour in the current v1.3.0 source,
reviewed against the canonical MariaDB schema, stored procedures and Razor Page
handlers. It distinguishes intended rules from checks the implementation actually
performs. It is a source review, not certification of a deployed database.

See [architecture](architecture.md) for component responsibilities and
[contribution guidance](../CONTRIBUTING.md) for migration and validation requirements.

## Model and terminology

OrchidApp records a correctable horticultural history rather than an immutable
event log. Observations, repotting and flowering are narrative records. Location
intervals, split boundaries and propagation origins carry structural relationships
and must be changed through the relevant workflows and procedures.

User input is generally a calendar date. Stored values also contain a time used
for ordering and boundary checks. Those times often represent the time of entry,
not a measured time at which a historical event occurred. Do not present them as
precise historical observations.

### Storage and clocks

The following fields currently use MariaDB `DATETIME` without declared fractional
second precision:

| Domain | Fields | Nullability |
| --- | --- | --- |
| Plant lifecycle | `plant.acquisitionDate`, `plant.endDate` | Both nullable |
| Observation | `plantevent.eventDateTime` | Required |
| Repotting | `repotting.repotDate` | Required |
| Flowering | `flowering.startDate`, `flowering.endDate` | Start required, end nullable |
| Location | `plantlocationhistory.startDateTime`, `endDateTime` | Start required, end nullable |
| Split | `plantsplit.splitDateTime` | Required |
| Propagation | `plantpropagation.propagationDateTime` | Required |

Names ending in `Date` do not imply a SQL DATE column. Repotting and flowering
have already moved to DATETIME; this is not a future schema transition.

Page handlers use the web server's `DateTime.Now`/`Today`; procedures use database
`NOW()`, `CURRENT_TIME` or `CURRENT_DATE`. These are local wall-clock values, with
no stored timezone/offset or common UTC conversion policy. Hosts must have aligned
clocks and timezone configuration. Daylight-saving transitions, clock changes and
different server timezones can affect ordering; the current model does not resolve
those ambiguities. Infrastructure timestamps such as migration/backup diagnostics
are separate from horticultural event dates.

## Date-to-time assignment

| Workflow | Creation | Editing |
| --- | --- | --- |
| Normal plant acquisition | `spAddPlant` combines the supplied date with database current time; unknown date stays NULL | `spUpdatePlantDetails` keeps the existing time when present, otherwise assigns database current time |
| Manual plant end | Procedure assigns database current time when first setting an end date | Existing end time is preserved when changing the date; clearing the value is supported by the procedure, subject to split rules |
| Observation | Event Add combines selected date with web-server current hour/minute/second; the Photos page uses current server time | Event Edit preserves the previous time-of-day |
| Repotting | Event Add combines selected date with web-server current hour/minute/second | Event Edit preserves the previous time-of-day |
| Flowering | Event Add combines selected start/end dates with current server hour/minute/second | Event Edit assigns current server time again to both supplied dates; it does not preserve the original time |
| Location move | `spMovePlantToLocation` combines the selected date with database current time | Event Edit passes `EventDate.Date` to `spEditPlantLocation`, replacing the start time with midnight |
| Split | Page handler combines selected date with current server hour/minute, setting seconds to zero | No general split-edit workflow |
| Propagation | Procedure combines selected date with database current time | No general propagation-edit workflow |

The location procedure accepts a full DATETIME, but its current caller supplies
date-only midnight. The Split property is named `SplitDateTime`, but the form is
date-only and the handler assigns the time. Do not infer UI capabilities from
parameter or property names.

## Ordering and same-day events

Plant Details reads `vplantlifecyclehistory`, ordering by `EventDateTime` descending
and then `SourceId` descending. The view combines active Observation, Repotting,
Flowering and LocationChange records for active plant records. Separate lineage
views/workflows represent split and propagation relationships.

There is no universal insertion-order guarantee for events on the same day:

- DATETIME values can collide within a second; split times have minute precision.
- Source IDs are table-local, so different event types can have equal timestamps
  and equal IDs. The current sort is not a total order across those ties.
- Changing a calendar date changes placement in the history. Flowering edits
  also replace the time and can reorder same-day records; location edits reset it.
- Preserving time in Observation and Repotting edits does not make all event
  ordering immutable.

No user-controlled sequence field or explicit same-day reorder tool is implemented.
Any future ordering guarantee needs an explicit cross-domain tie-breaking policy
and meaningful tests, not only DATETIME storage.

## Plant lifecycle

`acquisitionDate` identifies entry to the collection and can be unknown.
`endDate` identifies lifecycle closure; NULL means no recorded end. `isActive`
controls record inclusion/soft deletion separately. An ended plant can remain an
active record and appear in Details/history.

### Creation and editing

`spAddPlant` rejects future acquisition calendar dates. `spUpdatePlantDetails`
rejects future acquisition/end dates and, when both are supplied, requires the
end calendar date to be strictly after the acquisition calendar date. This manual
edit rule differs from split, which checks exact timestamps and can create a
same-calendar-day boundary when the resulting timestamp is valid.

The update procedure checks split lineage before allowing changes to the calendar
date of a split child's acquisition or split parent's end. It preserves the
existing time for an unchanged or edited non-null date. This protects boundaries
through that procedure; it is not a universal immutable-column constraint.
Propagation-child acquisition dates do not receive the same lineage-specific
protection in this procedure.

The plant Edit POST rejects a plant whose existing end date is non-null. Thus the
procedure's ability to clear an end date does not establish a working reactivation
workflow in the current Edit page. Do not promise users general reactivation.

### Closure and known schema mismatch

When first setting an end date, `spUpdatePlantDetails` attempts to close open
location and flowering intervals. It currently refers to `flowering.endDateTime`,
but the table defines `flowering.endDate`. This is a source defect that can make
manual lifecycle closure fail. The procedure has no explicit transaction/rollback
handler around the plant update and subsequent closure statements, so callers
must not assume the whole operation rolls back together on failure.

Do not describe manual closure as a proven cascade to all affected records.
The procedure also does not comprehensively validate existing narrative history
against revised lifecycle dates. Clearing an end date does not automatically
reopen old location rows or create a new location assignment.

## Narrative events

### Observations

Event Add/Edit checks calendar dates against today and the plant's known
acquisition/end dates, then writes through EF Core. Same-calendar-day events can
still lie outside exact lifecycle timestamps because these checks compare dates.
The Photos page creates an Observation at current server time through a separate
handler; do not assume it shares every Event Add validation.

### Repotting

Repotting records cultivation history without itself ending a lifecycle. Event
Add validates future/acquisition/end calendar boundaries and assigns a time.
Event Edit preserves the existing time but its Repotting branch does not repeat
those date-boundary validations before saving. Therefore uniform lifecycle-date
validation across Add/Edit is a requirement to address, not an existing guarantee.

Split and propagation procedures can also create an initial repotting record
when a growth medium is supplied. That record uses the structural operation's
timestamp. This behaviour is already implemented.

### Flowering

Flowering is an interval with a required start and optional end. A NULL end
indicates an open flowering period. Add/Edit handlers validate calendar dates,
start/end relationships and conflicts with other active flowering periods before
writing through EF Core. They use date-level overlap comparisons; do not infer
full timestamp interval semantics or database-wide overlap enforcement from them.

Add and Edit both assign current server time to supplied dates. The previous
document's promise that all narrative edits preserve the original time was
incorrect for flowering.

### Removal and enforcement limits

Event Remove soft-deletes narrative records by changing `isActive`; location
removal calls its structural procedure. This preserves rows rather than physically
erasing event history. Each workflow's lifecycle/taxonomy checks must be assessed
separately. There is no common database constraint enforcing all narrative date
boundaries or an identical ended-plant restriction across every handler.

## Location timeline

An active location row has a required start and optional end. NULL end identifies
the current location. The table checks that any end is strictly later than its
start. Insert/update triggers reject a second active open location row. These
checks do not themselves enforce every historical overlap or lifecycle boundary.

- **Move:** the procedure rejects the current location as a destination, checks
  against existing timeline points/overlaps, closes the current interval and
  inserts a new open interval. Date validation against the plant is also performed
  in the page handler. The procedure does not independently implement every one
  of those lifecycle checks.
- **Edit:** the procedure validates the new start against its effective end,
  previous start and next start, and adjusts a matching previous interval's end.
  It permits controlled boundary changes; structural timestamps are not all
  immutable. The current page supplies midnight rather than preserving the time.
- **Remove:** the procedure soft-deletes a row and stitches matching neighbours.
  Removing a current row can reopen a matching previous interval; removing an
  interior historical row can extend a matching previous row to the removed end.
  Missing neighbours are not automatically reconstructed.

The procedures use transactions for their multi-row operations, but the current
definitions do not include explicit exception rollback handlers. Do not claim
that all failure and concurrency cases are proven atomic merely because they use
`START TRANSACTION`/`COMMIT`. Validate rollback and locking behaviour under the
actual connection/transaction lifecycle.

## Split

`spSplitPlant` closes the parent and creates at least two children, retaining
taxonomy and recording `plantsplit`/`plantsplitchild` lineage. It validates the
parent state, taxonomy, date and prior split, and aligns:

```text
parent.endDate = child.acquisitionDate = plantsplit.splitDateTime
```

It closes active open parent location and flowering intervals at the split
timestamp. Children do not inherit a location. When a child's medium is supplied,
the procedure creates its initial repotting record at that same timestamp.

The unique parent key prevents multiple split records for a parent. No general
UI edit or reversal exists. The procedure uses a transaction but has no explicit
SQL exception rollback handler, so failure behaviour needs integration validation.
It does not comprehensively reject or repair every pre-existing narrative event
after a backdated split. Do not claim that splitting automatically makes all
historical data fit the new boundary.

## Propagation

`spPropagatePlant` leaves the parent lifecycle open and creates a new child with
acquisition time equal to `propagationDateTime`. The selected date is combined
with database current time. It validates parent/taxonomy state, future dates and
the parent acquisition boundary, and can create an initial medium/repotting record.

Each child has one propagation origin enforced by its unique child key; a parent
can have multiple propagated children. Children do not automatically receive a
location. There is no general edit/reversal workflow. As with split, transaction
statements alone do not establish complete error rollback coverage.

## Requirements for future changes

Keep narrative correction available without bypassing structural procedures.
Preserve lineage alignment and consistent location intervals. For any temporal
change, review calendar comparisons versus exact timestamps, unknown dates,
same-day boundaries, ended plants, neighbouring intervals and timezone assumptions.

The following need explicit implementation and tests before becoming guarantees:

- Reliable manual lifecycle closure with the correct flowering column and atomic
  failure handling.
- Consistent lifecycle/date validation across all narrative and photo handlers.
- A deliberate policy for preserving or replacing times on edits.
- A deterministic cross-domain history tie-breaker if strict ordering is required.
- Transaction rollback/concurrency behaviour for structural procedures.
- A supported reactivation workflow and protection of propagation origin dates.

Do not edit generated schema files to repair these issues. Use new migrations and
the normal export process for database changes.

## Source references and validation

Primary references are `database/schema/tables/`, `database/schema/routines/`,
`database/schema/triggers/`, `database/schema/views/vplantlifecyclehistory.sql`,
`src/OrchidApp.Web/Pages/Plants/Events/Add.cshtml.cs`,
`src/OrchidApp.Web/Pages/Plants/Events/Edit.cshtml.cs`,
`src/OrchidApp.Web/Pages/Plants/Events/Remove.cshtml.cs`,
`src/OrchidApp.Web/Pages/Plants/Events/Split.cshtml.cs`,
`src/OrchidApp.Web/Pages/Plants/Events/Propagate.cshtml.cs`,
`src/OrchidApp.Web/Pages/Plants/Edit/Index.cshtml.cs` and the plant Photos handler.

The current feature checks and CI schema rebuild do not establish all temporal
workflow guarantees. Validate changes in an isolated MariaDB environment with
save/reopen, invalid-input, rollback and concurrent-update cases. Include equal
timestamps, lifecycle boundary days, backdated splits, flowering edits, location
edits/removal and failed multi-step operations. Never use production data for
destructive validation.
