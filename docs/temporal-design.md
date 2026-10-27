# Temporal design

This reference describes the temporal behaviour in the current v1.3.0 source,
reviewed against the canonical MariaDB schema, stored procedures and Razor Page
handlers. It distinguishes intended rules from checks the implementation actually
performs. It is a source review, not certification of a deployed database.

See [architecture](architecture.md) for component responsibilities and
[contribution guidance](../CONTRIBUTING.md) for migration and validation requirements.

## Model and terminology

OrchidApp permits corrections while a plant has not ended. Once ended, its
details, events, photos and lifecycle dates are read-only; its history and
photographs remain viewable. There is no normal reactivation workflow. Observations, repotting and flowering are narrative records. Location
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
| Manual plant end | Procedure assigns database current time when first setting an end date | Ended plants cannot have their end date changed or cleared |
| Observation | Event Add combines selected date with web-server current hour/minute/second; the Photos page uses current server time | Event Edit preserves the previous time-of-day |
| Repotting | Event Add combines selected date with web-server current hour/minute/second | Event Edit preserves the previous time-of-day |
| Flowering | Event Add combines selected start/end dates with current server hour/minute/second | Event Edit preserves existing start/end times; a newly supplied end uses the start time on the same day, otherwise current time |
| Location move | `spMovePlantToLocation` combines the selected date with database current time | Event Edit combines the corrected date with the existing start time before calling spEditPlantLocation |
| Split | Page handler combines selected date with current server hour/minute, setting seconds to zero | No general split-edit workflow |
| Propagation | Procedure combines selected date with database current time | No general propagation-edit workflow |

Location corrections preserve the existing time rather than resetting it to
midnight. The Split property is named `SplitDateTime`, but the form is date-only
and the handler assigns the time. Do not infer UI capabilities from
parameter or property names.

## Ordering and same-day events

Plant Details reads `vplantlifecyclehistory` and explicitly orders the result by:

1. Stored `EventDateTime` descending (newest first).
2. `EventType` ascending when the complete date/time matches: Flowering,
   LocationChange (displayed as Move), Observation, Repotting.
3. `SourceId` descending within the same timestamp and event type.

This is the owner-approved C14 display rule. Event type takes precedence over
record ID when timestamps match. IDs are table-local; each current event type
maps to one source table with a unique primary key, so the full sort tuple is
unique for each visible event. The view combines active records for active plant
records; split and propagation relationships retain their separate lineage views.
The outer page query owns ordering. A view without an explicit outer sort does
not promise this order to arbitrary callers.

Changing a calendar date can reposition a card. Observation, Repotting, existing
Flowering timestamps and LocationChange corrections preserve the existing time;
returning a date to a tied timestamp restores its event-type/ID position. Times
that differ on the same day still sort by time before event type. Equal times
within one type retain descending record-ID order.

This provides stable display, not insertion order or exact historical chronology.
Stored DATETIME values have no timezone offset or daylight-saving fold. Records
from a repeated local clock hour with equal stored values therefore use the same
type/ID tie-breakers; no UTC order is inferred or reconstructed. Existing clock
and timezone limitations above remain. No user-controlled ordering field, manual
reordering workflow, timestamp rewrite or migration is introduced. See
[C14 evidence](maintenance/c14-history-ordering.md).

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
C12 also prevents changing a propagation child's acquisition calendar date,
including clearing a known origin date. This retains propagation lineage alignment.

### Ended plant policy (C12)

The owner-approved rule is read-only after ending. The main Edit page, event
Add/Edit/Remove handlers and photo handlers reject writes to an ended plant.
Split and propagation cannot create descendants from it. Direct event-form GETs
redirect to Details; the Details, read-only plant details and Photos pages remain
available. Server checks enforce this even when buttons are bypassed.

Event lookups and mutations are scoped to the requested plant, so substituting an
unended plant ID cannot modify another plant's ended history. The updated
spUpdatePlantDetails also rejects any call for an already-ended plant, including
attempts to clear its end date. Migration 202610261800_EndedPlantReadOnly.sql adds
that guard and propagation-origin protection without rewriting historical rows.

C13 places the normal plant POST handlers in a Read Committed transaction and
locks the route plant before loading mutable state. Its structural procedures
lock that same parent, so a waiting writer rechecks the committed end state. A
request commits only after a successful local redirect with valid model state;
validation/error pages and exceptions roll back its database changes. Direct
administrative SQL remains outside this protocol. See [C12 evidence](maintenance/c12-ended-plant-policy.md)
and [C13 evidence](maintenance/c13-structural-transactions.md).

### Atomic manual closure (C11)

Migration `202610261200_AtomicManualPlantClosure.sql` corrects the flowering field
to `flowering.endDate`. First setting an end date updates the plant and closes
its open location/flowering intervals at the same timestamp in one transaction.
The existing time-assignment and split/date protections remain. Closure is refused
if it would end an open flowering before its start or a location at/before its
start. Already closed intervals are unchanged. As before, closure updates all
open rows for that plant, including inactive open rows. C12 prevents later
normal editing or reactivation of the ended plant.

The procedure owns/commits a transaction only when none is active. Otherwise it
uses the reserved savepoint `orchidapp_update_plant_details`, releasing it on
success and rolling back to it on SQL failure without committing prior caller
work. SQL errors are rethrown. A deadlock can cause MariaDB to abort the whole
caller transaction; callers must handle that normal engine behavior. Do not use
the reserved savepoint name in calling code. C13 applies the same ownership
contract to the other structural operations and coordinates normal request writes.

Local native database and actual Edit-page save/reopen checks are recorded in
[C11 evidence](maintenance/c11-manual-closure.md). Existing partially applied
closures are not repaired automatically; use the read-only adoption review in
that guide. The current Edit page still rejects already-ended plants.

