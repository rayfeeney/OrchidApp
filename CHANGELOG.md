# C04 - Migration runners

Delivery date: 24 October 2026. Incremental source change after C01+C02 and the CI fixes that subsequently passed.

## Apply

1. Preserve or commit any independent edits to the listed files; merge them if necessary.
2. Extract this ZIP directly into the repository root, the folder containing OrchidApp.sln. Preserve folder paths and allow replacement of the modified files.
3. No deletions or moves are required. CHANGELOG.md is the delivery manifest and replaces the previous package manifest.
4. This is source/scripts/documentation/tests only. No compiled installer, live data, credentials or unchanged repository files are included. Build/package through your normal process.
5. Applying these files requires no manual schema, baseline or checksum-history edits. No new DDL migration is included because the schema is unchanged. Existing applied/baseline rows stay intact.
6. Commit and push the complete set so CI can run the new Linux checks. Update all migration clients together; older clients do not implement the pending-marker safeguard.

## Behaviour changes

- Apply-Migrations is the canonical PowerShell runner. Apply-MariaDBMigrations delegates to it. dev-runner applies successfully before exporting for maintainer review.
- All PowerShell routes require explicit MARIADB_HOST, MARIADB_PORT, MARIADB_DATABASE, MARIADB_USER and MARIADB_PASSWORD. No conflicting endpoint defaults or MYSQL_* inference remain in these runners.
- All routes accept -PlanOnly. It validates/prints the plan and writes no SQL, marker or exports. Operational PowerShell does not make a backup automatically; Desktop retains its existing backup gate.
- Both validators reject invalid/duplicate timestamps, changed checksums, required missing files, backdated pending changes and incompatible/empty history. The documented schema-baseline exceptions preserve legitimate historical payload and legacy rows.
- A durable migration:pending row serialises cooperating runners. Successful SQL is recorded with marker removal in one history transaction; failures leave the marker and block replay. InnoDB history is required. This does not provide DDL rollback.
- Do not delete a marker to force retry. Preserve the error and package, stop writers, and restore a verified pre-migration backup or obtain maintainer investigation.
- dev-runner no longer rejects old databases by exporting/comparing them with the newest schema before upgrade. Generated post-apply changes are reviewed and committed; an export failure does not undo successful SQL.

## Files

