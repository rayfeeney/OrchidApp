# C12 ended plants are read-only

Changes only: 23 modified and 3 added repository files plus this CHANGELOG.md. No deletions or moves. No private .env, collection data/DB backups or runtime binaries are included. Existing documentation illustrations remain embedded in the two edited Word guides.

## Apply to development

1. Extract over the repository root containing OrchidApp.sln, replacing only the listed files. This follows C11 and its .env/CI fixes. It is source, not a Windows installer.
2. Stop the development app and run this same command from the repository root:

   pwsh ./scripts/DevSetup/update-database.ps1

3. Retry the normal commit and run CI. The existing repository .env supplies credentials, the command takes its normal SQL backup and applies pending migrations. Do not bypass the hook or edit the generated cutoff. Normal dotnet run and the .env workflow are unchanged.

## Deploy/upgrade

Existing DBs require 202610261800_EndedPlantReadOnly.sql after C11, through the canonical migration ledger once. Fresh creation uses the regenerated schema/bootstrap and does not replay migrations. Windows uses a fully rebuilt/tested package and its normal Desktop backup/preflight gate. Linux/manual administration requires stopped writers, a verified backup, explicit target and canonical PlanOnly/application, followed by the updated app. No new site setting or historical data conversion is required. Both platform action lists are in docs/upgrade-checklist.md.

Ended details, dates, events and photos are read-only through normal workflows, including direct POSTs bypassing buttons; history/photos stay viewable. The procedure also rejects ended detail/reactivation calls and changes to a propagation child's acquisition date. For unended plants, repotting dates are checked, flowering/location corrections preserve existing times, and open flowering overlap checks include later periods. Existing rows/timestamps/photos are not rewritten by the migration.

## Files

| Change | Repository path | Purpose |
| --- | --- | --- |
| Modified | .gitattributes | Pin the new C12 migration to LF without changing historical migration bytes. |
| Modified | .github/workflows/ci.yml | Identify the expanded lifecycle/read-only SQL and HTTP job. |
| Modified | CONTRIBUTING.md | Document the combined C11/C12 acceptance suite. |
| Modified | RELEASE_NOTES.md | Record the read-only rule, temporal fixes and exact migration. |
| Modified | database/checksums/schema.json | Official exporter checksum output. |
| Added | database/migrations/202610261800_EndedPlantReadOnly.sql | Reject ended detail/reactivation calls and protect propagation-origin dates while preserving C11 atomic closure. |
| Modified | database/schema/bootstrap.json | Official regenerated input hashes and cutoff through C12. |
| Modified | database/schema/routines/spUpdatePlantDetails.sql | Official exporter output for fresh creation. |
| Modified | docs/architecture.md | Record the approved ended read-only policy and scope. |
| Modified | docs/code-change-backlog.md | Record C12 implementation/results and retain C13 concurrency follow-up. |
| Modified | docs/documentation-map.md | Link the C12 policy/evidence owner. |
| Modified | docs/index.md | Link C12 acceptance and upgrade guidance. |
| Modified | docs/maintenance/c11-manual-closure.md | Clarify that C12 supersedes earlier direct end-date correction behavior. |
| Added | docs/maintenance/c12-ended-plant-policy.md | Record approved rule, implementation, actual tests, guide review and pending targets. |
| Modified | docs/temporal-design.md | Describe current read-only, lineage, calendar and time-preservation behavior. |
| Modified | docs/upgrade-checklist.md | List exact Windows/Linux C12 adoption and verification actions. |
| Modified | docs/user-guides/linux/02-AddAndManagePlantsInOrchidApp-LinuxPi.docx | Apply the same read-only wording with platform guidance preserved. |
| Modified | docs/user-guides/windows/03-AddAndManagePlantsInOrchidApp.docx | State ended plants are read-only and retain screenshots. |
| Modified | src/OrchidApp.Web/Pages/Plants/Events/Add.cshtml.cs | Reject ended event POSTs and redirect ended mutating forms to Details. |
| Modified | src/OrchidApp.Web/Pages/Plants/Events/Edit.cshtml.cs | Reject ended/cross-parent edits, validate repotting dates, preserve existing flowering/location times and correct open overlap checks. |
| Modified | src/OrchidApp.Web/Pages/Plants/Events/Remove.cshtml.cs | Reject ended/cross-parent removals and scope confirmation/reload queries. |
| Modified | src/OrchidApp.Web/Pages/Plants/Events/Split.cshtml.cs | Block add-child form requests for ended plants. |
| Modified | src/OrchidApp.Web/Pages/Plants/Photos/Index.cshtml.cs | Reject photo creation before an imported future acquisition date, retaining ended guards. |
| Modified | tests/LifecycleClosure.Checks/Database.Checks.ps1 | Upgrade through current migration package and test both policy suites on migrated/fresh DBs; label the new revision. |
| Added | tests/LifecycleClosure.Checks/EndedPlant.Checks.py | Add 16 actual SQL/HTTP read-only, ownership, lineage and temporal scenarios with unchanged file/DB checks. |
| Modified | tests/LifecycleClosure.Checks/checks.py | Retain closure regression coverage and assert the new no-reactivation policy. |

## Validation actually completed

- New Windows MariaDB 10.11.16 fixtures and actual Release web hosts: 16 closure plus 16 C12 scenarios on each upgraded/fresh database, 64 scenario executions with no skips. Subcases cover all event types, details/taxonomy/photo/split/propagation writes, cross-parent IDs, read-only views, temporal invalid/same-day/unknown bounds, time preservation, open overlap and lineage. Failed writes preserved scoped DB values and photo-file hashes.
- All 44 creation/baseline, 53 migration/export and 10 child-process protocol checks passed. All 18 baseline policy checks and 24 Desktop migration policy scenarios passed, validating 246 migration files.
- Release build: zero warnings/errors. Policy-project runs reported NU1900 because NuGet vulnerability metadata was unavailable; no completed vulnerability audit is claimed. PowerShell syntax/actionlint passed (optional ShellCheck/Pyflakes disabled).
- Routine/checksum/bootstrap were regenerated by the official exporter from the migrated pristine schema. All 245 prior migration files, other schema inputs, developer .env helpers, startup configuration and Windows/Linux backup tools are unchanged. ZIP bytes/list, bootstrap hashes, exported routine/migration equivalence, local Markdown links and merge markers were checked.
- Both platform Word guides retain all 22 media files each byte-for-byte. Both render to 17 pages; all 34 pages were visually inspected, including changes on pages 2, 13 and 14. QA PDFs/PNGs are not separate deliverables.
- Owned generated DBs/server/web processes were cleaned up; diagnostic fixture directories remain. No owner .env or live/development collection was modified by this work.

## Remaining acceptance

Linux CI, real older-installation/device/installer acceptance remain pending. C13 owns structural rollback and concurrent write/closure coordination; application request guards are not a universal table immutability constraint. Direct administrative SQL is outside normal editing. C14 owns any stronger ordering guarantee; C19 owns broader photo compensation/readiness. No automatic retrospective repair or reactivation path is included.

Next in the agreed order: C13 structural transaction rollback and concurrency.
