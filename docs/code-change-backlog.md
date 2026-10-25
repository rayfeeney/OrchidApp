# Code change backlog

Documentation correction baseline: OrchidApp-clean.zip, reviewed 24 October 2026. The original documentation delivery left all items open. Subsequent implementation status is recorded below. Priorities are proposed implementation order: P1 affects creation, data recovery or the agreed installation boundary; P2 is subsequent correctness, consistency or validation work. Investigation items need policy/design confirmation before behaviour changes.

The database must be creatable from schema and required seeds alone, with no migration SQL dependency. Bespoke environmental monitoring belongs only to the owner's local installation and must default off elsewhere. These owner requirements take precedence over earlier platform-wide descriptions.

## Work order

Agreed order (20 issues in 18 steps):

| Phase | Issues in order |
| --- | --- |
| 1 - Database foundations | C03, C01+C02, C04, C16, C05 |
| 2 - Data protection | C06+C07, C08, C10, C09, C17 |
| 3 - Plant lifecycle | C11, C12, C13, C14 |
| 4 - Photos and readiness | C15, C19 |
| 5 - Installation validation | C18 |
| 6 - Testing and evidence | C20 |

Record actual evidence at each step.

| ID | Priority | Type | Change |
| --- | --- | --- | --- |
| [C01](#c01) | P1 | Confirmed defect / agreed requirement | Make fresh schema creation portable and dependency ordered |
| [C02](#c02) | P1 | Agreed requirement / current dependency gap | Supply schema-contained baseline identity for future upgrades |
| [C03](#c03) | P1 | Agreed requirement | Restrict bespoke monitoring to the owner’s installation |
| [C04](#c04) | P1 | Confirmed enforcement gap | Reconcile migration runners and enforce compatible history |
| [C05](#c05) | P1 | Confirmed CI coverage gap | Validate schema-only seeded creation and future upgrades in CI |
| [C06](#c06) | P1 | Confirmed source-selection gap | Bind legacy safety backup to the detected source |
| [C07](#c07) | P1 | Confirmed backup/restore format mismatch | Restore settings from the format written by backup |
| [C08](#c08) | P1 | Implemented; CI/installed acceptance pending | Make restore failure recoverable and preserve the source ZIP |
| [C09](#c09) | P2 | Confirmed parameter mismatch | Correct backup retention controls |
| [C10](#c10) | P1 | Implemented; CI/installed acceptance pending | Reconcile interrupted and completed legacy migration state |
| [C11](#c11) | P1 | Confirmed SQL defect | Correct manual lifecycle closure and its failure handling |
| [C12](#c12) | P2 | Confirmed inconsistency / policy decision required | Make temporal and ended-plant restrictions deliberate |
| [C13](#c13) | P2 | Investigation / documented transaction gap | Verify structural transaction rollback and concurrency |
| [C14](#c14) | P2 | Agreed guarantee needs design | Define deterministic history ordering if required |
| [C15](#c15) | P2 | Confirmed option/implementation mismatch | Implement or retire metadata-stripping configuration |
| [C16](#c16) | P1 | Confirmed portability/setup gaps | Make developer setup and native dependencies reproducible |
| [C17](#c17) | P1 | Confirmed personal-path and recovery consistency gap | Make Linux backup/restore portable and paired |
| [C18](#c18) | P2 | Validation gap / required operational contract | Validate packaged upgrades and recovery including app-only updates |
| [C19](#c19) | P2 | Documented consistency/readiness gap | Validate database/filesystem/native readiness and photo consistency |
| [C20](#c20) | P2 | Confirmed test inventory/evidence gap | Keep feature checks and build evidence reproducible |

## C01

**Make fresh schema creation portable and dependency ordered** — P1; Confirmed defect / agreed requirement; status: Implemented locally; Linux/native-photo acceptance pending.

Affected files/areas: database/scripts/rebuild.ps1; database/schema/; schema export tooling.

Required work: Resolve MariaDB tools by supported platform; require explicit target/credentials/charset/collation; prevent accidental production rebuild; apply views in dependency order and include required seeds. Never read/replay historical migration SQL to create a database.

Dependencies: None.

Acceptance: Create on Windows and Linux with database/migrations absent; required reference values and basic app workflows work; repeat safely only on an explicitly disposable target.

Implementation and local validation: [C01/C02 evidence](maintenance/c01-c02-schema-baseline.md). The creation script no longer drops databases. Schema-contained manifest and completion marker replace historical bookkeeping scans; existing history is preserved.

## C02

**Supply schema-contained baseline identity for future upgrades** — P1; Agreed requirement / current dependency gap; status: Implemented locally; Linux/native-photo acceptance pending.

Affected files/areas: src/OrchidApp.Web/Program.cs; database/scripts/Export-MariaDBSchema.ps1; rebuild and migration scripts; schema metadata.

Required work: Choose and implement a baseline/cutover contract carried with the schema export. Desktop creation must not enumerate migration files for bookkeeping. A new database ignores prior history and accepts only later compatible migrations. Do not hand-edit applied history.

Dependencies: C01 design coordination.

Acceptance: Fresh creation succeeds with no migration directory; reintroduce historic and one later migration: only the later change applies once. Existing Desktop baseline rows remain compatible through a reviewed upgrade path.

Implementation and local validation: [C01/C02 evidence](maintenance/c01-c02-schema-baseline.md). The creation script no longer drops databases. Schema-contained manifest and completion marker replace historical bookkeeping scans; existing history is preserved.

## C03

**Restrict bespoke monitoring to the owner’s installation** — P1; Agreed requirement; status: Implemented locally; owner device acceptance pending.

Affected files/areas: src/OrchidApp.Web/Configuration/PlatformFeatures.cs; Pages/Index.cshtml.cs; Program.cs; configuration; environment/chart tests.

Required work: Add an explicit installation-level opt-in defaulting off, retain appropriate host compatibility checks, and guard all bespoke summary/chart/net-cost queries and assets. Separate optional importer/configuration/grants from general installation. Define the actual setting name during implementation; documentation must not advertise a fictitious switch.

Dependencies: None.

Acceptance: An ordinary Linux ARM installation without any monitoring objects/settings opens Home with zero monitoring queries. Owner opt-in works on the supported local host; unsupported hosts stay off. Upgrade default and explicit preservation of owner settings are tested.

Implementation: Monitoring:Enabled defaults false and requires Linux ARM/ARM64. See [C03 evidence](maintenance/c03-monitoring-isolation.md).

## C04

**Reconcile migration runners and enforce compatible history** — P1; Confirmed enforcement gap; status: Implemented; local checks and corrected Linux CI confirmed passed by the owner.

Affected files/areas: database/scripts/Apply-Migrations.ps1; Apply-MariaDBMigrations.ps1; dev-runner.ps1; src/OrchidApp.Web/Program.cs.

Required work: Choose supported routes; enforce format, duplicate timestamps, chronology, checksum integrity and missing-history compatibility as appropriate. Correct case-sensitive paths and inconsistent endpoint defaults. Avoid deleting a legitimate baseline row or rejecting it as a missing SQL file. Document intentional per-runner differences.

Dependencies: C02.

Acceptance: Isolated tests cover tampering, duplicate/backdated names, missing files, baseline compatibility, partial-failure reporting and future-only migration application. No claim of automatic DDL rollback.

Implementation: canonical PowerShell runner plus compatibility alias, matching Desktop validation, complete preflight and a durable pending marker. See [runner contract](migration-runners.md) and [C04 evidence](maintenance/c04-migration-runners.md). No historical migration or applied baseline/checksum rows were rewritten.

## C05

**Validate schema-only seeded creation and future upgrades in CI** — P1; Confirmed CI coverage gap; status: Open.

Affected files/areas: .github/workflows/ci.yml; database schema metadata/tests; tests/.

Required work: Add isolated fresh creation without migration files, required seed/readiness checks and subsequent-migration tests. Keep assembly/drift validation separate from upgrade-history checks.

Dependencies: C01, C02, C04.

Acceptance (agreed scope): CI checks empty-environment schema-only creation, then a later migration against that current-schema database with representative test records. Required seeds, view dependencies, baseline identity, record preservation and once-only application are asserted. Older-installation fixtures and historical-version upgrade acceptance are a separate future task, as agreed with the owner.

Implementation: CI uses the production creator from a stage containing scripts/schema and no migration directory, followed by separate disposable creation/upgrade checks and canonical export/drift comparison. The expanded suite passed all 44 checks locally; 18 C# baseline policy checks and the extracted CI creation/export/drift sequence also passed. See [C05 evidence](maintenance/c05-ci-database-acceptance.md). GitHub Actions/Linux acceptance remains pending; next in the agreed order is C06+C07, legacy backup source/settings compatibility.

## C06

**Bind legacy safety backup to the detected source** — P1; Confirmed source-selection gap; status: Implemented and locally verified; new CI/installed-machine acceptance pending.

Affected files/areas: src/OrchidApp.Launcher/OrchidAppLauncherForm.cs; app/tools/backup-orchidapp.ps1.

Required work: Pass/validate the selected legacy source explicitly; identify the actual MariaDB data directory even if port 3308 already has a listener. Do not dump another local instance and then copy the discovered source. Quiesce/validate writers for raw data copying.

Dependencies: None.

Acceptance: Different install and legacy roots, unrelated 3308 listener, absent paths and concurrent source writers cannot produce a false-success safety gate; the exact intended DB and all uploads/settings are recoverable.

Implementation: launcher captures a quiescent source with writes/deletion denied, passes that captured root to backup and migrates from the same captured data. SQL data-directory identity is checked even for an existing listener, and clean shutdown/verified ZIP are required. See [C06/C07 evidence](maintenance/c06-c07-backup-source-and-format.md). Original legacy data and staging remain available; C10 still owns state reconciliation.

## C07

**Restore settings from the format written by backup** — P1; Confirmed backup/restore format mismatch; status: Implemented and locally verified; new CI/installed-machine acceptance pending.

Affected files/areas: app/tools/backup-orchidapp.ps1; app/tools/restore-orchidapp.ps1.

Required work: Consume launcher-settings/launcher-settings.json from current backups and define compatibility for older formats. Validate manifest/version/required components; handle absent uploads without silently declaring a mismatched pair complete.

Dependencies: None.

Acceptance: Round-trip representative old/current archives into isolated fixtures; verify plants, photos across categories and settings. Missing/corrupt/incompatible components fail or report an explicitly supported partial recovery.

Implementation: version 2 payload inventories and original nested settings round-trip; known unversioned/root-settings compatibility is supported. Missing/corrupt/incompatible payloads fail, and restored photo references must match extracted files. See [archive contract](windows-backup-format.md) and [local evidence](maintenance/c06-c07-backup-source-and-format.md). Archive-layout compatibility is not historical-release database acceptance. C08 adds explicit recovery after partial failure.

## C08

**Make restore failure recoverable and preserve the source ZIP** — P1; status: Implemented with local recovery checks; CI/installed-machine acceptance pending.

Affected files/areas: src/OrchidApp.Launcher/OrchidAppLauncherForm.cs; app/tools/restore-orchidapp.ps1.

Required work: Preserve trusted recovery input and offer an appropriate safety copy of existing data. Define partial-failure recovery, clear launcher state/buttons after web shutdown failure, and avoid unsafe blind retries. Do not overwrite the selected recovery file through subsequent cloud backup.

Dependencies: C07.

Acceptance: Failures after SQL/import/upload/settings phases leave a documented recovery route; launcher actions remain understandable; restart/restore does not lose the preserved input. No claim of atomic cross-filesystem/SQL rollback without implementation.

Implementation: retained input, verified safety backup, persistent phase journal/startup gate, explicit retained-input/safety recovery and cloud destination protection. See [recovery procedure](windows-backup-format.md#failure-and-acceptance-boundaries) and [C08 evidence](maintenance/c08-restore-recovery.md). SQL/filesystem replacement remains sequential, with no automatic rollback.

## C09

**Correct backup retention controls** — P2; Confirmed parameter mismatch; status: Open.

Affected files/areas: app/tools/backup-orchidapp.ps1; src/OrchidApp.Launcher/OrchidAppLauncherForm.cs.

Required work: Reconcile PruneOldBackups, SkipOldBackupPruning and BackupsToKeep; distinguish normal and pre-upgrade retention and preserve necessary recovery copies.

Dependencies: C06 coordination.

Acceptance: Test retention enabled/disabled, minimum counts, unrelated files and pre-upgrade archives; launcher arguments match declared script parameters.

## C10

**Reconcile interrupted and completed legacy migration state** — P1; status: Implemented with local reconciliation checks; CI/installed-machine acceptance pending.

Affected files/areas: src/OrchidApp.Launcher/OrchidAppLayoutResolver.cs; Infrastructure/LegacyDataMigrationService.cs; Infrastructure/MigrationStateService.cs; OrchidAppLauncherForm.cs.

Required work: Define source-preserving resume/rollback for partial copies, atomic state writes and readiness-aware completion. A retained migrated source must not indefinitely conflict with a verified ProgramData target; ambiguous unrelated sources must still stop.

Dependencies: C06, C07.

Acceptance: Interrupted copy/state-write/database-start failure and next launch are tested; verified target precedence does not guess; original source is preserved and no data overwritten.

Implementation: version 2 atomic state, exclusive operation lock, captured-source fingerprint, target ownership token, hash-checked missing-file resume and readiness-aware completion. Preserved source precedence requires matching identity; unrelated/changed sources and unsupported version 1 state stop for review. See [contract](windows-upgrade-contract.md#migration-state-and-completion) and [C10 evidence](maintenance/c10-migration-reconciliation.md). No automatic partial-target deletion/rollback is claimed.

## C11

**Correct manual lifecycle closure and its failure handling** — P1; Confirmed SQL defect; status: Open.

Affected files/areas: new database/migrations SQL; exported spUpdatePlantDetails and schema checksums; lifecycle integration tests.

Required work: Use flowering.endDate, not nonexistent flowering.endDateTime. Make the intended plant/location/flowering closure coherent on failure and validate affected lifecycle boundaries. Implement through a new migration for existing DBs and normal export for fresh schema.

Dependencies: None; upgrade acceptance uses C02/C04.

Acceptance: Save/reopen closure succeeds; injected failure does not leave contradictory partial closure; unknown dates, flowering and location intervals and split lineage remain valid.

## C12

**Make temporal and ended-plant restrictions deliberate** — P2; Confirmed inconsistency / policy decision required; status: Open.

Affected files/areas: Pages/Plants/Events/Add.cshtml.cs, Edit.cshtml.cs, Remove.cshtml.cs; Photos/Index.cshtml.cs; plant Edit; relevant SQL.

Required work: Agree the supported corrections on ended plants and enforce consistently in handlers/procedures. Reconcile repotting edit date checks, flowering time replacement, location midnight resets, photo dates and propagation-origin protection. Do not change user history silently under a documentation patch.

Dependencies: C11; owner confirms policy before behaviour change.

Acceptance: Live save/reopen tests cover Add/Edit/Remove/photo routes, ended plants, exact versus calendar boundaries and validation failures, matching the approved policy.

## C13

**Verify structural transaction rollback and concurrency** — P2; Investigation / documented transaction gap; status: Open.

Affected files/areas: location/split/propagation stored procedures via new migrations; DB integration tests.

Required work: Test actual connection transaction/error behaviour; add appropriate rollback handlers and locking where required. START TRANSACTION/COMMIT alone is insufficient evidence.

Dependencies: C11/C12 coordination.

Acceptance: Injected errors and concurrent moves/splits/propagations preserve lineage and nonoverlapping intended intervals, with no partial commit or lingering transaction.

## C14

**Define deterministic history ordering if required** — P2; Agreed guarantee needs design; status: Open.

Affected files/areas: database/schema/views/vplantlifecyclehistory.sql via migration/export; plant history queries/tests.

Required work: Current SourceId is table-local and equal-second timestamps can tie. Choose a cross-domain tie-breaker only if strict order is promised; do not infer immutable order from DATETIME.

Dependencies: C12 policy.

Acceptance: Equal timestamps and equal IDs across event types render a deterministic agreed order; date corrections and daylight-saving cases meet documented policy.

## C15

**Implement or retire metadata-stripping configuration** — P2; Confirmed option/implementation mismatch; status: Open.

Affected files/areas: src/OrchidApp.Web/Services/PhotoPipeline.cs; MediaIngestionOptions.cs; image fixtures/tests.

Required work: Decide intended metadata/privacy and orientation behaviour; implement and test actual JPEG save/rotation rules or remove unused StripGpsMetadata. Preserve intentional colour handling and alpha rules.

Dependencies: None.

Acceptance: Output fixtures demonstrate the chosen GPS/EXIF/orientation/colour policy on supported native runtimes; docs describe measured behaviour.

## C16

**Make developer setup and native dependencies reproducible** — P1; Confirmed portability/setup gaps; status: Open.

Affected files/areas: scripts/DevSetup/setup.ps1; schema exporter; development configuration; runtime restore tooling.

Required work: Reconcile MYSQL/MARIADB setup variables and client discovery; make app/script DB endpoints explicit and aligned; avoid machine-specific committed secret values. Provide a tested native libvips source-run path and supported platform tool versions.

Dependencies: C01, C02.

Acceptance: Fresh isolated development machine can install prerequisites, configure credentials/uploads, create schema-only DB, run web app, upload/reopen photo and use the hook without hidden local preparation.

Follow-up: normal Development dotnet run now reads the repository .env and uses a per-user upload default; the wrapper is optional. Production/Desktop do not read the development file.

Implementation: one explicit MARIADB target generates app configuration; committed development secrets/personal paths removed; setup validates tools/server/hooks; source run restores the complete pinned Windows native runtime and probes the actual photo pipeline. Local schema creation, actual hook, source startup, HTTP photo upload/reopen and thumbnail retrieval passed. See [C16 evidence](maintenance/c16-developer-setup.md) and [developer setup](development-setup.md). New Windows/Linux CI steps and a completely fresh OS installation remain unverified; C05 is next in the agreed order.

## C17

**Make Linux backup/restore portable and paired** — P1; Confirmed personal-path and recovery consistency gap; status: Open.

Affected files/areas: infrastructure/backups/backup_orchids.sh; Linux deployment/support tooling.

Required work: Replace fixed personal home paths with explicit configuration; validate log/backup directories and remotes before use. Define a consistent database/upload backup and historical recovery strategy (versioned photos or coordinated snapshots), observable failures, retention and tested restore. Current one-way uploads mirror cannot guarantee an old SQL snapshot has matching files.

Dependencies: None.

Acceptance: Isolated account and cron share intended credentials/rclone config; backup/restore round trip checks rows/files/config; old snapshot, concurrent writes and missing files cannot falsely report full recovery.

## C18

**Validate packaged upgrades and recovery including app-only updates** — P2; Validation gap / required operational contract; status: Open.

Affected files/areas: installer/windows/OrchidApp.iss; scripts/build-windows-installer.ps1; launcher/packaging integration tests; CI as appropriate.

Required work: Decide and implement explicit backup policy for same-layout app-only updates, then test actual installer clean install/upgrade/uninstall and data persistence. Package creation alone is insufficient.

Dependencies: C06–C10.

Acceptance: Actual isolated installer tests preserve data, enforce the approved backup policy and recover from failures; signed status is verified per produced artefact, not presumed.

## C19

**Validate database/filesystem/native readiness and photo consistency** — P2; Documented consistency/readiness gap; status: Open.

Affected files/areas: src/OrchidApp.Web/Program.cs; PhotoPipeline.cs; photo handlers; host/backup integration tests.

Required work: Define useful startup/health diagnostics and compensation for partial photo/observation writes. Do not treat a listening service or successful SQL dump as end-to-end readiness.

Dependencies: C03, C15 coordination.

Acceptance: Missing DB/upload/native dependency, partial multi-photo failure and paired backup cases are observable and leave a defined recovery path; health criteria match documentation.

## C20

**Keep feature checks and build evidence reproducible** — P2; Confirmed test inventory/evidence gap; status: Open.

Affected files/areas: tests/GreenhouseCharts.Checks; other executable checks; .github/workflows/ci.yml; evidence generation.

Required work: Choose relevant checks for CI, include greenhouse policy/calculations with disposable integration where appropriate, and record commands/revision/environment for evidence. Test cached domain-unavailable results separately from exceptions; avoid fixed historical test counts as current assertions.

Dependencies: C03; relevant fix dependencies.

Acceptance: CI/local reports distinguish isolated, DB, benchmark and device checks, run the intended fixtures only, and state actual results without suggesting production or hardware validation.

## Closure rules

For each item, record actual changed paths, implementation revision, updated document owners from documentation-map.md, checks run/results and remaining limitations. Keep schema/current exports aligned using the normal export process; never edit applied migrations. Validate destructive workflows only in isolated targets. A code item is complete only after its acceptance is demonstrated and affected guides are updated in the same change. Link related documentation review findings as needed under history/documentation-review/; those reports describe the original snapshot and may contain superseded paths/requirements.
