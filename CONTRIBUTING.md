# Contributing to OrchidApp

Start with [developer setup](docs/development-setup.md) and the [documentation ownership map](docs/documentation-map.md). Run repository commands from the root. Use isolated development data, never the live collection.

## Required contracts

- MariaDB is the supported database engine. Validate case, collation and SQL behaviour on Linux as well as affected Windows packaging workflows.
- A fresh database is created from schema and required reference seeds alone; migrations apply only after creation. See [database creation](docs/database-creation.md) for baseline requirements and current blockers.
- Bespoke environment monitoring belongs only to the owner's local installation. General users/developers must not need those feeds, permissions or objects. Leave Monitoring:Enabled false; see the [activation boundary](docs/environment-summary-platform.md).
- Respect [architecture](docs/architecture.md), [temporal behaviour](docs/temporal-design.md) and [Windows upgrade safety](docs/windows-upgrade-contract.md). Requirements are not claims that every current failure path is already enforced.

## Changes to the database

For a compatible change after creation, add a new database/migrations/YYYYMMDDHHMM_Name.sql with a unique, ordered timestamp. Never edit applied history. Apply only to an existing, correctly baselined isolated database after a recoverable backup. Do not use migration replay to initialise a fresh environment.

```powershell
pwsh ./database/scripts/Apply-Migrations.ps1
```

Supply all five explicit MARIADB_HOST, MARIADB_PORT, MARIADB_DATABASE, MARIADB_USER and MARIADB_PASSWORD values. All PowerShell entry points use one canonical runner; the compatibility alias delegates to it, and dev-runner applies then exports for review. Desktop uses the matching C# policy plus its existing backup gate. See [migration runners](docs/migration-runners.md) for PlanOnly, raw-byte checksums, chronology, missing-file/baseline exceptions, incomplete markers and recovery. DDL failures can leave partial state; do not remove a pending marker to force a retry.

Schema and checksums are generated through database/scripts/Export-MariaDBSchema.ps1. Do not manually edit database/schema/ or database/checksums/schema.json. The pre-commit hook runs the exporter on every commit and stages generated changes; an export failure aborts. Review both the staged diff and finished commit so unrelated database changes cannot slip in. Use required hooks, not --no-verify. CI cannot prove local hook use.

Export preflight refuses pending migrations or database history older than the source schema cutoff before writing schema/checksum files. Apply reviewed migrations to the isolated development/export target first; the exporter does not migrate automatically. `pwsh ./tests/LifecycleClosure.Checks/ExportPreflight.Checks.ps1` checks policy without a DB; the lifecycle database suite verifies blocked exports leave all source bytes unchanged and migrated exports succeed. Restore all matching generated artifacts if a previous commit exported old definitions; do not adjust only bootstrap timestamps.

Development credentials already live in the repository-root `.env`. With the development app stopped, use `pwsh ./scripts/DevSetup/update-database.ps1`: it reads the five MARIADB settings, backs up SQL outside the repo and applies pending migrations. The hook uses `scripts/DevSetup/export-schema.ps1` and reads the same file, including for GUI commits. Do not print/commit the private file, ask the owner to re-enter its credentials, or run this workflow on a collection database. Low-level operational scripts keep their explicit environment contract. Check parsing with `pwsh ./tests/DevelopmentSetup.Checks/DotEnv.Checks.ps1`; check real update/backup/Git behavior with `pwsh ./tests/DevelopmentSetup.Checks/DatabaseUpdate.Checks.ps1` on an explicitly selected disposable server.

## Application and UI changes

Keep structural lifecycle writes in the intended stored procedures and other writes in the established EF Core patterns. Use asynchronous database I/O, parameterised values, trusted procedure identifiers and shared IStoredProcedureExecutor where appropriate. Do not hide operational failures or turn them into successful writes. Review calendar dates versus timestamps, same-day ties and ended-plant behaviour when changing lifecycle flows.

Use shared Razor components and preserve validated local return destinations on GET, POST, errors, Cancel and successful saves; see [navigation](docs/navigation.md). Reuse the sanitiser/editor/storage contract for [rich notes](docs/rich-notes.md). Check actual mobile workflows where affected. Update user-facing labels and screenshot references together with code.

## Documentation and history

Follow [AGENTS.md](AGENTS.md). Every code, SQL, config, dependency, script or packaging change requires a documentation impact check and affected guide updates in the same change. State which docs changed, or specifically why none were affected. Keep new supporting reports under docs/. Maintain [the code backlog](docs/code-change-backlog.md) for unresolved gaps and actual closure evidence.

