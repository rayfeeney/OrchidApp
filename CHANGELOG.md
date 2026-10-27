# C13 CI revision v3 for metadata cache polling

Changes only: five modified repository files plus this CHANGELOG.md. No repository additions, deletions or moves. No private .env, credentials, data or runtime binaries.

## Apply

Extract over the source repository root containing OrchidApp.sln, replacing the five listed files. This supersedes the earlier C13 CI-fix ZIP and includes that test correction. Commit normally and rerun CI; its output must identify c13-lock-cache-v3. No new migration, database-update command or configuration change is required. Keep the already delivered C13 app/procedure pairing.

## Diagnosis and correction

The new Linux diagnostics showed an empty cached transaction snapshot, not multiple wait edges. The previous count correction was incomplete. MariaDB's lock/transaction metadata cache requires over 100 ms without a read before it refreshes; every read resets that idle time. The former 50 ms polling could keep a stale empty snapshot alive on the fast Linux runner. Windows process startup had accidentally spaced its reads farther apart.

The helper now leaves 250 ms between metadata polling attempts, including after diagnostics. It still requires actual wait edges for the specific waiting connection and rejects early completion; time alone is not a pass. The HTTP closure check scopes its wait edges to the known blocking connection. A new regression uses a fast persistent observer to remove process startup as a hidden delay. The existing positive-count and two-holder checks remain.

See docs/maintenance/c13-structural-transactions.md for links to MariaDB's implementation, the supplied CI evidence and the correction to the earlier diagnosis.

## Files

| Change | Repository path | Purpose |
| --- | --- | --- |
| Modified | RELEASE_NOTES.md | Describe the cache-aware test correction and CI rerun. |
| Modified | docs/maintenance/c13-structural-transactions.md | Correct the incomplete earlier diagnosis and record MariaDB source evidence and direct reproduction. |
| Modified | docs/upgrade-checklist.md | Record v3 acceptance and confirm no additional migration/settings/deployment action. |
| Modified | tests/LifecycleClosure.Checks/Database.Checks.ps1 | Identify corrected checks as c13-lock-cache-v3. |
| Modified | tests/LifecycleClosure.Checks/Structural.Checks.py | Use cache-aware metadata polling, scope HTTP lock waits to their holding session and add a fast persistent-observer regression. |

## Validation actually completed

- Controlled native MariaDB 10.11.16 reproduction: the same fast-observer scenario with 50 ms polling failed for the full timeout with an empty transaction snapshot; changing to 250 ms observed the actual row-lock wait and passed. This reproduced the previously unexplained failure locally rather than relying only on a Windows pass.
- The complete Release HTTP/native SQL suite passed 16 closure + 16 C12 + 23 C13 scenarios on each upgraded/fresh-created database: 110 executions. This includes the fast-observer regression twice, two blocking holders, transaction failure/rollback and actual handler/closure concurrency.
- Python and PowerShell syntax, local documentation links, exact ZIP contents/bytes and full-repository hashes were checked. Every app file, migration, generated schema/checksum, developer helper/configuration and Word guide is unchanged. The guides were reviewed and remain applicable because no user workflow changed. Previous unrelated regression/policy results remain previous C13 evidence and were not rerun for this test-only fix.
- Tests used owned disposable databases/server/web processes, which were cleaned up. Diagnostic folders remain. No owner database, private .env or live photos were used or changed.

Linux CI must be rerun to confirm v3; no local Linux pass or installed-machine acceptance is claimed. Source/CI tests do not establish installed upgrade acceptance.