The procedure does not automatically repair existing narrative history. C12
refuses clearing an ended plant's end date; it does not reopen old location rows
or create a replacement assignment.

## Narrative events

### Observations

Event Add/Edit checks calendar dates against today and the plant's known
acquisition/end dates, then writes through EF Core. Same-calendar-day events can
still lie outside exact lifecycle timestamps because these checks compare dates.
The Photos page creates an Observation at current server time through a separate
handler. C12 blocks ended plants and refuses an imported future acquisition date
before creating a photo Observation or writing files.

### Repotting

Repotting records cultivation history without itself ending a lifecycle. Event
Add validates future/acquisition/end calendar boundaries and assigns a time.
Event Edit now repeats future/acquisition calendar-date validation and preserves
the existing time when saving a correction. The acquisition calendar day is
allowed, and an unknown acquisition date supplies no lower calendar bound. Ended
plants cannot be edited even when the requested event date precedes ending.

Split and propagation procedures can also create an initial repotting record
when a growth medium is supplied. That record uses the structural operation's
timestamp. This behaviour is already implemented.

### Flowering

Flowering is an interval with a required start and optional end. A NULL end
indicates an open flowering period. Add/Edit handlers validate calendar dates,
start/end relationships and conflicts with other active flowering periods before
writing through EF Core. They use date-level overlap comparisons; do not infer
full timestamp interval semantics or database-wide overlap enforcement from them.

Add assigns current server time to supplied dates. Edit preserves existing
start/end times, checks the resulting exact interval and uses inclusive calendar
overlap checks. An open edited flowering extends forward without an artificial
one-day end, so it cannot bypass a later existing flowering period.

### Removal and enforcement limits

Event Remove soft-deletes narrative records by changing `isActive`; location
removal calls its structural procedure. This preserves rows rather than physically
erasing event history. Each workflow's lifecycle/taxonomy checks must be assessed
separately. C12 rejects event removals for ended plants and scopes source IDs to
the route plant. C13 holds the parent-row lock for the complete write request,
including date checks and photo processing. There is no universal database
constraint enforcing all narrative date boundaries or direct administrative writes.

## Location timeline

An active location row has a required start and optional end. NULL end identifies
the current location. The table checks that any end is strictly later than its
start. Insert/update triggers reject a second active open location row. These
checks do not themselves enforce every historical overlap or lifecycle boundary.

- **Move:** the procedure rejects the current location as a destination, checks
  against existing timeline points/overlaps, closes the current interval and
  inserts a new open interval. Date validation against the plant is also performed
  in the page handler. C13 repeats known acquisition/future bounds in SQL,
  rejects ended plants and requires the new start to be strictly after the current
  start, including equal-second requests. Refresh before retrying a rejected save.
- **Edit:** the procedure validates the new start against its effective end,
  previous start and next start, and adjusts a matching previous interval's end.
  It permits controlled boundary changes; structural timestamps are not all
  immutable. The page preserves the existing time. C13 repeats lifecycle bounds
  in SQL and refuses overlap with other active intervals outside the adjusted pair.
- **Remove:** the procedure soft-deletes a row and stitches matching neighbours.
  Removing a current row can reopen a matching previous interval; removing an
  interior historical row can extend a matching previous row to the removed end.
  Missing neighbours are not automatically reconstructed.

C13 locks the plant before deciding which intervals to change. SQL exception
handlers roll back an owned transaction or the operation savepoint inside a
caller transaction, then rethrow the error. Current locking reads avoid using a
stale caller snapshot for timeline decisions. Tested failures cannot be committed
later through an unrelated successful operation on the same connection. Existing
corrupt timelines are refused where detected, rather than silently repaired.

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
UI edit or reversal exists. C13 rolls back the complete operation on error,
including children, lineage, optional repotting and parent closure. It validates
the children array and refuses inversion of open location/flowering intervals.
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
location. There is no general edit/reversal workflow. C13 serializes propagation
with other parent writes and rolls back a failed child/origin/medium operation.
Successful concurrent propagations remain separate children of the open parent.

## Requirements for future changes

Keep narrative correction available on unended plants without bypassing structural
procedures. Ended plants remain read-only under the agreed C12 policy.
Preserve lineage alignment and consistent location intervals. For any temporal
change, review calendar comparisons versus exact timestamps, unknown dates,
same-day boundaries, ended plants, neighbouring intervals and timezone assumptions.

The following need explicit implementation and tests before becoming guarantees:

- C11 atomic manual closure and C12 request/date policy are implemented locally;
  their Linux/installed acceptance and representative older DB checks remain.
- C19 adds photo request compensation and durable recovery records for uncertain outcomes. [Photo handling](photo-handling.md) defines confirmed rollback cleanup, retained evidence, readiness and operator review; SQL and files are not one atomic resource.
- C14 implements the agreed display tie-breaker; Linux CI and installed UI
  acceptance remain pending. Absolute chronology across local clock changes is
  not promised by the current DATETIME model.
- C13 structural rollback and parent-lock coordination require Linux/installed
  acceptance as well as local native SQL/HTTP checks.
- C12 protects propagation origin dates and forbids normal reactivation. Any
  future exceptional correction workflow would require a separate approved design.

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

## Implementation follow-up

[Code backlog C11–C14](code-change-backlog.md) tracks closure SQL, validation/ended-plant policy, structural rollback/concurrency and any agreed deterministic ordering work. No temporal code was changed by documentation cleanup. New databases use [schema-only creation](database-creation.md); later SQL corrections require forward migrations for existing databases and regenerated canonical schema.