Move superseded/inapplicable docs to docs/history/, preserve their context and update current incoming links. Do not delete recent change evidence simply because its intermediate behaviour is superseded. Maintain shared content in both platform Word guides together, preserve useful screenshots and render/inspect all pages after edits. Word originals are the maintained sources; historic release PDFs are not current editing masters. Preserve licence texts and required notices.

## Validate locally

Historical Linux verifier/adoption unit tests run with `python tests/HistoricalUpgrade.Checks/checks.py`. The Docker-backed command defaults to original read-only refusal; explicit `--adopt-and-migrate` verifies the exact reviewed historical structure/history, archives the original ledger unchanged, tests the four real forward migrations and confirms zero work on a second apply plus unchanged application data. This runs only in a newly owned disposable restore; no live adoption command or package/recovery acceptance is supplied. See [scope](docs/historical-linux-upgrade.md) and [adoption evidence](docs/maintenance/historical-linux-adoption.md). Missing/unreviewed inputs must fail.

Greenhouse execution is disjoint: the normal feature run covers isolated calculations/cache/policy; `--mode greenhouse-db` covers only guarded SQL loading/performance/net-cost suites. Successful logs must identify the selected suites with no mixed mode; the runner records/fails `modeEvidence` accordingly. Direct preview arguments require the connection to be cleared. See [CI mode evidence](docs/maintenance/ci-greenhouse-modes.md). Existing CI jobs and database safeguards remain separate and unchanged.

The existing lifecycle database runner also executes `tests/LifecycleClosure.Checks/ValidationMessages.Checks.py` against its generated upgraded and schema-only fixtures. It verifies rendered server-side errors, unchanged records on rejection and valid correction/save/reopen. See [plant-event message evidence](docs/maintenance/event-validation-messages.md); never run fixture tests against an installed collection.

Build the affected web application:

```powershell
dotnet build src/OrchidApp.Web/OrchidApp.Web.csproj --configuration Release
```

Choose relevant executable checks (these use dotnet run, not a conventional test discovery command):

```powershell
dotnet run --configuration Release --project tests/RichNotes.Checks/RichNotes.Checks.csproj
dotnet run --configuration Release --project tests/Navigation.Checks/Navigation.Checks.csproj
dotnet run --configuration Release --project tests/NameSearch.Checks/NameSearch.Checks.csproj
dotnet run --configuration Release --project tests/EnvironmentSummary.Checks/EnvironmentSummary.Checks.csproj
dotnet run --configuration Release --project tests/GreenhouseCharts.Checks/GreenhouseCharts.Checks.csproj
dotnet run --configuration Release --project tests/SchemaBaseline.Checks/SchemaBaseline.Checks.csproj
dotnet run --configuration Release --project tests/MigrationHistory.Checks/MigrationHistory.Checks.csproj
```

Schema creation/baseline integration checks also use pwsh ./tests/SchemaBaseline.Checks/Database.Checks.ps1 with explicit credentials for an isolated MariaDB server; they create/drop only a generated test database. See the [creation contract](docs/database-creation.md).

C16 provides pwsh ./tests/DevelopmentSetup.Checks/Configuration.Checks.ps1 and the native photo probe used by scripts/DevSetup/run.ps1; see [developer setup](docs/development-setup.md).

C04 also provides database-free PowerShell policy checks and isolated database/Desktop integration checks under tests/MigrationHistory.Checks; see the [runner guide](docs/migration-runners.md).

C06/C07 provide source-capture checks, payload compatibility checks on PowerShell 7/Windows PowerShell and an isolated Windows MariaDB backup/restore round trip under tests/BackupRestore.Checks. See [Windows archive checks](docs/windows-backup-format.md) for prerequisites, generated source/target fixtures and scope. Never run destructive restore experiments against a collection database.

C08 extends those checks with persistent recovery/cloud-copy policy, partial SQL failure, post-import photo verification failure and locked upload/settings replacement. Explicit retained-input and original-safety recovery must succeed on disposable fixtures before delivery. Keep the fixture parent short for native Windows MariaDB paths. See [C08 evidence](docs/maintenance/c08-restore-recovery.md).

