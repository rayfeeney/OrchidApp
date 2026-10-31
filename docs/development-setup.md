# Developer machine and first run

Use a separate development MariaDB server/database and upload directory. Run commands from the repository root in PowerShell 7. Never use the live collection for setup, hooks or experiments. Fresh databases come only from schema and required seeds; historical migration replay is not a setup step.

## Normal daily startup

From src/OrchidApp.Web, run:

```powershell
dotnet run
```

Development startup reads the repository root .env automatically and builds the app connection string from MARIADB_HOST, MARIADB_PORT, MARIADB_DATABASE, MARIADB_USER and MARIADB_PASSWORD. Keep your existing private credentials there; no wrapper, password prompt or repeated terminal configuration is required for the app. Existing explicit app/environment configuration overrides .env values. Production and Desktop do not read this development file.

The .env stays ignored by Git. Values are literal: KEY=value, optional export prefix, optional matching single/double quotes, blank lines and full-line # comments. There is no shell evaluation, variable expansion or backslash rewriting; unquoted # inside a password remains literal. Do not place inline comments after unquoted credentials. Only supported database, connection-string and upload keys are read; no unrelated process variables are imported.

Storage__UploadRoot is optional for the app. The default is the current user's local application-data directory under OrchidApp/Development/uploads (on Windows, %LOCALAPPDATA%/OrchidApp/Development/uploads), created automatically. If you already have development photographs in another folder, retain that location by adding Storage__UploadRoot with its absolute path to .env. No existing photographs are moved or deleted.

On Windows, dotnet run also discovers the complete libvips runtime already restored under app/runtime/libvips/win-x64/bin. Restore it once if needed using pwsh ./scripts/restore-windows-runtime.ps1 -LibVipsOnly from the repository root. No download or native probe runs on every normal app startup. Native readiness can be checked separately below.

## When a commit says the database needs updating

Stop the development app. From the repository root run:

```powershell
pwsh ./scripts/DevSetup/update-database.ps1
```

Then retry the commit. The command reads the five database credentials/settings already in the repository `.env`, displays the selected host/port/database (never the password), checks pending migrations, makes a SQL backup and applies them through the normal runner. It does not ask you to re-enter credentials or create a new database. With nothing pending it makes no extra backup and reports that you can commit. `-PlanOnly` shows pending changes without backing up or applying them.

The backup is stored outside the repository under the current user's local application-data directory, `OrchidApp/Development/database-backups/`, with a timestamp/unique folder and checksum record. The command stops before applying migrations if backup fails. This is a logical database backup, not a coordinated backup of uploads or a replacement for the deployed collection's recovery procedure. Keep the development app/other writers stopped while updating. Backups are retained for manual review; this command does not prune them.

The pre-commit hook now uses `scripts/DevSetup/export-schema.ps1`, which reads that same `.env`. Git GUI windows do not need inherited credential variables. The five `.env` values are used together, overriding stale ambient database credentials for these wrappers only, then the previous process environment is restored. No `.env` is copied into backups or commits. App configuration may still have its documented explicit overrides; keep those aligned if you use them. Missing/invalid `.env` settings fail without printing their values. Production/Desktop and direct operational scripts retain their existing configuration behavior.

[Validation and remaining platform acceptance](maintenance/development-dotenv-workflow.md).

## Prerequisites and platform scope

