# Pi 2 nightly standby restore — Block 2 implementation contract

Status: discovery/staging and candidate database-restore source exist in
`standby_restore.py` and `standby_database.py`; `standby_application.py` adds a
disposable application rehearsal. Full application acceptance/promotion/
reporting remain planned. Existing Block 1 code validates the
multi-database archive but cannot orchestrate a standby restore. This page specifies
the repeatable process and acceptance gates. See [completed preparation and
exact archive validation](../../maintenance/pi2-standby-preparation.md) and the
[Block 1 source/handoff contract](nightly-multi-database-backup.md).

## Application rehearsal source — installed acceptance pending

The new `probe-application` operation requires an exact DATA_RESTORED_APPLICATION_PENDING
generation, a private verified publication archive, an explicit root-owned .NET
executable and a separately prepared application directory. It checks the archive
against the backup's DLL fingerprint. It never starts the pristine data candidate:
it copies and verifies the archive again, extracts fresh private payload and imports
both databases into another new socket-only MariaDB candidate. The original state,
data candidate, accepted pointer and cloud remain unchanged.

The publication workspace excludes appsettings files, environment files,
web.config and captured uploads. Fresh settings and a clean child environment use
Production, monitoring disabled, only the cloned uploads and a fresh target-only
`standby_probe@localhost` password over the exact private Unix socket. The account
gets SELECT/INSERT/UPDATE/DELETE/EXECUTE only on the photo database; no global or
system-database grants. Existing definers must resolve to accounts already present
on the new candidate, except the exact opt-in mapping below. Missing definers
otherwise fail; there is no general SQL rewriting. This
check does not prove every routine/view works or provision EnergyMonitoring jobs.

The application runs as the non-login candidate user with no supplementary groups.
Only the launched process is stopped. The controller verifies `/proc` socket
ownership and the sole IPv4 loopback listener before each HTTP request. It uses no
proxy settings or redirects. Checks are readiness (all five known checks and no
false additional checks), home page and SHA-256 of every required photo/thumbnail
served over HTTP, hashing photo responses in bounded chunks rather than loading
large photographs into memory. All are repeated after an application restart. This is listener
isolation and fresh configuration, not an OS-enforced outbound network sandbox.

The source has policy checks and a Linux-owned synthetic HTTP fixture; actual
ARM64 OrchidApp execution is still pending. Run
`python tests/LinuxBackup.Checks/standby_application_checks.py`; Linux CI also
verifies real MariaDB definer resolution and limited target grants on its owned
cross-version fixture. The application root must already be candidate-user-owned
mode 700, separate from state/database roots and named `orchidapp-standby-app*`.
For this installation the reviewed path is `/var/lib/orchidapp-standby-apps`.
Do not run the following operation until the packaged revision and CI are verified:

```bash
sudo python3 /usr/local/lib/orchidapp-standby/standby_restore.py \
  probe-application --config /etc/orchidapp-standby/standby.json \
  --generation EXACT_SNAPSHOT \
  --publication /var/backups/orchidapp-standby/publication.tar.gz \
  --dotnet /opt/orchidapp-standby/dotnet-8.0.34/dotnet \
  --application-root /var/lib/orchidapp-standby-apps
```

The usual 30-hour freshness limit still applies. Obtain a newer matching backup
if it has expired; do not weaken the limit to accept stale data. One probe attempt
per prepared generation creates private `application-probe.json` and owned scratch
evidence. Failure retains all files/databases; no automatic retry or deletion.
Review evidence and disk capacity before another generation. Space preflight uses
four times combined declared payload/publication bytes plus the configured reserve;
this is an estimate, not a proven peak bound. Successful output is only
APPLICATION_PROBE_PASSED_ACCEPTANCE_PENDING. Create/save/upload/reopen workflows,
pristine acceptance, promotion, retention and restore emails remain unfinished.

