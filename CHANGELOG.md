# C10 legacy migration reconciliation

Changes only: 17 modified and 4 added repository files, plus this CHANGELOG.md. No deletions or moves. No private configuration, credentials, database contents, photos or runtime binaries are included.

## Apply

1. Extract over the source repository root containing OrchidApp.sln, accepting replacement of the listed files. This follows C08 and the working C16 .env startup fix. Keep private .env and collection data unchanged.
2. Review docs/windows-upgrade-contract.md and docs/maintenance/c10-migration-reconciliation.md. Rebuild/repackage Windows from source; this ZIP is not a deployed installer.
3. Run CI and perform installed-machine acceptance on disposable data. Existing Windows check steps execute the expanded suites without a workflow change.

Old version 1 migration state requires support review. Do not delete migration-state.json, the old installation, migration-target-id or partial destination files to bypass a stop. Version 2 copying can resume only matching recorded ownership; readiness retry never blindly recopies raw database files.

All 333 existing schema/checksum/historical migration artifacts were verified unchanged. No database migration is required. Development web startup files and C08 backup/restore tools were also verified unchanged.

## Files

| Change | Repository path | Description |
| --- | --- | --- |
| Modified | CONTRIBUTING.md | Document migration interruption/readiness checks and source fingerprint precautions. |
| Modified | RELEASE_NOTES.md | Record C10 missing-file resume, readiness-aware completion and review boundaries. |
| Modified | docs/code-change-backlog.md | Record implemented C10 reconciliation with CI/installed acceptance still pending. |
| Modified | docs/documentation-map.md | Link migration reconciliation evidence to the Windows contract. |
| Modified | docs/index.md | Link C10 evidence. |
| Added | docs/maintenance/c10-migration-reconciliation.md | Record implementation, local evidence and remaining acceptance limits. |
| Modified | docs/user-guides/windows/01-InstallOrUpgradeOrchidAppOnWindows.docx | Explain the resume prompt, retained original and support boundaries; preserve all illustrations. |
| Modified | docs/windows-backup-format.md | Replace the deferred reconciliation pointer with the implemented C10 contract. |
| Modified | docs/windows-upgrade-contract.md | Document version 2 ownership, atomic writes, copy/readiness phases, source precedence and unsupported old-state handling. |
| Modified | src/OrchidApp.Launcher/Infrastructure/LegacyDataMigrationService.cs | Reject all existing target MariaDB files, including partial system databases, in the older copy helper. |
| Added | src/OrchidApp.Launcher/Infrastructure/LegacyMigrationCoordinator.cs | Add ownership-bound, checksum-verified missing-file resume and readiness completion without source deletion or target overwrite. |
| Modified | src/OrchidApp.Launcher/Infrastructure/LegacySourceSnapshot.cs | Record the original source fingerprint while capture read locks are held. |
| Added | src/OrchidApp.Launcher/Infrastructure/MigrationFiles.cs | Add safe inventory, SHA-256 fingerprint and contained path helpers. |
| Modified | src/OrchidApp.Launcher/Infrastructure/MigrationState.cs | Add operation ID, phase, capture path, source fingerprint and copy inventory. |
| Modified | src/OrchidApp.Launcher/Infrastructure/MigrationStateService.cs | Reject empty/null state and save through a flushed temporary file plus atomic replacement. |
| Modified | src/OrchidApp.Launcher/OrchidAppLauncherForm.cs | Resume recorded migration under lock; mark completion after database identity/web readiness; block occupied ports/ordinary close and re-read state after locking; guard shutdown identity. |
| Modified | src/OrchidApp.Launcher/OrchidAppLayoutResolver.cs | Use validated migration ownership to distinguish the exact preserved source from unrelated/changed legacy sources; allow isolated discovery fixtures. |
| Modified | tests/BackupRestore.Checks/BackupRestore.Checks.csproj | Compile shared migration and layout policy into the existing Windows executable checks. |
| Modified | tests/BackupRestore.Checks/Database.Checks.ps1 | Test real interrupted raw copy, resume, native startup failure/retry, database identity/completion and next-launch source precedence alongside restore regressions. |
| Added | tests/BackupRestore.Checks/Migration.Checks.cs | Add disposable migration policy fixtures and integration CLI modes. |
| Modified | tests/BackupRestore.Checks/Program.cs | Run migration reconciliation scenarios and dispatch fixture CLI modes. |

## Validation actually performed

- Release launcher and fixture builds: zero warnings/errors.
- All 57 combined source, restore recovery and migration reconciliation executable checks passed. New cases include interrupted copy and matching-file resume; unknown/changed destination rejection; incomplete/full copy with failed state writes; locked completion commit retaining previous JSON; readiness failure without raw recopy; target/source identity, ambiguous roots and unsupported/corrupt/empty state; missing backup, changed capture and residual system database rejection.
- All 69 Windows/MariaDB 10.11 database checks passed. The suite interrupts an actual raw copy, resumes it, reports a real native server startup failure, retries readiness without recopying, starts/queries the migrated database, records completion and resolves the target with the original retained. The C06/C07/C08 archive, photo/settings byte, failed SQL/import and explicit restore recovery regressions also pass.
- The fixture database completion test checks database identity and state transitions. The full interactive launcher/web startup path has not been exercised as an installed application here.
- Windows guide 01 retains all 11 embedded media files. All 12 rendered pages were visually inspected. QA PDF/PNGs remain outside this ZIP.
- Changed Markdown links, merge-marker checks, unchanged database/startup/restore artifact hashes, ZIP entry list and archived source bytes were checked.
- Generated database processes were shut down; fixture/log directories remain for diagnosis. No live collection, actual ProgramData collection or user credential file was used. Antivirus remained enabled.

## Operating boundary and next work

Copying is not a cross-directory transaction. Failed or mismatched partial state is retained for resume/review; no automatic deletion or rollback is claimed. Do not run the old database again while relying on its preserved-source fingerprint. Original raw files can change during a database restart even when plant records appear unchanged.

Completed version 2 ownership distinguishes only the recorded preserved source. Unrelated or changed legacy sources still stop. Old version 1 copy-only state is not promoted automatically. Readiness is database identity plus a successful web response, not proof of every record/photo/device workflow. Missing permissions, incompatible runtime/credentials or damaged inputs may require support.

GitHub Actions, actual installer/interactive acceptance and reviewed real historical installations remain pending. Next in the agreed order is C09 backup retention, then C17 Linux backup/restore.
