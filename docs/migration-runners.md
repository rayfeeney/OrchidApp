# Migration runners

Use these routes only for an existing database created from schema or with a valid existing migration ledger. Fresh creation remains the [schema-only contract](database-creation.md). Never initialise a database by replaying historic migration SQL.

## Supported entry points

| Entry point | Behaviour |
| --- | --- |
| database/scripts/Apply-Migrations.ps1 | Canonical operational runner. Validates all files/history, applies pending SQL and records successful checksums. Does not require Git or export the schema. |
| database/scripts/Apply-MariaDBMigrations.ps1 | Compatibility entry point delegating to the canonical runner, with identical parameters and rules. |
| database/scripts/dev-runner.ps1 | Maintainer workflow: canonical validation/application, followed by schema/manifest/checksum export for review. PlanOnly skips both writes and export. It no longer compares an old DB with the newest schema before upgrade or treats expected exported changes as a failed migration. |
| Desktop startup | Uses the matching C# policy and durable marker. Performs the existing backup gate after preflight and before pending SQL. Uses the configured DefaultConnection; the web OrchidDb connection must point to the same database. |

PowerShell routes require all five explicit MARIADB_HOST, MARIADB_PORT, MARIADB_DATABASE, MARIADB_USER and MARIADB_PASSWORD values. They no longer choose conflicting port/database defaults or infer endpoints from MYSQL_* aliases. Keep credentials in private local configuration; they are passed to the client process through MYSQL_PWD, restored afterwards, and are not placed on its command line or in a generated plaintext credential file. Tool selection uses MARIADB_EXE or the [documented resolver](database-creation.md); the developer export also resolves mariadb-dump.

The default migration folder is relative to each script's repository location, independent of the caller working directory. All three PowerShell entry points accept MigrationFolder, MariaDbExe and PlanOnly. Script paths use the correct filename case on Linux.

Before applying: stop normal application writes using the relevant platform procedure, keep the complete migration package and verify a recoverable backup. Operational PowerShell runners do not create a backup automatically; Desktop retains its separate backup command. These differences are deliberate.

