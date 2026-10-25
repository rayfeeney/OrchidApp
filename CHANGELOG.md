# C16 follow-up: dotnet run with repository .env

Changes-only correction on top of C16/C05: 9 modified and 3 added repository files, plus this CHANGELOG.md. No private .env, credentials, photos, runtime binaries, whole repository or patch is included. No deletions or moves.

## Apply and start

1. Extract directly over the repository root containing OrchidApp.sln, replacing the listed files.
2. Keep your existing private repository .env. Its MARIADB_HOST, MARIADB_PORT, MARIADB_DATABASE, MARIADB_USER and MARIADB_PASSWORD values now configure the Development app automatically.
3. From src/OrchidApp.Web run dotnet run. No DevSetup wrapper or upload environment setting is required.

The upload default is %LOCALAPPDATA%/OrchidApp/Development/uploads on Windows. If existing development photos are in another directory, add Storage__UploadRoot with that absolute path to your private .env; no existing files are moved or deleted. Existing explicit environment/app settings override .env. Production/Desktop do not read the development file. Missing credentials are reported by key name without values or a guessed database target. A full Windows libvips runtime still needs its one-time restore for photo processing; normal startup does not download or run a photo probe.

## Files

| Change | Path | Description |
| --- | --- | --- |
| Modified | `.github/workflows/ci.yml` | Run the new Development startup configuration checks on both CI platforms. |
| Modified | `RELEASE_NOTES.md` | Record automatic .env loading and ordinary dotnet run startup. |
| Modified | `docs/code-change-backlog.md` | Record the C16 direct-start correction. |
| Modified | `docs/development-setup.md` | Make dotnet run the daily command; document private .env loading, precedence, upload default and optional diagnostics. |
| Modified | `docs/maintenance/c16-developer-setup.md` | Preserve original evidence and append the correction, tests and limits. |
| Modified | `scripts/DevSetup/configure.ps1` | Use the per-user development upload default when the optional wrapper has no upload setting. |
| Added | `src/OrchidApp.Web/Configuration/DevelopmentConfiguration.cs` | Development-only repository .env reader and MariaDB connection generation; local upload default and restored Windows native PATH. |
| Modified | `src/OrchidApp.Web/Program.cs` | Apply Development configuration before service setup. |
| Modified | `src/OrchidApp.Web/appsettings.Development.json` | Clear the inherited generic Linux upload default for Development. |
| Added | `tests/DevelopmentConfiguration.Checks/DevelopmentConfiguration.Checks.csproj` | Add the executable startup configuration check project. |
| Added | `tests/DevelopmentConfiguration.Checks/Program.cs` | Check .env discovery/credentials/precedence, uploads, errors and Production/Desktop isolation. |
| Modified | `tests/DevelopmentSetup.Checks/Configuration.Checks.ps1` | Verify omitted upload setting now uses an absolute local default. |

## Actual validation

- 14 C# Development startup configuration checks passed, including literal special-character credentials and Production/Desktop isolation.
- 18 PowerShell configuration checks passed, including the new optional upload default.
- Direct dotnet run started against an isolated MariaDB 10.11.16 database using only a temporary repository .env with five DB settings. No connection, credential or upload environment values and no wrapper were supplied. Home and Plants returned HTTP 200; startup created its upload default.
- Release web build passed with zero warnings/errors. actionlint workflow validation and modified PowerShell parsing passed. Changed Markdown links and JSON parsed; all 333 schema/checksum/historical migration files were unchanged.
- The generated database was dropped and the isolated test server shut down. The real collection was not used. No user credential file was modified.

## Remaining acceptance

The new CI steps still require a run. Direct-start HTTP checks cover database access and upload directory initialization; this follow-up does not claim a new end-to-end photo upload, historical data/photo migration, Linux direct-start acceptance or installer/recovery validation. Existing C16 photo tests remain earlier evidence.
