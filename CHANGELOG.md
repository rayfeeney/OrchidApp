# CI follow-up - Unix tool-resolution test

## Apply

1. Apply after the previous C01+C02 CI fix.
2. Extract directly into the repository root, the folder containing OrchidApp.sln. Replace the three modified files listed below, preserving their paths. Merge any independent edits you have made to these files.
3. CHANGELOG.md is this delivery manifest and replaces the previous package manifest. No files are added, deleted or moved apart from this manifest.
4. Commit and rerun CI. No database commands, schema regeneration or rebuild are needed.

## Cause

The Linux resolver assertions had passed. The fixture invocation failed because assignment from an if-expression unrolled its one-item argument array into the scalar string resolver-ok. PowerShell splatted the string as individual characters, so echo returned r e s o l v e r - o k. This was a test bug introduced in the prior fix.

The argument variable is now explicitly string[]. An additional check validates its type/count, and native invocation failures include captured output and exit code. The production resolver and workflow are unchanged.

## Changed files

| Repository path | Change |
| --- | --- |
| `tests/SchemaBaseline.Checks/ToolResolution.Checks.ps1` | Keeps fixture arguments as a string array, checks their type/count and reports the exit code/output if invocation fails. |
| `docs/maintenance/c01-c02-schema-baseline.md` | Adds the observed Linux test failure, exact cause, correction and validation evidence. |
| `RELEASE_NOTES.md` | Records the Unix regression-test argument correction. |

## Validation

- Eight tool-resolution checks passed locally on Windows.
- Native-process reproduction of the exact Unix single-argument expression: before, exit 1 with r e s o l v e r - o k; after, exit 0 with resolver-ok.
- PowerShell syntax and ZIP paths/contents were checked.
- The full Linux CI job was not executed locally and must be rerun.
- No production resolver, workflow, application code, SQL, schema metadata, checksums or migration history changed.

## Optional local check

```powershell
pwsh ./tests/SchemaBaseline.Checks/ToolResolution.Checks.ps1
```

No database is required.