On packaged Windows, Desktop now sends its pre-update backup to ProgramData/OrchidApp/backups/pre-migration with SkipOldBackupPruning. These safety copies are outside routine retention; see the [Windows retention contract](windows-backup-format.md#routine-backup-retention). This changes backup placement, not migration SQL/history policy or the Development .env startup flow.

```powershell
pwsh ./database/scripts/Apply-Migrations.ps1 -PlanOnly
pwsh ./database/scripts/Apply-Migrations.ps1
```

PlanOnly reads the selected database and lists pending names/checksums. It writes no marker, SQL, history or exports. Invalid or incomplete history still fails. Require a successful exit before continuing deployment.

## Validation before any migration SQL

Both validators enforce the same contract and run the same shared scenario fixtures:

- Names must be valid calendar timestamps followed by an ASCII description: YYYYMMDDHHMM_Description.sql. The suffix is lowercase .sql; names fit schemaversion.scriptName. Duplicate timestamps are rejected across both package files and recorded history.
- The existing schemaversion table must use InnoDB, matching the canonical schema, so its success-row/pending-marker transaction is real. Unsupported history-table engines are rejected rather than silently converted.
- Applied records require a valid SHA-256 checksum. Any supplied applied file must match its original raw bytes. File line-ending conversions count as changed bytes; restore the trusted original artifact instead of recomputing stored history.
- Applied files must remain available unless their timestamp is covered by the database's schema baseline. An empty/missing payload cannot silently hide a required applied file.
- Pending files after the schema cut-off must be later than every applied migration. Earlier missing steps/backdated additions fail, even if another pending file would otherwise be executable.
- Entire batches are validated before returning a plan, and before Desktop starts its backup gate. Pending SQL and its checksum are captured together; changed files are rejected on the post-acquisition recheck.

A baseline:v1 timestamp is an inclusive schema boundary. Historic filenames at or before it can be reintroduced or omitted and are not replayed. That timestamp alone cannot distinguish a newly invented backdated historical filename from an original covered one; never add changes below that boundary. Add a later forward migration instead. If a covered historical file is supplied and has a recorded checksum, the checksum is still verified.

Older literal baseline/baseline rows and per-file records remain untouched. A legacy marker with no ledger does not authorise an upgrade containing SQL. Markerless databases with a complete per-file ledger remain supported. Unknown/ambiguous baseline records, empty history and incomplete markers fail rather than being guessed or backfilled.

This is migration-history validation, not a universal live schema-drift certificate. Desktop's packaging may omit the migration directory only when no required ledger files are missing (for example a fresh schema-only baseline). PowerShell callers must supply an existing migration directory, which can be empty when the same compatibility rules permit it.

## Partial failure and competing runners

Immediately before each script, a runner inserts the fixed migration:pending row into the existing schemaversion table, with that script's checksum. The unique scriptName prevents cooperating C04 runners from executing scripts simultaneously. The owner re-reads history under that marker and validates again, so a stale plan does not replay SQL another runner already completed.

After successful SQL, insertion of its ordinary applied row and removal of migration:pending occur in one history transaction. This does not make DDL transactional. A SQL failure, process crash or uncertain success leaves an incomplete marker; later Desktop/PowerShell attempts stop, including PlanOnly. The failing invocation reports the script name; the stored digest can be matched to the trusted package. Successful applied rows and baseline rows are not rewritten.

Do not delete the marker to force a retry. Preserve the error, selected package and database, stop writers, and inspect the actual partial state. The normal recovery route is a verified pre-migration backup and a corrected/reviewed upgrade. Maintainer investigation is required if recovery cannot establish a trustworthy state. No automatic DDL rollback or blind recovery is claimed. All migration clients using the database must be updated together; older runners do not implement these safeguards.

The exporter rejects a pending marker before changing generated definitions. Do not export concurrently with database/schema changes; an export is not a consistent snapshot of a changing live database. Developer export runs only after the canonical runner succeeds. A post-apply export failure does not undo already applied SQL: preserve its output, fix export/tool configuration, and inspect the existing successful ledger before proceeding.

## Reproduce validation

From the repository root:

```powershell
dotnet run --configuration Release --project tests/MigrationHistory.Checks/MigrationHistory.Checks.csproj
pwsh ./tests/MigrationHistory.Checks/Policy.Checks.ps1
pwsh ./tests/MigrationHistory.Checks/Process.Checks.ps1
pwsh ./tests/MigrationHistory.Checks/Database.Checks.ps1
```

The first two run the same 24 policy scenarios without a database. Process.Checks.ps1 verifies the test-only child-process protocol without a database. Database.Checks.ps1 runs those protocol checks automatically first and matches the original exception message returned as JSON, rather than PowerShell formatted errors that can wrap differently on CI. The database suite requires explicit credentials/endpoint on a disposable MariaDB 10.11 server with create/drop rights. It creates/drops only an orchids_migrations_<guid> database, stages developer exports in a separate temporary source copy, and retains unique fixture folders for diagnosis. It tests both operational entry points, later-once-only application, complete preflight, legacy rows, failed DDL, retry blocking, competing runners, explicit target requirements and export refusal before source mutation.

After a Release web build on Windows, actual staged Desktop checks are available with the same isolated server settings:

```powershell
pwsh ./tests/MigrationHistory.Checks/Desktop.Checks.ps1
```

These create/drop only an orchids_desktop_<guid> database, copy the app/client into a unique temporary stage and simulate a successful backup command there. They verify actual application startup, once-only upgrades, preflight before backup, failed-DDL markers, blocked restart and the declared protected backup arguments. BackupFixture.ps1 records arguments only in that temporary stage and never writes the supplied backup directory. The synthetic command is never delivered as operational app code and does not validate real backups.

CI runs the C# policy check in the build job and the PowerShell policy/database checks in schema-contract. Local results and platform limits are in [C04 evidence](maintenance/c04-migration-runners.md). Full new-environment CI acceptance remains C05.
