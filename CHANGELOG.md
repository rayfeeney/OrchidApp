# C13 structural transaction rollback and concurrency

Changes only: 24 modified and 5 added repository files plus this CHANGELOG.md. No deletions or moves. No private .env, collection data, backups or runtime binaries. The existing guide illustrations remain embedded in the two edited Word files.

## Apply to source development

1. Extract over the repository root containing OrchidApp.sln, replacing the listed files. This follows merged C12. It is source, not a Windows installer.
2. Stop the development app and run the existing command from the repository root:

   pwsh ./scripts/DevSetup/update-database.ps1

3. Commit normally and run CI. The repository .env supplies credentials; the existing wrapper takes its logical backup and applies pending migrations. Keep the pre-commit export guard. Normal dotnet run is unchanged.

## Upgrade Windows or Linux

Existing DBs require 202610262000_StructuralTransactions.sql through the canonical migration ledger once. Stop writers and retain a verified recoverable backup. Deploy the matching rebuilt app and generated schema assets together: the preceding procedures can commit the new filter's caller transaction. Windows uses the normal Desktop backup/preflight gate and a fully rebuilt/tested package. Linux/manual administration uses PlanOnly and the canonical runner with its explicit target and operator backup. Fresh creation uses schema/seeds without replaying migrations. No setting change or historical data backfill is required. Exact platform steps are in docs/upgrade-checklist.md.

Structural failures roll back earlier operation writes and do not commit prior caller work. Normal event/photo/details requests share the parent lock with closure; a waiting writer rechecks the committed end state. Same-second zero-length moves and split interval inversion are refused. Hero selection uses the configured database. Refresh current plant history after a failed save before retrying; no automatic retry is introduced.

## Files

| Change | Repository path | Purpose |
| --- | --- | --- |
| Modified | .gitattributes | Pin only the new C13 migration to LF for cross-platform raw checksums. |
| Modified | .github/workflows/ci.yml | Identify the expanded structural transaction/concurrency acceptance job. |
| Modified | CONTRIBUTING.md | Document the combined lifecycle and structural acceptance checks. |
| Modified | RELEASE_NOTES.md | Describe C13 behavior and migration/deployment requirements. |
| Modified | database/checksums/schema.json | Official regenerated checksums. |
| Added | database/migrations/202610262000_StructuralTransactions.sql | Add parent locking, caller-preserving rollback/savepoints, interval validation and current-database hero selection. |
| Modified | database/schema/bootstrap.json | Official regenerated manifest and C13 cutoff. |
| Modified | database/schema/routines/spEditPlantLocation.sql | Official exporter output for fresh schema creation. |
| Modified | database/schema/routines/spMovePlantToLocation.sql | Official exporter output for fresh schema creation. |
| Modified | database/schema/routines/spPropagatePlant.sql | Official exporter output for fresh schema creation. |
| Modified | database/schema/routines/spRemovePlantLocation.sql | Official exporter output for fresh schema creation. |
| Modified | database/schema/routines/spSetHeroPhoto.sql | Official exporter output for fresh schema creation. |
| Modified | database/schema/routines/spSplitPlant.sql | Official exporter output for fresh schema creation. |
| Modified | docs/architecture.md | Record current transaction boundaries and remaining photo-file limits. |
| Modified | docs/code-change-backlog.md | Record implementation and pending Linux/installed acceptance. |
| Modified | docs/documentation-map.md | Link C13 evidence to its authoritative owners. |
| Modified | docs/index.md | Link the C13 acceptance and deployment report. |
| Added | docs/maintenance/c13-structural-transactions.md | Explain transaction/savepoint rules, actual checks, migration and pending targets. |
| Modified | docs/temporal-design.md | Replace prior structural transaction gaps with the implemented protocol and limits. |
| Modified | docs/upgrade-checklist.md | Add exact Windows/Linux C13 adoption, backup, matched-app and acceptance actions. |
| Modified | docs/user-guides/linux/02-AddAndManagePlantsInOrchidApp-LinuxPi.docx | Apply the same guidance to the Linux/Pi guide. |
| Modified | docs/user-guides/windows/03-AddAndManagePlantsInOrchidApp.docx | Add refresh-before-retry guidance while preserving all illustrations. |
| Modified | src/OrchidApp.Web/Pages/Plants/Events/Add.cshtml.cs | Use the enclosing request transaction instead of starting a nested observation transaction. |
| Modified | src/OrchidApp.Web/Program.cs | Register the scoped plant-write filter alongside existing navigation normalization. |
| Added | src/OrchidApp.Web/Services/PlantWriteFilter.cs | Hold a parent lock through the write request; reject conflicting IDs; commit only successful handlers. |
| Modified | src/OrchidApp.Web/infrastructure/StoredProcedureExecutor.cs | Enlist commands in EF transactions and surface trailing CALL errors. |
| Modified | tests/LifecycleClosure.Checks/Database.Checks.ps1 | Stage genuine preceding definitions and run all three suites on upgraded/fresh fixtures. |
| Added | tests/LifecycleClosure.Checks/PreC13Structural.sql | Retain the six verified preceding procedure definitions as read-only test input. |
| Added | tests/LifecycleClosure.Checks/Structural.Checks.py | Add persistent-session failure, caller transaction, concurrency and actual HTTP scenarios. |

## Validation actually completed

- Windows MariaDB 10.11.16 with actual Release web hosts: 16 closure + 16 C12 + 21 C13 scenarios on each upgraded/fresh database, 106 executions. Additional subcases exercise injected mid-write failures for six operations in owned and caller transactions, caller rollback/connection reuse, observed server lock waits, old repeatable-read snapshots, competing moves/splits/propagations, closure/writer ordering, actual HTTP structural/hero saves, late procedure errors and failed photo-processing database rollback.
- All 44 creation/baseline, 53 migration/export and 10 child-process protocol checks passed. All 18 baseline policy checks and 24 Desktop migration policy scenarios passed; 247 packaged migrations validated. Release build and workflow/PowerShell syntax checks passed. NU1900 indicates unavailable NuGet vulnerability metadata; no completed vulnerability audit is claimed. Optional ShellCheck/Pyflakes were disabled for actionlint.
- Genuine preceding definitions were restored before generating the upgrade fixture's manifest. Current canonical routines/checksums/bootstrap were regenerated only through the official exporter. All 246 historical migration files and other schema inputs are unchanged. ZIP file list/bytes, normalized manifest hashes, routine definitions, links, Python syntax and merge markers checked.
- Both guides remain 17 pages. All 34 rendered pages were visually inspected; page 13 adds refresh-before-retry guidance. All 22 embedded media files per guide are byte-identical. QA PDFs/PNGs are not separate deliverables.
- Only owned disposable server/DB/web fixtures were used and cleaned up. Diagnostic fixture folders remain. No owner's .env or collection/development DB/photos were changed.

## Remaining acceptance and limits

Linux CI, installed Windows/Pi and representative old-installation acceptance remain pending. Direct administrative SQL and taxonomy administration are outside the parent-write protocol. Deadlocks can abort a caller's whole transaction. Database rollback does not make filesystem changes atomic: broader photo compensation/readiness remains C19. No historical partial operation is repaired automatically. Migration DDL failures retain their normal pending-marker recovery contract; do not clear markers or downgrade binaries alone to force retry.

Next in the agreed order: C14 history ordering.
