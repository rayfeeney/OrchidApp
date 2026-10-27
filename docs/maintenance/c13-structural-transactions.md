# C13 structural transactions and concurrency

C13 coordinates normal plant writes with lifecycle closure and makes the affected
multi-row SQL procedures roll back failures. It follows the C12 ended read-only
policy. Existing installations need the migration and matching application as one
release; there is no new setting or historical data conversion.

## Database changes

`202610262000_StructuralTransactions.sql` replaces these procedures:

- `spMovePlantToLocation`, `spEditPlantLocation`, `spRemovePlantLocation`
- `spSplitPlant`, `spPropagatePlant`
- `spSetHeroPhoto`

Each locks the active parent plant before making mutable-state decisions and
refuses an ended parent. It starts and commits its own transaction only when
there is no caller transaction. Otherwise it uses a reserved operation savepoint.
On SQL errors it rolls back the owned transaction or operation savepoint and
rethrows the error. Successful calls never commit earlier caller work. Callers
must not reuse savepoints named `orchidapp_` followed by the lower-case operation
name, such as `orchidapp_splitplant` or `orchidapp_setherophoto`.

MariaDB deadlocks can abort an entire caller transaction. The handler checks
`@@in_transaction` before rolling back a savepoint; it does not promise to retain
caller work after the engine has aborted that transaction. Refresh the plant
history after a failed save before deciding whether to retry. No automatic retry
is introduced.

Location decisions use current locking reads, including inside a caller's older
repeatable-read transaction. A move cannot create a zero-length current interval,
including an equal-second request. SQL repeats future/known-acquisition bounds;
location edits reject overlaps outside the adjacent interval pair being adjusted.
Split requires an array of at least two children and rejects inversion of an open
location or flowering interval. Split failure also cleans up its reserved temporary
result table. Prior corrupt rows are not silently repaired.

Hero selection now uses the current connection's database rather than the fixed
`orchids` qualifier. Its two updates are atomic and share the parent lock. It still
requires an active photo belonging to the requested plant.

The canonical routines, checksums and bootstrap cutoff `202610262000` are generated
by the official schema exporter from an isolated migrated database. Historical
migration files are unchanged. Fresh creation uses schema and seeds, without
replaying migrations.

## Application coordination

`PlantWriteFilter` wraps POST handlers for existing plant details, event
Add/Edit/Remove/Split/Propagate and Photos in an EF Read Committed transaction.
It locks the route plant before executing the handler, rejects conflicting form
or query plant IDs and checks the committed end state after acquiring the lock.
The lock is held through validation, database writes and photo processing.
GET/history/photo viewing remains available.

A successful local redirect with valid model state commits the transaction.
Validation/error pages, rejected writes and exceptions roll back database changes,
including earlier `SaveChanges` calls. Observation Add uses this enclosing
transaction instead of starting a second one. The stored procedure executor
enlists both its collation command and CALL in the EF transaction, and consumes
trailing results so a late procedure error cannot masquerade as a saved child.

If a writer commits before closure, closure sees its new open intervals. If
closure commits first, the waiting writer rejects the ended plant. If closure
rolls back, the waiting structural operation can proceed against the open parent.
This protocol covers the listed application handlers and cooperating procedures;
it is not a universal immutable-table constraint for direct administrative SQL.

Database rollback does not make photo filesystem changes transactional. Invalid
photo processing is checked for database rollback here; full multi-file cleanup,
commit-uncertainty compensation and readiness remain C19. History ordering and
timezone guarantees remain C14. Taxonomy administration is outside this parent
write protocol.

## Windows and Linux upgrade actions

Use the platform [upgrade checklist](../upgrade-checklist.md). Stop writers and
retain a verified recoverable backup. Windows uses the rebuilt Desktop package's
normal backup/preflight migration gate. Linux/manual administration uses the
canonical runner, first `-PlanOnly`, then application against the explicit target.
Deploy the matching app and generated schema assets before restarting writers.
The preceding procedures can commit caller transactions, so do not mix the new
app filter with the old procedure definitions.

For an isolated source-development checkout, stop the app and run:

```powershell
pwsh ./scripts/DevSetup/update-database.ps1
```

The existing wrapper reads the repository `.env`, takes its normal logical backup
outside the source tree and applies pending migrations. No credential re-entry or
database name change is needed. Commit normally afterward; keep the export guard.
Do not use the source-development workflow against a collection database.

No backfill or repair is applied to historical partial operations. A failed
migration retains the existing pending-marker recovery contract; routine DDL is
not automatically rolled back. Do not clear the marker or downgrade only binaries
to force a retry.

## Validation and remaining acceptance

Run the combined suite only against a separate disposable MariaDB server:

```powershell
pwsh ./tests/LifecycleClosure.Checks/Database.Checks.ps1
```

It requires explicit test-server credentials, Python 3, .NET 8 and MariaDB tools.
It creates/drops generated `orchids_c11_` databases, starts a loopback web host and
uses synthetic uploads. The preceding structural definitions are retained in
`PreC13Structural.sql`; they were checked against the C12 source hashes. The upgrade
fixture restores them before manifest generation. The second fixture uses the
current schema alone without a migration directory. The maintainer `-ExportSchema`
option regenerates source artifacts from the migrated pristine schema, before
test-only objects are created.

The C13 suite contains 21 scenarios with additional operation subcases:

- Injected failures after earlier writes in move, edit, remove, split, propagation
  and hero selection, in owned and caller transactions; unchanged rows and later
  connection reuse/commit are checked.
