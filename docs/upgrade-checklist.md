# Upgrade action checklist: C01–C20

This is the single list of deployment actions arising from C01–C20. Use the Windows or Linux section for the machine being upgraded. Development setup is separate. Detailed procedures remain in the linked platform guides.

**Release and installed acceptance remain open; source CI has passed.** Verified 30 October 2026: source baseline `283eb06c9bcb3a9d8fc220b9d21e4c6fe7daecac`; [normal CI 40780100240 passed](https://github.com/rayfeeney/OrchidApp/actions/runs/40780100240). [Full historical Linux acceptance 40777537302 passed](https://github.com/rayfeeney/OrchidApp/actions/runs/40777537302) on PR head `0f5a3b825a52dc104b4d245f36c5e899356d7b34`, whose Git tree is identical to the merged baseline (`7cb0497de9716c141f2472c09ea81d15a5e141af`). This is isolated package/application/recovery evidence, not live Pi/systemd/provider/browser or Windows installed acceptance. Follow the [fixed work list and scope decisions](current-state.md). C05 is complete for its CI scope; C16 is complete following owner acceptance of the clean Windows developer-PC setup on 1 November 2026. Windows starts at v1.4.0; earlier Windows upgrade paths are outside scope. The platform steps below are a reusable checklist: mark excluded legacy paths inapplicable with that reason, rather than claim they passed. No production upgrade is authorised by a CI result.

## How to use and maintain this list

- For each release, record the exact version/commit, target machine and platform below. Tick each applicable action and record evidence; mark inapplicable actions with a reason. A tick from another machine/release does not carry forward automatically.
- One-time configuration is needed on first adoption or when the setting/path changes. Every-upgrade checks must still be repeated. Failure/recovery actions apply only when that condition occurs.
- Each remaining C-item implementation must update its coverage row and the applicable platform steps in the same change. Record actual migration filenames, supported upgrade origins, changed settings/defaults and recovery instructions. Do not leave deployment consequences only in release notes or a delivery changelog.
- Before packaging, freeze a copy of this checklist for that release alongside its validation evidence. Keep private paths/credentials and machine-specific completed records outside the public repository. A private completed document is sufficient initially; the eventual tracking tool/automation is undecided.
- New items may automate a step later. Until then, the listed operator/release-owner action remains explicit. C18 now requires a verified installer snapshot even for app-only updates. C19 readiness checks still require application acceptance.
- For database-changing source commits, stop the development app and run `pwsh ./scripts/DevSetup/update-database.ps1`, then retry the commit. The command reads the repository `.env`, makes a SQL backup outside the repo and applies pending migrations; the hook reads the same file. The exporter still refuses pending/older history rather than changing source files. Do not bypass it. See [C11's developer procedure](maintenance/c11-manual-closure.md#development-checkout-before-committing). This source workflow is separate from either deployed platform's upgrade procedure.

## Windows: release preparation

- [ ] **Every release — identify the supported upgrade path.** Record old/new versions and package identity. Test the actual v1.4.0 installer on a clean PC, including restart, backup and recovery. For this release, establish a clean v1.4.0 Windows baseline; earlier Windows upgrade paths are outside scope. Future upgrades use the preserved specimen. (C01/C02/C04/C10/C18/C20)
- [ ] **Every release — build the complete distribution.** Use the Windows packaging/installer process with application, launcher, runtime, schema/bootstrap manifest, complete migration set and shared backup/restore helpers. Source changes-only ZIPs are applied to the source checkout, not copied over an installed application. Retain the prior installer and verify the produced artifact's signing status rather than assuming it. (C01/C02/C04/C06–C10/C18)
- [ ] **For C11/C12/C13 and C15/C19 — finalise database/configuration changes.** Include `202610261200_AtomicManualPlantClosure.sql` and `202610261800_EndedPlantReadOnly.sql`. Include `202610262000_StructuralTransactions.sql`; include `202610271200_PhotoTaxonTransaction.sql` and verify the policy/readiness steps below. Test against an existing isolated database, preserving history/checksums. (C11–C15/C19)
- [ ] **Every release — record relevant CI, database, installer and native-photo evidence.** Include revision/runtime versions, failures, skipped checks and remaining device tests. The final readiness/recovery criteria must include the completed C19/C20 work. (C05/C15/C18/C19/C20)

## Windows: actions on the installed machine

### Before installing

- [ ] **First adoption of C11 — preserve evidence of old closure failures.** After the verified backup, run the read-only `database/scripts/Review-ManualPlantClosure.sql` against the explicitly selected collection database. Review returned ended/open or invalid-interval records using the [C11 adoption guidance](maintenance/c11-manual-closure.md). Results are not automatic repair instructions. The migration does not rewrite historical data and already-ended plants remain read-only in Edit. (C11)

- [ ] **Every upgrade — identify and preserve the collection.** Record the current app/data/uploads/settings/backup locations and versions privately. Take a verified recoverable backup and retain a separate off-computer copy before changing files. Include rollback application/configuration as needed; a SQL-only backup is insufficient. C18 now creates a separate verified local offline snapshot before replacement; keep the normal off-computer backup too. See [installer recovery](windows-installer-recovery.md). (C06–C10/C18)
- [ ] **Every upgrade — stop the application and other writers.** Close OrchidApp and follow the [Windows upgrade contract](windows-upgrade-contract.md). Do not manually merge, delete or overwrite ambiguous legacy/ProgramData data folders. (C06/C10/C18)
- [ ] **Only if using administration scripts — supply the explicit target.** Securely provide MARIADB_HOST, MARIADB_PORT, MARIADB_DATABASE, MARIADB_USER and MARIADB_PASSWORD in the invoking environment. These scripts do not load the development .env or infer MYSQL aliases. Desktop startup uses its own configured connections instead. (C04/C16)

### Install and first start

- [ ] **When C13 is pending — include/apply `202610262000_StructuralTransactions.sql` through the normal Desktop migration route.** Ship the matching rebuilt app, generated schema/bootstrap/checksums and complete migration package. Stop other writers for the upgrade; keep the normal verified backup/preflight gate. No new setting or data backfill is required. Do not deploy the app transaction filter against the preceding procedures, which can commit a caller transaction. (C13)

- [ ] **When C12 is pending — apply `202610261800_EndedPlantReadOnly.sql` through the normal Desktop migration route.** Deploy the matching application, generated routine/bootstrap/checksums and full migration package. There is no new site setting or historical data conversion. Ended details, events, photos and lifecycle dates become read-only; normal reactivation is unavailable. Preserve historical review findings for separate investigation rather than bypassing the new rule. (C12)

- [ ] **When C11 is pending — include/apply `202610261200_AtomicManualPlantClosure.sql`.** The complete Desktop package must carry the migration and updated schema/bootstrap/checksums. Let the normal Desktop preflight/backup/migration route apply it once, or use the reviewed manual runner route; do not do both. No new site setting is required. Fresh creation already includes the fix without migration replay. (C11)

- [ ] **Every upgrade — use the tested installer.** Preserve ProgramData and external data/configuration. An existing collection must not be run through rebuild.ps1 or fresh-schema creation. C01/C02 changed fresh creation, not the collection-upgrade route. (C01/C02/C18)
- [ ] **If legacy data is detected — let the launcher use the verified source.** Retain the original source, staging and safety archive. If it reports ambiguity, changed source, unsupported state or an interrupted operation, stop for review instead of deleting state/target files. (C06/C07/C10)
- [ ] **If database migrations are pending — require successful preflight and backup.** Desktop applies the compatible later migrations through its backup gate; do not separately apply them again. If intentionally using the manual runner, plan first and take the backup yourself. Keep all migration files/history unchanged. (C02/C04/C11/C12/C13)
- [ ] **First adoption of C09, and after backup-path changes — check actual backup locations.** Routine archives normally retain three verified unprotected ZIPs; protected/unrecognised files can increase that number. Migration safety copies go to backups/pre-migration, legacy safety copies to backups/pre-upgrade. Verify the intended local/cloud destination and available capacity. No existing archives are moved automatically. (C09)

### Verify before returning to use

- [ ] **After adopting C11 — verify manual closure on disposable data.** Use an unended test plant with open location and flowering, set a valid end date in Edit, save and reopen. Verify the plant and both open intervals have the same end timestamp and the ended plant is read-only. Failure/rollback injection belongs in the isolated C11 suite, not the collection database. Retain/review any historical audit findings separately. (C11)

- [ ] **Every upgrade — verify the real collection, not only Home.** Check representative plant/history rows, settings, plant and taxon photographs/thumbnails, a disposable save/reopen and photo upload/reopen, and a clean restart. Confirm the configured upload path and native image processing work. Remove only your disposable test records through supported application actions. (C07/C15/C19)
- [ ] **After adopting C12 — verify read-only and active-date behavior.** On disposable data confirm ended Details/Photos remain viewable, Add/Edit/Remove/photo changes and reactivation are blocked, and unended repotting/flowering/location date corrections save/reopen with existing times preserved. Do not use valuable ended history as an edit test. (C12)
- [ ] **After adopting C13 — verify failures and competing writes on disposable data.** Run `pwsh ./tests/LifecycleClosure.Checks/Database.Checks.ps1` against a separate disposable MariaDB server with its explicit test credentials and Python 3/.NET 8. Verify save/reopen for a move, split, propagation and hero photo in the installed package. Confirm a failed save leaves the prior state; refresh before retrying a contention error. This suite injects failure triggers and creates/drops generated DBs: never target the collection server. C19 adds request photo compensation and retained recovery journals; review [photo recovery](photo-handling.md). (C13)
- [ ] **After adopting C14 — verify history display in the updated app.** No C14 migration, new setting or historical conversion is required. On disposable data, confirm newest date/time first; matching timestamps use Flowering, Move, Observation, Repotting, then descending record ID within one type. Refresh and correct an unended event date to verify repositioning. Run the combined lifecycle suite against a separate disposable server for equal-ID and repeated-clock-hour cases; do not alter valuable history to create test ties. (C14)
- [ ] **After adopting C15/C19 — verify photo policy and readiness.** Apply `202610271200_PhotoTaxonTransaction.sql` with the app. Check `/health/ready` returns 200; the launcher waits for it. Verify new photo orientation, ICC colour, white alpha and default metadata removal. Audit any explicit `MediaIngestion:StripGpsMetadata=false` override: it retains metadata. Existing photos are not rewritten. Preserve `.photo-recovery` with paired backups and follow [photo recovery](photo-handling.md) on 503 or an uncertain save. (C15/C19)
- [ ] **Every upgrade — verify a new backup and recovery route.** Check that the actual backup succeeds, needed photos/settings are present, retention preserves recovery inputs and the off-computer copy is available. Test restore only on an isolated target; retain pre-upgrade material until acceptance is recorded. (C07–C09/C18/C19)
- [ ] **On failure only — preserve evidence and use the documented recovery route.** Incomplete SQL may be partially applied. Pending migration/restore markers and their retained input/safety archives must not be deleted to force startup. Consult [migration recovery](migration-runners.md) and [Windows restore recovery](windows-backup-format.md#failure-and-acceptance-boundaries). Reinstalling older binaries alone is not a database rollback. (C04/C08/C10/C18)

Windows monitoring remains disabled; C03 requires no Windows activation. C16 development .env behavior does not configure an installed Desktop application. No separate normal-user setting has been introduced for C06–C10, but the full updated package and the checks above are required.

## Linux/Pi: release preparation

- [ ] **Every release — identify and test the supported origin/target.** Record old/new versions, OS/architecture, MariaDB/native runtime and exact app publication. Test a representative existing installation on a disposable target, including later migrations and recovery. Cross-publishing/CI does not certify Pi hardware or a real older installation. (C01/C02/C04/C05/C18/C20)
- [ ] **For C11/C12/C13 and C15/C19 — finalise exact migration/policy instructions.** Include `202610261200_AtomicManualPlantClosure.sql` and `202610261800_EndedPlantReadOnly.sql`; include `202610262000_StructuralTransactions.sql` and include `202610271200_PhotoTaxonTransaction.sql` and verify the photo policy/readiness steps below. Test against existing data and update this checklist. Do not invent future migration or data-conversion steps. (C11–C15/C19)
- [ ] **Every release — retain compatible binaries/configuration and test evidence.** Distribute complete schema/bootstrap/migration/script assets as applicable. Include the backup Python helper with both entry points. Record CI, database, native-photo, service and recovery results separately, including skipped cases and final C19/C20 criteria. (C01/C02/C04/C15–C20)

## Linux/Pi: actions on the installed machine

### Before changing application/database files

- [ ] **First adoption of C11 — review existing closure inconsistencies.** After a verified backup, run the read-only `database/scripts/Review-ManualPlantClosure.sql` using the explicitly selected collection database. Investigate findings under [C11 guidance](maintenance/c11-manual-closure.md); do not bulk close/reopen rows or clear ended dates to force an edit. The new procedure does not retrospectively repair data. (C11)

- [ ] **Every upgrade — record the current installation privately.** Identify service account/units/timers, app version/root, actual MariaDB endpoint/database, uploads, external settings, backup destinations and keys. Preserve grants and effective service definitions needed for replacement recovery. (C03/C16/C17/C18)
- [ ] **Every upgrade — take a verified stopped-writer backup.** Follow the [full pre-upgrade guide](user-guides/linux/Full-App-Backup-Pre-Upgrade.md), stop all relevant writers and retain a verified off-device copy plus compatible app/configuration rollback material. Omit the bespoke importer on general installations. Do not rely on an old SQL dump plus today's uploads mirror. (C17/C18/C19)
- [ ] **First adoption of C03, or if service settings change — preserve monitoring choice.** On the owner's supported Linux ARM/ARM64 installation, put Monitoring__Enabled=true in private service configuration and retain it through deployment. General installations leave it absent/false. The monitoring importer, objects and grants are not general installation prerequisites. (C03)
- [ ] **Every manual database upgrade — set explicit administration credentials/target.** Supply the five MARIADB_HOST/PORT/DATABASE/USER/PASSWORD values securely. Verify this is the intended existing database; the runtime connection string does not configure migration tools. Use PowerShell 7 and the supported MariaDB tools. (C04/C16)

### Apply the upgrade

- [ ] **When C13 is pending — apply `202610262000_StructuralTransactions.sql` using the canonical runner after PlanOnly and a verified backup.** Keep all writers stopped until the matching app and schema assets are deployed. No new setting or historical data conversion is required. Treat app/procedures as one release: old procedures can commit the new app transaction. Preserve the normal pending-marker recovery contract for migration failures. (C13)

- [ ] **When C12 is pending — apply `202610261800_EndedPlantReadOnly.sql` with the canonical runner after PlanOnly and a verified backup.** Keep writers stopped and deploy the matching application/schema assets. No new site setting or historical conversion is required. Ended details, events, photos and lifecycle dates become read-only, without normal reactivation. Keep historical review findings separate; do not bypass the rule to repair them. (C12)

- [ ] **When C11 is pending — apply `202610261200_AtomicManualPlantClosure.sql` through the canonical runner.** Confirm it appears in PlanOnly, keep writers stopped and the backup verified, then apply once and retain the recorded checksum/history. Deploy matching schema/bootstrap/checksums for future fresh installs. No new site setting is needed; do not run schema creation over the collection. (C11)

- [ ] **Every upgrade — keep writers stopped during migration/deployment.** Follow [Linux installation/upgrades](user-guides/linux/installation-upgrade.md). Preserve uploads and external configuration while publishing/replacing application files. Do not run fresh schema creation over an existing or restored collection. (C01/C02/C04/C18)
- [ ] **If pending migrations exist — plan, then apply once.** Use Apply-Migrations.ps1 -PlanOnly, review the pending list against the release, confirm the recoverable backup, then use the canonical runner. It does not take a backup automatically. Preserve checksums/history and the complete migration package. A no-DDL application release still needs backup and deployment acceptance. (C02/C04/C11/C12/C13)
- [ ] **On migration failure — stop here.** Preserve the pending marker/error and backup; SQL may be partially applied. Investigate or restore through the tested isolated recovery route before retrying. Do not clear a marker, rewrite ledger rows or downgrade binaries as a substitute for database recovery. (C04/C18)
- [ ] **First adoption of C17 — replace the old backup setup before relying on it.** Install Python 3.9+ and the other [runbook prerequisites](user-guides/linux/OrchidApp-MariaDB-Backup-and-Restore-Runbook.md). Configure private backup.json, stable collection UUID, shared client defaults, uploads/configuration paths, mode-700 backup root, private log/rclone config, dedicated remote and every actual writer unit. Keep both Bash scripts and orchid_backup.py together. An old no-argument cron job will now fail; update and test that exact scheduled invocation. (C17)
- [ ] **First adoption of C17, or after account/path/provider changes — test before scheduling.** Run manual paired capture and restore to a disposable isolated server; verify rows/photos/settings. Test as the scheduling account with a minimal environment, noninteractive service-control rights and explicit client/rclone paths. Configure the schedule, failure notifications and log rotation only after that succeeds. (C17)
- [ ] **First adoption of C17, then periodically — review capacity/retention.** Default local retention is 14 verified unpinned pairs, minimum one. Preserve recovery pins. Remote deletion is manual; old SQL-only objects and the uploads mirror remain untouched. Retain keys/off-device recovery material separately. (C17)

### Restart and verify before returning to use

- [ ] **After adopting C11 — save/reopen a disposable manual closure.** On an unended test plant with open location and flowering, save a valid end date and verify all three ends match and Edit becomes read-only. Run SQL/HTTP rollback injection only against the generated isolated fixture, not the collection. Historical audit findings remain a separate review. (C11)

- [ ] **Every upgrade — restore the intended service states.** Start the app and only those optional units/timers that should be active. Verify external connection/upload settings, service account access and native image dependencies. C17 scheduled mode restores only previously active configured writer units; that does not prove app readiness. (C03/C16/C17/C19)
- [ ] **Every upgrade — test actual application behavior.** Check collection rows/settings, plant/taxon photos/thumbnails, disposable save/upload/reopen and restart. On the owner's installation check monitoring summaries/charts/feeds; on general installations confirm no monitoring dependency. (C03/C15/C19)
- [ ] **After adopting C12 — verify read-only and active-date behavior.** On disposable data confirm ended Details/Photos remain viewable, all event/photo/detail/date writes and reactivation are blocked, and unended repotting/flowering/location corrections save/reopen with existing times preserved. Do not test mutations on valuable ended history. (C12)
- [ ] **After adopting C13 — verify failures and competing writes on disposable data.** Run `pwsh ./tests/LifecycleClosure.Checks/Database.Checks.ps1` against a separate disposable MariaDB server with its explicit test credentials and Python 3/.NET 8. Verify save/reopen for a move, split, propagation and hero photo in the installed package. Confirm a failed save leaves the prior state; refresh before retrying a contention error. This suite injects failure triggers and creates/drops generated DBs: never target the collection server. C19 adds request photo compensation and retained recovery journals; review [photo recovery](photo-handling.md). (C13)
- [ ] **After adopting C14 — verify history display in the updated app.** No C14 migration, new setting or historical conversion is required. On disposable data, confirm newest date/time first; matching timestamps use Flowering, Move, Observation, Repotting, then descending record ID within one type. Refresh and correct an unended event date to verify repositioning. Run the combined lifecycle suite against a separate disposable server for equal-ID and repeated-clock-hour cases; do not alter valuable history to create test ties. (C14)
- [ ] **After adopting C15/C19 — verify photo policy and readiness.** Apply `202610271200_PhotoTaxonTransaction.sql` with the app. Require `curl --fail http://127.0.0.1:5000/health/ready` using the actual local listener. Verify installed libvips, upload permissions, photo/thumbnail reopen and default metadata removal with upright orientation/ICC colour/white alpha. Audit explicit `MediaIngestion:StripGpsMetadata=false` overrides; existing files are not rewritten. Preserve `.photo-recovery` with paired backups and follow [photo recovery](photo-handling.md) for unresolved records. (C15/C19)
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
| C11 | Apply `202610261200_AtomicManualPlantClosure.sql`; read-only historical review and disposable save/reopen | Same through manual runner with explicit backup | Implemented/local DB+HTTP passed; Linux CI passed; installed acceptance pending; no automatic historical repair |
| C12 | Apply `202610261800_EndedPlantReadOnly.sql`; deploy app and test ended read-only/active corrections | Same via canonical manual runner | Approved read-only policy implemented/local SQL+HTTP passed; Linux CI passed; installed acceptance pending; no retrospective repair |
| C13 | Apply `202610262000_StructuralTransactions.sql` with matching app; disposable rollback/concurrency and installed save/reopen | Same via canonical runner after backup | Implemented; native SQL/HTTP checks recorded in C13 evidence; Linux CI passed; installed acceptance pending; use cache-aware test revision v3; no additional migration/settings/action change |
| C14 | Deploy updated app; verify newest time, event type, ID order on disposable history | Same; no migration/configuration/data action | Agreed order implemented; local SQL/HTTP evidence in C14 report; Linux CI passed; installed UI acceptance pending |
| C15 | Verify default stripping, rotation, ICC and alpha; audit explicit false override | Same on installed Linux native runtime | Source implemented; existing files unchanged; Linux CI passed; installed acceptance pending |
| C16 | Developer setup separate; deployed runtime/upload settings still checked | Same; preserve production settings/native dependencies | C16 complete: new Windows developer-PC acceptance confirmed 1 November 2026; .env is Development-only; installed release acceptance remains separate |
| C17 | No Linux-backup configuration on Windows | One-time backup reconfiguration, restore/schedule tests and ongoing monitoring | Linux CI passed; real services/cron/provider/Pi acceptance pending |
| C18 | Stop writers; mandatory verified offline snapshot even for app-only updates; inspect artifact signing evidence | Existing stopped-writer paired backup and compatible app/config rollback remain mandatory for app-only updates too | Source and isolated Inno/MariaDB checks implemented; v1.4.0 administrator installer-baseline and Linux device acceptance pending; earlier Windows upgrades outside scope |
| C19 | Apply C19 migration; launcher readiness; retain/review recovery journals | Same migration; explicitly require readiness 200 after service start/restore | Source implemented; Linux/installed acceptance and concurrent backup guarantees remain unproven |
| C20 | Release owner retains isolated/DB reports, actual package/signature evidence and machine acceptance | Same; greenhouse DB uses a separate disposable service; benchmark/device results remain separate | Implemented in source; local isolated and disposable MariaDB checks passed; merged-revision CI passed; device acceptance pending; earlier Windows upgrades outside scope |

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

## C15/C19 source development adoption

Stop the development app and run `pwsh ./scripts/DevSetup/update-database.ps1` from the checkout root. It uses the existing `.env`, backs up and applies pending migrations through the canonical runner. Start with normal `dotnet run`, require readiness 200 and test new photo/thumbnail reopen. Commit normally; the hook exports schema but never applies migrations. Do not run the development wrapper against an installed collection.

## C18 adoption and failure actions

- **Windows release:** rebuild/package all three snapshot tools, build the installer and retain its actual `.evidence.json` checksum/signature result. Run the isolated C18 checks and clean-PC v1.4.0 baseline acceptance; preserve the specimen for future upgrades. A changes-only source ZIP is not installed over Program Files.
- **Windows operator, every upgrade:** retain a normal off-computer backup and prior installer; close the launcher/database/other writers and keep them stopped through setup. Setup now takes a new verified `backups/pre-install/OrchidAppUpgrade-...zip` before file replacement even with no SQL changes. Resolve pending recovery state before upgrading. On failure preserve its archive/log/staging and follow [installer recovery](windows-installer-recovery.md); this raw snapshot is not accepted by the normal Restore dialog. It is not automatically pruned.
- **Linux operator, every upgrade:** no new installer, configuration or migration is introduced by C18. Continue the C17 stopped-writer paired backup, off-device verification and compatible prior app/config preservation, including app-only updates. Test actual service/photo/readiness/restore after deployment. Windows fixture success is not Linux/Pi acceptance.
- **Source development:** no C18 migration or new setting. Normal `dotnet run` and existing `.env` credentials remain unchanged.

## C20 evidence actions for each release

- **Windows and Linux release owner:** run `python scripts/run-feature-checks.py` from source; retain its revision/environment/source fingerprint, command/result JSON and logs. CI also runs `--mode greenhouse-db` only against its new dedicated empty MariaDB service. Review failures and all `notRun` categories; record the merged revision and CI artifact links in the release/machine record above.
- Keep existing lifecycle/schema/migration, backup/recovery, native-photo and actual installer job results with those reports. A green feature report covers its listed fixtures only. Retain package checksum/signature evidence separately and finish representative older-installation and actual machine/device acceptance before claiming upgrade readiness.
- **Windows and Linux operators:** C20 adds no setting, migration, credential change or normal startup command. Existing backup/migration/deployment actions above still apply. Do not run greenhouse fixture SQL on a development or collection server. Dense benchmark and physical-device results require separate explicit records; a skipped/not-run case must never be ticked as passed.

## CHAT-R01–R03 plant-event message correction

- **Coverage:** existing add-event field errors now show beside the observation/move/repotting dates, flowering dates, new repotting medium and observation notes. Handler rules and data are unchanged; this app-only correction adds no SQL migration, `.env` setting or startup action. See [evidence and remaining acceptance](maintenance/event-validation-messages.md).
- **Windows release/operator:** include the rebuilt web app through the normal complete packaging/installer route. Retain the normal off-computer backup and C18 app-only installer snapshot. On disposable data, submit a future observation, flowering end before start and repotting without a medium; require a visible explanation and no new records. Correct each input, save and reopen successfully.
- **Linux/Pi release/operator:** republish/deploy through the existing stopped-writer backup and supported upgrade procedure, including the app-only backup requirement. Perform the same invalid/corrected-input checks on disposable data after service start. Do not replace or repair the frozen historical specimen to demonstrate the new behaviour.
- **CI/release owner:** the existing lifecycle runner now includes `ValidationMessages.Checks.py` for both generated upgraded and schema-only fixtures. Local current-source HTTP checks passed; retain the actual merged-revision CI result. Browser/device/installed and C18 historical upgrade/recovery acceptance remain separate.

## CHAT-R04 greenhouse CI deduplication

- **Windows and Linux release owner:** keep the existing isolated feature, greenhouse database and lifecycle jobs. Run the same evidence commands; require successful disjoint greenhouse `modeEvidence`. The database report now covers SQL suites only; fewer assertions there do not indicate lost isolated coverage. Preserve actual logs/source identity and the applied/merged-revision CI result. See [local validation and direct-executable behavior](maintenance/ci-greenhouse-modes.md).
- **Windows and Linux operators:** this is test/evidence code only. No application rebuild/deployment solely for this item, new migration, setting, credential or startup action is required. No fixture SQL belongs on the collection server. Existing upgrade/backup requirements for other included changes remain in force; C18 acceptance is not completed by this correction.

## Historical Linux specimen: package/application/recovery checks

- **Release/source owner:** the existing fixture release is published and unchanged; no new specimen upload is needed. The extended manual workflow defaults to reviewed admission plus ARM64 package/action/app-only/recovery checks. Disable application checks for the already proven database-only phase, or disable both for original refusal. Missing/wrong assets and incomplete phases fail. See [commands/status](historical-linux-upgrade.md) and [phase evidence](maintenance/historical-linux-application-recovery.md).
- **Packaging/CI owner:** `package-linuxpi.ps1 -NoVersionStamp -OutputRoot <new-absolute-folder> -InformationalVersionOverride <build-label>` builds unattended without modifying tracked version properties. Explicit output must be absent. A nonzero native publish now stops before ZIP creation. Normal interactive release stamping is retained. CI builds two distinct compiled test packages, configures ARM64/QEMU and records runtime identities; no release version is published by the test.
- **CHAT-R12 photo correction:** rebuild/deploy the web app through the normal complete platform package process. No migration, setting, journal deletion or one-time database operation is introduced. On an isolated clean upload root, create/save a plant without photos, then add photo plus note; require no false recovery journal and successful main/thumbnail reopen. Existing real unresolved recovery records remain protected.
- **CHAT-R10/R11:** the exact reviewed historical baseline/audit rollover remains unchanged. Four real forward migrations, zero-work repeat, unchanged pre-workflow data and exact final structure are checked before application test mutations. Original 245 records survive in the audit ledger. Injected failure SQL exists only in ignored test staging, never the production migration directory.
- **Windows/Linux operators:** this harness never contacts the collection/Pi. Current Linux container acceptance is distinct from real Pi service-account/systemd/provider and Windows installer/launcher acceptance. Existing stop-writer, full compatible recovery-set and readiness requirements remain. Do not copy fixture SQL onto the collection server or manually remove migration/recovery markers.


### Historical packaging test shell exit

CI owners: the policy script's expected failing publish must not leave a nonzero native exit after successful assertions/cleanup. Validate through GitHub-style dot-sourced PowerShell, including a deliberately failing assertion. This affects both normal feature CI and the manual historical workflow; it requires no operator, schema, setting, package rebuild or live Pi action. Preserve the evidence uploader's strict missing-file behavior. See [PR #362 correction evidence](maintenance/historical-linux-application-recovery.md).


### Hosted paired-backup diagnostics

CI owners: historical acceptance retains the production paired CLI's sanitized ERROR summary when backup/restore fails; raw native diagnostics, credentials and backup contents remain excluded from uploaded artifacts. A failed pre-upgrade backup stops migration/application replacement. This test-reporting change requires no operator/database setting or live Pi action.

Hosted CI fixture setup additionally assigns/verifies copied admin configuration as root:root mode 600 after a deliberate foreign-owner probe. Do not relax the production backup protected-file requirement. This is isolated fixture provisioning and requires no live configuration changes.

## MySqlConnector security update

This subsequent security maintenance addresses GHSA-473q-m89c-ghf8; C01–C20 remain closed. See [evidence and limits](maintenance/mysqlconnector-security.md).

- [ ] **Windows release and adoption:** build the complete Web and launcher payloads resolving MySqlConnector 2.6.1; verify both components and package inventory, then install through the normal stopped-app/verified-backup procedure. Check database-backed save/reopen, photos and readiness after restart.
- [ ] **Linux/Pi release and adoption:** rebuild the linux-arm64 Web payload resolving MySqlConnector 2.6.1; retain the normal paired backup and stopped-writer upgrade process. Verify package identity, restart, database-backed save/reopen, photos and readiness.
- [ ] **Both platforms:** retain revision/package identity and dependency-audit/CI evidence. No database migration/recreation or new setting is required; preserve TLS settings and private configuration. Old rollback binaries remain affected; recovery must retain matching application/configuration/data without treating that rollback as a security fix.
