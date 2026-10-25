# C09 protected backup retention

Changes only: 17 modified and 4 added repository files plus this CHANGELOG.md. No deletions or moves. No private .env, collection data, photos or runtime binaries are included.

## Apply

1. Extract over the source repository root containing OrchidApp.sln, accepting replacement of the listed files. This follows C10 and the working C16 startup fix. Keep private configuration/data unchanged.
2. Review docs/windows-backup-format.md and docs/maintenance/c09-backup-retention.md. Rebuild/repackage Windows from source; this is not a deployed installer ZIP.
3. Keep Backup-Retention.ps1, Backup-Contract.ps1 and Restore-Recovery.ps1 with the tool scripts. Packaging now requires all three helpers. Run CI; the workflow adds dual-PowerShell retention checks.

Routine Normal backups now prune after a new verified ZIP, keeping three verified unprotected routine archives by default and never fewer than one. SkipOldBackupPruning disables pruning. PreUpgrade and protected safety directories never prune; recorded recovery/migration inputs and unrecognised files remain. These extras can exceed the nominal count. Desktop database-update safety backups move to backups/pre-migration with pruning disabled. No existing backup files are moved by applying this source ZIP.

All 333 schema/checksum/historical SQL artifacts were verified unchanged. No migration is required. Development configuration, restore recovery and migration reconciliation files are unchanged. Reconstructing the two previous backup-call blocks reproduces their pre-C09 file hashes, confirming Program.cs/launcher edits are confined to those invocations.

## Files

| Change | Repository path | Description |
| --- | --- | --- |
| Modified | .github/workflows/ci.yml | Run retention fixtures under both PowerShell versions before Windows packaging. |
| Modified | CONTRIBUTING.md | Document retention/native and Desktop argument checks. |
| Modified | RELEASE_NOTES.md | Record effective retention controls, protected safety copies and complete ZIP payloads. |
| Modified | app/tools/Backup-Contract.ps1 | Add shared ZIP creation preserving empty directories and hidden files. |
| Added | app/tools/Backup-Retention.ps1 | Add verified routine retention with recovery/migration pins, protected directories and fail-closed history handling. |
| Modified | app/tools/backup-orchidapp.ps1 | Validate minimum count, serialise same-directory runs and prune only after new ZIP verification using the declared controls. |
| Modified | docs/code-change-backlog.md | Record C09 implementation and pending CI/installed acceptance. |
| Modified | docs/documentation-map.md | Identify the maintained retention contract and evidence. |
| Modified | docs/index.md | Link C09 evidence. |
| Added | docs/maintenance/c09-backup-retention.md | Record changes, validation evidence and operating limits. |
| Modified | docs/migration-runners.md | Document protected pre-migration safety placement and the Desktop recording fixture. |
| Modified | docs/user-guides/windows/04-ConfigureCloudBackupFolderInOrchidAppForWindows.docx | Explain the default local routine count and protected/review extras; preserve illustrations. |
| Modified | docs/windows-backup-format.md | Describe actual retention scope, exclusions, ordering, warnings and archive creation. |
| Modified | docs/windows-upgrade-contract.md | Replace the old undeclared-variable gap with the implemented retention boundary. |
| Modified | scripts/package-windows.ps1 | Require all three shared backup/restore helper files in the package inventory. |
| Modified | src/OrchidApp.Launcher/OrchidAppLauncherForm.cs | Pass declared Normal/root/count arguments for routine backups through ArgumentList. |
| Modified | src/OrchidApp.Web/Program.cs | Send Desktop migration safety backups to the protected pre-migration directory with pruning disabled. |
| Modified | tests/BackupRestore.Checks/Database.Checks.ps1 | Add native routine pruning, skip, unrelated-copy preservation and failure-before-pruning checks. |
| Added | tests/BackupRestore.Checks/Retention.Checks.ps1 | Add disposable archive fixtures for effective retention, protected files, invalid inputs, locks and complete ZIP payloads. |
| Added | tests/MigrationHistory.Checks/BackupFixture.ps1 | Record Desktop safety arguments only in a temporary stage; never write the supplied backup directory. |
| Modified | tests/MigrationHistory.Checks/Desktop.Checks.ps1 | Use the named recording fixture and verify the real Desktop caller passes protected declared arguments. |

## Validation actually performed

- All 29 retention checks passed under PowerShell 7 and Windows PowerShell 5.1, including default/minimum/disabled/pre-upgrade modes, invalid counts, old/current names, timestamp skew, unrelated/foreign/corrupt/nested ZIPs, pinned/protected inputs, unreadable history, pending restore, locked deletion and complete hidden/empty payloads.
- All 28 existing archive/journal policy checks passed under both versions.
- All 77 native Windows/MariaDB checks passed, including actual backup pruning, skip mode, unrelated-copy preservation and no deletion after a failed new backup, alongside migration/restore regressions.
- All 13 staged Desktop migration checks passed. The real C# caller invoked the recording-only synthetic backup with declared Normal/root/skip arguments. This fixture never writes the supplied real ProgramData path and does not substitute for a real safety archive test.
- Web and launcher Release builds: zero warnings/errors. All 14 development startup configuration checks passed.
- Changed PowerShell syntax and actionlint workflow checks passed (optional ShellCheck/Pyflakes integrations disabled). Required helper source files and changed Markdown links were verified.
- Windows guide 04 retained all five embedded media files. All six rendered pages were visually inspected. Existing screenshots illustrate buttons; historic log text is not the new policy. QA PDF/PNGs remain outside this ZIP.
- Archived file list/bytes, merge markers, unchanged SQL/startup/reconciliation/restore artifacts and backup-only C# edits were checked. Generated database processes were shut down; diagnostic fixture directories remain. No live collection or private credential file was used.

## Limits and next work

Retention is not an exact disk-space cap or cloud version history. Validation may need temporary space and time; unknown/protected files and cleanup warnings can leave extra archives. This does not add atomic SQL/filesystem backup consistency or certify a real installer/interactive recovery. Keep a verified off-computer copy.

GitHub Actions and real installed-machine acceptance remain pending. Next in the agreed order is C17 Linux backup/restore portability and pairing.
