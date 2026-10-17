# Contributing to OrchidApp

This guide describes how to prepare a development checkout, make changes and
validate them before opening a pull request. Run commands from the repository root.
MariaDB is the supported database engine on all platforms. Use a development
MariaDB database, never a production database, for development and tests.

## Project references

- [Documentation index](docs/index.md): current operational and feature guides.
- [Architecture](docs/architecture.md): system responsibilities and invariants.
- [Temporal design](docs/temporal-design.md): lifecycle dates and ordering.
- [Windows upgrade contract](docs/windows-upgrade-contract.md): installer ownership
  and persistent data requirements.

These documents define the project rules. The validation sections below describe
what the current tools actually check. A rule remains a requirement even where
automation does not yet enforce it; do not assume a passing build proves compliance.

## Prepare a development checkout

Install Git, PowerShell 7 or later and the .NET 8 SDK. Database work and the
pre-commit hook also require a reachable development MariaDB database named
`orchids`, with credentials permitted to export its schema.

The current setup script checks that MariaDB's legacy client aliases `mysql`
and `mysqldump` are on PATH. These checks do not require or support a separate
MySQL server. The
exporter uses `mariadb` and `mariadb-dump` on Linux; on Windows it uses executables
under `C:\Program Files\MariaDB 10.11\bin`. Check those paths before committing.
The bundled Windows application database does not replace these developer tools.

### Configure credentials and hooks

Use your local secret-management method to supply credentials to the terminal
and Git client running the hook. Do not commit credentials or place passwords in
command-line arguments, screenshots or pull request output.

The scripts currently use different variable names:

| Script | Required credential variables |
| --- | --- |
| `scripts/DevSetup/setup.ps1` | `MYSQL_USER`, `MYSQL_PASSWORD` |
| Schema exporter and migration runner | `MARIADB_USER`, `MARIADB_PASSWORD` |

The `MYSQL_*` pair is a legacy setup-script compatibility requirement, not a
second database configuration. Supply both pairs for the same development
MariaDB account. If the `MARIADB_*`
variables are already set, the setup compatibility variables can be assigned in
the current PowerShell session without printing the password:

```powershell
$env:MYSQL_USER = $env:MARIADB_USER
$env:MYSQL_PASSWORD = $env:MARIADB_PASSWORD
pwsh ./scripts/DevSetup/setup.ps1
git config --local --get core.hooksPath
```

The final command should return `.githooks`. Setup configures the hooks path; it
does not install .NET, create a database or verify every export prerequisite.
If using GitHub Desktop, restart it after changing its environment. Variables set
in a terminal do not automatically become available to an already running app.

For database scripts, set `MARIADB_HOST` and `MARIADB_PORT` when the development
server differs from the defaults `localhost:3306`. The exporter always targets
`orchids`; the migration runner also defaults to `orchids` and accepts
`MARIADB_DATABASE`. Ensure both target the intended development database.

Local hooks are required by project policy. CI does not verify that a contributor
ran setup or has hooks installed.

## Database changes

### Schema evolution and fresh installation

For an existing database, put structural changes in a new SQL migration under
`database/migrations/`, named `YYYYMMDDHHMM_Name.sql`. Use a unique timestamp and
preserve user data. Never edit a migration that has already been applied.

Fresh database creation uses the canonical schema; existing installations use
migrations. Do not run a schema rebuild as an upgrade. Do not make ad hoc schema
changes on production databases outside the reviewed migration process.

Apply a new migration to the development database using the configured
`MARIADB_*` environment variables:

```powershell
pwsh ./database/scripts/Apply-Migrations.ps1
```

Review the result before committing. Migration DDL is not automatically rolled
back if a later statement fails; investigate failures before rerunning.

### Generated schema and hook behaviour

`database/schema/` and `database/checksums/schema.json` are generated artefacts.
Do not edit them manually. The pre-commit hook runs
`database/scripts/Export-MariaDBSchema.ps1` against the configured database and
stages the generated schema and checksum files. It aborts if export fails.

The hook runs for every commit, including documentation-only commits. Use a
development database aligned with the intended changes so unrelated database
changes are not exported into a commit. Review the resulting diff; if the hook
introduces unexpected files, stop and correct the development environment.
Do not bypass the hook with `--no-verify` or a disabled hooks path.

For a database-only change, stage the new migration and commit normally:

```bash
git add database/migrations/YYYYMMDDHHMM_Name.sql
git diff --cached
git commit -m "Describe the database change"
```

Replace the example filename with the actual migration. An empty commit is not
a substitute for recording a migration. The hook stages generated exports; review
the complete commit after it finishes.

### Current migration enforcement limits

