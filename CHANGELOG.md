# C01+C02 - Schema creation and baseline changes

Delivery date: 24 October 2026.

## Apply this delivery

1. Apply the C03 changes-only package first. This is an incremental delivery on that source version.
2. Preserve or commit any independent edits you have made to the listed files; merge those edits if necessary.
3. Extract this ZIP directly into the repository root, the folder containing OrchidApp.sln. There is no enclosing repository folder. Allow replacement of the listed modified files.
4. No deletions or moves are required. CHANGELOG.md is this package manifest and replaces the previous package manifest if present.
5. This delivery updates source, scripts, documentation and generated schema metadata. It contains no compiled installer or application binaries. Existing SQL definitions, schema checksums and historical migrations are unchanged.
6. Existing collection databases: do not run rebuild.ps1 to apply this source update. That command is solely for an explicitly selected new/empty target. No manual history edits or data migrations are needed for the preserved legacy baseline format.

## What changed

Fresh setup now imports schema and required reference data from a generated ordered manifest, without historical migration files. It records a baseline completion marker only after success. The retained rebuild.ps1 filename never drops a database and refuses nonempty/partial targets. Desktop and PowerShell upgrade paths recognise the database cut-off and retain existing history. Future SQL applies once; recorded checksums are checked.

Creation now requires an exact -ConfirmDatabase value and all seven explicit MARIADB_* settings. Client executables are resolved from explicit overrides, PATH, then the Windows MariaDB 10.11 fallback. The script no longer auto-loads .env. See docs/database-creation.md before creating any new target.

## Files

14 modified repository files and 8 added repository files, plus this CHANGELOG.md.

| Status | Repository path | Change |
| --- | --- | --- |
| Modified | `CONTRIBUTING.md` | Updates baseline/export guidance and adds the new verification commands. |
| Modified | `RELEASE_NOTES.md` | Records C01+C02 behaviour and outstanding platform acceptance. |
| Added | `database/schema/bootstrap.json` | Generated manifest covering 87 existing SQL files through 202606041820. |
| Modified | `database/scripts/Apply-MariaDBMigrations.ps1` | Recognises current/legacy baselines, skips covered history, honours the database target and corrects the export path. |
| Modified | `database/scripts/Apply-Migrations.ps1` | Recognises baseline cut-offs, checks recorded checksums and refuses database initialisation. |
| Modified | `database/scripts/Export-MariaDBSchema.ps1` | Resolves platform clients, honours the selected database and regenerates schema metadata from recorded history. |
| Added | `database/scripts/New-SchemaManifest.ps1` | Generates ordered schema metadata and rejects cyclic view dependencies. |
| Added | `database/scripts/Schema-Baseline.ps1` | Adds shared manifest, checksum, baseline and client-resolution helpers. |
| Modified | `database/scripts/dev-runner.ps1` | Corrects case-sensitive script references. |
| Modified | `database/scripts/rebuild.ps1` | Replaces destructive rebuilding with explicitly confirmed, non-overwriting schema-only creation. |
| Modified | `docs/architecture.md` | Describes the implemented creation/baseline paths and remaining runner limits. |
| Modified | `docs/code-change-backlog.md` | Records C01/C02 implementation and pending Linux/native-photo acceptance. |
| Modified | `docs/database-creation.md` | Defines the schema manifest, creation command, future migrations, legacy compatibility and recovery limits. |
| Modified | `docs/development-setup.md` | Uses explicit schema-only creation and correct target/tool guidance. |
| Modified | `docs/index.md` | Links the implementation evidence and current status. |
| Added | `docs/maintenance/c01-c02-schema-baseline.md` | Records implementation, actual local results, reproduction steps and remaining acceptance. |
| Modified | `docs/user-guides/linux/installation-upgrade.md` | Explains the portable creation command and pending Linux platform validation. |
| Added | `src/OrchidApp.Web/Infrastructure/SchemaBaseline.cs` | Adds matching Desktop manifest validation and future-only/legacy migration selection. |
| Modified | `src/OrchidApp.Web/Program.cs` | Uses the manifest for Desktop first use, preserves configured client credentials, and selects later migrations without rewriting history. |
| Added | `tests/SchemaBaseline.Checks/Database.Checks.ps1` | Adds repeatable disposable MariaDB creation, upgrade and failed-import checks. |
| Added | `tests/SchemaBaseline.Checks/Program.cs` | Checks metadata, cut-offs, tampering, legacy history and schema input safety. |
| Added | `tests/SchemaBaseline.Checks/SchemaBaseline.Checks.csproj` | Adds the executable baseline verification project. |

## Validation completed

- Release web build succeeded with zero errors/warnings.
- 18 schema baseline checks passed.
- 28 disposable MariaDB creation/baseline checks passed on Windows MariaDB 10.11.16.
- 163 monitoring isolation regression checks passed (NuGet vulnerability lookup was unavailable; NU1900).
- All 16 canonical views queried successfully; reference seeds supported real stored-procedure plant creation and saved-note reopening.
- Schema export regenerated an identical manifest and equivalent canonical SQL.
- Actual staged Desktop first use succeeded with no migration directory; Home and Plants returned HTTP 200. Desktop upgrade applied one future change, skipped historical poison SQL, and a restart did not apply it again. PowerShell and Desktop recorded matching manifest digests.
- The alternate developer runner recognised the baseline and applied a future change in a separate clean Git fixture.
- Failed final seed import left no completion marker; subsequent creation/migration attempts refused the incomplete database.
- Documentation links and archive paths/contents were checked.

## Remaining acceptance

Linux/MariaDB validation and a full native-photo save/reopen check remain pending. No Linux Docker engine was available locally. Staged Desktop migration testing used a synthetic successful-backup fixture; it did not validate real backup/recovery, and that fixture is excluded from this ZIP. No live database or owner settings were changed.

C01/C02 are implemented locally with the remaining acceptance recorded in docs/maintenance/c01-c02-schema-baseline.md. C03 owner-device acceptance remains pending. Next agreed implementation step: C04, migration runners.

## Re-run the checks

From the repository root:

```powershell
dotnet run --configuration Release --project tests/SchemaBaseline.Checks/SchemaBaseline.Checks.csproj
dotnet run --configuration Release --project tests/EnvironmentSummary.Checks/EnvironmentSummary.Checks.csproj
pwsh ./tests/SchemaBaseline.Checks/Database.Checks.ps1
```

The database check requires explicit credentials/endpoint for a disposable server with create/drop privileges. It creates and drops only a generated orchids_contract_<guid> database. See docs/database-creation.md for the exact contract.
