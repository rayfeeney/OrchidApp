# CI correction: .env fixture privacy false positive

Changes only: two modified repository files plus this CHANGELOG.md. No additions, deletions or moves. No private .env, credentials, DB changes, migrations, backup files or runtime binaries are included.

## Apply

Extract over the repository root containing OrchidApp.sln after the development .env delivery, commit normally and rerun CI. Your development update command and .env are unchanged. No further database update is required for this test-only correction.

The CI administrator password is the common word root, which also appears in Git's legitimate root-commit output. The old whole-output substring assertion therefore produced a false password-disclosure alarm. The test now creates a separate random account with a unique high-entropy password for the wrappers' .env, preserves the strict password/stale-secret checks, and drops that account during cleanup. Its grants cover only the generated DB plus mysql.proc read access needed for routine export/dump. Administrative bootstrap/cleanup credentials are separate.

## Files

| Repository path | Purpose |
| --- | --- |
| tests/DevelopmentSetup.Checks/DatabaseUpdate.Checks.ps1 | Use a unique generated .env account/password rather than searching all hook output for the common CI administrator password; clean up the account. |
| docs/maintenance/development-dotenv-workflow.md | Record the false-positive cause, unchanged strict privacy assertion and actual validation. |

## Actual verification

All 24 real SQL/backup/actual Git-hook checks passed twice on new Windows MariaDB 10.11.16 fixtures: once with the previous test admin credentials and once with CI's root/root admin credentials. Both runs used the unique wrapper account/password and preserved the output privacy checks. Generated accounts/databases and owned servers were cleaned up. The changed PowerShell file parsed successfully; documentation links, exact changed-file/ZIP bytes and unchanged application, schema, migrations and developer commands were checked.

Linux CI still needs the corrected commit rerun. No user .env or real development/collection database was changed.
