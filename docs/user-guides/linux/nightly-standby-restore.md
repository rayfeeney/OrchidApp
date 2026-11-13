# Pi 2 nightly standby restore — Block 2 implementation contract

Status: phase 1 source implementation exists in `infrastructure/backups/standby_restore.py`;
full restore/acceptance/reporting remain planned. Existing Block 1 code validates the
multi-database archive but cannot orchestrate a standby restore. This page specifies
the repeatable process and acceptance gates. See [completed preparation and
exact archive validation](../../maintenance/pi2-standby-preparation.md) and the
[Block 1 source/handoff contract](nightly-multi-database-backup.md).

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
   matching the archived DLL fingerprint, plus supported .NET 8/native dependencies.
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