Pi 2 now has private .NET/ASP.NET 8.0.34 and libvips installed (owner-run evidence
below). [.NET 8 reached end of support on 10 November 2026](https://dotnet.microsoft.com/en-us/download/dotnet/8.0).
The project remains on .NET 8 for this recovery rehearsal; Debian 13 operation
must be demonstrated on the target and is not a claim of current vendor support.
A supported-major application upgrade is separate work.

### Explicit EnergyMonitoring definer rule and reviewed retry

Owner-run rehearsal stopped before app launch because six EnergyMonitoring views
name absent `root@192.168.7.153`. The opt-in `--view-definer-policy energy-six-v1`
uses `standby_definers.py` only on a new disposable rehearsal clone. It requires
exactly these six names with that exact source definer: `vw_Tariff`,
`vw_MonitoringDeviceLocation`, `vw_GoveeHourly`, `vw_EnphaseHourly`, `vw_TapoHourly`,
`vw_WeatherHourly`. Missing names, changed source definers or additional views
naming that source definer fail before writes. Other missing definers still fail.

The rule creates fresh `standby_energy_views@localhost` with a random password,
ACCOUNT LOCK and SELECT on EnergyMonitoring.* only; an existing account is refused.
ALTER VIEW retains the server's stored SELECT, ordered columns, algorithm, security,
check option and character settings. Post-change metadata must differ only in
definer, and every mapped view must execute a representative SELECT. The private
report records the mapping. No dump bytes, source accounts, Pi 1 database, original
restored candidate or accepted standby are modified. This is target compatibility
provisioning on a fresh clone, not a source migration.

Derived-view correction: the first policy attempt found a stored Enphase SELECT
but no information_schema.COLUMNS rows while its source definer was absent. The
rule now uses only the owner-reviewed 15-column Enphase contract when this exact
view has missing columns; it still refuses missing columns on other views. After
ALTER, all 15 names/order must match and the stored SELECT/attributes must remain
unchanged. The native regression uses a derived aggregate/join view with timezone
conversion, rather than six flat witness views, and first proves the missing-column
condition. No generic column inference or SELECT parsing is introduced.

The explicit EnergyMonitoring rehearsal also checks UTC-to-Europe/London conversion
in winter and summer. If missing/incorrect, it generates the two required zone
tables from root-owned target `/usr/share/zoneinfo/Etc/UTC` and `Europe/London` with
`mariadb-tzinfo-to-sql`, and imports that SQL only through the verified candidate's
private socket into its mysql timezone tables. Source system tables/accounts are
not imported, and the system MariaDB is not contacted. Both conversions must then
match (12:00 winter, 13:00 summer for 12:00 UTC); the report records zonefile hashes.
Already valid candidate zones are retained. Missing tool/data or failed conversion
stops rehearsal. This uses target OS IANA rules, not a claim of identical source
tzdata versions. See [MariaDB timezone loader](https://mariadb.com/docs/server/clients-and-utilities/administrative-tools/mariadb-tzinfo-to-sql)
and [CONVERT_TZ requirements](https://mariadb.com/docs/server/reference/sql-functions/date-time-functions/convert_tz).
This is necessary because a successful SELECT returning NULL conversion results
would not prove useful recovery of tariff/time-based views.

MariaDB documents [ALTER VIEW](https://mariadb.com/docs/server/server-usage/views/alter-view),
[view metadata](https://mariadb.com/docs/server/server-usage/views/information-schema-views-table)
and [account locking](https://mariadb.com/docs/server/security/user-account-management/account-locking).
Native CI checks actual locked-owner view execution, metadata preservation,
SELECT-only grants and default refusal without the explicit policy. Actual Pi 2
mapping and application execution remain pending.

An explicitly reviewed failed attempt can be retried with its exact report token
as `--retry-failed-probe TOKEN`. The old report is preserved as
`application-probe-failed-TOKEN.json`, and a NEW SQL/uploads clone is restored.
No failed database/workspace is resumed or removed. Pending/successful attempts,
wrong tokens, changed archive identities and more than three retained retries are
refused. The normal backup freshness and free-space checks still apply.

For root-run rehearsal, copy the transferred user-owned publication with
`install -o root -g root -m 600` into the private root-owned backup directory and
use the path above. Mode 600 alone does not satisfy root ownership validation.

## Boundaries

Pi 1 remains authoritative and runs Block 1. Pi 2 independently lists completed
OneDrive sets, restores the same named databases and matching files, verifies the
applications, preserves a clean accepted standby and reports success/failure.
Pi-hole, Pi 1, unrelated services and historical recovery inputs are outside scope.
Do not change or silently downgrade Pi 2's chosen MariaDB 11.8.6 baseline. The
actual 10.11.14-to-11.8.6 logical restore must be tested. No migration runner is
automatically applied during nightly recovery.

All scripts, tests, templates, packages and operational evidence belong in the
repository on a Block 2 branch. The owner controls Pi connections and runs only
reviewed package commands; ad hoc SQL and tar extraction are not a replacement for
the coordinator. Required helpers may be shared, but importing Block 1 code must
not give Pi 2 a backup schedule or upload/prune route. Do not use the old
single-database restore CLI for the multi-database archive.

## Implemented phase 1: discovery and inert staging

`standby_restore.py discover --config /etc/orchidapp-standby/standby.json` lists
and reads completed records only. `prepare` also downloads, checks and stages the
latest eligible set. The example JSON has no database credentials, service names
or email credentials: this phase has no database/service/email capability. Install
all three modules together root-owned. Config and cloud credentials must be root/
operator-owned mode 600; new state root is private mode 700 and separate from
config/credentials. No automatic schedule is supplied for this incomplete phase.

The cloud interface constructs only `lsf` and exact-object `cat` commands. Listing
and record responses are bounded in memory/time; archive download is bounded to
the declared length plus one byte, then length/hash checked. Rclone documents the
[bounded cat option](https://rclone.org/commands/rclone_cat/). It may refresh its
local credential file but cannot construct upload/delete/sync commands. Bad record
identity, database list, hash, size, timestamp/order or object name fails discovery.
Old records may be listed, but the latest recovery point must be within 30 hours
by default. Future timestamps fail. An invalid newer record never causes silent
fallback. An existing last-accepted record, written only by a future acceptance
implementation, prevents rollback/rewrite; this phase never writes that record.

Each attempt creates a new owned generation under `state_root/generations`.
Before download it checks archive-size plus reserve; before extraction it checks
actual declared payload-size plus reserve. This is preparation space only, not a
future MariaDB/app clone allowance. Default reserve 1 GiB, maximum compressed input
5 GiB, unpack limit 20 GiB, maximum 1,000 ready records and three owned/unknown
generation entries. Limits must be reviewed for collection growth. No generations
are deleted automatically; capacity exhaustion refuses more work. Repeating a
snapshot with existing state refuses reuse rather than guessing whether to retry.

States are DOWNLOADING, VALIDATING, EXTRACTING, PREPARED_RESTORE_PENDING or FAILED.
A private owner token and exact ready record are durable before download. Extraction
rejects unexpected/changed entries and creates plain private files without archived
ownership or modes. Post-extraction inventory and archive rehash must match.
Captured .env, account SQL and units remain inert under payload. Failure leaves
input/state for inspection; process interruption may leave an intermediate marker
and stale operation lock, both requiring review. No accepted pointer, MariaDB,
system service or OneDrive object is modified.

Exit 0 for discover/prepare means that phase completed, not standby acceptance.
Prepare prints PREPARED_RESTORE_PENDING. Full restore-success email and scheduling
are explicitly unavailable. The output must never be relabelled a working standby.
Run `python tests/LinuxBackup.Checks/standby_checks.py`: synthetic policy tests and
an optional real rclone crypt round trip against private local disposable storage.
The Linux CI step installs rclone and runs the real crypt case too. No live cloud
account, Pi database or source credentials are used by tests. Package sources with
`python scripts/package-standby-restore.py`; it includes hashes and examples only.

## Candidate database restore — first installed data stage passed

`restore-data --generation EXACT_SNAPSHOT --config TARGET_JSON` accepts only a
pristine PREPARED_RESTORE_PENDING generation, rechecks its archive and extracted
inventory, and requires an explicit non-root system account and separate private
`database_root` owned by that account. Its basename must start with
`orchidapp-standby-db`, cannot overlap state storage and must already exist.
Account/directory provisioning is a separate reviewed installation step.

The code initialises a new candidate directory with MariaDB 11.8 tools, starts its
own child server as that user with networking/binlogging/replication startup/events
disabled, and uses only its private socket. It verifies actual datadir, socket,
networking, events, generated server ID, process liveness and version before SQL
writes and each import. No host/port/live client-file arguments are accepted.
Root uses explicit --user; a non-root fixture runs as itself. The initial empty
root password exists only inside the private socket-only candidate and is replaced
after identity checks with a random password in a private target client file.
Captured credentials are not used. See [MariaDB initialisation options](https://mariadb.com/docs/server/clients-and-utilities/deployment-tools/mariadb-install-db).

Only named application dumps are imported, never accounts.sql. Durable pending
state precedes SQL. Failure retains data, diagnostics and DATABASE_FAILED state;
retry into partial data is refused. No DROP/repair or automatic deletion is used.
SIGINT/SIGTERM unwind the owned child; hard termination/power loss need review.
Shutdown targets only the child created here, never an external PID/default
endpoint. Forced shutdown fails the data stage. The normal MariaDB service and
Pi-hole are not queried or stopped.

Post-import checks compare SQL photo references/files and inventory table row
counts, views/routines/definers/events. Counts are evidence, not source fingerprints
that this backup format does not contain. Definer/grant compatibility and actual
application behavior remain pending. The owned server stops before successful exit.
DATA_RESTORED_APPLICATION_PENDING is not application readiness or an accepted
standby. No accepted pointer, restore-success email or schedule is created.

Policy tests: `python tests/LinuxBackup.Checks/standby_database_checks.py`.
Native Linux fixture: `python tests/LinuxBackup.Checks/standby_native_linux.py` on a
non-root disposable runner with Docker and MariaDB 11.8 tools. It creates its own
labelled network-none MariaDB 10.11.14 source, generates synthetic dumps and exercises
actual 11.8 restore, objects/photos/events-off, partial DDL and retry preservation.
It accepts no live endpoint and removes only its verified owned container. Private
host data/logs remain for review; no SQL/credentials are uploaded as CI artifacts.
Native run [43514710945](https://github.com/rayfeeney/OrchidApp/actions/runs/43514710945)
passed on `7c090cb`, including both databases, views/routines/triggers/events-off,
photos, accounts.sql exclusion, partial DDL/retry refusal and prior marker
preservation. Corrected policy head `14faccb` passed all eight hosted jobs in run
43515352028. The owner then ran the packaged data stage on Pi 2's actual archive
successfully (25 orchids/10 EnergyMonitoring base tables). These results do not
certify full application behavior; see the updated installed evidence.

## Capture the matching application publication

The data backup intentionally excludes application binaries. The repository helper
`standby_publication.py` captures the complete source publication only when its
OrchidApp.Web.dll matches the backup's expected hash. It requires source ARM64 and
.NET 8 metadata, checks copied/source inventories, verifies the finished archive
and publishes it atomically without overwriting an existing file. Symlinks and
special files are rejected. Destination parent must be a private root/operator-owned
directory separate from source. Required free space is three times source bytes
plus 1 GiB; concurrent disk users can still cause failure. Source files and running
services are never changed. Ordinary failure removes only its temporary staging.

Install this single helper beside existing `orchid_backup.py` and `nightly_backup.py`
on Pi 1; standby database code is not required there. Run as the operator if all
source files are readable. Example after reviewed deployment:

```
python3 /usr/local/lib/orchidapp-backup/standby_publication.py capture \
  --source /opt/orchidapp/publish \
  --destination /home/raymond-23/orchidapp-publication-transfer/publication.tar.gz \
  --expected-web-sha256 EXPECTED_DLL_SHA256_FROM_BACKUP
```

The output reports archive size/SHA-256 and DLL identity. Keep its private mode-600
output, transfer over SSH, verify whole-file hash and run the helper's
`verify --archive EXACT_FILE --expected-web-sha256 EXACT_HASH` on Pi 2. This does
not extract/activate captured settings, install a runtime or start the application.
The archive may contain secret app settings: never commit it, attach it to a PR
or upload it as CI diagnostics. Preserve software with its matching recovery point;
do not infer source Git identity from a DLL fingerprint.

Eight synthetic cases in `tests/LinuxBackup.Checks/standby_publication_checks.py`
cover capture/verify, hidden/empty files, source mutation, no-overwrite, wrong DLL/
architecture, low space and unsafe members. No real publication is used. Actual
capture and this helper's new Linux CI acceptance remain pending until observed;
the older data-stage CI is not relabelled as publication validation.

## Complete Block 2 phases and durable states

1. **Discover.** List only the configured crypt directory for the explicit stable
   collection. Read exact `.ready.json` records with bounded size. Validate format,
   collection, snapshot/name correspondence, SHA-256, declared size, exact database
   list, timezone-aware timestamps and maximum recovery-point age. Choose a new
   eligible recovery point; do not silently roll back accepted state because a
   newer candidate failed. A filename or newly visible archive alone is not ready.
2. **Download and validate.** Check local space before download/extraction/import.
   Retain the exact completion record and archive with private permissions. Bound
   download size, verify actual length and SHA-256, validate full archive inventory,
   member safety, limits and required photo references. Keep source records/hashes
   unchanged. Discovery/validation failure cannot modify a database or accepted
   pointer. The observed archive check is complete preparation for this phase,
   not a completed automatic implementation.
3. **Stage.** Create a new private generation with an ownership token and durable
   phase marker. Extract only validated plain files/directories without archived
   owners/modes. Stage all source settings as inert bytes. Reject existing or
   overlapping destinations, symlinks and unknown owned-generation state. Keep
   scratch/download storage separate from accepted runtime state.
4. **Restore candidate.** Initialise a new MariaDB data directory with target
   11.8 tools. Use an explicitly isolated socket/endpoint that the live app cannot
   reach; never select a target merely by passing a database name. Query and verify
   actual datadir/socket/networking/identity before import. Dumps use original names
   and may contain qualified SQL/definers. Import only the selected application
   dumps, never accounts.sql wholesale or system databases. A durable pending
   marker precedes SQL; partial DDL/import preserves evidence and blocks reuse.
   The default system MariaDB listener is not automatically an isolated candidate.
5. **Provision applications.** Require exact compatible ARM64 application bytes
   matching the archived DLL fingerprint, plus compatible .NET 8/native dependencies.
   Absence of compatible software fails the candidate; do not rebuild whatever
   happens to be latest and claim identity. Configure explicit target-only runtime
   accounts, SQL definer handling, settings, upload paths and file permissions.
   Never source captured .env files or install captured service definitions blindly.
   Keep events, importers, collectors, outbound feeds and source backup jobs off.
6. **Validate.** Check both databases' objects, tables, data/history, stored routines,
   required seed/settings behavior and photo bytes/references. Verify readiness,
   representative pages/photos/thumbnails, restart and isolated create/save/upload/
   reopen. Perform write workflows on a separate disposable validation clone;
   accepted generation must retain pristine backup data, with no validation records
   or files. Compare pristine state to capture before acceptance. Missing active
   media or unresolved photo-recovery records must not be hidden to force readiness.
7. **Accept.** Only when all required checks pass, persist an acceptance record
   tied to collection/snapshot/hash and software identity, then switch a single
   guarded target pointer. Coordinate application/database generations together;
   do not claim an atomic multi-file switch unless the implementation proves it.
   Retain previous accepted generation and a tested fallback path. Failure or
   restart during promotion must resolve conservatively to known state, not a
   mixture. Do not delete last working state before replacement is accepted.
8. **Report and retain.** Send an accepted-restore email only after application
   acceptance, not after SQL exit zero. Failure reports identify phase and both
   attempted and last accepted recovery points. Use private durable SMTP outbox,
   bounded retries without redoing imports, and independent overdue monitor that
   still works with a stuck restore lock. Target sender/recipient default to the
   agreed GMX/Gmail route, with separate protected target credentials. Retention
   manages only verified owned local generations; it never deletes OneDrive sets.

No restore timer is installed until the process passes a full manual rehearsal.
First automatic refresh and received report, failure preservation, reboot/startup,
clock/freshness thresholds and minimum free space are separate installed acceptance.
There is no automatic live takeover or switch-back. A takeover runbook must ensure
only one Pi runs the real writers. Read-only cloud operations in the coordinator
do not imply the copied provider token has read-only permissions.

## Required tests before installed use

- Pure policy: completion record limits/identity/date/hash/name/database rejection,
  no-new-snapshot behavior, stale/future records, size/space checks and no cloud
  writes. Discovery errors preserve accepted state.
- Archive/staging: full corrupt/missing-photo/path/link/duplicate/oversize rejection,
  hidden/empty files, source metadata inertness and input changed during capture.
- Database fixture: owned isolated MariaDB 11.8, actual 10.11 logical dump inputs,
  endpoint mismatch refusal before SQL, both database import/data/object/photo
  checks, definer/account behavior, partial DDL interruption and no blind retry.
- Application fixture: exact ARM64 publication, readiness/photo/save/reopen/restart,
  isolation of validation writes, pristine accepted state, previous working-state
  preservation and interrupted acceptance recovery. No production endpoint inputs.
- Reporting: success only after full acceptance, failed/overdue reports with last
  working point, SMTP failure independent of restore result and bounded retries.
- Installed Pi 2: permissions, services, absent external writers, read-only cloud
  behavior, email receipt, peak disk/time and first scheduled cycle. Pi-hole health
  and Pi 1 remain unchanged.

New feature checks must run in CI and packages must include only reviewed source
and examples, never downloaded backups, captured configuration, SQL or credentials.
Update the [current state](../../current-state.md) and [upgrade checklist](../../upgrade-checklist.md)
with actual evidence, distinguishing preparation, source tests and installed use.
