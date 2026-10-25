# Development startup recovery

The inspected checkout has no DevelopmentConfiguration.Apply startup call and no DevelopmentConfiguration.cs. This restores the previously implemented C16 direct dotnet run fix. The cause of the missing files has not been established.

## Apply and start

Stop the running development app. Extract this archive over the repository root containing OrchidApp.sln, accepting replacement of the listed files. Keep the existing private .env at that root. Then run dotnet run from src/OrchidApp.Web. No wrapper or manual credential export is required.

## Files

- src/OrchidApp.Web/Program.cs: applies development configuration before registering database services.
- src/OrchidApp.Web/Configuration/DevelopmentConfiguration.cs: reads allowlisted root .env settings in Development, constructs OrchidDb, selects an absolute development upload directory, and locates an already restored Windows image runtime.
- src/OrchidApp.Web/appsettings.Development.json: leaves the upload directory unset so the development default or private override takes effect.
- tests/DevelopmentConfiguration.Checks/DevelopmentConfiguration.Checks.csproj: standalone startup configuration check project.
- tests/DevelopmentConfiguration.Checks/Program.cs: checks .env loading, explicit precedence, missing settings, upload defaults and environment isolation.
- docs/development-setup.md: documents direct dotnet run and private .env setup.
- docs/maintenance/c16-developer-setup.md: records C16 implementation and validation scope.

No deletions or moves. No credentials, database contents, uploads or runtime binaries are included. This is a targeted recovery package, not a replacement repository or a cumulative delivery of all phases.

## Validation

Re-ran the startup configuration suite: all 14 checks passed. Verified every packaged repository file against its source bytes. The user's development database was not accessed and the user's checkout was not modified. Actual local startup after applying remains to be confirmed.