C10 extends the same executable and database suites with atomic migration state, interrupted-copy reconciliation, ownership/source precedence and readiness-aware completion. Keep the original quiescent: even restarting its database changes raw fingerprint evidence. Missing/changed target files after readiness must not be repaired by blindly recopying a raw database. See [C10 evidence](docs/maintenance/c10-migration-reconciliation.md).

C09 adds tests/BackupRestore.Checks/Retention.Checks.ps1 on both PowerShell versions and real backup retention cases in the disposable database suite. Desktop.Checks.ps1 also checks the protected pre-migration invocation using its recording-only BackupFixture.ps1. Verify unrelated/pinned/pre-upgrade files survive before changing retention. See [C09 evidence](docs/maintenance/c09-backup-retention.md).

Default checks use isolated/substitute data and SQL translation where designed. Optional greenhouse DB/benchmark modes require a disposable instance, never the owner's production database; see the [local guide](docs/local-installation/greenhouse-monitoring.md). Passing these does not prove live save/reopen, native image processing, device behaviour, installer safety or restore completeness.

For docs-only work, check paths, links, commands, setting names, platform scope and Word rendering rather than requiring an app build. For database, backup/restore and package changes, validate the actual affected workflow on an isolated supported target. Preserve the recovery input and verify records, photos, settings and restart behaviour. Inspect git diff --check, staged changes and the completed commit.

## Current CI limits

C11/C12/C13/C14 provide `pwsh ./tests/LifecycleClosure.Checks/Database.Checks.ps1` with explicit MARIADB_HOST/PORT/USER/PASSWORD for a disposable server, Python 3 and .NET 8. It stages the real prior procedure with a synthetic prior-cutoff manifest, reproduces partial failure, applies the current migration package via the canonical runner, checks guarded export/checksums/history/data preservation, then runs closure, ended-plant/date, structural transaction/concurrency and history-order SQL/HTTP suites against upgraded and migration-free fresh-created databases. It drops only generated fixture DBs. `-ExportSchema` is a maintainer-only source-regeneration option, not needed by CI/operators. See [C11 evidence](docs/maintenance/c11-manual-closure.md) and [C12 evidence](docs/maintenance/c12-ended-plant-policy.md). Never inject failure triggers into a collection database. C14 adds `HistoryOrdering.Checks.py` to that same fixture runner and tests the actual Details HTML on equal timestamps/IDs, corrected dates, repeated reads and local clock-hour ties; see [C14 evidence](docs/maintenance/c14-history-ordering.md). C13 checks use persistent connections and observable server lock waits, caller-owned transactions and injected mid-operation errors; see [C13 evidence](docs/maintenance/c13-structural-transactions.md).

C17 provides `python3 tests/LinuxBackup.Checks/checks.py` for archive/service/retention policy and `pwsh ./tests/LinuxBackup.Checks/Database.Checks.ps1` for a generated canonical-schema database on an explicitly selected disposable MariaDB server. Supply explicit MARIADB_HOST, MARIADB_PORT, MARIADB_USER and MARIADB_PASSWORD. The latter drops only its generated database but acquires a server-wide read lock; never target a collection server. Native checks use service/cloud adapters, while an additional rclone crypt test uses local disposable encrypted storage when rclone is installed. The new Linux CI job runs both paths; real systemd/cron/provider/Pi acceptance remains pending. See [C17 evidence](docs/maintenance/c17-linux-paired-backup.md).

C05 replaces CI's duplicated schema assembly loops with the production schema-only creator in a stage without migration SQL. A separate 44-check disposable suite verifies seeds, baseline identity, usable views/plant records, a once-only later migration and negative creation cases. The canonical database is exported and checked for drift separately. See [creation/CI checks](docs/database-creation.md) and [C05 evidence](docs/maintenance/c05-ci-database-acceptance.md). The updated workflow still needs a GitHub Actions run. Real older-release fixtures remain a separate future task.

The [workflow](.github/workflows/ci.yml) builds/publishes linux-arm64, reconstructs/exports a MariaDB 10.11 schema to check drift, and creates a Windows package. C04 adds the shared C#/PowerShell migration-policy scenarios, actual package inventory validation and disposable runner/failed-DDL checks. The owner confirmed these corrected C04 Linux checks passed. C16 adds development configuration and native photo/thumbnail save/reopen checks on Windows and Linux; those new steps still need CI confirmation. C18 now compiles/tests an isolated Inno installer and compiles the production artifact with signing evidence. C20 adds eight isolated feature executables and greenhouse SQL integration with retained reports. It still does not exercise every historical DDL against representative old releases or prove device install/recovery. See [testing/evidence](docs/testing-evidence.md) for the maintained inventory and remaining acceptance. Cross-publishing is not Pi hardware validation.

