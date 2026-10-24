# Developer machine and first run

Use an isolated development database and upload directory. Never aim setup, hooks, migrations or recovery experiments at the live collection. Commands below are run from the repository root. Schema-only creation is implemented locally; see the creation contract for remaining Linux/native-photo acceptance. Historical migrations are never a creation workaround.

## Tools and checkout

Obtain the repository from its owner or clone the agreed remote, then open its root (the folder containing OrchidApp.sln). Install Git, PowerShell 7+, the .NET 8 SDK and MariaDB 10.11 server/client tools for the validated development platform. Windows launcher/installer work additionally needs Windows, the Windows desktop build toolchain and Inno Setup for actual installers. Linux database validation is required for case/collation/procedure behaviour. Exact supported OS/package-image validation is part of [C16](code-change-backlog.md#c16), not established by this document.

Check available tools without changing data:

```powershell
git --version
pwsh --version
dotnet --list-sdks
```

DevSetup still checks mysql/mysqldump aliases on PATH. Creation/export resolve mariadb/mariadb-dump through explicit tool overrides, PATH and a Windows fallback. These client names do not imply MySQL server support. Native/developer tooling reconciliation remains C16.

## Database creation prerequisite

Use the [schema-only creation contract](database-creation.md). First supply the explicit target and credentials below, plus MARIADB_DATABASE, MARIADB_CHARSET=utf8mb4 and MARIADB_COLLATION=utf8mb4_unicode_ci. Then, from the repository root:

```powershell
pwsh ./database/scripts/rebuild.ps1 -ConfirmDatabase $env:MARIADB_DATABASE
```

This creates only an absent or empty target and records its baseline after all seeds succeed. It never drops existing data and refuses partial/nonempty targets. Development startup does not create the schema. Keep runtime and schema-administration permissions separate. See [local validation and remaining platform acceptance](maintenance/c01-c02-schema-baseline.md).

## Configure one explicit development target

Supply settings in the same terminal that starts the app and scripts; process-local variables do not automatically reach an already running GUI Git client. Use local secret management. Do not commit credentials or print them in support output. For an existing development target, these names must agree:

| Consumer | Configuration |
| --- | --- |
| Web app | ConnectionStrings__OrchidDb (complete MariaDB connection string) |
| Upload services | Storage__UploadRoot (isolated writable absolute path) |
| Export/migration scripts | MARIADB_HOST, MARIADB_PORT, MARIADB_USER, MARIADB_PASSWORD and MARIADB_DATABASE |
| Setup compatibility checks | MYSQL_USER and MYSQL_PASSWORD assigned from the MARIADB account |

Creation requires an explicit MARIADB_DATABASE. The exporter and documented migration runner honour that target (default orchids for compatibility outside creation). Set endpoint values explicitly; committed Development settings and older wrapper defaults differ. MARIADB_* variables do not configure the app connection string. App/export/creation do not automatically load repository .env files.

Use PowerShell to collect a password without echoing it, after supplying your explicit non-secret endpoint/account values:

```powershell
$devCredential = Get-Credential -UserName $env:MARIADB_USER -Message 'Development MariaDB credentials'
$env:MARIADB_PASSWORD = $devCredential.GetNetworkCredential().Password
Remove-Variable devCredential
$env:MYSQL_USER = $env:MARIADB_USER
$env:MYSQL_PASSWORD = $env:MARIADB_PASSWORD
```

Provide ConnectionStrings__OrchidDb using your local secret method, with the same endpoint/database/account and correctly escaped connection-string values. Create the configured upload folder, ensure your app account can write it, and keep it separate from real photos. Clear secret variables when finished; terminal variables are still process-readable and are not a secret store.

## Native image processing

Managed package restore/build does not install a usable native libvips runtime automatically. On Windows, scripts/restore-windows-runtime.ps1 restores packaged runtimes; review its prerequisites before running it. For a source web run, ensure the matching libvips bin directory is on that terminal's PATH. The launcher normally adds it for its child process; direct dotnet run does not. On Linux install the compatible libvips/native dependencies for the validated OS image. A real test-photo upload/reopen is the acceptance check. Repeatable native setup is tracked in [C16](code-change-backlog.md#c16).

## Build and run the web application

After database and native prerequisites are satisfied:

```powershell
dotnet restore src/OrchidApp.Web/OrchidApp.Web.csproj
dotnet build src/OrchidApp.Web/OrchidApp.Web.csproj --configuration Release
dotnet run --project src/OrchidApp.Web/OrchidApp.Web.csproj --launch-profile http
```

Open http://localhost:5285 yourself; the profile selects Development and does not open a browser. Check a database-backed list, add a disposable test plant, save/reopen notes, upload/reopen a test photo and check its storage location. Home alone is not full readiness. Other installations must not depend on the owner's monitoring feeds. Leave Monitoring:Enabled false or absent for general development and validate Home without bespoke feeds.

## Activate hooks and make changes

Once the database/export prerequisites are verified:

```powershell
pwsh ./scripts/DevSetup/setup.ps1
git config --local --get core.hooksPath
```

The result should be .githooks. Setup only configures/checks prerequisites; it does not install .NET, initialise the database or validate a photo pipeline. Every commit, including docs-only commits, exports/stages schema/checksum files. Use the intended development target and review the full resulting commit. Do not bypass the hook to conceal an unexpected schema export. See [CONTRIBUTING](../CONTRIBUTING.md) for migration and test discipline.

## Other development routes

For Windows packaging, inspect scripts/package-windows.ps1 and scripts/build-windows-installer.ps1, restore required runtimes and use the installer contract. A source web run is not a packaged-launcher test. For Linux deployment, use the [platform guide](user-guides/linux/installation-upgrade.md). Relevant feature checks and validation limits are listed in CONTRIBUTING. No setup or recovery procedure in this documentation cleanup has been executed on a fresh machine.
