# C04 CI follow-up - formatted error assertion

## Apply

1. Apply after the C04 changes-only delivery.
2. Extract directly into the repository root, the folder containing OrchidApp.sln, preserving folder paths. Replace the four modified files and add the two new test files listed below. Merge independent edits if necessary.
3. No deletions or moves are needed. CHANGELOG.md replaces the previous delivery manifest.
4. Commit and push all six repository files, then inspect the CI run for that new commit. No schema regeneration, database command or application rebuild is needed for this test-harness correction.

## Cause and correction

The supplied CI log showed the intended failed-DDL error. PowerShell wrapped the phrase SQL may be partially applied across formatted error lines and inserted a gutter. The test searched that display text as a contiguous substring and rejected the expected failure.

The database suite now reads the original exception message from a JSON child-process result, independently of terminal width or error-view decoration. The nonzero exit requirement and every database-state assertion remain. Parameters and switches are explicitly bound from JSON data, with no path/value interpolation as executable code. Diagnostic output remains available on unexpected failures.

## Files

| Status | Repository path | Change |
| --- | --- | --- |
| Modified | `tests/MigrationHistory.Checks/Database.Checks.ps1` | Runs protocol checks first and compares structured child exception messages instead of formatted terminal output. |
| Added | `tests/MigrationHistory.Checks/Process.Helpers.ps1` | Adds a test-only JSON child-process result protocol with safe argument binding and captured exit codes. |
| Added | `tests/MigrationHistory.Checks/Process.Checks.ps1` | Adds ten regression checks covering the reported wrap, long/multiline messages, Unicode, quotes and argument/exit handling. |
| Modified | `docs/migration-runners.md` | Documents the database-free protocol check and its automatic execution before the database suite. |
| Modified | `docs/maintenance/c04-migration-runners.md` | Records the Linux CI assertion defect, correction and actual validation results. |
| Modified | `RELEASE_NOTES.md` | Records the test-harness-only correction. |

## Verification

- Ten child-process protocol checks passed locally, including the exact reported formatting split, complete long/multiline exception round trips, Unicode/quotes, paths with spaces, named/switch/positional parameters and success/failure exit codes.
- All 53 migration database checks passed on the isolated Windows MariaDB 10.11.16 instance using the new harness.
- PowerShell syntax, documentation links and ZIP paths/contents were checked.
- Linux CI has not been run locally and must be rerun.
- Production migration runners, CI workflow, application code, SQL, history, baseline and generated schema metadata are unchanged.

## Recognise the corrected CI run

The database step now starts with:

```text
10 child-process protocol checks passed.
```

It then runs all 53 database assertions. The database-free regression can also be run alone:

```powershell
pwsh ./tests/MigrationHistory.Checks/Process.Checks.ps1
```