The runner sorts SQL files by name, skips filenames already recorded in
`schemaversion` and records a SHA256 checksum for each newly applied file.
It currently does **not** compare recorded checksums for skipped files, enforce
the filename format, reject duplicate timestamps or reject new files dated before
already applied migrations. These remain review requirements for this runner. Desktop bootstrap and the
separate developer runner have different checks; see the
[architecture migration comparison](docs/architecture.md#implemented-migration-paths).
Schema export
checksums and CI schema drift checks do not establish migration-history integrity.

## Application changes

- Keep database constraints and stored procedures authoritative for lifecycle and
  structural writes, including plant location history, splitting and propagation.
- Use the shared `IStoredProcedureExecutor` for the result-returning procedure
  patterns it supports. Existing EF Core command and mapped result-set patterns
  remain applicable where established. Keep exceptional database plumbing in
  infrastructure rather than adding manual ADO.NET commands to PageModels.
- Keep database I/O asynchronous. Parameterise values and use fixed, trusted
  procedure identifiers; never build executable SQL from user input.
- Translate expected validation or database errors into useful messages. Preserve
  logging and appropriate handling of operational failures; do not hide unexpected
  failures or treat them as successful writes.
- Respect the established temporal model. Changes to date handling, same-day
  ordering or lifecycle boundaries require corresponding design review.

## User interface and documentation

Use shared Razor components under `src/OrchidApp.Web/Pages/Shared/`. Preserve local
return destinations through forms, validation and successful saves, following
[the navigation guide](docs/navigation.md). Check mobile layouts and use familiar
user-facing labels.

For formatted notes, reuse the shared editor, sanitisation and storage contract
described in [the rich-notes guide](docs/rich-notes.md).

Update existing documentation when user-facing behaviour changes, especially
installation, upgrades, backups, recovery, privacy and support. Put platform
instructions under `docs/user-guides/<platform>/` and feature references under
`docs/`. Link them from the documentation index. Avoid duplicate patch readmes
and changed-file inventories; use Git history and release notes for change history.
Keep historical release snapshots and required third-party notices intact.

## Packaging, upgrades and recovery

- Public Windows upgrades use the installer. Do not recommend ZIP overwrite.
- Keep replaceable application files separate from persistent database files,
  uploads and user settings. Preserve user data during install, upgrade and uninstall.
- Follow the Windows upgrade contract for installer and launcher responsibilities,
  ProgramData locations, legacy layout detection and migration.
- Require recoverable backups before migrations or operations that could damage
  data. Include external configuration and photos where applicable.
- Validate backup restoration in an isolated environment. A completed archive,
  matching hash or successful database dump alone does not prove recoverability.
- Document and validate changes to backup locations, cloud copies, restore paths,
  bundled runtimes or platform-specific services.
- Preserve the project licence and bundled third-party licence obligations when
  adding dependencies or changing release contents.

## Validate changes locally

For application changes, build the web project:

```bash
dotnet build src/OrchidApp.Web/OrchidApp.Web.csproj --configuration Release
```

Run the relevant executable check projects; these use `dotnet run`:

```bash
dotnet run --configuration Release --project tests/RichNotes.Checks/RichNotes.Checks.csproj
dotnet run --configuration Release --project tests/Navigation.Checks/Navigation.Checks.csproj
dotnet run --configuration Release --project tests/NameSearch.Checks/NameSearch.Checks.csproj
dotnet run --configuration Release --project tests/EnvironmentSummary.Checks/EnvironmentSummary.Checks.csproj
```

Choose checks appropriate to the change. Documentation-only changes need link,
command and formatting review rather than an application build. For database,
packaging or operational changes, also validate the affected workflow using the
relevant platform guide. Do not run destructive recovery tests on production.

The executable checks include isolated handlers, substitute data and SQL translation
checks. They do not replace live MariaDB save/reopen checks, actual installer tests,
Raspberry Pi smoke checks or physical mobile-device testing where those matter.

Review `git diff --check` and the staged diff before committing, then inspect the
completed commit because the hook may have staged generated files.

## What CI currently validates

The checked-in [CI workflow](.github/workflows/ci.yml) runs on pull requests,
pushes to `main` and manual dispatch. It currently:

1. Restores, builds and publishes the web app for `linux-arm64` and checks that
   the published DLL exists. This is cross-platform build validation, not a run
   on Raspberry Pi hardware.
2. Creates a disposable MariaDB 10.11 database from the committed schema, exports
   it again and checks for schema drift.
3. Restores Windows runtime dependencies and runs Windows package creation.

It does not currently run the four executable feature-check projects, replay
historical migrations, validate migration ordering/checksum integrity, build the
Inno Setup installer or exercise installation and restoration on user machines.
Do not describe these as enforced checks until the workflow implements them.

All required CI jobs must pass before merging. A passing run supplements code
review and relevant local validation; it does not establish complete correctness.

## Pull requests

Describe the problem, the resulting behaviour and any material operational or
compatibility effects. State the checks actually run, their results and relevant
limits. Include manual validation for workflows that automated checks do not cover.

For schema changes, include the new migration and generated exports. For dependency
or distribution changes, review licences and bundled notices. For user-facing
changes, update the appropriate guides. Keep the scope focused and exclude
credentials, private data, local uploads and unrelated generated changes.
