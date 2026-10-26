# Upgrade action checklist: C01–C20

This is the single list of deployment actions arising from C01–C20. Use the Windows or Linux section for the machine being upgraded. Development setup is separate. Detailed procedures remain in the linked platform guides.

**This is a maintained draft, not approval to deploy all twenty issues.** C12–C15 and C18–C20 are unfinished. Their migration names, configuration decisions and final acceptance commands must be filled in when implemented. C11 now has a specific migration/adoption review below, with Linux CI and installed acceptance pending. An upgrade advertised as containing all C01–C20 is not ready until those rows are resolved and its actual package passes acceptance. The [backlog](code-change-backlog.md) owns implementation status; a merge or successful CI run is not installed-machine acceptance.

## How to use and maintain this list

- For each release, record the exact version/commit, target machine and platform below. Tick each applicable action and record evidence; mark inapplicable actions with a reason. A tick from another machine/release does not carry forward automatically.
- One-time configuration is needed on first adoption or when the setting/path changes. Every-upgrade checks must still be repeated. Failure/recovery actions apply only when that condition occurs.
- Each remaining C-item implementation must update its coverage row and the applicable platform steps in the same change. Record actual migration filenames, supported upgrade origins, changed settings/defaults and recovery instructions. Do not leave deployment consequences only in release notes or a delivery changelog.
- Before packaging, freeze a copy of this checklist for that release alongside its validation evidence. Keep private paths/credentials and machine-specific completed records outside the public repository. A private completed document is sufficient initially; the eventual tracking tool/automation is undecided.
- New items may automate a step later. Until then, the listed operator/release-owner action remains explicit. Do not assume the current installer performs unfinished C18 safeguards or C19 readiness checks.
- For database-changing source commits, stop the development app and run `pwsh ./scripts/DevSetup/update-database.ps1`, then retry the commit. The command reads the repository `.env`, makes a SQL backup outside the repo and applies pending migrations; the hook reads the same file. The exporter still refuses pending/older history rather than changing source files. Do not bypass it. See [C11's developer procedure](maintenance/c11-manual-closure.md#development-checkout-before-committing). This source workflow is separate from either deployed platform's upgrade procedure.

## Windows: release preparation

- [ ] **Every release — identify the supported upgrade path.** Record old/new versions and package identity. Test the actual installer against a disposable representative older installation, including data preservation, restart and recovery. The separate older-installation fixture task and C18 remain open; do not infer compatibility from fresh-schema tests. (C01/C02/C04/C10/C18/C20)
- [ ] **Every release — build the complete distribution.** Use the Windows packaging/installer process with application, launcher, runtime, schema/bootstrap manifest, complete migration set and shared backup/restore helpers. Source changes-only ZIPs are applied to the source checkout, not copied over an installed application. Retain the prior installer and verify the produced artifact's signing status rather than assuming it. (C01/C02/C04/C06–C10/C18)
- [ ] **For C11 and future C12–C15 — finalise database/configuration changes.** Include `202610261200_AtomicManualPlantClosure.sql` for C11. List subsequent exact migrations and any photo-policy setting change when C12–C15 are implemented. Test against an existing isolated database, preserving history/checksums. (C11–C15)
- [ ] **Every release — record relevant CI, database, installer and native-photo evidence.** Include revision/runtime versions, failures, skipped checks and remaining device tests. The final readiness/recovery criteria must include the completed C19/C20 work. (C05/C15/C18/C19/C20)

## Windows: actions on the installed machine

### Before installing

- [ ] **First adoption of C11 — preserve evidence of old closure failures.** After the verified backup, run the read-only `database/scripts/Review-ManualPlantClosure.sql` against the explicitly selected collection database. Review returned ended/open or invalid-interval records using the [C11 adoption guidance](maintenance/c11-manual-closure.md). Results are not automatic repair instructions. The migration does not rewrite historical data and already-ended plants remain read-only in Edit. (C11)

- [ ] **Every upgrade — identify and preserve the collection.** Record the current app/data/uploads/settings/backup locations and versions privately. Take a verified recoverable backup and retain a separate off-computer copy before changing files. Include rollback application/configuration as needed; a SQL-only backup is insufficient. The current installer does not provide a universal pre-install backup gate. (C06–C10/C18)
- [ ] **Every upgrade — stop the application and other writers.** Close OrchidApp and follow the [Windows upgrade contract](windows-upgrade-contract.md). Do not manually merge, delete or overwrite ambiguous legacy/ProgramData data folders. (C06/C10/C18)
- [ ] **Only if using administration scripts — supply the explicit target.** Securely provide MARIADB_HOST, MARIADB_PORT, MARIADB_DATABASE, MARIADB_USER and MARIADB_PASSWORD in the invoking environment. These scripts do not load the development .env or infer MYSQL aliases. Desktop startup uses its own configured connections instead. (C04/C16)

### Install and first start

- [ ] **When C11 is pending — include/apply `202610261200_AtomicManualPlantClosure.sql`.** The complete Desktop package must carry the migration and updated schema/bootstrap/checksums. Let the normal Desktop preflight/backup/migration route apply it once, or use the reviewed manual runner route; do not do both. No new site setting is required. Fresh creation already includes the fix without migration replay. (C11)

- [ ] **Every upgrade — use the tested installer.** Preserve ProgramData and external data/configuration. An existing collection must not be run through rebuild.ps1 or fresh-schema creation. C01/C02 changed fresh creation, not the collection-upgrade route. (C01/C02/C18)
- [ ] **If legacy data is detected — let the launcher use the verified source.** Retain the original source, staging and safety archive. If it reports ambiguity, changed source, unsupported state or an interrupted operation, stop for review instead of deleting state/target files. (C06/C07/C10)
- [ ] **If database migrations are pending — require successful preflight and backup.** Desktop applies the compatible later migrations through its backup gate; do not separately apply them again. If intentionally using the manual runner, plan first and take the backup yourself. Keep all migration files/history unchanged. (C02/C04 and future C11–C14)
- [ ] **First adoption of C09, and after backup-path changes — check actual backup locations.** Routine archives normally retain three verified unprotected ZIPs; protected/unrecognised files can increase that number. Migration safety copies go to backups/pre-migration, legacy safety copies to backups/pre-upgrade. Verify the intended local/cloud destination and available capacity. No existing archives are moved automatically. (C09)

### Verify before returning to use

- [ ] **After adopting C11 — verify manual closure on disposable data.** Use an unended test plant with open location and flowering, set a valid end date in Edit, save and reopen. Verify the plant and both open intervals have the same end timestamp and the ended plant is read-only. Failure/rollback injection belongs in the isolated C11 suite, not the collection database. Retain/review any historical audit findings separately. (C11)

- [ ] **Every upgrade — verify the real collection, not only Home.** Check representative plant/history rows, settings, plant and taxon photographs/thumbnails, a disposable save/reopen and photo upload/reopen, and a clean restart. Confirm the configured upload path and native image processing work. Remove only your disposable test records through supported application actions. (C07/C15/C19)
- [ ] **When C12–C14 are included — use their approved lifecycle acceptance procedure.** Test ended-plant/event/date behavior on disposable representative data, history ordering and structural operations. Do not alter valuable history as an upgrade test. These additional scenarios are pending implementation; C11's specific closure check is above. (C12–C14)
- [ ] **When C15 is included — check its final photo policy.** Verify new-photo orientation, colour and agreed metadata/GPS behavior. Whether existing files require any action is undecided; do not bulk rewrite them on assumption. (C15)
- [ ] **Every upgrade — verify a new backup and recovery route.** Check that the actual backup succeeds, needed photos/settings are present, retention preserves recovery inputs and the off-computer copy is available. Test restore only on an isolated target; retain pre-upgrade material until acceptance is recorded. (C07–C09/C18/C19)
- [ ] **On failure only — preserve evidence and use the documented recovery route.** Incomplete SQL may be partially applied. Pending migration/restore markers and their retained input/safety archives must not be deleted to force startup. Consult [migration recovery](migration-runners.md) and [Windows restore recovery](windows-backup-format.md#failure-and-acceptance-boundaries). Reinstalling older binaries alone is not a database rollback. (C04/C08/C10/C18)

Windows monitoring remains disabled; C03 requires no Windows activation. C16 development .env behavior does not configure an installed Desktop application. No separate normal-user setting has been introduced for C06–C10, but the full updated package and the checks above are required.

## Linux/Pi: release preparation

- [ ] **Every release — identify and test the supported origin/target.** Record old/new versions, OS/architecture, MariaDB/native runtime and exact app publication. Test a representative existing installation on a disposable target, including later migrations and recovery. Cross-publishing/CI does not certify Pi hardware or a real older installation. (C01/C02/C04/C05/C18/C20)
- [ ] **For C11 and future C12–C15 — finalise exact migration/policy instructions.** Include `202610261200_AtomicManualPlantClosure.sql` for C11; record later migration filenames and any changed photo setting/default when implemented. Test against existing data and update this checklist. Do not invent future migration or data-conversion steps. (C11–C15)
- [ ] **Every release — retain compatible binaries/configuration and test evidence.** Distribute complete schema/bootstrap/migration/script assets as applicable. Include the backup Python helper with both entry points. Record CI, database, native-photo, service and recovery results separately, including skipped cases and final C19/C20 criteria. (C01/C02/C04/C15–C20)

## Linux/Pi: actions on the installed machine

### Before changing application/database files

- [ ] **First adoption of C11 — review existing closure inconsistencies.** After a verified backup, run the read-only `database/scripts/Review-ManualPlantClosure.sql` using the explicitly selected collection database. Investigate findings under [C11 guidance](maintenance/c11-manual-closure.md); do not bulk close/reopen rows or clear ended dates to force an edit. The new procedure does not retrospectively repair data. (C11)

- [ ] **Every upgrade — record the current installation privately.** Identify service account/units/timers, app version/root, actual MariaDB endpoint/database, uploads, external settings, backup destinations and keys. Preserve grants and effective service definitions needed for replacement recovery. (C03/C16/C17/C18)
- [ ] **Every upgrade — take a verified stopped-writer backup.** Follow the [full pre-upgrade guide](user-guides/linux/Full-App-Backup-Pre-Upgrade.md), stop all relevant writers and retain a verified off-device copy plus compatible app/configuration rollback material. Omit the bespoke importer on general installations. Do not rely on an old SQL dump plus today's uploads mirror. (C17/C18/C19)
- [ ] **First adoption of C03, or if service settings change — preserve monitoring choice.** On the owner's supported Linux ARM/ARM64 installation, put Monitoring__Enabled=true in private service configuration and retain it through deployment. General installations leave it absent/false. The monitoring importer, objects and grants are not general installation prerequisites. (C03)
- [ ] **Every manual database upgrade — set explicit administration credentials/target.** Supply the five MARIADB_HOST/PORT/DATABASE/USER/PASSWORD values securely. Verify this is the intended existing database; the runtime connection string does not configure migration tools. Use PowerShell 7 and the supported MariaDB tools. (C04/C16)

### Apply the upgrade

- [ ] **When C11 is pending — apply `202610261200_AtomicManualPlantClosure.sql` through the canonical runner.** Confirm it appears in PlanOnly, keep writers stopped and the backup verified, then apply once and retain the recorded checksum/history. Deploy matching schema/bootstrap/checksums for future fresh installs. No new site setting is needed; do not run schema creation over the collection. (C11)

- [ ] **Every upgrade — keep writers stopped during migration/deployment.** Follow [Linux installation/upgrades](user-guides/linux/installation-upgrade.md). Preserve uploads and external configuration while publishing/replacing application files. Do not run fresh schema creation over an existing or restored collection. (C01/C02/C04/C18)
- [ ] **If pending migrations exist — plan, then apply once.** Use Apply-Migrations.ps1 -PlanOnly, review the pending list against the release, confirm the recoverable backup, then use the canonical runner. It does not take a backup automatically. Preserve checksums/history and the complete migration package. A no-DDL application release still needs backup and deployment acceptance. (C02/C04 and future C11–C14)
- [ ] **On migration failure — stop here.** Preserve the pending marker/error and backup; SQL may be partially applied. Investigate or restore through the tested isolated recovery route before retrying. Do not clear a marker, rewrite ledger rows or downgrade binaries as a substitute for database recovery. (C04/C18)
- [ ] **First adoption of C17 — replace the old backup setup before relying on it.** Install Python 3.9+ and the other [runbook prerequisites](user-guides/linux/OrchidApp-MariaDB-Backup-and-Restore-Runbook.md). Configure private backup.json, stable collection UUID, shared client defaults, uploads/configuration paths, mode-700 backup root, private log/rclone config, dedicated remote and every actual writer unit. Keep both Bash scripts and orchid_backup.py together. An old no-argument cron job will now fail; update and test that exact scheduled invocation. (C17)
- [ ] **First adoption of C17, or after account/path/provider changes — test before scheduling.** Run manual paired capture and restore to a disposable isolated server; verify rows/photos/settings. Test as the scheduling account with a minimal environment, noninteractive service-control rights and explicit client/rclone paths. Configure the schedule, failure notifications and log rotation only after that succeeds. (C17)
- [ ] **First adoption of C17, then periodically — review capacity/retention.** Default local retention is 14 verified unpinned pairs, minimum one. Preserve recovery pins. Remote deletion is manual; old SQL-only objects and the uploads mirror remain untouched. Retain keys/off-device recovery material separately. (C17)

### Restart and verify before returning to use

- [ ] **After adopting C11 — save/reopen a disposable manual closure.** On an unended test plant with open location and flowering, save a valid end date and verify all three ends match and Edit becomes read-only. Run SQL/HTTP rollback injection only against the generated isolated fixture, not the collection. Historical audit findings remain a separate review. (C11)

- [ ] **Every upgrade — restore the intended service states.** Start the app and only those optional units/timers that should be active. Verify external connection/upload settings, service account access and native image dependencies. C17 scheduled mode restores only previously active configured writer units; that does not prove app readiness. (C03/C16/C17/C19)
- [ ] **Every upgrade — test actual application behavior.** Check collection rows/settings, plant/taxon photos/thumbnails, disposable save/upload/reopen and restart. On the owner's installation check monitoring summaries/charts/feeds; on general installations confirm no monitoring dependency. (C03/C15/C19)
- [ ] **When C12–C14 are included — run their approved disposable lifecycle acceptance cases.** Cover allowed corrections on ended plants, dates/intervals, structural operations and history ordering. These additional cases remain pending; C11's specific closure check is above. (C12–C14)
- [ ] **When C15 is included — verify its final photo metadata/orientation/colour policy.** Do not assume existing photos are rewritten or need conversion; record the implemented decision first. (C15)
- [ ] **Every upgrade — check backup operation after deployment.** Verify a new paired archive, exact remote read-back, intended local retention, available space and the next scheduled run/notification. Keep pre-upgrade backups until recovery/application acceptance is recorded. (C17–C20)
- [ ] **On restore failure — preserve input and RESTORE-PENDING.json.** Do not retry blindly into partial SQL. Use an isolated, empty same-name database and new destination for a controlled recovery; review staged configuration privately before activation. A restored data marker is not application acceptance. (C17/C18/C19)

## C01–C20 coverage and unresolved decisions

Every issue is listed, including those with no site configuration. This table is not a claim that all issues are implemented.

| Item | Windows upgrade consequence | Linux upgrade consequence | Still to settle before an all-items release |
| --- | --- | --- | --- |
| C01 | Package creation assets; never recreate collection DB | Same; fresh creation is a separate procedure | Representative old-installation acceptance |
| C02 | Preserve baseline/history; use compatible later migrations | Same | Representative historical ledger compatibility |
| C03 | Monitoring stays off | Preserve owner's explicit opt-in; off elsewhere | Owner-device acceptance |
| C04 | Desktop backup gate, or explicit manual-script credentials/backup | Explicit credentials, plan, manual backup and apply | Review actual release migration plan; handle failures explicitly |
| C05 | Release-owner CI evidence, no site setting | Same | Verify evidence for the shipped revision |
| C06 | Complete launcher/tools; retain verified legacy source/safety copy | Windows-specific; no Linux source migration step | Installed legacy-upgrade acceptance |
| C07 | Updated tools and isolated photo/settings restore acceptance | Windows archive format; Linux uses C17 | Installed recovery acceptance |
| C08 | Preserve restore input/safety/journal; explicit recovery on failure | Windows-specific journal; Linux uses C17 marker | Interactive installed recovery acceptance |
| C09 | Verify new retention/destinations; protected extras may accumulate | Windows retention rules do not apply; use C17 | Installed retention/capacity acceptance |
| C10 | Preserve reconciliation state/source; stop on ambiguity | Windows-specific source reconciliation | Representative interrupted/old-version acceptance |
| C11 | Apply `202610261200_AtomicManualPlantClosure.sql`; read-only historical review and disposable save/reopen | Same through manual runner with explicit backup | Implemented/local DB+HTTP passed; Linux CI/installed acceptance pending; no automatic historical repair |
| C12 | Deploy approved lifecycle policy and test it | Same | Policy approval, migration/config needs; not implemented |
| C13 | Deploy required transaction fixes and test failures/concurrency | Same | Findings, exact migrations and recovery implications; not implemented |
| C14 | Deploy/test agreed history ordering | Same | Ordering policy and migration needs; not implemented |
| C15 | Verify native photo policy; possible setting change | Same on Linux native runtime | Metadata/orientation decision, existing-photo policy; not implemented |
| C16 | Developer setup separate; deployed runtime/upload settings still checked | Same; preserve production settings/native dependencies | Fresh-machine/platform acceptance; .env is Development-only |
| C17 | No Linux-backup configuration on Windows | One-time backup reconfiguration, restore/schedule tests and ongoing monitoring | Linux CI, real services/cron/provider/Pi acceptance |
| C18 | Tested installer, backup policy and recovery path | Test actual platform upgrade/recovery; do not assume installer behavior | Final backup policy/packaged acceptance; not implemented |
| C19 | Verify actual DB/files/native/app readiness | Same | Final diagnostics, compensation and acceptance steps; not implemented |
| C20 | Release-owner reproducible checks/evidence | Same | Final test inventory/evidence process; not implemented |

## Per-upgrade completion record

Keep a completed copy privately for each machine. Do not put passwords/connection strings in it.

| Record | Value/evidence |
| --- | --- |
| Machine / platform / operator | |
| Old version and new version / exact commit | |
| Package identity / checksum / signing status where applicable | |
| Included C-items and approved supported upgrade origin | |
| Checklist revision and inapplicable steps with reasons | |
| Verified pre-upgrade backup and off-device recovery reference | |
| Exact pending/applied migrations and result | |
| One-time settings/schedule changes completed | |
| App / photos / lifecycle / monitoring acceptance results | |
| Backup/read-back / restore / scheduled-run evidence | |
| Failures, pending markers and recovery decision | |
| Remaining limitations, release decision, date and owner | |

The eventual storage/tracking/automation for these records is intentionally undecided. The maintained checklist and a release-specific completed record provide a clear manual process in the meantime.
