# Developer machine and first run

Use a separate development MariaDB server/database and upload directory. Run commands from the repository root in PowerShell 7. Never use the live collection for setup, hooks or experiments. Fresh databases come only from schema and required seeds; historical migration replay is not a setup step.

## Prerequisites and platform scope

| Component | Requirement and evidence |
| --- | --- |
| Git | Command-line Git, including its shell for the pre-commit hook; tested with the installed Git for Windows |
| PowerShell | 7 or newer; use pwsh, including on Linux |
| .NET | SDK 8 or newer plus .NET 8 and ASP.NET Core 8 runtimes; the application targets net8.0. Local C16 checks used SDK 9.0.315 and the installed .NET 8 runtimes |
| MariaDB | Server, mariadb and mariadb-dump 10.11; tested locally with 10.11.16. MySQL server and mysql/mysqldump aliases are not the setup contract |
| Windows native images | Windows x64; the source-run command restores the complete libvips 8.18.2 archive, verifies its SHA-256 and checks required DLLs/version |
| Linux native images | A system libvips installation with PNG/JPEG support; the Ubuntu CI check installs libvips-tools and reports its actual version. The new Linux check still needs CI confirmation |

Install Git, PowerShell, the SDK/ASP.NET runtime and MariaDB using your platform's supported installers/package manager. Start an isolated MariaDB instance and prepare an account permitted to create the intended development database and its objects. setup.ps1 verifies tools, server connectivity/version and hooks; it does not install these tools, start a server, create accounts or change database objects. Windows source development does not require Chocolatey: the -LibVipsOnly restore path downloads only libvips. Windows packaging retains its separate MariaDB runtime restore path.

Check installed tools:

```powershell
git --version
pwsh --version
dotnet --list-sdks
dotnet --list-runtimes
```

For MariaDB tools, MARIADB_EXE and MARIADB_DUMP_EXE may hold explicit executable paths, including paths with spaces. Otherwise discovery uses mariadb/mariadb-dump on PATH, then the Windows MariaDB 10.11 installation directory. One executable is selected even if PATH exposes multiple copies.

## Configure one target in one terminal

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

The dot-sourced configure.ps1 generates ConnectionStrings__OrchidDb from the same five MARIADB values, quoting credentials correctly. It requires an absolute upload path, selects Development, disables monitoring and sets the schema creation charset/collation. The app and scripts therefore use the same explicit target. Committed Development settings contain no endpoint, password or personal upload directory.

No MYSQL_USER/MYSQL_PASSWORD aliases, default target/port or repository .env loading is used. Creation, migrations and export all require the explicit MARIADB target. MYSQL_PWD is used only as the native client's temporary password transport; setup/export preserve its previous value. Environment values remain process-readable: use a private development terminal or your local secret management, and do not commit credentials or echo the connection string.

Keep this terminal open for app commands and command-line Git commits. A GUI Git client already running elsewhere does not inherit these settings; launch it from the configured environment if needed. Repeat configuration in each new terminal and after changing target values. Runtime deployment permissions remain a separate concern; this is an isolated developer workflow.

## Create the database from schema and seeds

After setup succeeds:

```powershell
pwsh ./database/scripts/rebuild.ps1 -ConfirmDatabase $env:MARIADB_DATABASE
```

The creator uses the manifest's dependency order, imports required seeds and records its completion marker last. It accepts only an absent or empty target, never drops existing data and rejects partial/nonempty targets. It does not need the migrations directory. See [database creation](database-creation.md). Development web startup does not initialise a database.

## Native check and source run

```powershell
# Validate native decoding, photo/thumbnail save and reopen without starting the app.
pwsh ./scripts/DevSetup/run.ps1 -CheckOnly
# Run the app after the same native check.
pwsh ./scripts/DevSetup/run.ps1
```

On Windows, run.ps1 downloads the pinned full libvips runtime on first use, adds its bin directory to the child process PATH and restores PATH when finished. This handles the DLLs needed by NetVips 2.4.2; the smaller native NuGet binary alone was insufficient in local testing. Downloaded archives and restored runtimes are ignored by Git. On Linux, install your distribution's libvips runtime/tools first; the native probe is the compatibility check. No Windows runtime is installed on Linux.

The probe calls the application's actual PhotoPipeline with a generated PNG, saves and fully decodes separate JPEG photo and thumbnail files in a unique child of Storage__UploadRoot, checks dimensions and removes only that probe directory. It verifies native/filesystem behavior, not database or browser readiness. A failed probe prevents source app startup.

Open http://localhost:5285. Use -Url http://127.0.0.1:5286 if that port is occupied. The command selects Development explicitly without a launch profile. It does not open a browser. Check a database-backed list, create a disposable plant, save/reopen notes, upload a test photo and reopen the photo page. Verify both photo files under the configured upload root. Home alone does not prove readiness. General development leaves bespoke monitoring disabled.

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

C16's local setup, schema creation, actual hook, source startup and photo HTTP round trip are recorded in [C16 evidence](maintenance/c16-developer-setup.md). The added Windows/Linux CI checks and a completely fresh OS installation still need acceptance; local Windows success is not Linux/device/installer proof.
