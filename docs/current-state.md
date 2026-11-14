# Current state and fixed v1.4.0 work list

## Pi 2 Block 2 progress — reconciled 14 November 2026

Latest installed probe failed after mapping: CHECK TABLE now establishes a real
UCA1400/general_ci collation conflict in the Enphase aggregate, explaining missing
column metadata. Source correction is limited to explicit utf8mb4/general_ci
defaults (including character_set_collations) on the isolated --no-defaults server,
with startup verification. Source fixture clients now explicitly use utf8mb4;
native negative/positive SQL must reproduce the conflict and verify the fix before
delivery. No table conversion, system configuration or EnergyMonitoring source
change is planned. Actual Pi 2 verification/application acceptance remains pending.

Owner's explicit-policy retry failed before ALTER: Enphase stored definition exists
but missing source definer hides its column metadata. Both failed attempts remain
retained. New correction uses only the reviewed 15-column Enphase contract plus
post-ALTER column/query equality, with a derived aggregate/join native regression.
The shown view also requires named timezone tables: candidate-only UTC/London setup
and winter/summer checks are now source changes, not yet installed acceptance.
No application process has yet passed readiness on Pi 2.
Hosted d733f98 failed its new native precondition because a simplified derived
fixture did not reproduce missing columns. A closer synthetic date-grouping,
battery aggregate and tariff-date join fixture is required before delivery; the
assertion is retained. EnergyMonitoring source changes belong to its separate
repository; OrchidApp owns this shared restore tooling and disposable tests.
The closer 1ea2bfb fixture also returned columns. Native coverage now explicitly
injects the single observed missing-metadata response, retaining real DDL and all
post-checks; it does not claim a naturally reproduced MariaDB defect. Installed
Pi 2 execution is still required.

Owner installed rehearsal revision 65d7b52 and passed all 48 target package checks.
After correcting publication input ownership, the actual rehearsal failed safely
before app launch: six EnergyMonitoring views name absent root@192.168.7.153;
all orchids definers resolve. New `standby_definers.py` implements an explicitly
selected six-view mapping to a locked SELECT-only local account, retaining queries
and attributes. Exact failed-token retry preserves the old attempt and creates a
new clone. Policy/retry tests and native view/grant checks precede redeployment;
actual app/CRUD/standby acceptance remains pending.

New source `standby_application.py` adds a separate SQL/uploads-clone application
rehearsal: target-only limited SQL account/clean Production settings, missing-definer
refusal, owned loopback listener, readiness/home/every photo hash and restart.
Its success explicitly leaves acceptance pending. Seven policy/HTTP tests are wired
into Linux CI (Windows skips the real /proc HTTP fixture); the native cross-version
fixture now checks target grants and no global CREATE DATABASE privilege. Source
and target execution are separate acceptance gates. CRUD, pristine promotion,
retention, restore email/overdue scheduling remain unfinished.

Owner-run publication capture/transfer/verification succeeded. Pi 2 now has private
.NET and ASP.NET 8.0.34 and libvips42t64 8.16.1-1+deb13u2; Pi-hole/system MariaDB
remain active. .NET 8 is out of support; keep the mandated application framework
for this rehearsal and track supported-major upgrade separately. The application
process has not launched successfully on Pi 2; see [current evidence](maintenance/pi2-standby-preparation.md).

Phase 1 source now exists in `infrastructure/backups/standby_restore.py`: bounded
read-only cloud discovery/download, strict record/hash/archive validation, private
inert generation staging and durable pending/failure state. Policy tests and a real
rclone crypt/local-storage test are added to Linux CI. No SQL import, application
acceptance/promotion, full restore email, cleanup or schedule is implemented by
this phase. Its PREPARED_RESTORE_PENDING result must not be called restored.

