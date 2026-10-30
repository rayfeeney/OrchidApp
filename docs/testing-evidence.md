# Reproducible checks and release evidence

Run from the source repository root with .NET 8 and Python 3 available. The selected checks are executable programs, not a conventional test-discovery suite. Their current assertions determine success; a historical number of checks is not a pass criterion.

## Default feature checks

```powershell
python scripts/run-feature-checks.py
```

This runs the Release configuration of RichNotes, Navigation, NameSearch, EnvironmentSummary, GreenhouseCharts, SchemaBaseline, MigrationHistory and DevelopmentConfiguration checks, continuing independent checks after a failure. EnvironmentSummary uses a temporary local HTTP server and simulated platform policy; it requires loopback networking but no database or physical ARM device. These fixtures do not start the normal application or read its private development `.env`.

Each run creates a unique directory under `artifacts/feature-checks/`, ignored by Git. `--output <directory>` selects a different parent; existing run directories are never replaced. `--timeout <seconds>` bounds each check executable, default 600. A failed check, launch failure, timeout or invalid database configuration yields a nonzero runner exit code. Failures are retained rather than converted to passes. Child-process timeouts do not certify resource cleanup; inspect retained logs and temporary fixture processes if a timeout occurs.

The runner removes inherited GREENHOUSE, MARIADB and MYSQL optional-test settings from child processes. Thus default feature checks cannot silently turn into database or dense benchmark runs. It does not load `.env`, enable monitoring, supply normal app credentials or forward arbitrary executable arguments.

## Disposable greenhouse database integration

CI uses its own new MariaDB 10.11 service on loopback port 33317, separate from every other database job. Locally, provision a new empty disposable MariaDB server on that port. Do not use the development server selected by `.env` or a collection server. The fixture owns the fixed schemas `orchids` and `EnergyMonitoring`; those names are synthetic monitoring fixture inputs, not deployment defaults. This fixture is deliberately separate from canonical application database creation and does not initialise a normal installation.

Explicitly supply `GREENHOUSE_TEST_CONNECTION` for that disposable server and `GREENHOUSE_DISPOSABLE_INSTANCE=1` in the test process environment, then run:

```powershell
python scripts/run-feature-checks.py --mode greenhouse-db
```

The connection must select 127.0.0.1:33317. Before any fixture SQL, the executable refuses every pre-existing user schema, including an old fixture or a bootstrap `test` schema. Use a new empty server for each run; do not delete existing data to make a chosen server pass. The executable opens its setup connection without a default database, then explicitly selects the created fixture `orchids` for EF queries. It reports actual server version in its log. No schemas are automatically dropped by the runner. Destroy only the disposable server you created after retaining evidence.

This mode executes only real SQL summary, aggregate, mapping, tariff, performance and net-cost fixtures. Isolated calculation/cache/policy checks run separately in the default feature mode and are not repeated here. It does not create live monitoring feeds or certify collector grants. Direct execution with a connection selects the same database-only path and instance confirmation/empty-server guards. Preview arguments require an isolated process with the connection cleared; database-plus-preview combinations are refused before setup. Clear optional variables after direct manual testing.

## Evidence contents

`report.json` records UTC start/end, selected mode, exact argument arrays, per-executable exit/status/duration, log filenames and SHA-256 hashes, OS/architecture, Python, .NET SDK and installed runtimes. It records Git HEAD and tracked working-tree status when the source root is a Git checkout. A source fingerprint covers the stated source extensions under src/tests/scripts/database/.github plus root build metadata, excluding build outputs and appsettings/private configuration. This fingerprint supplements revision identity; it is not a full release package hash or proof of a clean checkout. An extracted source mirror records revision/status as `unavailable`; never invent a revision for it.

Individual logs retain actual assertion summaries and the MariaDB version for integration. Counts are observations for that run, not frozen expected totals. The JSON does not dump environment variables or connection strings. Logs may still contain machine paths or test diagnostics; inspect before sharing. Keep release package hashes/signing evidence, source revision, these reports and the completed [platform upgrade record](upgrade-checklist.md) together.

For a successful greenhouse executable, `modeEvidence` additionally requires all three suite labels for the selected mode and rejects labels from the other mode. Missing or mixed mode evidence makes the report fail even on process exit code zero. This prevents duplicated or incorrectly selected execution without running the suites a second time. See [CHAT-R04 measured validation](maintenance/ci-greenhouse-modes.md).

GitHub CI uploads the feature and greenhouse database evidence even when their run fails. Checkout/runtime setup failures can prevent report creation; a missing artifact is an error, not successful evidence. Existing database, backup, native-photo and installer jobs retain their own logs/artifacts and must also pass; these reports do not replace them.

## Check inventory and boundaries

The feature job runs 23 pure historical fixture/adoption/package/ownership checks plus three PowerShell package policy checks. The manual historical workflow now defaults to actual ARM64 package/application/action/app-only/recovery phases, using the unchanged published fixture and reviewed database admission. The earlier hosted database-only success is retained separately; the full extended workflow passed in run [40777537302](https://github.com/rayfeeney/OrchidApp/actions/runs/40777537302) on the identical merged source tree; see [current status](current-state.md). Bounded reports distinguish actual migration, intentional action writes, app-only state preservation, failed-DDL marker/refusal and full compatible recovery. Real Pi/systemd/provider/browser and Windows installed acceptance remain separate. See [scope](historical-linux-upgrade.md) and [actual phase results](maintenance/historical-linux-application-recovery.md).

| Category | Checks and execution | What remains separate |
| --- | --- | --- |
| Isolated feature/policy | Eight executable projects selected by `scripts/run-feature-checks.py`; evidence-runner behavior via `python tests/FeatureEvidence.Checks/checks.py` | A local HTTP fixture is not a physical ARM browser/server check |
| Greenhouse database | Explicit empty-server `greenhouse-db` mode; dedicated CI service | Owner monitoring deployment, external feed/grant compatibility and real sensor values |
| Schema/migration/lifecycle DB | Existing SchemaBaseline, MigrationHistory, DevelopmentSetup and LifecycleClosure `.ps1` runners in CI; upgraded/fresh SQL and HTTP scenarios, including `ValidationMessages.Checks.py` for rejected field errors and corrected saves | Representative old release installations and live collection recovery |
| Native photo and Desktop/installer | Existing DevelopmentNative, BackupRestore, InstallerUpgrade jobs and C18 artifact evidence | Actual supported OS/native runtime combinations and production administrator installation |
| Linux paired recovery | Existing LinuxBackup CI fixtures and disposable DB runner | Real systemd/cron/cloud provider/Pi acceptance |
| Dense benchmark | Direct greenhouse executable only with explicit disposable connection/confirmation plus `GREENHOUSE_BENCHMARK=1` | Not run by this runner or default CI; timing is synthetic and machine-specific |
| Device/installed acceptance | Per-machine Windows/Linux checklist and representative older-installation task | Always recorded separately, never inferred from an executable pass or cross-publish |

Successful domain-unavailable chart results are deliberately cached until expiry, preserving null/gap values. Exceptions propagate and do not poison the cache. Separate tests exercise these behaviors and recovery after expiry. Current owner procedures remain in [monitoring](local-installation/greenhouse-monitoring.md); C20 changes no feature gate, cache setting or production query.

See [C20 implementation evidence](maintenance/c20-reproducible-checks.md) for this delivery's measured results and remaining acceptance.
