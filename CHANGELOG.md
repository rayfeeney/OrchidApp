# C18 CI correction - installer compiler output

Changes only: one modified repository file plus this CHANGELOG.md. No additions, deletions or moves to application code or data.

## Apply

Extract into the source repository root containing OrchidApp.sln after C18, replacing the listed test file. Commit and rerun CI. No database migration, .env change, installed application upgrade or repackaging is required for this test-only correction.

## Exact change

- tests/InstallerUpgrade.Checks/Installer.Checks.ps1: route compiler progress to the host stream so the Build function returns only the executable path. Inno 6 emitted Preprocessing on stdout, which PowerShell previously collected together with the path. Verify that the compiled executable exists before returning it.

## Validation

All 22 actual isolated installer checks passed using the local Inno 7 compiler through a temporary wrapper that deliberately emits the same Preprocessing stdout text. This exercises real compilation, clean installation, app-only upgrade, failed-snapshot blocking, recovery extraction and uninstall preservation. PowerShell parsing passed. Inno 6.7.1 itself was not available locally; rerun GitHub CI for that compiler. Production installer and backup policy are unchanged.
