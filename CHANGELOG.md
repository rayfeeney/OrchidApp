# Reissued CI tool-resolution test fix

## Apply

Extract directly into the repository root (the folder containing OrchidApp.sln) and replace the two listed files. Preserve paths; no deletions or moves are needed. Merge any independent edits to those files. CHANGELOG.md replaces the previous delivery manifest.

Commit and push the corrected test file to the branch used by CI, then open the CI run belonging to that new commit. The earlier log shows the old throw expression and cannot be from this corrected source.

The test step must now print this revision label before its checks:

    Tool resolution check revision: array-arguments-v2

If the label is absent, verify the test file on the run's commit rather than making another resolver change.

## Files

| Repository path | Change |
| --- | --- |
| tests/SchemaBaseline.Checks/ToolResolution.Checks.ps1 | Reissues the complete corrected test: typed native argument array, count/type assertion, invocation diagnostics and an explicit revision label. |
| docs/maintenance/c01-c02-schema-baseline.md | Records the source-version mismatch and how to recognise the corrected test in CI. |

## Validation

Eight tool-resolution checks pass locally on Windows. The one-argument native-process construction was previously reproduced failing as spaced characters and passing after retaining the typed array. Linux CI has not been run locally.

No resolver, workflow, application, SQL, schema or migration changes are included. This package assumes the first CI resolver fix (selecting one PATH match) has already been applied.

Exact SHA-256 of the test file inside this ZIP (line-ending-sensitive):

10123793c3a8298e33327c685045cbbe0d18d6aef702d94f5b9304e214dfa7de