Candidate database-restore source is now being added separately in
`standby_database.py`: new non-root-user-owned 11.8 instance, exact private socket/
datadir/server-ID verification before SQL, source account exclusion, durable
partial-import failure state and stopped-server DATA_RESTORED_APPLICATION_PENDING
output. Ten local adapter tests pass. Hosted run 43514710945 on `7c090cb` passed
the real 10.11.14-to-11.8 fixture, including both databases, routines/views/triggers,
events-off, photos, accounts.sql exclusion, partial-DDL marker/retry refusal and
prior-state preservation. All 23 staging/crypt tests also passed on Linux. The
separate adapter-policy job initially failed because its Windows API adapter
substituted a fake UID on Linux; the correction retains the actual UID and does
not weaken protected-file checks. All eight hosted jobs passed on `14faccb`
(run 43515352028), including corrected policy and real cross-version checks.
The owner then installed the candidate package, ran 23 staging/crypt and 10 policy
tests on Pi 2 (all passed), provisioned private non-login account/storage, and
completed discovery, preparation and the first actual archive data restore.
Result: DATA_RESTORED_APPLICATION_PENDING on 11.8.6, 25 orchids and 10
EnergyMonitoring base tables, accepted state unchanged. Source accounts/settings
and scheduled writers were not activated. Application/definer/grant checks,
acceptance/promotion and reporting remain
pending. Pi 1's current DLL was confirmed to match the archive fingerprint, with
both .NET and ASP.NET runtimes 8.0.23. Target runtime installation is recorded above;
application execution still needs installed testing.

Owner reports a clean Debian 13/ARM64 Pi 2 (`pihole2`, 192.168.7.50), Pi-hole
operational, Python 3.13.5, PowerShell 7.6.6 retained, 45 GB free and MariaDB
11.8.6 active/enabled with only system databases at baseline. .NET was absent then;
the subsequent private runtime installation is recorded above. MariaDB events
are OFF, lower_case_table_names=0, utf8mb4/utf8mb4_general_ci. A separate old
temporary MariaDB restore server was identified and stopped; intended service
remains active. Official rclone 1.73.0 ARM64 package checksum/install passed.
Root-owned private crypt configuration, cloud listing, exact ready-record download
hash and full archive inventory/required-photo validation passed on Pi 2 for the
17:07:58 UTC Block 1 snapshot (both databases; 756 active photo/thumbnail references).
See [preparation evidence](maintenance/pi2-standby-preparation.md) and the [Block 2
implementation contract](user-guides/linux/nightly-standby-restore.md).

Preparation and isolated data import passed, not complete application recovery.
Captured settings activation, application acceptance, Pi 2 restore/email automation
and scheduling remain pending. The actual archive imported on 11.8.6; application/
runtime compatibility and target runtime grants/definers still need validation.
New `standby_publication.py` source captures matching ARM64 .NET 8 publication
bytes with private verified output and no source changes. Eight local synthetic
checks passed; its new hosted tests and actual capture remain pending.
Pi 1 and Pi-hole stay outside
restore scope. Work-list items 9/10 remain open.

## Pi 1 multi-database nightly backup installed — 13 November 2026

Owner-run first capture passed: both selected databases and photographs, 9.1 seconds
capture/restart, 438.7 seconds total, 474,190,903-byte archive, minimum sampled free
space 4,396,077,056 bytes, active services/timers and readiness 200. GMX-to-Gmail
receipt confirmed; recipient changed to bloodandsand44@gmail.com. The subsequent
run was blocked at private-file validation after the imported atomic JSON helper
replaced config under a normal umask. Candidate fix explicitly creates temporary
JSON mode 600; new regression covers creation/replacement under umask 022.
Pi permissions were repaired and the patched helper deployed after SHA-256 verification.
The second capture passed with one matching local archive/completion record, about
5.1 GB free and a received Gmail success report. Controlled low-space failure and
isolated overdue-state tests both produced the expected failure/overdue emails.
The root-owned rclone copy is `/etc/orchidapp/nightly-rclone.conf`; the user's old
configuration is unchanged. Mail to the original Microsoft address was not received;
GMX self-delivery and delivery to `bloodandsand44@gmail.com` were confirmed.

Both systemd timers are enabled: backup at 02:00 Europe/London (first due
14 November), freshness/email retry every 15 minutes. The monitor's first installed
run returned `Result=success`, `ExecMainStatus=0`; timer's next check was listed.
Systemd validation passed; clock synchronised. Logrotate uses `daily` and `maxsize 1M`.
The old user cron entry was commented after saving the complete crontab to
`/home/raymond-23/orchid-crontab-before-nightly-20261113-172127.txt`.
The original script and historical recovery material remain protected.

The opt-in Block 1 implementation in `infrastructure/backups/nightly_backup.py` captures
selected databases together, restarts writers before cloud transfer, verifies crypt
upload/read-back/completion record, retains scoped history and reports through a
private SMTP outbox and independent freshness monitor. See the [operating contract](user-guides/linux/nightly-multi-database-backup.md).
Old repository backup/restore commands are unchanged. Block 2 is unimplemented and
the new format cannot be restored with the old CLI. Owner-run installed observations
above are distinct from the 21 local synthetic checks, 20 pre-fix synthetic checks
run on Pi 1, and owned Windows native MariaDB SQL round trip. The first overnight
scheduled backup/received success report, exact live-set restore/application
acceptance, reboot acceptance and Pi 2 reporting remain pending. Work-list items
9/10 stay open. See the [installed evidence record](maintenance/pi1-nightly-backup-block1.md).