| Component | Requirement, scope and how it is provided |
| --- | --- |
| Git | Command-line Git, including its shell for the pre-commit hook; tested with the installed Git for Windows |
| Repository access and checkout | Obtain GitHub access and clone `https://github.com/rayfeeney/OrchidApp.git` using Git or GitHub Desktop. An extracted source ZIP cannot configure the required Git hooks. |
| Editor and graphical Git client | VS Code is an optional editor; GitHub Desktop is an optional graphical Git client. Neither replaces the command-line Git, PowerShell or .NET requirements. |
| PowerShell | 7 or newer; use pwsh, including on Linux |
| .NET | SDK 8 or newer plus .NET 8 and ASP.NET Core 8 runtimes; the application targets net8.0. Local C16 checks used SDK 9.0.315 and the installed .NET 8 runtimes |
| MariaDB | **Download and install MariaDB 10.11**, including the server and the `mariadb` and `mariadb-dump` command-line tools. On Windows, install into `C:\Program Files\MariaDB 10.11`. Set a root password during installation and keep it private. |
| Photo processing | **Download and install libvips separately; it is not included in a fresh clone.** On Windows x64, run `pwsh ./scripts/restore-windows-runtime.ps1 -LibVipsOnly` from the repository root; this downloads, verifies and installs libvips 8.18.2 into `app/runtime/libvips/win-x64` without Chocolatey or a manual installer. On Linux, install libvips with PNG/JPEG support using your distribution's package manager (Ubuntu CI uses `libvips-tools`). After installation, run `pwsh ./scripts/DevSetup/run.ps1 -CheckOnly` to verify native photo processing. |
| .NET application packages | **No manual download or installation required.** The required packages are defined in the repository and downloaded automatically by .NET when you first build or run the app. Internet access is required for that first download. |
| Formatted-text editor | Quill 2.0.3 JavaScript and CSS are already bundled under `src/OrchidApp.Web/wwwroot/lib/quill/`. No separate installation or CDN download is required. Retain the bundled editor assets and legal notices when packaging. |
| Development configuration and storage | Prepare a separate MariaDB instance/account permitted to create the development database and its objects, private connection settings and a writable development upload directory. The app and development update/export wrappers read the repository-root `.env`; direct administration scripts use the explicit environment settings below. Keep credentials out of Git. |
| Browser | Required for testing database-backed pages, formatted notes and photo upload/reopen at `http://localhost:5285`. A successful build alone does not verify these workflows. |
| Python 3 | **Download and install Python 3 separately.** It is not included in the repository. On Windows, enable the installer option to add Python to PATH. Open a new terminal and run `python --version` (or `python3 --version` on Linux) to confirm Python 3 is available. It is required to run the repository checks. |
| Windows launcher | **No additional installation required** once the .NET SDK is installed. The launcher source is included in the repository. Develop and build it on Windows. |
| Windows installer creation | **Download and install [Inno Setup 7](https://jrsoftware.org/isdl.php) on your Windows PC.** Install it in `C:\Program Files\Inno Setup 7`, where the repository build script expects it. It is not included in the repository. |
| Windows packaged runtimes | **No additional manual download required** when MariaDB 10.11 is installed as described below. The repository script prepares the runtime files needed for the installer; see Windows packaging preparation below. |

### Check installed software

On the PC being set up, open a new PowerShell 7 terminal after installing the software. Run these checks; they do not install anything.

| Component | Check | Expected result |
| --- | --- | --- |
| Git | `git --version` | A Git version is displayed. |
| PowerShell | `pwsh --version` | Version 7 or newer. |
| .NET SDK | `dotnet --list-sdks` | At least one SDK version 8 or newer. |
| .NET runtimes | `dotnet --list-runtimes` | Both `Microsoft.NETCore.App 8.x` and `Microsoft.AspNetCore.App 8.x`. |
| Python | `python --version` (Linux: `python3 --version`) | Python 3.x. |
| MariaDB client (Windows) | `& 'C:\Program Files\MariaDB 10.11\bin\mariadb.exe' --no-defaults --version` | MariaDB 10.11.x. |
| MariaDB backup tool (Windows) | `& 'C:\Program Files\MariaDB 10.11\bin\mariadb-dump.exe' --no-defaults --version` | MariaDB 10.11.x. |
| MariaDB server executable (Windows) | `& 'C:\Program Files\MariaDB 10.11\bin\mariadbd.exe' --no-defaults --version` | MariaDB 10.11.x. This does not prove the server is running. |
| MariaDB tools (Linux) | Run `mariadb --no-defaults --version`, `mariadb-dump --no-defaults --version` and `mariadbd --no-defaults --version`. | Each reports MariaDB 10.11.x. |
| libvips (Windows, after runtime preparation) | `& './app/runtime/libvips/win-x64/bin/vips.exe' --version` | `vips-8.18.2`. Run from the repository root. |
| libvips (Linux) | `vips --version` | A libvips version is displayed. Check photo support using the diagnostic below. |
| Inno Setup (Windows installer development) | Open Inno Setup and select Help > About to check the version. Run `Test-Path 'C:\Program Files\Inno Setup 7\ISCC.exe'` to check the compiler is at the expected location. | The application reports version 7.x and the path check returns `True`. |
| VS Code (optional) | `code --version` | A VS Code version is displayed if its command is on PATH. Otherwise use Help > About in VS Code. |
| GitHub Desktop (optional) | Open Help > About GitHub Desktop. | The installed version is displayed. |

If a command cannot be found, check that the software is installed and its command is on PATH, or use its full installation path. Adjust the explicit Windows paths if you installed elsewhere.

Quill is bundled and .NET packages are downloaded automatically; neither needs a separate PC installation check. After cloning, `dotnet restore OrchidApp.sln` checks that the .NET packages can be restored. After preparing libvips, `pwsh ./scripts/DevSetup/run.ps1 -CheckOnly` checks actual native photo processing.

After configuring the development database connection below, run `pwsh ./scripts/DevSetup/setup.ps1`. It checks the required tools and the running MariaDB server version/connectivity, and enables Git hooks. It does not install software, start the server, create accounts or create the database.

For MariaDB tools, MARIADB_EXE and MARIADB_DUMP_EXE may hold explicit executable paths, including paths with spaces. Otherwise discovery uses mariadb/mariadb-dump on PATH, then the Windows MariaDB 10.11 installation directory. One executable is selected even if PATH exposes multiple copies.


## Windows packaging preparation

With MariaDB installed at the location in the prerequisites table, the preparation script copies its runtime into the repository and downloads libvips if needed.

From the repository root, run:

```powershell
pwsh ./scripts/restore-windows-runtime.ps1
```

If MariaDB is missing from that location, stop and correct its installation first: the script otherwise attempts to install MariaDB through Chocolatey.

These runtime files are preparation for packaging. The Windows release payload must also be built before running `scripts/build-windows-installer.ps1`. If Inno Setup is installed elsewhere, supply `-InnoCompiler <absolute-ISCC-path>` to that script.

## Configure administration scripts and hooks (when needed)

Choose your own endpoint, database and account. These example non-secret values describe a disposable local instance; replace them before running:

```powershell
$env:MARIADB_HOST = '127.0.0.1'
$env:MARIADB_PORT = '3306'
$env:MARIADB_DATABASE = 'orchids_dev'
$env:MARIADB_USER = 'orchid_developer'
# Choose an absolute path used only for development photographs.
$env:Storage__UploadRoot = Join-Path $HOME 'OrchidApp-development-uploads'
$devCredential = Get-Credential -UserName $env:MARIADB_USER -Message 'Isolated development MariaDB credentials'
$env:MARIADB_PASSWORD = $devCredential.GetNetworkCredential().Password
Remove-Variable devCredential
. ./scripts/DevSetup/configure.ps1
pwsh ./scripts/DevSetup/setup.ps1
```

The optional dot-sourced configure.ps1 generates ConnectionStrings__OrchidDb from the same five MARIADB values, quoting credentials correctly. It uses the same local upload default if none is supplied, selects Development, disables monitoring and sets the schema creation charset/collation. The app and scripts therefore use the same explicit target. Committed Development settings contain no endpoint, password or personal upload directory.

The administration scripts below still use explicit MARIADB environment values and do not load .env themselves; this is separate from the web app's automatic Development .env loading. No MYSQL_USER/MYSQL_PASSWORD aliases or database endpoint defaults are used. Creation, migrations and export all require the explicit MARIADB target. MYSQL_PWD is used only as the native client's temporary password transport; setup/export preserve its previous value. Environment values remain process-readable: use a private development terminal or your local secret management, and do not commit credentials or echo the connection string.

Keep this terminal open only for direct administration commands that use its environment. Normal app startup and the developer update/export wrappers read `.env`; Git GUI commits now use the export wrapper and do not need to inherit these variables. Runtime deployment permissions remain a separate concern; this is an isolated developer workflow.

## Create the database from schema and seeds

After setup succeeds:

```powershell
pwsh ./database/scripts/rebuild.ps1 -ConfirmDatabase $env:MARIADB_DATABASE
```

The creator uses the manifest's dependency order, imports required seeds and records its completion marker last. It accepts only an absent or empty target, never drops existing data and rejects partial/nonempty targets. It does not need the migrations directory. See [database creation](database-creation.md). Development web startup does not initialise a database.

## Optional native diagnostic checks

```powershell
# Validate native decoding, photo/thumbnail save and reopen without starting the app.
pwsh ./scripts/DevSetup/run.ps1 -CheckOnly
# Optional diagnostic wrapper: check native processing, then run the app.
pwsh ./scripts/DevSetup/run.ps1
```

On Windows, run.ps1 downloads the pinned full libvips runtime on first use, adds its bin directory to the child process PATH and restores PATH when finished. This handles the DLLs needed by NetVips 2.4.2; the smaller native NuGet binary alone was insufficient in local testing. Downloaded archives and restored runtimes are ignored by Git. On Linux, install your distribution's libvips runtime/tools first; the native probe is the compatibility check. No Windows runtime is installed on Linux.

The probe calls the application's actual PhotoPipeline with a generated PNG, saves and fully decodes separate JPEG photo and thumbnail files in a unique child of Storage__UploadRoot, checks dimensions and removes only that probe directory. It verifies native/filesystem behavior, not database or browser readiness. A failed probe prevents startup through that optional wrapper. Normal dotnet run does not invoke the probe.

Open http://localhost:5285. Use -Url http://127.0.0.1:5286 if that port is occupied. The optional wrapper selects Development explicitly without a launch profile; ordinary dotnet run uses the Development launch profile. It does not open a browser. Check a database-backed list, create a disposable plant, save/reopen notes, upload a test photo and reopen the photo page. Verify both photo files under the configured upload root. Home alone does not prove readiness. General development leaves bespoke monitoring disabled.

## Hooks and local checks

setup.ps1 activates .githooks in this Git checkout. Verify and use the configured terminal:

```powershell
git config --local --get core.hooksPath
pwsh ./tests/DevelopmentSetup.Checks/Configuration.Checks.ps1
```

Every commit, including docs-only commits, runs the schema exporter and stages generated schema/checksum files. The exporter requires all five MARIADB values, ignores native option files and uses TCP; hidden client defaults cannot choose another endpoint. Review all staged/generated changes and the resulting commit. Do not bypass a failing hook. An export may report legitimate platform/schema differences that require review.

For isolated database suites, supply the same explicit server credentials and run:

```powershell
pwsh ./scripts/DevSetup/ci-local.ps1
```

This runs the existing schema baseline and migration database checks, which use generated disposable database names. It replaces the obsolete MySQL Docker/Assemble-Schema route; it does not claim to mirror every CI step or validate the running app. Relevant feature checks are in [CONTRIBUTING](../CONTRIBUTING.md).

For later database changes use [migration runners](migration-runners.md), beginning with PlanOnly and a recoverable backup. Never remove incomplete markers or edit applied SQL/history. Windows packaging and installer work use the separate packaging scripts and [upgrade contract](windows-upgrade-contract.md).

C11 introduces `202610261200_AtomicManualPlantClosure.sql`. Use the single development update command above before committing, then retry the commit. It loads `.env`, backs up and applies reviewed pending migrations through the canonical runner. The exporter still refuses pending migrations or history older than source before writing schema/checksum files; the hook never applies migrations itself. Normal Development dotnet run remains unchanged. See [C11 guidance](maintenance/c11-manual-closure.md).

C16's local setup, schema creation, actual hook, source startup and photo HTTP round trip are recorded in [C16 evidence](maintenance/c16-developer-setup.md). The added Windows/Linux CI checks and a completely fresh OS installation still need acceptance; local Windows success is not Linux/device/installer proof.

The C16 direct-start follow-up adds automatic Development .env loading and the local upload default. See [C16 evidence](maintenance/c16-developer-setup.md) for validation of that correction.

## C15/C19 photo adoption

Stop the app and use the same `pwsh ./scripts/DevSetup/update-database.ps1` command to adopt `202610271200_PhotoTaxonTransaction.sql`; credentials remain in the repository `.env`. Normal `dotnet run` stays the daily start command. It does not apply migrations automatically. Check `/health/ready` for database/storage/native/reference/recovery readiness; `/health/live` only proves a responding web process. The optional pre-start native probe remains separate. See [photo handling](photo-handling.md) for policy and the read-only recovery report. Existing photos are unchanged.
