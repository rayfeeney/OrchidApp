# C17 Linux paired backup and recovery

Changes only: 10 modified and 6 added repository files, plus this CHANGELOG.md. No deletions/moves. No credentials, private .env, collection data, backup archives or runtime binaries are included.

## Apply

1. Extract over the source root containing OrchidApp.sln, replacing only the listed files. This follows C09. It does not install software, change credentials, schedule a job or operate a collection.
2. Run CI. The new Linux job requires its first GitHub Actions run. Keep backup_orchids.sh, restore_orchids.sh and orchid_backup.py together.
3. Existing Linux deployments must configure the new explicit JSON/client/rclone paths and Python dependency before invoking/scheduling the replacement backup script. An old no-argument cron invocation now fails safely; update/test it rather than restoring personal hard-coded defaults.
4. Follow docs/user-guides/linux/OrchidApp-MariaDB-Backup-and-Restore-Runbook.md. Test a manual backup and isolated recovery before scheduling --stop-writers. The scheduled account needs all listed tool, file and service-control permissions.

Each new archive carries its own SQL, uploads and external settings. The tool requires quiescent application writers and holds a server-wide database read lock during capture. Verified immutable remote copy/read-back precedes local retention (default 14, minimum 1). Pinned, foreign/unknown/corrupt and legacy files remain. Remote deletion is manual; previous SQL-only snapshots/current uploads mirror are not converted or deleted.

Restore requires one trusted archive, an absent output directory and an explicitly confirmed isolated existing empty database with the source name. It does not overwrite current uploads/settings or activate captured configuration. Failed SQL may be partially applied; input and RESTORE-PENDING.json are preserved. After data verification, application/replacement acceptance remains necessary.

All 333 schema/checksum/historical SQL artifacts are unchanged. No migration is required. Every src/ file, Windows backup/restore tool and Windows guide is unchanged, including the working Development startup configuration and C09 safeguards.

## Files

| Change | Repository path | Purpose |
| --- | --- | --- |
| Modified | .github/workflows/ci.yml | Add isolated Linux archive/MariaDB/crypt checks and wrapper smoke checks. |
| Modified | CONTRIBUTING.md | Document executable checks, disposable-server requirements and remaining platform acceptance. |
| Modified | RELEASE_NOTES.md | Record paired Linux snapshots and required deployment reconfiguration. |
| Modified | docs/code-change-backlog.md | Record C17 implementation, evidence and pending Linux/installation acceptance. |
| Modified | docs/documentation-map.md | Link Linux snapshot ownership/evidence. |
| Modified | docs/index.md | Link C17 evidence. |
| Added | docs/maintenance/c17-linux-paired-backup.md | Record actual checks, skipped platforms and operating limits. |
| Modified | docs/user-guides/linux/Full-App-Backup-Pre-Upgrade.md | Distinguish paired data snapshots from whole-app/OS rollback. |
| Modified | docs/user-guides/linux/OrchidApp-MariaDB-Backup-and-Restore-Runbook.md | Replace obsolete mirror instructions with configuration, scheduling, paired capture, retention and isolated recovery. |
| Modified | docs/user-guides/linux/installation-upgrade.md | Add Python requirement and distinguish routine/full-backup dependencies. |
| Added | infrastructure/backups/backup.example.json | Supply non-secret explicit configuration template requiring a stable collection UUID. |
| Modified | infrastructure/backups/backup_orchids.sh | Replace personal-path SQL/mirror script with explicit paired backup entry point. |
| Added | infrastructure/backups/orchid_backup.py | Implement private configuration, writer control/read lock, checked snapshot capture, remote read-back, local retention and failed-restore marker. |
| Added | infrastructure/backups/restore_orchids.sh | Add matching isolated recovery entry point. |
| Added | tests/LinuxBackup.Checks/Database.Checks.ps1 | Create/drop only a generated canonical database with protected temporary client defaults for native checks. |
| Added | tests/LinuxBackup.Checks/checks.py | Add policy fixtures, actual optional crypt backend and generated canonical-schema MariaDB round trip. |

## Validation actually completed

- Final local suite: 31 discovered tests, 28 passed and 3 explicit platform skips (POSIX permissions, source symlink creation and actual rclone crypt backend).
- Actual MariaDB 10.11.16 round trip on a newly generated Windows instance and canonical schema/seeds, with no migration replay. It checked old rows/photos/hidden uploads/configuration, blocked concurrent SQL writer, missing photo rejection and persistent partial-DDL recovery state. Service/cloud adapters were simulated; no live data or private environment file was used. The generated database was dropped and owned server shut down.
- Both Bash wrappers passed installed Git Bash syntax checks. Changed PowerShell parsed without errors. actionlint passed with optional ShellCheck/Pyflakes integrations disabled.
- Exact changed-file list/ZIP bytes, Markdown links, merge markers, Python syntax, template JSON and unchanged SQL/Windows/startup artifacts were checked. Existing Linux Word guides have no affected script instructions; no Word edit/render was required.

## Limits and next work

Linux CI, real systemd/cron/provider credentials, Pi hardware and compatible application save/reopen/replacement acceptance remain pending. CI adds an actual rclone crypt test on local disposable storage; that is not a real cloud-provider test. Direct filesystem writers outside configured units must also be paused. Source hashes cannot detect all transient writes. Database read locks affect the entire selected server, and restored secret configuration needs private review. Interrupted operations can leave stopped units/stale locks; investigate before clearing. Remote retention is manual and local count is not a storage cap.

Next in the agreed sequence: phase 3, C11 manual lifecycle closure/failure handling.
