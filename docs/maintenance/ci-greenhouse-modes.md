# Greenhouse CI execution modes — CHAT-R04

Previously both the isolated feature job and greenhouse database job ran the calculation, cache and net-cost policy checks before the optional SQL integration. The jobs remain separate; the repeated isolated execution has been removed.

## Execution and evidence

With no `GREENHOUSE_TEST_CONNECTION`, the executable runs isolated calculations, cache and net-cost policy checks. With an explicitly configured disposable connection, it runs only SQL loading/summary, SQL performance and SQL net-cost checks, then exits before the isolated suites. Existing `GREENHOUSE_DISPOSABLE_INSTANCE=1`, exact loopback/port and empty-user-schema guards still apply before fixture SQL. SQL checks and helper implementations are unchanged.

No new mode setting or CLI flag is introduced. The existing runner commands remain:

```powershell
python scripts/run-feature-checks.py
python scripts/run-feature-checks.py --mode greenhouse-db
```

The first command strips optional database/benchmark variables. The second requires the explicit disposable connection and confirmation; see the [test procedure](../testing-evidence.md). Direct execution with a connection also selects database-only execution. Preview arguments such as `--serve` or `--fixture-output` must use isolated execution with the connection cleared; mixing them with database mode is refused before connection parsing/setup rather than unexpectedly mutating a database or serving after an integration run. Dense benchmarking remains a separate explicit direct-executable opt-in.

The executable emits its mode and suite labels. A successful greenhouse process must show all three selected suite labels and no labels from the other mode. The runner records `modeEvidence` and fails the report/job on missing or mixed evidence even if the executable returned zero. Assertions are still executed normally; historical pass counts are not used as criteria. Other check executables retain their existing result handling.

The workflow still has the isolated feature, disposable greenhouse database and lifecycle jobs. No workflow YAML, fixture SQL, application behavior, database migration, environment setting or installed startup command changes.

## Local validation: 28 October 2026

Windows AMD64, .NET SDK 9.0.315 targeting net8.0 and Python 3; a new private MariaDB 10.11.16 data directory served only its generated greenhouse fixtures.

- All eight selected isolated feature suites passed in the evidence runner. Greenhouse reported 65 isolated assertions and only isolated mode/suite labels.
- The explicitly disposable database run passed, reporting 18 database assertions and only database mode/suite labels. Its setup/summary, SQL performance and SQL net-cost coverage remained present. The former combined run reported 83, including the 65 isolated assertions; these are measured observations, not expected totals in code.
- A separate nonempty-server attempt was refused before fixture SQL. Its synthetic sentinel row remained 42 and neither greenhouse fixture schema was created. Only the owned private server was subsequently shut down; no collection/development server or private `.env` was used.
- Eight evidence-runner tests passed. They include missing/mixed suite evidence and a zero-exit wrong-mode process producing a failed report.
- An actual database-plus-preview invocation was refused before parsing a deliberately invalid synthetic connection string; no preview file or isolated suite was produced.
- The initial restricted isolated run retained an EnvironmentSummary HTTP/socket failure. Repeating with loopback access available passed all eight suites. That environmental failure was not changed into a successful record.
- All named Program assertions were retained. The SQL/cache/net-cost helper files and fixture SQL were not changed. Package/schema/data invariants do not rely on frozen assertion counts.

The greenhouse build emitted NU1900 warnings because the NuGet vulnerability service was unavailable during restore; executable checks passed. This is not a vulnerability audit. Workflow syntax, Python parsing and changed-document links are checked with delivery. GitHub CI on the applied/merged revision, Linux runtime and device/installed acceptance remain pending.

The operator and plant-management guides require no edits: this changes internal test execution/evidence only, not application controls or deployment prerequisites. See the [upgrade action list](../upgrade-checklist.md#chat-r04-greenhouse-ci-deduplication). C18 historical upgrade/recovery and specimen publication remain separate work.
