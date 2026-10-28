# CHAT-R04 — greenhouse CI deduplication

Database execution no longer repeats isolated greenhouse calculations/cache/net-cost policy tests. The existing isolated, greenhouse database and lifecycle jobs remain separate. No SQL assertion/helper/fixture coverage is removed.

## Apply

1. Apply after `OrchidApp-CHAT-R01-R03-changes-only.zip`. Shared documentation includes that preceding correction. Review/extract the repository-relative files below into the source root containing OrchidApp.sln, preserving unrelated local changes.
2. Commit and run the existing CI. Commands and job names are unchanged: `python scripts/run-feature-checks.py` and, only on the configured new empty disposable service, `python scripts/run-feature-checks.py --mode greenhouse-db`.
3. Require passed greenhouse `modeEvidence` with no mixed modes. Keep all job results and retained logs. The database assertion total is smaller because the isolated assertions run once in their own job, not because SQL coverage was removed.
4. For direct manual preview use, clear optional connection variables before `--fixture-output`/`--serve`. With a connection, direct execution now selects database-only mode; database-plus-preview arguments are refused before setup.

**No application deployment/rebuild solely for this correction, database migration, .env setting, credential or normal startup change is required.** Other included changes retain their normal deployment/backup obligations. Fixture SQL must never run on a collection/development server.

## Every added/modified repository file

- **Modified `tests/GreenhouseCharts.Checks/Program.cs`** — Select guarded database-only execution before isolated suites, retain SQL coverage, emit mode/suite labels and refuse database-plus-preview arguments before setup.
- **Modified `scripts/run-feature-checks.py`** — Record greenhouse mode evidence and fail missing/mixed suite selection even when the process exits zero; keep commands, guards, log hashes and other suite handling.
- **Modified `tests/FeatureEvidence.Checks/checks.py`** — Add exclusive-mode/suite evidence cases and zero-exit wrong-mode failure-report regression coverage.
- **Modified `CONTRIBUTING.md`** — Explain disjoint execution, evidence requirements and preview constraints.
- **Modified `RELEASE_NOTES.md`** — Describe CI deduplication and unchanged operator/migration requirements.
- **Modified `docs/testing-evidence.md`** — Document SQL-only mode, direct-executable behavior and additive modeEvidence results.
- **Modified `docs/upgrade-checklist.md`** — Record release-owner evidence checks and no Windows/Linux operator action for this test-only change.
- **Modified `docs/code-change-backlog.md`** — Track CHAT-R04 implementation and local validation, leaving applied/merged CI pending.
- **Modified `docs/index.md`** — Link measured CI-mode evidence.
- **Modified `docs/maintenance/c20-reproducible-checks.md`** — Preserve original C20 observations and link the subsequent disjoint-mode change.
- **Added `docs/maintenance/ci-greenhouse-modes.md`** — Record execution contract, actual tests, guards, warning/failure history and remaining limits.

Root CHANGELOG.md is included only as this delivery inventory. No other application/source files, logs, private settings, data or binaries are packaged.

## Actual validation

- Eight evidence-runner unit tests passed, including complete/missing/mixed suite labels and an executable that exits zero in the wrong mode producing a failed report.
- All eight selected isolated feature executables passed in the final run; greenhouse reported 65 isolated assertions with only its isolated suites.
- Fresh private MariaDB 10.11.16 database-only execution passed, reporting 18 SQL assertions with loading/summary, performance and net-cost suites, with no isolated execution. SQL/cache/net-cost helper implementations and all named Program assertions are retained.
- Nonempty disposable-server guard refused setup before fixture SQL, left the synthetic sentinel value 42 unchanged and created neither greenhouse fixture schema. Only the owned private server was shut down.
- Database-plus-preview execution refused a synthetic invalid connection before parsing/setup and wrote no preview file.
- Final isolated/database reports have matching selected-source fingerprint `7c43a7b77c2ab892287ecd91a3fbf6927eeed5700aea1d3725424cfcba74bfad`. This is source evidence, not a release-package hash or Git revision.
- Python sources parsed; unchanged workflow passed actionlint with optional ShellCheck/Pyflakes disabled; changed Markdown local links resolve. User/operator and plant-management guides need no changes for this test-only execution update.

## Limits and retained failures

- Windows AMD64, .NET SDK 9.0.315 targeting net8.0, Python 3, private MariaDB 10.11.16. This extracted source mirror has no Git revision identity.
- The initial restricted full feature run retained an EnvironmentSummary socket/loopback failure; the subsequent run with loopback access passed. That environmental failure was not erased or labelled successful.
- Restore emitted NU1900 warnings because the NuGet vulnerability service was unavailable; this is not a vulnerability audit.
- Applied/merged-revision GitHub CI, Linux runtime and device/installed acceptance remain pending. No C18 historical upgrade/recovery or Windows fixture work is claimed. The frozen historical specimen is unchanged.
- Assertion totals above are measured observations, never fixed pass criteria.