## Photo row deactivation — 12 November 2026

Photo removal now deactivates the row and clears its hero flag, retaining both files. No DELETE grant or migration is needed. Local .NET 8 locked restore/build passed (zero build warnings/errors), as did storage retention checks. On a new disposable Linux MariaDB 10.11.14 server, the upgraded fixture passed 28 photo HTTP checks plus all 74 existing lifecycle/date/validation/structural/history checks. The schema-only fixture passed 29 photo checks but initially failed one newly added test's trigger syntax; the corrected hero-replacement rollback test, restricted SELECT/INSERT/UPDATE/EXECUTE-account test (no DELETE), and nonhero/repeat test then passed on both fixtures (six targeted checks). The full runner was not green as one invocation; its setup failure and targeted correction are retained in local ignored logs. Current documentation links and diff whitespace checks passed. Hosted CI, installed Pi/Windows acceptance and shared Word-guide screenshot updates remain pending; deployment has not been performed.


Last reconciled: 7 November 2026. This is the owner-agreed bounded work list, not evidence that pending tasks passed.

## Pi 1 v1.3.0 to v1.4.1 historical ledger adoption candidate — 11 November

Development branch `pi1-safe-historical-adoption` starts at `bcc4e7d`. A separate Linux maintenance command now reuses the exact reviewed structure/history contract while requiring explicit target, approval, stopped/masked writers, read-only server, isolated administrative access and consistent restore-tested/off-device recovery evidence. It retains the entire 245-row ledger and records durable interruption state. See the [Linux operating procedure](user-guides/linux/installation-upgrade.md#historical-pi-1-v130-ledger-adoption) and [implementation/test record](maintenance/pi130-operational-adoption.md).

Locally passed: 13 new operational policy/interruption tests and the existing 23 historical checks, compilation and diff checks. After Windows restart and manual Docker startup, the operational core passed a new owned Linux/MariaDB 10.11.14 fixture run (`20261111T185743Z-b150022c`): real native-session disconnection released its lock, competing access was refused, staging survived interruption and blocked retry, all 245 audit rows survived exactly, all four real forward migrations applied, a second apply did nothing, and application data/counts and reviewed post-upgrade schema matched. The 13 new policy tests also passed inside an isolated Linux Python container, exercising Linux journal fsync. Both test containers were removed after ownership checks. The dedicated hosted historical workflow [43084947989](https://github.com/rayfeeney/OrchidApp/actions/runs/43084947989) also passed on source commit `fd08fe7220cca19d4323b69cdb532a92cd98c3cf`, independently verifying both the original fixture and the new operational core. Source review and the required pre-commit hook passed with no generated schema/checksum differences; normal CI and merge status are tracked on [PR #383](https://github.com/rayfeeney/OrchidApp/pull/383). Real systemd/mask, complete CLI and installed/recovery acceptance remain pending. No production adoption or migration was performed or approved.

Owner-reported Pi 1 state remains app/importer/timer stopped, MariaDB running, source checkout `bcc4e7d`. The current local archive `/opt/orchidapp-rollbacks/20261111T175203Z.tar.gz` passed integrity verification but is not restore-tested or verified off-device. Evidence for a different earlier backup does not satisfy these gates for this stopped recovery set. Live apply must remain blocked until implementation verification, recovery prerequisites and explicit approval are complete.

## Pi 1 root-password compatibility follow-up

The merged read-only command at `ca17bb7` reached Pi 1 but password-free root authentication was rejected. Inspection made no database changes. A follow-up adds `--ask-root-password` for the existing root account; it does not change authentication, grants or accepted schema/history. Fifteen safety checks pass locally, including hidden-prompt failure behavior and child-only credential transport. Its isolated database and hosted validation are recorded in the [adoption evidence](maintenance/pi130-operational-adoption.md). Live adoption remains unperformed and unapproved.

## Confirmed baseline

Verified 30 October 2026: source baseline `283eb06c9bcb3a9d8fc220b9d21e4c6fe7daecac`; [normal CI 40780100240 passed](https://github.com/rayfeeney/OrchidApp/actions/runs/40780100240). [Full historical Linux acceptance 40777537302 passed](https://github.com/rayfeeney/OrchidApp/actions/runs/40777537302) on PR head `0f5a3b825a52dc104b4d245f36c5e899356d7b34`, whose Git tree is identical to the merged baseline (`7cb0497de9716c141f2472c09ea81d15a5e141af`). This is isolated package/application/recovery evidence, not live Pi/systemd/provider/browser or Windows installed acceptance.

The owner designates this source baseline for the planned v1.4.0 release; that is a release plan, not a claim that v1.4.0 packages have been built or published. The checkout was clean and matched origin/main at verification. Source-baseline confirmation is closed. No product version is changed by this documentation delivery.

## Subsequent security maintenance

MySqlConnector GHSA-473q-m89c-ghf8: launcher 2.5.0 and Web transitive 2.4.0 updated in source to 2.6.1. Local build, configuration/policy checks, dependency audit and all 186 isolated SQL/HTTP tests passed. GitHub CI and rebuilt installed release acceptance remain pending. See [security update evidence and adoption](maintenance/mysqlconnector-security.md). This is new maintenance after closure of C01–C20.

## Windows .NET 8 startup maintenance

An installed Windows build reset browser requests when EF Core tried to load DiagnosticSource 9. The web project targeted .NET 8, but Pomelo 9 resolved EF Core 9 and its logging dependencies. The package also published the launcher over the web app in a shared directory, where the launcher could replace shared runtime files. The installer copies that directory, including DLLs.

The candidate uses Pomelo 8.0.3, EF Core 8.0.33 and the existing patched MySqlConnector 2.6.1. The Windows build publishes the launcher first, skips its development content bundles and checks the final DiagnosticSource assembly. Package database cleanup uses a unique local named pipe with TCP disabled to isolate the staged copy from installed MariaDB. The repo selects SDK 8, checks project frameworks at build time and verifies the web lockfile in CI.

Local checks passed for locked restore, Release build, Linux ARM64 publish, Windows package inventory, unsigned Inno installer compilation and isolated application, migration-policy, installer-policy and native photo suites. The Windows package contains DiagnosticSource assembly version 8.0.0.0. Hosted CI and release-machine acceptance are pending. Record Windows clean install and v1.4.0 upgrade readiness, database and photo preservation, photo upload/reopen and restart on disposable fixtures. Confirm the Linux ARM64 build and readiness separately. See the [upgrade checklist](upgrade-checklist.md).

## Windows restore preflight maintenance

Installed testing found two pre-replacement failures. A OneDrive reparse-point ZIP was rejected before opening, and a regular local ZIP passed archive validation but stopped during safety backup when a second MariaDB process tried to open the running database's data directory. No restore SQL started. The retained copy remains available for recovery.

The candidate checks the actual loopback endpoint and verifies its database directory before reusing it. Only a refused connection permits a new server start. The archive path guard now explains how to select a regular local copy. The 57 source/recovery checks and 80 disposable Windows database checks passed, including alias rejection and restore with an already running database. Installed testing confirmed local restore. OneDrive input now accepts Windows Cloud Files tags and stages the ZIP in the existing local recovery directory before validation. Installed OneDrive testing stopped before copying because Windows PowerShell could not compile the file-tag helper from the packaged application directory. The helper now reports the native error using a core exception type that does not require the conflicting assembly reference. A rebuilt installer still needs end-to-end OneDrive restore and unavailable-file acceptance. See the [Windows backup and restore contract](windows-backup-format.md).

## Fixed work list

1. **Procure the new Pi.** Complete. Raspberry Pi 2 has been received and is available for the planned recovery, upgrade rehearsal and standby implementation. Installation and recovery acceptance remain covered by subsequent work-list items.
2. **Complete developer setup on the new PC.** Complete - 7 November 2026 reconciliation. New-PC development environment established and verified. Developer setup acceptance completed, closing the remaining C16 new-PC acceptance requirement.
3. **Reconcile status documents.** Complete. C05/C16 status, superseded pending statements and agreed scope decisions reconciled. Historical acceptance evidence preserved. Documentation changes applied and merged into `main`.
4. **Record the live Pi baseline.** Complete - 7 November 2026. Read-only evidence collected for hardware, operating system, software versions, published application, database schema and migration history, configuration structure, services, scheduled jobs, backup arrangements and file locations. See [Live Raspberry Pi Baseline](live-pi-baseline-2026-11-07.md). The deliberately absent test migration is an accepted exception. Exact binary provenance remains unverified. Remote backup objects were confirmed present, but backup integrity and restoration are reserved for item 5.
5. **Create a complete recovery backup of the live Pi.** Complete — 7 November 2026. Captured matching MariaDB database, photographs, deployed application binaries, configuration, service definitions and scheduled jobs while application writers were stopped. Original services were restored successfully. Archive integrity and local SHA-256 checks passed. All five recovery files (605.054 MiB) were uploaded to encrypted OneDrive storage at `orchidcrypt:recovery-2026-11-07`. Independent download-based verification confirmed five matching files and zero differences. Recovery functionality will be tested on Pi 2 under item 6.
6. **Restore onto the empty new Pi. — COMPLETE (7 November 2026).** Restored and verified the original OrchidApp application, database and photographs on Pi 2. Confirmed application functionality, existing data, photographs and services. Automatic startup, scheduled backups and environmental data imports are disabled; no external writers are active. Pi 1 remains live and unchanged.
7. **Rehearse the restored Pi upgrade to v1.4.0.** Build the actual release package from the agreed baseline; record commit/checksum, resolve compatibility, verify functionality and data/photo preservation, and retain the proven procedure/results.
8. **Upgrade the live Pi.** Take a fresh recovery backup, follow the proven procedure and verify the result.
9. **Implement daily cloud-backup restoration to the second Pi.** Matching data/photos/configuration and compatible software; readiness/photo/disposable add-save-reopen checks; retain the last working recovery state on failure. Standby test writes must never reach live data or cloud backups. Verify that historical database backups cannot be paired silently with incompatible or missing photographs. Recovery must preserve the last known working state and report incomplete or inconsistent backup pairs.
10. **Monitor freshness and send failure alerts through GMX.** Block 1 installed 13 November: GMX delivery to `bloodandsand44@gmail.com` confirmed for success, failure and overdue tests; maximum backup recovery-point age 30 hours, monitor every 15 minutes. Independent power-cut monitoring is outside agreed scope. First overnight scheduled backup/report and Block 2 restore/freshness/reporting remain pending; confirm restoration of the exact new snapshot before closing this item.
11. **Complete operational acceptance.** Reboot/autostart, service/file permissions, usual browsers/devices and photo upload; Home Screen/installed web-app behavior where used; monitoring feeds/charts and scheduled backups during takeover. Include representative plant lifecycle and history operations, transaction-failure and concurrency checks where appropriate, and photo metadata, orientation and consistency checks. Use existing automated evidence where sufficient; reserve installed-system testing for behaviour that requires it.
12. **Document and rehearse takeover.** Isolate the former live Pi, switch access, enable required jobs and ensure only one Pi is live. Repair the former live Pi and establish it as the new warm standby; no automatic switch-back.
13. **Establish the v1.4.0 Windows baseline.** Complete. Clean installation and independent offline restore passed, including the restart check. The sanitised Windows v1.4.0 specimen was established for future upgrade and recovery testing. Launcher backup/restore defects remain open. WIN-PHOTO-02 has a development candidate with Windows native checks; hosted Linux, installed Windows/Pi, and real phone acceptance remain pending. See [mobile photo evidence](maintenance/win-photo-02.md). Earlier Windows upgrade paths remain outside scope.

## Scope and accepted records

- Earlier Windows-to-v1.4.0 upgrades, including older legacy migration acceptance, are outside the agreed release scope. They are not recorded as passed. Future Windows CI upgrades start with the preserved v1.4.0 specimen.
- CHAT-R08: future capture free-space protection is deferred optional tooling. The original disk-full incident is resolved; no immediate recapture is required.
- CHAT-R09: clearer future build/source identity reporting is deferred. The frozen historical binary source remains unproven; preserve its exact bytes/checksums rather than invent provenance.
- CI action/runtime and runner-image notices are deferred routine maintenance; successful CI establishes no immediate failure.
- CHAT-D01: four absent photo references on inactive historical specimen records are accepted known data; no missing active reference was found. This is not a live-data repair instruction.
- The exact fixture adoption helper does not authorise a live Pi upgrade. Tasks 4–7 must establish compatibility and a supported procedure for the actual installation.

## Evidence and closure

Keep original maintenance reports and historical snapshots. Their counts, failures and delivery-stage pending statements remain historical; this dated reconciliation records later results without changing them. A new release must retain its exact package identities/signing status and completed per-machine [upgrade record](upgrade-checklist.md#per-upgrade-completion-record). Mark excluded cases inapplicable with a reason, not passed. When completing a task, record actual outcome and remaining limits; this list does not certify future upgrades or ongoing daily operations.
