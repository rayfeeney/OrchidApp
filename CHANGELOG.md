# C14 history ordered by event type when timestamps match

Changes only: 13 modified and 2 added repository files plus this CHANGELOG.md. No deletions or moves. No private .env, credentials, collection data or runtime binaries. Existing documentation illustrations remain embedded in the two edited Word guides.

## Apply to source

Extract over the repository root containing OrchidApp.sln, replacing only the listed files. This follows C13 and its cache-aware CI revision v3. Restart/rebuild the app, commit normally and run CI. No C14 migration, database-update command, settings change or historical conversion is required. The existing .env and developer startup workflow are unchanged; keep all earlier C13 app/procedure requirements.

## Behavior

History remains newest stored date/time first. Exact timestamp ties sort Flowering, LocationChange (shown as Move), Observation, Repotting. Within one timestamp/type, record ID remains descending. Event type therefore precedes cross-table IDs, as agreed. A date correction can reposition a card; different times on the same date still take precedence over type. Equal wall-clock values from a repeated clock hour use the same stable display tie-breaker, with no inferred UTC chronology or rewritten timestamps.

The page's outer query owns this ordering. The existing view/model already supply every required field, so all database/schema/checksum/bootstrap and migration bytes are unchanged. No manual reordering field or insertion-order guarantee is added.

## Windows and Linux upgrade actions

Deploy the updated app through the normal rebuilt/tested platform package and backup/upgrade procedure. C14 adds no database/settings action. Verify tie ordering, refresh and date-correction behavior on disposable data in the installed app; do not alter valuable history to construct ties. Both platform actions are maintained in docs/upgrade-checklist.md. This ZIP is source, not an installer.

## Files

| Change | Repository path | Purpose |
| --- | --- | --- |
| Modified | .github/workflows/ci.yml | Identify history ordering in the existing lifecycle CI job. |
| Modified | CONTRIBUTING.md | Document the new history-order suite and its disposable runner. |
| Modified | RELEASE_NOTES.md | Describe the agreed rule and absence of a C14 migration/configuration action. |
| Modified | docs/architecture.md | Record the implemented history display order. |
| Modified | docs/code-change-backlog.md | Record the owner decision, implementation and remaining acceptance. |
| Modified | docs/documentation-map.md | Link the C14 policy/evidence owner. |
| Modified | docs/index.md | Add the C14 history-order reference. |
| Added | docs/maintenance/c14-history-ordering.md | Explain implementation, actual validation, deployment and remaining limits. |
| Modified | docs/temporal-design.md | Define timestamp/type/ID precedence, corrections and local clock-hour limits. |
| Modified | docs/upgrade-checklist.md | List Windows/Linux app adoption and display acceptance; no C14 DB/settings action. |
| Modified | docs/user-guides/linux/02-AddAndManagePlantsInOrchidApp-LinuxPi.docx | Apply the same history guidance to the Linux/Pi guide. |
| Modified | docs/user-guides/windows/03-AddAndManagePlantsInOrchidApp.docx | Update the history guidance bullet while preserving illustrations and pagination. |
| Modified | src/OrchidApp.Web/Pages/Plants/Details.cshtml.cs | Sort matching timestamps by event type ascending before record ID descending. |
| Modified | tests/LifecycleClosure.Checks/Database.Checks.ps1 | Run history-order scenarios on both upgraded and schema-only fresh fixtures, retaining C13 cache-aware checks. |
| Added | tests/LifecycleClosure.Checks/HistoryOrdering.Checks.py | Add ten actual MariaDB/Details HTML scenarios for ties, correction, repeated reads and scoped/ended history. |

## Validation actually completed

- Native Windows MariaDB 10.11.16 with actual Release HTTP hosts: ten C14 scenarios on each upgraded/fresh database, alongside 16 closure, 16 C12 and 23 C13 scenarios per fixture, 130 executions. The C14 tests inspect rendered Details summaries from the actual EF/MariaDB query, including equal timestamps and IDs, type precedence over higher IDs, same-day time precedence, same-type ID fallback, repeated reads/no row changes, real HTTP date correction/time preservation, repeated local clock-hour ties, ended history and inactive/other-plant exclusion.
- Release build completed with zero warnings/errors. Workflow and PowerShell syntax, Python syntax and local Markdown links passed. Previous unrelated database creation/migration-policy results remain previous evidence and were not rerun for this query-only change.
- Both Word guides remain 17 pages; all 34 rendered pages were visually inspected, with changed bullets on page 5. All 22 embedded media files per guide remain byte-identical. The existing screenshots remain relevant; no action/form layout changed. QA PDFs/PNGs are not separate deliverables.
- Full-repository hashes verify the exact 15-file change set, no deletions/moves and unchanged database assets, other app files, developer helpers/configuration and C13 cache-aware tests. ZIP paths/list and source bytes verified.
- Only owned disposable server/database/web fixtures were used and cleaned up. Diagnostic folders remain. No owner .env, collection/development DB or live photos were used or modified.

## Remaining acceptance

Linux CI and installed Windows/Linux/Pi UI acceptance remain pending. CI should retain c13-lock-cache-v3 and additionally print c14-event-type-v1. Stable display does not establish absolute chronology across timezone/clock changes. No timestamp repair, ordering control or new database migration is included.