## Pull requests

For C01–C20 and deployment-affecting work, update the [upgrade action checklist](docs/upgrade-checklist.md) in the same change. Fill the relevant Windows/Linux steps and coverage row with actual migration names, changed settings/defaults, configuration timing and failure/recovery instructions. Pending design must stay visibly pending. Before release, retain a revision-specific checklist and private machine acceptance record; the eventual tracking tool is not yet selected.

Describe the concrete problem and resulting behaviour, operational/compatibility effects, docs updated and checks actually run with their limits. Include new migrations and generated exports for DB changes. Review licences for dependency/distribution changes. Require appropriate CI and local checks; do not describe planned safeguards or unrun tests as completed. Keep credentials, private data, local uploads and unrelated generated changes out of the contribution.

## C15/C19 photo policy and recovery checks

`tests/DevelopmentNative.Checks` now references the real Web project and includes synthetic orientation/GPS/XMP/ICC/alpha fixtures, pair-publish failure and transaction/recovery fault checks. Run its existing native check command with the restored supported libvips runtime. It executes 611 policy assertions and 32 recovery assertions plus the original save/decode round trip. Fixtures are generated test images with synthetic metadata, not collection photos.

The lifecycle database runner now runs `PhotoConsistency.Checks.py` before the existing C11–C14 scenarios on both upgraded and schema-only fresh fixtures. Its 19 scenarios include plant/taxon rollback, caller-preserving taxon SQL, readiness failures, private/read-only recovery reporting and a synthetic paired SQL-and-upload archive restore. Together the suites execute 168 SQL/HTTP scenarios. Use only the runner's disposable database server contract; never point these failure-injection checks at a collection. Linux CI installs libvips-tools for actual native processing. Controlled native dependency/commit/rollback faults are not proof of a physical crash or every supported runtime. See [policy and recovery](docs/photo-handling.md) and [evidence](docs/maintenance/c15-c19-photo-handling.md).

## C18 installer acceptance

Run `tests/InstallerUpgrade.Checks/Policy.Checks.ps1` on Windows PowerShell 5.1 and PowerShell 7, `Installer.Checks.ps1` with Inno Setup, and `Database.Checks.ps1` with the isolated Windows MariaDB runtime. Build the Release launcher before `Build.Checks.ps1`. Pass `-InnoCompiler <absolute-ISCC-path>` where needed. These use generated temporary roots, synthetic data and an unrelated per-user installer identity; never run experiments against an installed collection. Fixture installers substitute process enumeration, with the strict production decisions tested on controlled rows. Native sharing locks, ZIP verification, actual fixture install/upgrade/uninstall and real database recovery are exercised separately.

`scripts/build-windows-installer.ps1` rejects stale/missing packaged helpers and records the actual produced artifact checksum/signature in `.evidence.json`; `-RequireValidSignature` enforces a signed-release requirement without signing. The Windows package CI job compiles the production artifact and retains this report. Source/local fixtures still require representative old-release, full administrator installer and real-machine acceptance. See [C18 recovery](docs/windows-installer-recovery.md) and [validation evidence](docs/maintenance/c18-installer-upgrades.md).

## C20 reproducible feature checks

Run `python scripts/run-feature-checks.py` with .NET 8/Python 3 available. This runs the curated isolated feature set, strips inherited optional database/benchmark settings, retains logs plus revision/source/environment/command/result JSON under ignored `artifacts/feature-checks/`, and fails if any selected check fails. It does not read private `.env`. `python tests/FeatureEvidence.Checks/checks.py` validates reporting and isolation behavior.

CI separately runs `python scripts/run-feature-checks.py --mode greenhouse-db` against a new dedicated empty MariaDB service. Direct/manual integration now requires `GREENHOUSE_DISPOSABLE_INSTANCE=1` as well as `GREENHOUSE_TEST_CONNECTION` selecting 127.0.0.1:33317; all existing user schemas cause refusal before fixture SQL. No existing development or collection server is suitable. Benchmarks remain explicit direct-executable opt-in and are not enabled by the runner. Record actual results, not fixed historical test counts. See [procedure and inventory](docs/testing-evidence.md) and [C20 evidence](docs/maintenance/c20-reproducible-checks.md). No normal application setting/migration or user guide flow changes.
