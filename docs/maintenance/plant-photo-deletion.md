# Individual plant photo deletion

Scope: the existing gallery, request transaction/recovery completion, safe main/thumbnail cleanup, recovery report, and automated checks. No schema change or photo ingestion redesign. The plant observation remains as history after its last photo is removed.

The confirmation uses native HTML details and a separate explicit confirm submit, so cancellation and confirmation work without JavaScript. Existing anti-forgery and parent-row lifecycle locking apply. Database commit precedes physical deletion; partial cleanup or unknown transaction outcome retains the journal. Path checks reject traversal, Windows stream syntax and ancestor links/junctions on both platforms. A storage administrator replacing directories concurrently is outside the application writer-lock contract.

## Files changed

| File | Purpose |
| --- | --- |
| [Index.cshtml](../../src/OrchidApp.Web/Pages/Plants/Photos/Index.cshtml) | Confirmation/Cancel, delete action and feedback |
| [Index.cshtml.cs](../../src/OrchidApp.Web/Pages/Plants/Photos/Index.cshtml.cs) | Ownership/shared-file checks, metadata removal and hero replacement |
| [PhotoDeletionPaths.cs](../../src/OrchidApp.Web/Services/PhotoDeletionPaths.cs) | Cross-platform filename and link protection |
| [PhotoWriteBatch.cs](../../src/OrchidApp.Web/Services/PhotoWriteBatch.cs) | Durable deletion journal and commit-only cleanup |
| [PhotoWriteCompletion.cs](../../src/OrchidApp.Web/Services/PhotoWriteCompletion.cs) | Transaction failure and cleanup feedback |
| [review.ps1](../../scripts/PhotoRecovery/review.ps1) | Safe legacy filename recovery reporting |
| [PhotoConsistency.Checks.py](../../tests/LifecycleClosure.Checks/PhotoConsistency.Checks.py) | Real SQL/HTTP deletion regression cases |
| [PhotoDeletion.Checks.csproj](../../tests/PhotoDeletion.Checks/PhotoDeletion.Checks.csproj), [Program.cs](../../tests/PhotoDeletion.Checks/Program.cs) | Database-free filesystem/recovery checks |
| [ci.yml](../../.github/workflows/ci.yml) | Run storage checks on Windows and Linux |
| [photo-handling.md](../photo-handling.md), [current-state.md](../current-state.md), [upgrade-checklist.md](../upgrade-checklist.md), this report | Behaviour, recovery, adoption and validation limits |

## Validation on 1 November 2026

- `dotnet run --configuration Release --project tests/PhotoDeletion.Checks/PhotoDeletion.Checks.csproj`: 14 checks passed on Windows. The optional symbolic-link test was skipped because Windows denied link creation; Linux CI includes that test. The suite verifies confirmed cleanup, rollback, missing file/folder, unsafe names, unknown outcome, recovery blocking and deterministic partial-cleanup failure.
- `dotnet build src/OrchidApp.Web/OrchidApp.Web.csproj --configuration Release --no-restore`: passed, zero errors. Two temporary file-copy retries resolved when the owned fixture host exited.
- `pwsh ./tests/LifecycleClosure.Checks/Database.Checks.ps1 -PythonExe python`: passed all 200 SQL/HTTP tests across upgraded and schema-only fixtures, plus 12 schema-export policy checks. The upgraded fixture ran six new deletion cases; the schema-only fixture also ran the two added cross-plant/shared-path cases (eight deletion cases). Generated databases were removed successfully. The final completion/error-message refinements were subsequently rebuilt and exercised by storage/native recovery checks; hosted CI remains the check of one immutable final tree.
- `dotnet run --configuration Release --project tests/DevelopmentNative.Checks/DevelopmentNative.Checks.csproj`: 611 metadata/orientation/colour checks, 37 pair/transaction recovery checks and native main/thumbnail save/reopen passed with libvips 8.18.2.
- `git diff --check`: passed. Python syntax and all file links in this report passed. CI runs the new storage executable in both existing Windows and Linux jobs; the existing lifecycle runner automatically includes the new HTTP cases on both platforms.

The SQL runner creates its own generated databases and temporary upload roots using the existing development server credentials without printing passwords. It tests migrated and schema-only creation fixtures and removes only its generated databases. No collection data is used.

Pending: hosted Windows/Linux CI and installed Windows/Pi/mobile browser acceptance. No Linux runtime is installed on the local machine. Shared Windows 03/Linux 02 Word guides and screenshots still require updating and rendered review; see [current status](../current-state.md) and [upgrade actions](../upgrade-checklist.md).