| Status | Repository path | Change |
| --- | --- | --- |
| Modified | `.github/workflows/ci.yml` | Adds C# and PowerShell policy/package validation and isolated runner/failed-DDL checks to CI. |
| Modified | `CONTRIBUTING.md` | Updates supported entry points, explicit settings, verification commands and CI scope. |
| Modified | `RELEASE_NOTES.md` | Records C04 behaviour, pending markers and validation limits. |
| Modified | `database/scripts/Apply-MariaDBMigrations.ps1` | Compatibility wrapper using the canonical runner and identical parameters. |
| Modified | `database/scripts/Apply-Migrations.ps1` | Canonical runner: explicit endpoint, complete preflight, PlanOnly, durable pending marker, revalidation and atomic history completion. |
| Modified | `database/scripts/Export-MariaDBSchema.ps1` | Refuses incomplete migration state before exporting definitions. |
| Added | `database/scripts/Migration-History.ps1` | Shared PowerShell validation for filenames, timestamps, checksums, missing files and baseline exceptions. |
| Modified | `database/scripts/Schema-Baseline.ps1` | Recognises incomplete migration markers and blocks unsafe continuation. |
| Modified | `database/scripts/dev-runner.ps1` | Applies using the canonical runner, then exports for maintainer review; PlanOnly does not export. |
| Modified | `docs/architecture.md` | Describes consolidated routes and their actual guarantees. |
| Modified | `docs/code-change-backlog.md` | Records C04 implementation and pending Linux CI acceptance. |
| Modified | `docs/database-creation.md` | Links the C04 upgrade rules while keeping fresh creation separate. |
| Modified | `docs/development-setup.md` | Explains explicit targets, PlanOnly and developer apply-then-export workflow. |
| Modified | `docs/documentation-map.md` | Registers the migration runner guide as the subject owner. |
| Modified | `docs/index.md` | Links the migration runner guide. |
| Added | `docs/maintenance/c04-migration-runners.md` | Records actual test evidence and remaining Linux/operational limits. |
| Added | `docs/migration-runners.md` | New authoritative entry-point, validation, baseline, pending-marker and recovery contract. |
| Modified | `docs/user-guides/linux/installation-upgrade.md` | Updates migration safeguards and incomplete-state recovery instructions. |
| Modified | `src/OrchidApp.Web/Program.cs` | Uses matching C# preflight and pending-marker execution, retaining the backup gate and captured SQL. |
| Added | `src/OrchidApp.Web/Infrastructure/MigrationHistory.cs` | Adds the Desktop history validator and immutable pending SQL/checksum snapshots. |
| Modified | `src/OrchidApp.Web/Infrastructure/SchemaBaseline.cs` | Validates the InnoDB history table and routes the compatibility Pending helper through the C04 policy. |
| Added | `tests/MigrationHistory.Checks/Database.Checks.ps1` | Checks both operational routes, partial failures, competing runners, engine/endpoint validation and staged developer export. |
| Added | `tests/MigrationHistory.Checks/Desktop.Checks.ps1` | Checks actual staged Windows Desktop startup/upgrade/preflight and failed-upgrade restart using a disposable database. |
| Added | `tests/MigrationHistory.Checks/Fixtures/policy.json` | Defines 24 shared success/failure scenarios for both validators. |
| Added | `tests/MigrationHistory.Checks/MigrationHistory.Checks.csproj` | Adds the executable C# migration policy check project. |
| Added | `tests/MigrationHistory.Checks/Policy.Checks.ps1` | Runs the same policy scenarios and real package inventory through PowerShell. |
| Added | `tests/MigrationHistory.Checks/Program.cs` | Runs the shared policy scenarios and validates the real migration inventory. |

## Verification completed locally

- Release web build: passed, zero warnings/errors.
- 24 policy scenarios passed in C# and the same 24 in PowerShell; both validated all 244 current packaged migrations.
- 53 disposable Windows MariaDB migration checks passed.
- 12 actual staged Windows Desktop checks passed.
- Regression checks passed: 18 schema policy, 28 schema-creation/database, 163 monitoring isolation and 8 tool-resolution checks.
- Failed-DDL tests verified observable partial state, stopped later statements, retained pending markers and blocked retries. Competing runners applied the change once. Non-InnoDB history was rejected. Export with incomplete history left staged generated files unchanged.
- Schema definitions, manifest, schema checksums and all historical SQL were verified unchanged. PowerShell syntax, documentation links and ZIP contents were checked.
- The monitoring regression emitted NU1900 because package vulnerability lookup was unavailable locally; its tests passed.

## Remaining acceptance

The newly added Linux CI steps have not been run locally; verify the CI run for this commit. Actual Desktop tests used a synthetic successful-backup command only in their disposable stage: they do not certify real backups or recovery. Full device/installer validation, historical DDL replay against representative real backups, live drift and broader new-environment acceptance remain separate. See docs/maintenance/c04-migration-runners.md.

Next agreed implementation step: C16 - developer setup; then C05 - CI database acceptance.

## Check commands

From the repository root:

```powershell
dotnet run --configuration Release --project tests/MigrationHistory.Checks/MigrationHistory.Checks.csproj
pwsh ./tests/MigrationHistory.Checks/Policy.Checks.ps1
pwsh ./tests/MigrationHistory.Checks/Database.Checks.ps1
```

Database.Checks requires explicit credentials for a disposable MariaDB server with create/drop privileges. Windows staged-app checks additionally use Desktop.Checks.ps1 after a Release web build. See docs/migration-runners.md for the complete contract.
