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

Record actual evidence at each step. The order above is the original implementation sequence, not a list of unfinished implementation.

## Current status — 30 October 2026

Verified 30 October 2026: source baseline `283eb06c9bcb3a9d8fc220b9d21e4c6fe7daecac`; [normal CI 40780100240 passed](https://github.com/rayfeeney/OrchidApp/actions/runs/40780100240). [Full historical Linux acceptance 40777537302 passed](https://github.com/rayfeeney/OrchidApp/actions/runs/40777537302) on PR head `0f5a3b825a52dc104b4d245f36c5e899356d7b34`, whose Git tree is identical to the merged baseline (`7cb0497de9716c141f2472c09ea81d15a5e141af`). This is isolated package/application/recovery evidence, not live Pi/systemd/provider/browser or Windows installed acceptance.

All C01–C20 have implementation in the confirmed baseline. C05 is complete within its agreed CI scope. C16 awaits fresh new-PC developer acceptance. Remaining machine/release acceptance and owner scope decisions are recorded in the [fixed v1.4.0 work list](current-state.md). Earlier Windows upgrade paths are outside the agreed scope; v1.4.0 is the future Windows specimen baseline. Original local results/counts below remain historical evidence.


| ID | Priority | Type | Change |
| --- | --- | --- | --- |
| [C01](#c01) | P1 | Confirmed defect / agreed requirement | Make fresh schema creation portable and dependency ordered |
| [C02](#c02) | P1 | Agreed requirement / current dependency gap | Supply schema-contained baseline identity for future upgrades |
| [C03](#c03) | P1 | Agreed requirement | Restrict bespoke monitoring to the ownerâ€™s installation |
| [C04](#c04) | P1 | Confirmed enforcement gap | Reconcile migration runners and enforce compatible history |
| [C05](#c05) | P1 | Complete within agreed CI scope | Validate schema-only seeded creation and future upgrades in CI |
| [C06](#c06) | P1 | Confirmed source-selection gap | Bind legacy safety backup to the detected source |
| [C07](#c07) | P1 | Confirmed backup/restore format mismatch | Restore settings from the format written by backup |
| [C08](#c08) | P1 | Implemented; CI passed; installed acceptance pending | Make restore failure recoverable and preserve the source ZIP |
| [C09](#c09) | P2 | Implemented; CI passed; installed acceptance pending | Correct backup retention controls |
| [C10](#c10) | P1 | Implemented; CI passed; installed acceptance pending | Reconcile interrupted and completed legacy migration state |
| [C11](#c11) | P1 | Implemented with local DB/HTTP checks; Linux CI passed; installation acceptance pending | Correct manual lifecycle closure and its failure handling |
| [C12](#c12) | P2 | Implemented with local SQL/HTTP checks; Linux CI passed; installed acceptance pending | Make temporal and ended-plant restrictions deliberate |
| [C13](#c13) | P2 | Implemented; CI passed; installed acceptance pending | Verify structural transaction rollback and concurrency |
| [C14](#c14) | P2 | Agreed display order implemented; CI passed; installed acceptance pending | Define deterministic history ordering if required |
| [C15](#c15) | P2 | Implemented; Linux CI passed; installed acceptance pending | Implement or retire metadata-stripping configuration |
| [C16](#c16) | P1 | Implemented; CI passed; fresh new-PC acceptance pending | Make developer setup and native dependencies reproducible |
| [C17](#c17) | P1 | Implemented with local archive/native checks; Linux CI passed; installation acceptance pending | Make Linux backup/restore portable and paired |
| [C18](#c18) | P2 | Source/isolated checks implemented; installed acceptance pending | Validate packaged upgrades and recovery including app-only updates |
| [C19](#c19) | P2 | Implemented; Linux CI passed; installed acceptance pending | Validate database/filesystem/native readiness and photo consistency |
| [C20](#c20) | P2 | Implemented; merged-revision CI passed; device acceptance pending | Keep feature checks and build evidence reproducible |

## C01

**Make fresh schema creation portable and dependency ordered** â€” P1; Confirmed defect / agreed requirement; status: Implemented locally; Linux CI passed; installed native-photo acceptance pending.

Affected files/areas: database/scripts/rebuild.ps1; database/schema/; schema export tooling.

Required work: Resolve MariaDB tools by supported platform; require explicit target/credentials/charset/collation; prevent accidental production rebuild; apply views in dependency order and include required seeds. Never read/replay historical migration SQL to create a database.

Dependencies: None.

Acceptance: Create on Windows and Linux with database/migrations absent; required reference values and basic app workflows work; repeat safely only on an explicitly disposable target.

Implementation and local validation: [C01/C02 evidence](maintenance/c01-c02-schema-baseline.md). The creation script no longer drops databases. Schema-contained manifest and completion marker replace historical bookkeeping scans; existing history is preserved.

## C02

**Supply schema-contained baseline identity for future upgrades** â€” P1; Agreed requirement / current dependency gap; status: Implemented locally; Linux CI passed; installed native-photo acceptance pending.

Affected files/areas: src/OrchidApp.Web/Program.cs; database/scripts/Export-MariaDBSchema.ps1; rebuild and migration scripts; schema metadata.

Required work: Choose and implement a baseline/cutover contract carried with the schema export. Desktop creation must not enumerate migration files for bookkeeping. A new database ignores prior history and accepts only later compatible migrations. Do not hand-edit applied history.

Dependencies: C01 design coordination.

Acceptance: Fresh creation succeeds with no migration directory; reintroduce historic and one later migration: only the later change applies once. Existing Desktop baseline rows remain compatible through a reviewed upgrade path.

Implementation and local validation: [C01/C02 evidence](maintenance/c01-c02-schema-baseline.md). The creation script no longer drops databases. Schema-contained manifest and completion marker replace historical bookkeeping scans; existing history is preserved.

## C03

**Restrict bespoke monitoring to the ownerâ€™s installation** â€” P1; Agreed requirement; status: Implemented locally; owner device acceptance pending.

Affected files/areas: src/OrchidApp.Web/Configuration/PlatformFeatures.cs; Pages/Index.cshtml.cs; Program.cs; configuration; environment/chart tests.

Required work: Add an explicit installation-level opt-in defaulting off, retain appropriate host compatibility checks, and guard all bespoke summary/chart/net-cost queries and assets. Separate optional importer/configuration/grants from general installation. Define the actual setting name during implementation; documentation must not advertise a fictitious switch.

Dependencies: None.

Acceptance: An ordinary Linux ARM installation without any monitoring objects/settings opens Home with zero monitoring queries. Owner opt-in works on the supported local host; unsupported hosts stay off. Upgrade default and explicit preservation of owner settings are tested.

Implementation: Monitoring:Enabled defaults false and requires Linux ARM/ARM64. See [C03 evidence](maintenance/c03-monitoring-isolation.md).

## C04

**Reconcile migration runners and enforce compatible history** â€” P1; Confirmed enforcement gap; status: Implemented; local checks and corrected Linux CI confirmed passed by the owner.

Affected files/areas: database/scripts/Apply-Migrations.ps1; Apply-MariaDBMigrations.ps1; dev-runner.ps1; src/OrchidApp.Web/Program.cs.

Required work: Choose supported routes; enforce format, duplicate timestamps, chronology, checksum integrity and missing-history compatibility as appropriate. Correct case-sensitive paths and inconsistent endpoint defaults. Avoid deleting a legitimate baseline row or rejecting it as a missing SQL file. Document intentional per-runner differences.

Dependencies: C02.

Acceptance: Isolated tests cover tampering, duplicate/backdated names, missing files, baseline compatibility, partial-failure reporting and future-only migration application. No claim of automatic DDL rollback.

Implementation: canonical PowerShell runner plus compatibility alias, matching Desktop validation, complete preflight and a durable pending marker. See [runner contract](migration-runners.md) and [C04 evidence](maintenance/c04-migration-runners.md). No historical migration or applied baseline/checksum rows were rewritten.

## C05

**Validate schema-only seeded creation and future upgrades in CI** â€” P1; Confirmed CI coverage gap; status: Complete within agreed CI scope.

Affected files/areas: .github/workflows/ci.yml; database schema metadata/tests; tests/.

Required work: Add isolated fresh creation without migration files, required seed/readiness checks and subsequent-migration tests. Keep assembly/drift validation separate from upgrade-history checks.

Dependencies: C01, C02, C04.

Acceptance (agreed scope): CI checks empty-environment schema-only creation, then a later migration against that current-schema database with representative test records. Required seeds, view dependencies, baseline identity, record preservation and once-only application are asserted. Older-installation fixtures and historical-version upgrade acceptance are a separate future task, as agreed with the owner.

Implementation: CI uses the production creator from a stage containing scripts/schema and no migration directory, followed by separate disposable creation/upgrade checks and canonical export/drift comparison. The expanded suite passed all 44 checks locally; 18 C# baseline policy checks and the extracted CI creation/export/drift sequence also passed. See [C05 evidence](maintenance/c05-ci-database-acceptance.md). The schema contract job passed in confirmed CI 40780100240. C05 is complete within the agreed current-schema/future-migration scope; this does not certify a live upgrade.

## C06

Current release scope: earlier Windows legacy/older-version upgrade acceptance is outside the agreed v1.4.0 baseline scope; it is not claimed as passed. The original requirements below remain recorded for future reference.

**Bind legacy safety backup to the detected source** â€” P1; Confirmed source-selection gap; status: Implemented and locally verified; CI passed; installed-machine acceptance pending.

Affected files/areas: src/OrchidApp.Launcher/OrchidAppLauncherForm.cs; app/tools/backup-orchidapp.ps1.

Required work: Pass/validate the selected legacy source explicitly; identify the actual MariaDB data directory even if port 3308 already has a listener. Do not dump another local instance and then copy the discovered source. Quiesce/validate writers for raw data copying.

Dependencies: None.

Acceptance: Different install and legacy roots, unrelated 3308 listener, absent paths and concurrent source writers cannot produce a false-success safety gate; the exact intended DB and all uploads/settings are recoverable.

Implementation: launcher captures a quiescent source with writes/deletion denied, passes that captured root to backup and migrates from the same captured data. SQL data-directory identity is checked even for an existing listener, and clean shutdown/verified ZIP are required. See [C06/C07 evidence](maintenance/c06-c07-backup-source-and-format.md). Original legacy data and staging remain available; C10 still owns state reconciliation.

## C07

**Restore settings from the format written by backup** â€” P1; Confirmed backup/restore format mismatch; status: Implemented and locally verified; CI passed; installed-machine acceptance pending.

Affected files/areas: app/tools/backup-orchidapp.ps1; app/tools/restore-orchidapp.ps1.

Required work: Consume launcher-settings/launcher-settings.json from current backups and define compatibility for older formats. Validate manifest/version/required components; handle absent uploads without silently declaring a mismatched pair complete.

Dependencies: None.

Acceptance: Round-trip representative old/current archives into isolated fixtures; verify plants, photos across categories and settings. Missing/corrupt/incompatible components fail or report an explicitly supported partial recovery.

Implementation: version 2 payload inventories and original nested settings round-trip; known unversioned/root-settings compatibility is supported. Missing/corrupt/incompatible payloads fail, and restored photo references must match extracted files. See [archive contract](windows-backup-format.md) and [local evidence](maintenance/c06-c07-backup-source-and-format.md). Archive-layout compatibility is not historical-release database acceptance. C08 adds explicit recovery after partial failure.

## C08

**Make restore failure recoverable and preserve the source ZIP** â€” P1; status: Implemented with local recovery checks; CI passed; installed-machine acceptance pending.

Affected files/areas: src/OrchidApp.Launcher/OrchidAppLauncherForm.cs; app/tools/restore-orchidapp.ps1.

Required work: Preserve trusted recovery input and offer an appropriate safety copy of existing data. Define partial-failure recovery, clear launcher state/buttons after web shutdown failure, and avoid unsafe blind retries. Do not overwrite the selected recovery file through subsequent cloud backup.

Dependencies: C07.

Acceptance: Failures after SQL/import/upload/settings phases leave a documented recovery route; launcher actions remain understandable; restart/restore does not lose the preserved input. No claim of atomic cross-filesystem/SQL rollback without implementation.

Implementation: retained input, verified safety backup, persistent phase journal/startup gate, explicit retained-input/safety recovery and cloud destination protection. See [recovery procedure](windows-backup-format.md#failure-and-acceptance-boundaries) and [C08 evidence](maintenance/c08-restore-recovery.md). SQL/filesystem replacement remains sequential, with no automatic rollback.

## C09

**Correct backup retention controls** â€” P2; status: Implemented with local retention/native/Desktop checks; CI passed; installed-machine acceptance pending.

Affected files/areas: app/tools/backup-orchidapp.ps1; src/OrchidApp.Launcher/OrchidAppLauncherForm.cs.

Required work: Reconcile PruneOldBackups, SkipOldBackupPruning and BackupsToKeep; distinguish normal and pre-upgrade retention and preserve necessary recovery copies.

Dependencies: C06 coordination.

Acceptance: Test retention enabled/disabled, minimum counts, unrelated files and pre-upgrade archives; launcher arguments match declared script parameters.

Implementation: declared skip/count controls, minimum one backup, validated top-level routine candidates, pinned recovery/migration copies, protected safety directories and same-destination backup lock. The Desktop update backup now uses a separate non-pruning directory. Empty/hidden payload entries are preserved during ZIP creation. See [retention contract](windows-backup-format.md#routine-backup-retention) and [C09 evidence](maintenance/c09-backup-retention.md).

## C10

Current release scope: earlier Windows legacy/older-version upgrade acceptance is outside the agreed v1.4.0 baseline scope; it is not claimed as passed. The original requirements below remain recorded for future reference.

**Reconcile interrupted and completed legacy migration state** â€” P1; status: Implemented with local reconciliation checks; CI passed; installed-machine acceptance pending.

Affected files/areas: src/OrchidApp.Launcher/OrchidAppLayoutResolver.cs; Infrastructure/LegacyDataMigrationService.cs; Infrastructure/MigrationStateService.cs; OrchidAppLauncherForm.cs.

Required work: Define source-preserving resume/rollback for partial copies, atomic state writes and readiness-aware completion. A retained migrated source must not indefinitely conflict with a verified ProgramData target; ambiguous unrelated sources must still stop.

Dependencies: C06, C07.

Acceptance: Interrupted copy/state-write/database-start failure and next launch are tested; verified target precedence does not guess; original source is preserved and no data overwritten.

Implementation: version 2 atomic state, exclusive operation lock, captured-source fingerprint, target ownership token, hash-checked missing-file resume and readiness-aware completion. Preserved source precedence requires matching identity; unrelated/changed sources and unsupported version 1 state stop for review. See [contract](windows-upgrade-contract.md#migration-state-and-completion) and [C10 evidence](maintenance/c10-migration-reconciliation.md). No automatic partial-target deletion/rollback is claimed.

## C11

**Correct manual lifecycle closure and its failure handling** â€” P1; status: Implemented with local DB/HTTP checks; Linux CI passed; installation acceptance pending.

Affected files/areas: new database/migrations SQL; exported spUpdatePlantDetails and schema checksums; lifecycle integration tests.

Required work: Use flowering.endDate, not nonexistent flowering.endDateTime. Make the intended plant/location/flowering closure coherent on failure and validate affected lifecycle boundaries. Implement through a new migration for existing DBs and normal export for fresh schema.

Dependencies: None; upgrade acceptance uses C02/C04.

Acceptance: Save/reopen closure succeeds; injected failure does not leave contradictory partial closure; unknown dates, flowering and location intervals and split lineage remain valid.

Implementation: new migration `202610261200_AtomicManualPlantClosure.sql` corrects flowering.endDate, wraps the operation in an owned transaction or caller-preserving savepoint, rethrows failures and checks open interval start bounds. Canonical schema/checksums/bootstrap are regenerated through the exporter. The actual Edit-page failure stays editable with unchanged DB rows; retry succeeds. A read-only adoption review identifies historical records for investigation without rewriting them. See [C11 evidence](maintenance/c11-manual-closure.md) and the [upgrade checklist](upgrade-checklist.md). C12â€“C14 policy/concurrency work and real older-installation acceptance remain separate.

## C12

**Make temporal and ended-plant restrictions deliberate** â€” P2; status: Implemented with local SQL/HTTP checks; Linux CI passed; installed acceptance pending.

Affected files/areas: Pages/Plants/Events/Add.cshtml.cs, Edit.cshtml.cs, Remove.cshtml.cs; Photos/Index.cshtml.cs; plant Edit; relevant SQL.

Required work: Agree the supported corrections on ended plants and enforce consistently in handlers/procedures. Reconcile repotting edit date checks, flowering time replacement, location midnight resets, photo dates and propagation-origin protection. Do not change user history silently under a documentation patch.

Dependencies: C11; owner confirms policy before behaviour change.

Approved policy: ended plants are read-only, including details, lifecycle dates, events and photos. History/photos remain viewable; normal reactivation is not allowed.

Acceptance: Live save/reopen tests cover Add/Edit/Remove/photo routes, ended plants, exact versus calendar boundaries and validation failures, matching the approved policy.

Implementation: event handlers reject ended writes and scope source IDs to their plant; mutating form GETs redirect to Details. Repotting edits validate calendar dates, flowering/location corrections preserve existing times, open flowering overlap checks cover later periods, and photo uploads reject future acquisition. Migration `202610261800_EndedPlantReadOnly.sql` rejects ended detail/reactivation calls and protects propagation-child acquisition dates. Both generated schema and platform guides/checklists are updated. See [C12 evidence](maintenance/c12-ended-plant-policy.md). Concurrency/structural rollback remains C13; historical records are not rewritten.

## C13

**Verify structural transaction rollback and concurrency** â€” P2; implemented in source; Linux CI passed; installed acceptance pending.

Affected files/areas: location/split/propagation stored procedures via new migrations; DB integration tests.

C12 follow-up scope: include event/photo writes racing with plant closure and the handler/transaction coordination needed to preserve the ended read-only rule. Sequential request checks do not establish this concurrency guarantee.

Required work: Test actual connection transaction/error behaviour; add appropriate rollback handlers and locking where required. START TRANSACTION/COMMIT alone is insufficient evidence.

Dependencies: C11/C12 coordination.

Acceptance: Injected errors and concurrent moves/splits/propagations preserve lineage and nonoverlapping intended intervals, with no partial commit or lingering transaction.

Implementation: migration `202610262000_StructuralTransactions.sql` adds caller-preserving rollback/savepoints and parent-row locking to structural location/split/propagation and hero-photo procedures. A scoped page filter coordinates plant event/photo/details writes with closure, rolls back unsuccessful handlers and rejects route-ID overrides. The procedure executor enlists in the EF transaction and consumes trailing results. Same-second moves and split interval inversion are refused. See [C13 evidence](maintenance/c13-structural-transactions.md) and the platform [upgrade checklist](upgrade-checklist.md). No historical repair or filesystem/database atomicity is claimed.

## C14

**Define deterministic history ordering if required** â€” P2; agreed policy implemented; Linux CI passed; installed UI acceptance pending.

Affected files/areas: database/schema/views/vplantlifecyclehistory.sql via migration/export; plant history queries/tests.

Required work: Current SourceId is table-local and equal-second timestamps can tie. Choose a cross-domain tie-breaker only if strict order is promised; do not infer immutable order from DATETIME.

Dependencies: C12 policy.

Acceptance: Equal timestamps and equal IDs across event types render a deterministic agreed order; date corrections and daylight-saving cases meet documented policy.

Owner decision: newest stored date/time first; matching timestamps use event type ascending (Flowering, LocationChange/Move, Observation, Repotting), then SourceId descending within the same type. The Details page outer query now implements that order. No view/schema/data change or migration is required. Actual SQL/HTTP checks cover ties, type-before-ID precedence, repeated reads, date corrections, ended/inactive scope and repeated local clock-hour values. This is display stability, not insertion order or reconstructed UTC chronology. See [C14 evidence](maintenance/c14-history-ordering.md).

## C15

**Implement or retire metadata-stripping configuration** â€” P2; Confirmed option/implementation mismatch; status: Implemented in source; Linux native CI passed; installed acceptance pending.

Affected files/areas: src/OrchidApp.Web/Services/PhotoPipeline.cs; MediaIngestionOptions.cs; image fixtures/tests.

Original requirement: Decide intended metadata/privacy and orientation behaviour; implement and test actual JPEG save/rotation rules or remove unused StripGpsMetadata. Preserve intentional colour handling and alpha rules.

Dependencies: None.

Acceptance: Output fixtures demonstrate the chosen GPS/EXIF/orientation/colour policy on supported native runtimes; docs describe measured behaviour.

Implementation and evidence: [C15/C19 photo handling](maintenance/c15-c19-photo-handling.md). Windows native policy/recovery checks and isolated upgraded/fresh SQL/HTTP checks passed; isolated Linux ARM64 package/action/recovery acceptance passed in run 40777537302; real Pi and Windows installed acceptance remain pending.

## C16

**Make developer setup and native dependencies reproducible** â€” P1; Confirmed portability/setup gaps; status: Implemented; CI passed; fresh new-PC developer acceptance pending.

Affected files/areas: scripts/DevSetup/setup.ps1; schema exporter; development configuration; runtime restore tooling.

Required work: Reconcile MYSQL/MARIADB setup variables and client discovery; make app/script DB endpoints explicit and aligned; avoid machine-specific committed secret values. Provide a tested native libvips source-run path and supported platform tool versions.

Dependencies: C01, C02.

Acceptance: Fresh isolated development machine can install prerequisites, configure credentials/uploads, create schema-only DB, run web app, upload/reopen photo and use the hook without hidden local preparation.

Follow-up: normal Development dotnet run now reads the repository .env and uses a per-user upload default; the wrapper is optional. Production/Desktop do not read the development file.

Implementation: one explicit MARIADB target generates app configuration; committed development secrets/personal paths removed; setup validates tools/server/hooks; source run restores the complete pinned Windows native runtime and probes the actual photo pipeline. Local schema creation, actual hook, source startup, HTTP photo upload/reopen and thumbnail retrieval passed. See [C16 evidence](maintenance/c16-developer-setup.md) and [developer setup](development-setup.md). Windows/Linux CI passed in run 40780100240. Fresh new-PC developer setup remains pending under task 2 of the fixed work list.

## C17

**Make Linux backup/restore portable and paired** â€” P1; status: Implemented with local archive/native checks; Linux CI passed; installation acceptance pending.

Affected files/areas: infrastructure/backups/backup_orchids.sh; Linux deployment/support tooling.

Required work: Replace fixed personal home paths with explicit configuration; validate log/backup directories and remotes before use. Define a consistent database/upload backup and historical recovery strategy (versioned photos or coordinated snapshots), observable failures, retention and tested restore. Current one-way uploads mirror cannot guarantee an old SQL snapshot has matching files.

Dependencies: None.

Acceptance: Isolated account and cron share intended credentials/rclone config; backup/restore round trip checks rows/files/config; old snapshot, concurrent writes and missing files cannot falsely report full recovery.

Implementation: explicit private JSON/client/rclone paths, configured writer stop/restart, persistent database read lock, checked historical SQL/upload/configuration pairs, immutable remote upload/read-back, scoped local retention and isolated non-overwriting restore with a persistent failed-import marker. Legacy remote SQL/mirrors remain untouched. Native MariaDB checks restore an old pair and verify blocked concurrent SQL writes, missing-photo rejection and partial-DDL failure; service/cloud adapters do not certify real systemd/cron/provider/Pi operation. See the [runbook](user-guides/linux/OrchidApp-MariaDB-Backup-and-Restore-Runbook.md) and [C17 evidence](maintenance/c17-linux-paired-backup.md).

## C18

**Validate packaged upgrades and recovery including app-only updates** â€” P2; Validation gap / required operational contract; status: Implemented in source; v1.4.0 Windows installer-baseline and live Pi acceptance pending; earlier Windows upgrade paths outside agreed scope.

Affected files/areas: installer/windows/OrchidApp.iss; scripts/build-windows-installer.ps1; launcher/packaging integration tests; CI as appropriate.

Original requirement: Decide and implement explicit backup policy for same-layout app-only updates, then test actual installer clean install/upgrade/uninstall and data persistence. Package creation alone is insufficient.

Dependencies: C06â€“C10.

Acceptance: Actual isolated installer tests preserve data, enforce the approved backup policy and recover from failures; signed status is verified per produced artefact, not presumed.

Implementation: mandatory verified offline installer snapshot for every existing-file replacement, including app-only updates; refusal of busy/unclear processes or unresolved recovery state; non-overwriting review/extraction and actual artifact signing evidence. Real isolated Inno fixtures and owned MariaDB rollback tests are recorded in [C18 evidence](maintenance/c18-installer-upgrades.md). Representative older-release and actual administrator deployment acceptance remain open.

## C19

**Validate database/filesystem/native readiness and photo consistency** â€” P2; Documented consistency/readiness gap; status: Implemented in source; Linux native CI passed; installed acceptance pending.

Affected files/areas: src/OrchidApp.Web/Program.cs; PhotoPipeline.cs; photo handlers; host/backup integration tests.

Original requirement: Define useful startup/health diagnostics and compensation for partial photo/observation writes. Do not treat a listening service or successful SQL dump as end-to-end readiness.

Dependencies: C03, C15 coordination.

Acceptance: Missing DB/upload/native dependency, partial multi-photo failure and paired backup cases are observable and leave a defined recovery path; health criteria match documentation.

Implementation and evidence: [C15/C19 photo handling](maintenance/c15-c19-photo-handling.md). Windows native policy/recovery checks and isolated upgraded/fresh SQL/HTTP checks passed; isolated Linux ARM64 package/action/recovery acceptance passed in run 40777537302; real Pi and Windows installed acceptance remain pending.

## C20

**Keep feature checks and build evidence reproducible** â€” P2; Implemented curated CI and reproducible evidence; CI passed; device acceptance pending; status: Implemented in source.

Affected files/areas: tests/GreenhouseCharts.Checks; other executable checks; .github/workflows/ci.yml; evidence generation.

Required work: Choose relevant checks for CI, include greenhouse policy/calculations with disposable integration where appropriate, and record commands/revision/environment for evidence. Test cached domain-unavailable results separately from exceptions; avoid fixed historical test counts as current assertions.

Dependencies: C03; relevant fix dependencies.

Acceptance: CI/local reports distinguish isolated, DB, benchmark and device checks, run the intended fixtures only, and state actual results without suggesting production or hardware validation.

Implementation: [testing/evidence owner](testing-evidence.md) selects isolated feature executables and an explicitly empty disposable greenhouse server in separate CI jobs. Domain-unavailable cache results, exceptions and expiry/recovery are tested separately. Reports retain commands, source identity, environment, failures and omissions without fixed historical pass-count assertions. [C20 evidence](maintenance/c20-reproducible-checks.md) records measured local isolated/SQL results; Merged-revision Linux CI passed; real device acceptance remains in the fixed work list. Earlier Windows upgrade paths are outside the agreed scope.

## CHAT-R01–R03: plant-event validation explanations

**Status: implemented in source; local HTTP checks passed; merged-revision CI passed; installed acceptance pending.**

The current add-event form reproduced the historical specimen's missing explanations for a future observation, flowering end before start and absent new repotting medium. Related date and empty-note errors had the same display gap. Field-message elements now show the existing handler errors without changing rules or database state. See [implementation and measured evidence](maintenance/event-validation-messages.md).

Affected paths: `src/OrchidApp.Web/Pages/Plants/Events/Add.cshtml`; `tests/LifecycleClosure.Checks/ValidationMessages.Checks.py`; the existing lifecycle runner and linked contributor/test/upgrade documentation. No migration or setting is introduced. Acceptance requires readable errors, no writes on rejection and successful corrected saves on the current build. The frozen older specimen and all applied SQL/history remain unchanged. C18 historical package upgrade/recovery work remains separate.

## CHAT-R04: greenhouse CI deduplication

**Status: implemented in source; isolated/database local checks passed; merged-revision CI passed.**

Database mode now exits after its guarded SQL loading, performance and net-cost suites; isolated calculation/cache/policy suites run only in isolated mode. The evidence runner rejects missing/mixed mode labels even after a zero-exit executable. No SQL assertions, helper implementations, workflow jobs, fixture guards or application behavior were removed. See [measured mode validation](maintenance/ci-greenhouse-modes.md) and [test procedure](testing-evidence.md).

Affected paths: `tests/GreenhouseCharts.Checks/Program.cs`, `scripts/run-feature-checks.py`, `tests/FeatureEvidence.Checks/checks.py` and linked documentation. No migration or production configuration/startup change. Preserve the three separate CI jobs and finish C18 historical upgrade/recovery work independently.

## CHAT-R05/R07: historical Linux package/application/recovery checks

**Status: repository implementation extended; local phase results are recorded in the linked acceptance article. Full hosted acceptance passed in run 40777537302 on the identical merged source tree.** The previously merged database phase and published immutable fixture remain unchanged. The new manual default builds actual Linux ARM64 packages, executes current plant actions/readiness/restart, tests a distinct app-only build with unchanged state, and uses production paired backup/restore for broken-app and actual failed-DDL recovery. Normal CI adds 21 pure checks and three package policy checks. Real systemd/Pi/provider/browser and Windows installed acceptance remain separate. See [scope](historical-linux-upgrade.md) and [actual phase evidence](maintenance/historical-linux-application-recovery.md).

## CHAT-R10/R11: historical ledger and raw-byte packaging compatibility

**Status: immediate fixture blocker addressed by reviewed adoption; broad live adoption and wider historical packaging compatibility remain separate.** The original 245 records are preserved unchanged in `schemaversion_legacy_pi_130`; the verified historical marker starts active planning. Forward raw checksums, original-refusal testing and exact admission identities remain unchanged. Recovery restores matching historical records/binaries instead of deleting a pending marker to retry. See [investigation](maintenance/historical-ledger-compatibility.md) and [adoption evidence](maintenance/historical-linux-adoption.md).

## CHAT-R12: false recovery record after a no-photo save

**Priority: high. Status: corrected in source; reproduced by pre-fix ARM64 package and covered by corrected HTTP/native cases; merged-revision CI passed; installed acceptance pending.** On a clean upload root, successful non-photo completion tried deleting a never-created journal directory, wrote an empty cleanup-required journal, then blocked subsequent legitimate photos. `PhotoWriteBatch` now avoids journal I/O for empty Track/commit/rollback. Genuine uncertainty/cleanup protection remains unchanged. Five new native assertions cover empty paths and later successful photo tracking; existing 611 metadata plus 37 recovery checks passed locally. No SQL/settings/automatic journal removal. See [evidence](maintenance/historical-linux-application-recovery.md) and [photo contract](photo-handling.md).

## CHAT-R13: Linux package unattended and failure handling

**Priority: normal. Status: corrected/tested locally; merged-revision CI passed.** The package script always prompted/stamped source and ignored native publish failure. The explicit non-stamping/absent-output/build-identity options support actual CI packages, and native failure now aborts ZIP creation. Three real script policy checks cover publish failure/no ZIP, existing-output preservation and unchanged version properties. Existing interactive packaging is retained. See [commands and evidence](maintenance/historical-linux-application-recovery.md).

## Closure rules

For each item, record actual changed paths, implementation revision, updated document owners from documentation-map.md, checks run/results and remaining limitations. Keep schema/current exports aligned using the normal export process; never edit applied migrations. Validate destructive workflows only in isolated targets. A code item is complete only after its acceptance is demonstrated and affected guides are updated in the same change. Link related documentation review findings as needed under history/documentation-review/; those reports describe the original snapshot and may contain superseded paths/requirements.
