# C08 Windows restore recovery

Changes only: 16 modified and 3 added repository files, plus this CHANGELOG.md. No deletions or moves. No credentials, private .env, database contents, photos or runtime binaries are included.

## Apply

1. Extract over the source repository root containing OrchidApp.sln and review the listed files. This follows the merged C06/C07 and C16 startup fix. Keep all existing private configuration.
2. Rebuild/repackage Windows from source. This ZIP is not a deployed installer. The package script copies the complete tools directory, including new Restore-Recovery.ps1; do not distribute the restore script without both shared helpers.
3. Run CI. For restore acceptance use disposable data and the Windows recovery guide; do not test destructive failure scenarios against the live collection.

C08 does not modify the web startup files that now read the repository .env for ordinary dotnet run. All 333 schema/checksum/historical SQL artifacts were verified unchanged. No migration is required.

## Files

| Change | Repository path | Description |
| --- | --- | --- |
| Modified | CONTRIBUTING.md | Document expanded recovery checks and disposable Windows fixture requirements. |
| Modified | RELEASE_NOTES.md | Describe C08 restore recovery and its operating limits. |
| Added | app/tools/Restore-Recovery.ps1 | Add atomic persistent recovery journal writes compatible with both PowerShell versions. |
| Modified | app/tools/backup-orchidapp.ps1 | Block normal backups during pending restore and shorten native backup working paths. |
| Modified | app/tools/restore-orchidapp.ps1 | Retain input, require verified safety backup, persist phases and offer explicit input/safety recovery with importer survival guard. |
| Modified | docs/code-change-backlog.md | Record C08 implementation and pending CI/installed acceptance. |
| Modified | docs/documentation-map.md | Identify the restore recovery reference and evidence. |
| Modified | docs/index.md | Link C08 recovery evidence. |
| Added | docs/maintenance/c08-restore-recovery.md | Record design, validation evidence and remaining limits. |
| Modified | docs/user-guides/windows/04-ConfigureCloudBackupFolderInOrchidAppForWindows.docx | Explain protection of selected restore ZIP paths from later cloud copies; preserve illustrations. |
| Modified | docs/user-guides/windows/05-RecoverOrchidAppOnReplacementWindowsComputer.docx | Explain safety copies and explicit recovery choices after interruption; preserve illustrations. |
| Modified | docs/windows-backup-format.md | Maintain recovery procedures, persistent phases, cloud protection and support commands. |
| Modified | docs/windows-upgrade-contract.md | Replace obsolete restore safety-copy gap with the implemented recovery boundary. |
| Added | src/OrchidApp.Launcher/Infrastructure/RestoreRecovery.cs | Read persistent recovery state and protect recorded cloud destinations across restarts. |
| Modified | src/OrchidApp.Launcher/OrchidAppLauncherForm.cs | Gate startup on pending restore, offer recovery choices, prevent ordinary close during restore, restore useful controls and guard cloud copies. |
| Modified | tests/BackupRestore.Checks/BackupRestore.Checks.csproj | Compile shared restore recovery policy into the executable checks. |
| Modified | tests/BackupRestore.Checks/Database.Checks.ps1 | Exercise actual failed restore phases, safety/input recovery, prior importer guard, clean shutdown and restart on generated MariaDB data. |
| Modified | tests/BackupRestore.Checks/Policy.Checks.ps1 | Verify atomic pending/history journal writes and failed-phase persistence on both PowerShell versions. |
| Modified | tests/BackupRestore.Checks/Program.cs | Check pending state, protected cloud destinations, incomplete preflight and corrupt history. |

## Validation actually performed

- Release launcher build: zero warnings/errors.
- 23 C# source/recovery checks passed; 14 existing development startup checks passed.
- 28 payload/recovery journal checks passed under PowerShell 7 and again under Windows PowerShell 5.1.
- 59 Windows/MariaDB database checks passed. Generated fixtures covered SQL failure, missing referenced photo after import, locked upload/settings replacement, inability to create the safety copy, blocking an active prior importer, explicit retained-input and original-safety recovery, tool-owned clean database shutdown and subsequent restart. Existing archive compatibility and photo/settings byte checks also passed.
- Selected inputs remained byte-identical; original safety archives and completed/failed phase history remained retained. Ordinary restore and backup were blocked during pending recovery.
- Word guides 04 and 05 retained all five embedded images each. Six and seven rendered pages were visually inspected. QA PDFs/PNGs are outside this ZIP.
- Changed Markdown links, unchanged database/startup artifacts, archive entries and file bytes were verified. No live collection or actual ProgramData collection was used. Antivirus stayed enabled.

## Limits and next work

Replacement remains sequential across SQL, uploads and settings; no automatic or atomic rollback is claimed. Recovery can still require support for disk/permission/runtime/input problems. Keep the retained input, safety archive and journal; do not delete restore-pending.json to force startup. Close other app instances during restore. Completed history protects selected ZIP paths from later fixed-name cloud overwrite; choose a different future cloud folder if necessary.

Existing Windows CI steps run the expanded suites, but GitHub Actions and interactive installed-machine acceptance have not been run here. These fixtures do not prove recovery from actual historical releases. General concurrent-write backup consistency remains outside C08. Next in the agreed order is C10 migration-state reconciliation, followed by C09 retention and C17 Linux backup/restore.
