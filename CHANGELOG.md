# C18 - installer upgrade safeguards and recovery

Changes only: 16 modified and 10 added repository files, plus this CHANGELOG.md. No deletions or moves. No private .env, credentials, collection data, runtime binaries or generated installers are included.

## Apply to source

1. Apply after the merged C15/C19 changes. Extract into the source repository root containing OrchidApp.sln, replacing only the listed files. Review the resulting Git changes, including this delivery changelog.
2. Run normal CI. C18 requires no database migration, credentials change or development startup change. Keep .env private; ordinary dotnet run remains the development entry point.
3. This is source, not an installed upgrade ZIP. Rebuild/package Windows from source; do not extract over Program Files.

## Windows release and upgrade actions

Package all three snapshot helpers and build the installer. Keep its .evidence.json beside the release artifact and inspect its actual signing status. The optional RequireValidSignature build switch enforces a valid signature; it does not sign anything.

Before every upgrade, including app-only updates and repair, keep a normal off-computer backup and the previous installer. Close the launcher, database and other writers and keep them stopped until setup finishes. Setup now requires a new verified offline snapshot before replacing existing files. A truly empty fresh installation creates no snapshot or database.

Snapshots are stored under ProgramData/OrchidApp/backups/pre-install and are not automatically pruned. They contain raw stopped database files paired with application, photo and settings files, excluding existing top-level backup directories. They are distinct from normal logical backup ZIPs and must not be passed to the Restore dialog. Recovery is support-assisted: verify/extract to a new staging root, preserve the failed state and use matching old application/runtime and data. No automatic rollback or active-data overwrite is performed. See docs/windows-installer-recovery.md and docs/upgrade-checklist.md.

## Linux upgrade actions

C18 adds no Linux setting, migration or automatic backup gate. Continue the documented stopped-writer paired database/photo backup and retain compatible old application/configuration for recovery, including app-only updates. The complete Windows/Linux C1-C20 action list remains docs/upgrade-checklist.md; C20 is next.

## Validation and remaining acceptance

- Policy: 28 checks passed on Windows PowerShell 5.1 and 28 on PowerShell 7.
- Actual isolated Inno installer: 22 checks passed, including clean install, app-only upgrade, failure blocking, recovery staging and uninstall data preservation.
- Disposable real MariaDB recovery: 9 checks passed. Previous row/schema history, photo/settings and application marker were recovered; failed-upgrade files were preserved. This is not a historical full application launch test.
- Build evidence: 5 checks passed. Local generated installer artifacts were NotSigned; no signed release is claimed.
- PowerShell parsing and workflow lint passed. Both edited Word guides were rendered and all 19 pages inspected; all 16 embedded media files are unchanged.
- Every database artifact is byte-identical to the C18 baseline. Application feature code and development configuration are unchanged.
- Installer fixtures use a separate identity, temporary roots and controlled process inventory. Production still rejects unidentified potential database processes. Real database file-lock refusal was also tested.
- GitHub CI has been configured but has not been run here. Full production administrator installation, representative older-release upgrade/recovery and Linux device acceptance remain pending. Retain the separate historical installation task.

## Exact file list

| File | Change | Purpose |
|---|---|---|
| `.github/workflows/ci.yml` | Modified | Run installer policy, actual installer, database recovery and artifact evidence checks in Windows CI. |
| `CONTRIBUTING.md` | Modified | Document C18 validation commands and limits. |
| `RELEASE_NOTES.md` | Modified | Record installer safeguards and outstanding acceptance. |
| `app/tools/Installer-Snapshot.ps1` | Added | Capture, verify and safely stage offline rollback snapshots. |
| `app/tools/prepare-installer-upgrade.ps1` | Added | Abort setup before replacement if pre-install checks or snapshot fail. |
| `app/tools/review-installer-snapshot.ps1` | Added | Verify snapshots or extract into an absent staging directory. |
| `docs/architecture.md` | Modified | Align upgrade policy, recovery instructions, implementation status and evidence links with C18. |
| `docs/code-change-backlog.md` | Modified | Align upgrade policy, recovery instructions, implementation status and evidence links with C18. |
| `docs/documentation-map.md` | Modified | Align upgrade policy, recovery instructions, implementation status and evidence links with C18. |
| `docs/index.md` | Modified | Align upgrade policy, recovery instructions, implementation status and evidence links with C18. |
| `docs/maintenance/c18-installer-upgrades.md` | Added | Align upgrade policy, recovery instructions, implementation status and evidence links with C18. |
| `docs/upgrade-checklist.md` | Modified | Align upgrade policy, recovery instructions, implementation status and evidence links with C18. |
| `docs/user-guides/linux/installation-upgrade.md` | Modified | Align upgrade policy, recovery instructions, implementation status and evidence links with C18. |
| `docs/user-guides/windows/01-InstallOrUpgradeOrchidAppOnWindows.docx` | Modified | Update Windows user instructions; preserve all embedded screenshots. |
| `docs/user-guides/windows/05-RecoverOrchidAppOnReplacementWindowsComputer.docx` | Modified | Update Windows user instructions; preserve all embedded screenshots. |
| `docs/windows-backup-format.md` | Modified | Align upgrade policy, recovery instructions, implementation status and evidence links with C18. |
| `docs/windows-installer-recovery.md` | Added | Align upgrade policy, recovery instructions, implementation status and evidence links with C18. |
| `docs/windows-upgrade-contract.md` | Modified | Align upgrade policy, recovery instructions, implementation status and evidence links with C18. |
| `installer/windows/OrchidApp.iss` | Modified | Run embedded pre-install snapshot gate; isolate test installer identity. |
| `scripts/build-windows-installer.ps1` | Modified | Validate packaged helpers and record actual checksum/signature status. |
| `scripts/package-windows.ps1` | Modified | Require all three snapshot helpers in the Windows package. |
| `tests/InstallerUpgrade.Checks/Build.Checks.ps1` | Added | Test real installer build evidence and unsigned enforcement. |
| `tests/InstallerUpgrade.Checks/Database.Checks.ps1` | Added | Test recovery with a disposable real MariaDB instance. |
| `tests/InstallerUpgrade.Checks/Installer.Checks.ps1` | Added | Test isolated actual clean install, upgrade, blocking and uninstall preservation. |
| `tests/InstallerUpgrade.Checks/Policy.Checks.ps1` | Added | Test snapshot safety, integrity and process policy on both PowerShell versions. |
| `tests/InstallerUpgrade.Checks/PrepareFixture.ps1` | Added | Supply controlled process inventory only for the isolated installer fixture. |
