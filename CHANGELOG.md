# Development credentials from .env: one update command

Changes only: 9 modified and 6 added repository files plus this CHANGELOG.md. No deletion/move. No private .env, passwords, database backups, collection data or runtime binaries are included.

## Apply

1. Extract over the repository root containing OrchidApp.sln after the C11 and export-guard corrections. Keep all helper scripts and the hook together.
2. Stop the development app. From that repository root run:

   pwsh ./scripts/DevSetup/update-database.ps1

3. Retry the normal commit. No repeated credential entry or special Git GUI launch is required. The command and hook read the existing repository .env; do not copy it into Git or this ZIP.

The update command reads all five MARIADB values from .env, checks the pending plan, makes a logical SQL backup outside the checkout, then uses the canonical migration runner. Backup failure blocks SQL. With no pending migrations it is a no-op; -PlanOnly previews without backup/application. Backups are retained under the current user's local app-data OrchidApp/Development/database-backups directory, with hashes and unique names. This is not an uploads/configuration snapshot or whole-collection recovery guarantee. Keep writers stopped and review retained backups privately.

The hook now loads the same file through scripts/DevSetup/export-schema.ps1. It still refuses pending migrations/older history and never updates the DB automatically. Complete file-based credentials override stale ambient DB values only inside these wrappers, with restoration afterwards. Passwords are neither printed nor command arguments. AGENTS.md explicitly records that .env holds development credentials and the owner should not be asked to re-enter them.

This delivery does not update the owner's actual database: the owner runs the command after extraction. No new migration/schema/app startup/production deployment contract change is introduced.

## Files

| Change | Repository path | Purpose |
| --- | --- | --- |
| Modified | .githooks/pre-commit | Read .env through the developer export wrapper, preserving guarded export and normal Git staging. |
| Modified | .github/workflows/ci.yml | Run parser checks on Windows/Linux and real DB/backup/Git workflow in the Linux lifecycle job. |
| Modified | AGENTS.md | Record that repository .env holds development credentials; never request/reveal/repackage them. |
| Modified | CONTRIBUTING.md | Document the single update command and developer credential convention. |
| Modified | RELEASE_NOTES.md | Explain the one-command development update and consistent GUI hook credentials. |
| Modified | docs/development-setup.md | Give the one-command update/commit steps and exact backup/credential behavior. |
| Modified | docs/maintenance/c11-manual-closure.md | Replace repeated manual credential setup with the developer command. |
| Added | docs/maintenance/development-dotenv-workflow.md | Record behavior, actual tests and remaining Linux/device limits. |
| Modified | docs/upgrade-checklist.md | Keep the source-development prerequisite aligned with the .env workflow. |
| Added | scripts/DevSetup/Repository-Environment.ps1 | Parse only five literal credential keys, use the complete file target and restore the caller environment. |
| Added | scripts/DevSetup/export-schema.ps1 | Load .env for guarded development/pre-commit export without applying SQL. |
| Modified | scripts/DevSetup/setup.ps1 | Correct the message about GUI hook credentials. |
| Added | scripts/DevSetup/update-database.ps1 | Plan, back up SQL outside the repo and apply pending development migrations; provide no-op and PlanOnly paths. |
| Added | tests/DevelopmentSetup.Checks/DatabaseUpdate.Checks.ps1 | Add 24 real database/backup/actual Git-hook checks on disposable fixtures. |
| Added | tests/DevelopmentSetup.Checks/DotEnv.Checks.ps1 | Add 26 parser/environment/privacy checks. |

## Validation actually completed

- 26 .env parsing/environment checks passed, including quotes/literal special characters, stale ambient credentials, canonical key casing, ignored keys, invalid/missing values and restoration after success/failure.
- 24 native Windows MariaDB 10.11.16/backup/actual Git-hook checks passed on a new server and temporary repo: pending commit failed, plan was read-only, failed backup blocked migration, successful update backed up then applied once, repeat was a no-op, and the real Git commit succeeded with deliberately wrong ambient credentials. No password/backup/.env entered captured output or hook-staged files.
- All 18 existing development configuration checks passed. Six changed PowerShell files parsed successfully. actionlint passed with optional ShellCheck/Pyflakes integrations disabled.
- Exact changed files/ZIP bytes, Markdown links, merge markers and unchanged database/schema/history/application/backup artifacts were checked. No Word behavior/instruction change required editing/rendering the installed-app guides.
- Owned generated DB/server was cleaned up, synthetic .env removed, diagnostic synthetic sources/backups retained. No actual user .env values or real development/collection database were modified.

Linux CI and real Git GUI/device acceptance remain pending. Direct production/operational scripts keep explicit environment configuration; this is the development workflow only.
