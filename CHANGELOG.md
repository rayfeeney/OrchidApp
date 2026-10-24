# C01+C02 follow-up - Linux CI schema-export fix

## Apply this delivery

1. Apply after the C01+C02 changes-only ZIP.
2. Extract directly into the repository root (the folder containing OrchidApp.sln), preserving folder paths and replacing the five modified files listed below. Merge any independent edits you have made to those files.
3. One repository test file is added. CHANGELOG.md is this package manifest and replaces the previous delivery manifest if present. No deletions or moves are needed.
4. Commit the changed files and rerun CI. No database commands, schema regeneration, history edits or rebuild are required to apply this correction.

## Cause and correction

The supplied Linux CI log shows two executable paths returned by Get-Command: /usr/bin/mariadb and /bin/mariadb. The resolver returned both, which were interpreted as one invalid command. It now returns the first application match in PATH order, including override-by-command-name lookups. The shared helper also resolves mariadb-dump and clients used by creation and migration scripts.

## Files

| Status | Repository path | Change |
| --- | --- | --- |
| Modified | `database/scripts/Schema-Baseline.ps1` | Selects only the first executable match for PATH and override lookups, preventing joined /usr/bin and /bin paths. |
| Modified | `.github/workflows/ci.yml` | Runs the cross-platform tool-resolution regression check before schema export in the schema-contract job. |
| Added | `tests/SchemaBaseline.Checks/ToolResolution.Checks.ps1` | Adds seven checks for duplicate PATH entries, executable invocation, paths containing spaces and override behaviour. |
| Modified | `docs/database-creation.md` | Documents single-executable lookup and the new regression-check command. |
| Modified | `docs/maintenance/c01-c02-schema-baseline.md` | Records the CI failure, cause, reproduction, correction and validation limits. |
| Modified | `RELEASE_NOTES.md` | Records the Linux CI tool-resolution correction. |

## Validation

- The regression test reproduced the failure before the fix: Resolution returns one string failed.
- With the fix all seven checks passed on Windows using two actual executable fixtures on PATH. Tests also execute the selected tool from a path containing spaces.
- Both the real local MariaDB client and dump executable resolved to single strings and executed their version commands successfully.
- PowerShell syntax checks passed. Documentation links and package paths/contents were verified.
- Linux schema CI now runs the new regression test before export. The full Linux CI job was not run locally; rerun it to confirm export and subsequent drift checks.
- No application code, database SQL, schema manifest, baseline timestamp, schema checksums or historical migrations changed.

## Local check

```powershell
pwsh ./tests/SchemaBaseline.Checks/ToolResolution.Checks.ps1
```

This check requires no database.
