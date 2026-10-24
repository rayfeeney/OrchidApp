# Contributing to OrchidApp

Start with [developer setup](docs/development-setup.md) and the [documentation ownership map](docs/documentation-map.md). Run repository commands from the root. Use isolated development data, never the live collection.

## Required contracts

- MariaDB is the supported database engine. Validate case, collation and SQL behaviour on Linux as well as affected Windows packaging workflows.
- A fresh database is created from schema and required reference seeds alone; migrations apply only after creation. See [database creation](docs/database-creation.md) for baseline requirements and current blockers.
- Bespoke environment monitoring belongs only to the owner's local installation. General users/developers must not need those feeds, permissions or objects. Current installation isolation needs [C03](docs/code-change-backlog.md#c03).
- Respect [architecture](docs/architecture.md), [temporal behaviour](docs/temporal-design.md) and [Windows upgrade safety](docs/windows-upgrade-contract.md). Requirements are not claims that every current failure path is already enforced.

## Changes to the database

For a compatible change after creation, add a new database/migrations/YYYYMMDDHHMM_Name.sql with a unique, ordered timestamp. Never edit applied history. Apply only to an existing, correctly baselined isolated database after a recoverable backup. Do not use migration replay to initialise a fresh environment.

```powershell
pwsh ./database/scripts/Apply-Migrations.ps1
```

Supply explicit MARIADB_* credentials/endpoint; MARIADB_DATABASE is accepted by this runner. The exporter always targets orchids. DDL failures can leave partial state; investigate rather than blindly rerunning. This runner sorts filenames, skips recorded names and records new checksums, but does not enforce every chronology, format or skipped-file checksum rule. Desktop and the separate developer runner differ; see [migration paths](docs/architecture.md#implemented-migration-paths). [C02/C04](docs/code-change-backlog.md) track baseline and enforcement fixes.

Schema and checksums are generated through database/scripts/Export-MariaDBSchema.ps1. Do not manually edit database/schema/ or database/checksums/schema.json. The pre-commit hook runs the exporter on every commit and stages generated changes; an export failure aborts. Review both the staged diff and finished commit so unrelated database changes cannot slip in. Use required hooks, not --no-verify. CI cannot prove local hook use.

## Application and UI changes

Keep structural lifecycle writes in the intended stored procedures and other writes in the established EF Core patterns. Use asynchronous database I/O, parameterised values, trusted procedure identifiers and shared IStoredProcedureExecutor where appropriate. Do not hide operational failures or turn them into successful writes. Review calendar dates versus timestamps, same-day ties and ended-plant behaviour when changing lifecycle flows.

Use shared Razor components and preserve validated local return destinations on GET, POST, errors, Cancel and successful saves; see [navigation](docs/navigation.md). Reuse the sanitiser/editor/storage contract for [rich notes](docs/rich-notes.md). Check actual mobile workflows where affected. Update user-facing labels and screenshot references together with code.

## Documentation and history

Follow [AGENTS.md](AGENTS.md). Every code, SQL, config, dependency, script or packaging change requires a documentation impact check and affected guide updates in the same change. State which docs changed, or specifically why none were affected. Keep new supporting reports under docs/. Maintain [the code backlog](docs/code-change-backlog.md) for unresolved gaps and actual closure evidence.

Move superseded/inapplicable docs to docs/history/, preserve their context and update current incoming links. Do not delete recent change evidence simply because its intermediate behaviour is superseded. Maintain shared content in both platform Word guides together, preserve useful screenshots and render/inspect all pages after edits. Word originals are the maintained sources; historic release PDFs are not current editing masters. Preserve licence texts and required notices.

## Validate locally

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
```

Default checks use isolated/substitute data and SQL translation where designed. Optional greenhouse DB/benchmark modes require a disposable instance, never the owner's production database; see the [local guide](docs/local-installation/greenhouse-monitoring.md). Passing these does not prove live save/reopen, native image processing, device behaviour, installer safety or restore completeness.

For docs-only work, check paths, links, commands, setting names, platform scope and Word rendering rather than requiring an app build. For database, backup/restore and package changes, validate the actual affected workflow on an isolated supported target. Preserve the recovery input and verify records, photos, settings and restart behaviour. Inspect git diff --check, staged changes and the completed commit.

## Current CI limits

The [workflow](.github/workflows/ci.yml) builds/publishes linux-arm64, reconstructs/exports a disposable MariaDB 10.11 schema to check drift, and creates a Windows package. It does not establish seeded schema-only first run independent of migrations, run all five executable check projects, replay and validate upgrade history, build the Inno Setup installer or exercise actual device install/recovery. [C05/C20](docs/code-change-backlog.md) track improved coverage. Cross-publishing is not Pi hardware validation.

## Pull requests

Describe the concrete problem and resulting behaviour, operational/compatibility effects, docs updated and checks actually run with their limits. Include new migrations and generated exports for DB changes. Review licences for dependency/distribution changes. Require appropriate CI and local checks; do not describe planned safeguards or unrun tests as completed. Keep credentials, private data, local uploads and unrelated generated changes out of the contribution.
