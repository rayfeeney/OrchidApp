# C13 CI correction for lock wait observation

Changes only: five modified repository files plus this CHANGELOG.md. No additions, deletions or moves in the repository. No private .env, credentials, data or runtime binaries.

## Apply

Extract over the source repository root containing OrchidApp.sln, replacing the five listed files. This overlays the previous C13 delivery. Commit normally and rerun CI. The job output must identify c13-lock-wait-count-v2. No new database update command, migration or configuration change is needed for this correction. Keep the previously delivered C13 app and procedure pairing.

## Correction

The test previously required exactly one row from INNODB_LOCK_WAITS for the waiting connection. This is a count of wait edges and can exceed one. The helper now requires a positive count and continues to reject completion before the held lock is released. A real two-holder scenario proves multiple wait edges, continued blocking after the first release and successful completion after the second release. Timeout/early-completion diagnostics include the connection and server/task state. Fresh plants are created at the start of each subcase so an earlier failed assertion cannot cascade into subsequent cases on an already-ended fixture.

The supplied Linux log lacks actual wait counts, so their exact CI values are not claimed. Linux CI must confirm the correction; the unavailable local Linux engine prevented a Linux reproduction.

## Files

| Change | Repository path | Purpose |
| --- | --- | --- |
| Modified | RELEASE_NOTES.md | Describe the test correction and required CI rerun. |
| Modified | docs/maintenance/c13-structural-transactions.md | Record CI evidence, the exact-count defect, regression coverage, limits and test-only scope. |
| Modified | docs/upgrade-checklist.md | Record that this CI correction adds no migration, setting or deployment action. |
| Modified | tests/LifecycleClosure.Checks/Database.Checks.ps1 | Identify corrected checks as c13-lock-wait-count-v2. |
| Modified | tests/LifecycleClosure.Checks/Structural.Checks.py | Accept any positive lock-wait count for the waiting connection; add an actual two-holder regression, timeout diagnostics and fresh fixtures at subcase start. |

## Validation

The combined native Windows MariaDB 10.11.16/Release HTTP suite passed 16 closure + 16 C12 + 22 C13 scenarios on each upgraded/fresh-created database: 108 executions, including the real two-blocker regression twice. The database suite also checks migration/creation history and schema-export preflight in disposable source copies. Generated fixture databases/web/server processes were cleaned up; diagnostic folders remain. No owner database or .env was used or modified.

Python syntax, PowerShell syntax, local documentation links and exact ZIP contents/bytes were checked. Full-repository hashes confirm every application file, all migrations, generated schema/checksums, configuration/development helpers and both Word guides are unchanged. User guides were reviewed and remain applicable because this changes test assertions/fixture isolation only. The previous 44/53/10 regression and policy results remain the previous C13 evidence; they were not rerun for this test-only correction. Linux CI and installed-target acceptance remain pending.