- Caller rollback after successful operations and caller work retained after
  ordinary operation errors; no lingering owned transaction.
- Competing moves, splits and propagations, observed through actual server lock
  waits rather than timing alone; intended intervals and lineage are checked.
- A move within an older repeatable-read caller snapshot uses current interval
  rows rather than its stale consistent snapshot.
- Committed and rolled-back closure against waiting structural operations, and
  committed closure against waiting event/photo handlers.
- Closure waiting for a real HTTP flowering write, then closing that new interval.
- Actual HTTP move/split/propagation/hero save and reopen, conflicting route/form
  IDs, a trailing procedure error and failed photo processing rollback.
- Split interval inversion and malformed children rejection.

Local Windows MariaDB 10.11.16 and Release web-host results are recorded with the
delivery after both the upgrade and fresh fixture complete: 16 closure, 16 C12
and 21 C13 scenarios on each, 106 executions. The unchanged creation/baseline,
migration/export and child-process suites supply 44, 53 and 10 regression checks.
Policy checks cover 18 baseline cases, 24 Desktop migration-policy scenarios and
247 packaged migrations. A Release build and workflow/PowerShell syntax checks
are included. NU1900 means NuGet vulnerability metadata was unavailable; these
runs do not establish a completed vulnerability audit.

Both platform plant-management Word guides add the refresh-before-retry guidance.
All 44 embedded media files are unchanged; each guide remains 17 pages. All 34
rendered pages were inspected, including the changed paragraph on page 13.
Screenshots remain applicable because no action/form layout changed.

Linux CI, installed Desktop/Pi acceptance and representative older installations
remain pending. Cross-publishing or source success does not certify those targets.
No owner's `.env`, collection database or live photos are modified by these checks.
Next in the agreed order is C14 history ordering.

## CI follow-up on 27 October 2026

This records the first, incomplete correction. The later cache diagnosis below
explains the continued Linux failure; a positive wait count alone was insufficient.

The first Linux CI run failed in the test helper that observes structural lock
waits. The helper compared the count from `INNODB_LOCK_WAITS` to exactly one.
Those rows describe wait edges: a waiting transaction can have more than one
blocking lock/transaction. The corrected check requires a positive count for the
specific waiting connection and still fails if the operation completes before
the held lock is released. Timeout output now includes connection ID, count and
transaction state/query rather than only a generic failure message.

The pasted CI log does not contain the observed counts, so it cannot independently
establish their exact values. Its initial wait timeouts and subsequent subcase
failures are consistent with this invalid exact-count assumption. The follow-up
adds an actual database regression with two shared lock holders: the writer has
at least two wait edges, remains blocked after one holder commits, and completes
only after both release. This reproduces the original assertion's false negative
without weakening the requirement to observe a real wait. Each closure/photo
subcase now creates its fresh plant at the start, preventing an earlier assertion
failure from leaving later subcases pointed at an already-ended fixture.

The suite identifies this correction as `c13-lock-wait-count-v2` and contains 22
structural scenarios, alongside the existing 16 closure and 16 C12 scenarios on
each upgraded/fresh fixture: 108 executions. The delivery records the completed
local run; Linux CI must be rerun to confirm its result. A local Linux container
engine was unavailable, so no Linux reproduction or pass is claimed.

This is a test-only correction. Application code, migration SQL, generated schema,
settings and deployment actions are unchanged. The Windows/Linux user guides were
reviewed; their failed-save and upgrade instructions still apply, so no Word edit
or new database migration is required. Keep the existing C13 app/migration pairing.

## CI cache diagnosis and revision v3

The next Linux log reports `wait_count=['0']; transaction=[]` while the competing
operation remains pending. The earlier two-holder regression passes in that same
run. This rules out the exact-count assumption as the explanation of the remaining
failure and points to stale observation data rather than an absent row lock.

MariaDB 10.11 shares a cache across `INNODB_TRX`, `INNODB_LOCKS` and
`INNODB_LOCK_WAITS`. Its refresh requires more than 100 ms since the last cache
read, and each read updates that time. Polling it every 50 ms can therefore keep
an empty snapshot alive. See the [MariaDB cache implementation](https://github.com/MariaDB/server/blob/10.11/storage/innobase/trx/trx0i_s.cc#L898-L914)
and [read timestamp update](https://github.com/MariaDB/server/blob/10.11/storage/innobase/trx/trx0i_s.cc#L1062-L1066).
Process startup made the old polling slower on Windows, masking the problem.

Revision `c13-lock-cache-v3` leaves 250 ms between metadata polling attempts,
including after timeout diagnostic reads. The test still requires observed wait
edges for the specific waiting connection; a delay alone is not success. The
HTTP closure-wait check also uses this spacing and scopes its wait edges to the
actual holding connection, rather than any wait on the server. Process-list-only
observation of the synthetic user lock does not read the InnoDB cache and keeps
its existing polling behavior.

A new regression uses a persistent, fast observer connection and primes an empty
snapshot before starting the blocked writer. This removes Windows process startup
as an accidental cache-refresh delay. The maintainer reproduction runs that same
scenario first with the old 50 ms setting, expecting the full-timeout empty-cache
failure, then with 250 ms spacing, requiring a real wait and successful completion
only after releasing the parent lock. Its results and the full upgraded/fresh
fixture run are recorded in the delivery.

There are now 23 structural scenarios, plus 16 closure and 16 C12 scenarios on
each fixture: 110 executions. Linux CI must still be rerun; local native testing
does not certify the Linux runner. This remains a test-only correction. No app,
SQL, schema, credentials, Word-guide or deployment-action change is required.
