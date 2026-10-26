# C11 atomic manual plant closure

Changes only: 13 modified and 6 added repository files, plus this CHANGELOG.md. No deletions/moves. No private settings/credentials, collection data, photos or runtime binaries are included.

## Apply to source and development

1. Extract over the repository root containing OrchidApp.sln, replacing only listed source files. This follows C17 and the maintained C01–C20 upgrade checklist. It is not an installer or a live database update.
2. BEFORE COMMITTING, back up the isolated development/export database, configure its explicit MARIADB administration environment, review Apply-Migrations.ps1 -PlanOnly and apply through the canonical runner. The new file is 202610261200_AtomicManualPlantClosure.sql. Normal Development dotnet run does not migrate DBs and the admin scripts do not load the app's .env. The pre-commit exporter must see the updated DB or it can replace delivered schema artifacts with old definitions. Review generated/staged changes; do not bypass the hook or use the live collection.
3. Keep the new .gitattributes migration-specific LF rule. It preserves the new raw checksum across Windows/Linux checkouts without changing historical file bytes. Never edit an applied migration or manually alter the ledger.

## Apply on deployment

- Windows: build/test the complete installer/package, then use the normal Desktop preflight/backup/migration route. Manual administrators may use the canonical runner instead; do not apply by hand and then again through the ledger.
- Linux: preserve a verified stopped-writer backup, supply all five explicit MARIADB connection values, PlanOnly and apply via Apply-Migrations.ps1, publish compatible app files and perform acceptance. The operational runner does not take a backup automatically.
- Existing DBs need the new migration; fresh creation uses the exported schema/bootstrap without replaying it. Do not recreate an existing collection. No new site setting is required.
- First adoption: run database/scripts/Review-ManualPlantClosure.sql read-only on the explicitly selected DB. Investigate historical ended/open or invalid-interval findings privately. This migration deliberately does not repair old partial closures or make ended plants editable. Do not bulk correct history or clear end dates without an agreed evidence-based repair.
- Both platforms: use docs/upgrade-checklist.md and docs/maintenance/c11-manual-closure.md for exact adoption, disposable save/reopen checks and failure handling. Failed DDL may be partially applied; preserve pending markers/backup and investigate before retrying.

## Behavior

Manual first closure now writes flowering.endDate and atomically saves the plant plus open location/flowering ends at the same timestamp. Standalone calls own their transaction; calls inside an existing transaction use a reserved savepoint without committing earlier caller work. SQL failures roll back/rethrow. Invalid open start bounds are rejected. Existing date/time/split rules, all-open-row scope, direct clearing behavior and the ended-plant UI remain. Broader correction/concurrency rules remain C12–C14.

## Files

| Change | Path | Purpose |
| --- | --- | --- |
| Modified | .gitattributes | Pin only the new migration to LF so its raw checksum is portable. |
| Modified | .github/workflows/ci.yml | Add Linux canonical upgrade/fresh-creation and actual HTTP closure acceptance job. |
| Modified | CONTRIBUTING.md | Document the disposable lifecycle suite and source-export option. |
| Modified | RELEASE_NOTES.md | Record migration, rollback behavior and historical-data review. |
| Modified | database/checksums/schema.json | Official exporter checksum output. |
| Added | database/migrations/202610261200_AtomicManualPlantClosure.sql | Add atomic first-closure procedure with caller-preserving transaction/savepoint and interval checks. |
| Modified | database/schema/bootstrap.json | Official generated manifest/checksum and cutoff through the applied C11 migration. |
| Modified | database/schema/routines/spUpdatePlantDetails.sql | Official exporter output of the migrated procedure for fresh creation. |
| Added | database/scripts/Review-ManualPlantClosure.sql | Read-only historical ended/open and invalid interval review; no automatic repair. |
| Modified | docs/code-change-backlog.md | Record implementation/evidence and remaining Linux/installed acceptance. |
| Modified | docs/development-setup.md | Require migrating the isolated export database before committing this source change. |
| Modified | docs/documentation-map.md | Link C11 evidence to temporal ownership. |
| Modified | docs/index.md | Link C11 acceptance and adoption guidance. |
| Added | docs/maintenance/c11-manual-closure.md | Document upgrade/developer steps, tests, historical review and remaining acceptance. |
| Modified | docs/temporal-design.md | Replace the old mismatch warning with actual atomic closure semantics and limits. |
| Modified | docs/upgrade-checklist.md | Add exact C11 Windows/Linux migration, historical review and disposable acceptance actions; retain C12–C20 pending work. |
| Added | tests/LifecycleClosure.Checks/Database.Checks.ps1 | Run targeted prior-procedure upgrade and migration-free fresh schema with real web hosts on generated DBs. |
| Added | tests/LifecycleClosure.Checks/PreC11UpdatePlantDetails.sql | Preserve the genuine prior defective procedure as a synthetic upgrade fixture only. |
| Added | tests/LifecycleClosure.Checks/checks.py | Exercise 16 native SQL/actual HTTP rollback, boundary, timestamp and split-protection scenarios on both paths. |

## Validation actually completed

- New private Windows MariaDB 10.11.16 instance: reproduced the original partial failure; canonical runner applied C11 once with the raw checksum and unchanged prior baseline. The read-only review identified the historical fixture without rewriting it.
- All 16 lifecycle/actual HTTP scenarios passed against both upgraded and migration-free fresh-created databases: 32 executions, no skips. Rollback injected at location/flowering updates left all components unchanged; a failed actual Edit POST stayed editable and successful retry/reopen persisted the closure.
- All 44 existing creation/baseline DB checks, 18 schema baseline policy checks and 24 Desktop migration policy scenarios passed (245 packaged migrations validated).
- Release web build: zero warnings/errors. Policy project runs reported NU1900 for unavailable NuGet vulnerability metadata; this is not a successful vulnerability audit.
- PowerShell syntax and actionlint passed (optional ShellCheck/Pyflakes disabled). Source/ZIP byte lists, local documentation links, bootstrap input hashes, exported procedure/migration equivalence and unchanged historical migrations were checked. All 244 pre-existing migration files and all application/Windows/Linux backup code are byte-identical to the preceding delivery.
- Canonical routine, schema checksums and bootstrap were regenerated by the official exporter from the migrated pristine fixture, never hand-edited. Both platform Word plant guides were reviewed; their event/split instructions do not change, so no Word edit/render was needed. Owned servers/web hosts and generated DBs were cleaned up; diagnostic fixture directories remain.

## Limits and next work

New Linux CI, real older-release databases, installed Windows/Pi/hardware acceptance and collection-specific historical findings remain pending. Synthetic prior-procedure staging is not historical-release certification. Deadlocks can abort an entire caller transaction according to MariaDB semantics. No retrospective data repair or broader temporal-policy change is claimed.

Next: C12, agree and enforce ended-plant/date-correction policy.
