# Development .env database update and commit workflow

The owner keeps development credentials in the repository-root .env. Asking for repeated environment setup made the C11 commit prerequisite unnecessarily difficult. AGENTS.md now records this convention explicitly: reuse those credentials as literal data, never print/package/commit them, and keep development separate from production/collection administration.

## Implemented

- `scripts/DevSetup/update-database.ps1` is the single development command. With the app/other writers stopped, it loads the five MARIADB connection values from .env, runs canonical preflight, makes a logical SQL backup and applies pending migrations through the existing runner. `-PlanOnly` does not back up or apply. With nothing pending it is a no-op.
- Backups are retained under the current user's local app-data `OrchidApp/Development/database-backups` outside the repo, with unique folders, SQL completion/exit checks and SHA-256 metadata. Failure blocks migration. This is not a coordinated upload/configuration snapshot or a tested whole-collection restore. Keep backup files private; retention/recovery review is manual.
- `scripts/DevSetup/export-schema.ps1` reads the same file and invokes the existing guarded exporter. The pre-commit hook now calls this wrapper. It never applies SQL itself. Git GUIs and terminals therefore use the same complete file-based target even when their inherited database variables are stale.
- The common parser accepts the app's literal KEY=value convention, export prefix, matching quotes, trailing comments after quoted values and literal unquoted hashes. No variable/backslash/shell expansion occurs. Only the five canonical database keys are imported, as one complete set without ambient fallback. Password values are never emitted; missing/invalid entries report keys/line numbers only. The previous process environment is restored after success or failure.

## Evidence

All 26 parser/environment tests passed: punctuation/literal expressions, ignored keys, lower-case canonicalisation, missing/invalid values and complete credential replacement/restoration. The native integration passed 24 checks on a new Windows MariaDB 10.11.16 instance and temporary Git repository. It proved plan-only behavior, failed backup blocking SQL, automatic backup hash/pre-migration contents, once-only migration, no-op repeat, unchanged prior rows, failed commit while pending, and successful actual Git commit/export using .env despite deliberately wrong ambient credentials. Captured output contained neither fixture password nor stale secret, and hook staging did not include .env or backups.

The generated DB/server was cleaned up; the synthetic source/backups remain in a uniquely named diagnostic temp directory, with the synthetic .env removed. No owner's .env values were read into tool output or modified, and no real development/collection DB was updated. All 18 existing development configuration checks passed; PowerShell syntax and actionlint checks passed (optional ShellCheck/Pyflakes disabled). CI adds parser checks on Windows/Linux and actual SQL/backup/Git checks in the Linux lifecycle job. Those new Linux CI steps and real GUI/device acceptance still require a run.

No new migration, generated schema, app startup behavior, packaged Windows backup rule or production/Linux deployment credential contract changes. The maintained [developer guide](../development-setup.md), [C11 instructions](c11-manual-closure.md) and [upgrade checklist](../upgrade-checklist.md) contain the operator steps. Word guides concern installed-app workflows and require no edit/render for this source-development addition.

## CI follow-up: generic password substring caused a false alarm

The supplied Linux run failed the test's credential-output assertion. Its administrative CI password is the common word `root`; the old assertion rejected that substring anywhere in hook output, including Git's legitimate `root-commit` text. This did not establish that a password had been printed.

The generated fixture now creates a separate unique account and high-entropy password for the wrappers' .env. That account has rights on its generated database and read access to mysql.proc for routine export/dump, and is dropped during cleanup. Administrative bootstrap/cleanup credentials stay separate. The test still rejects any occurrence of the actual unique fixture password or the deliberately stale ambient secret; the privacy check is not removed or weakened. No real account, owner .env, application command or migration changes.

All 24 native database/backup/actual Git-hook checks passed with the dedicated account. All 24 also passed in a second local run using the same root/root administrative credentials as CI to cover the generic-password case. The changed PowerShell test parsed successfully. Both generated accounts/databases and owned servers were cleaned up; only private synthetic diagnostic fixtures remain. These are Windows MariaDB 10.11.16 results; the corrected Linux CI still needs rerunning.
