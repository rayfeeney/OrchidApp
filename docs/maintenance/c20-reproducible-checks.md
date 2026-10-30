# C20 reproducible feature checks and evidence

> Status reconciliation, 30 October 2026: this article preserves the original implementation/test record. Its earlier next-step, merge and CI-pending statements describe that delivery stage. See [current status and scope](../current-state.md) for confirmed later CI, the remaining machine acceptance, and the v1.4.0 Windows baseline decision. Original results and limitations below are retained.

Implemented in source: curated feature CI, a separate disposable greenhouse MariaDB job, retained command/environment/result reports, and distinct cached domain-unavailable versus exception tests. The owner is [testing and evidence](../testing-evidence.md). Source review mirror has no Git revision; the generated evidence records `unavailable` plus its source fingerprint. Record the actual merged revision and CI artifact identity when accepting a release.

## Changes

- `scripts/run-feature-checks.py` selects eight isolated feature executables or explicit greenhouse DB mode, isolates optional variables, preserves failures/log hashes and records source/environment/commands.
- `tests/FeatureEvidence.Checks/checks.py` tests optional-mode isolation, explicit DB opt-in, failed-check continuation/evidence and invalid-configuration reports.
- `tests/GreenhouseCharts.Checks/PerformanceChecks.cs` separately checks cached missing readings/costs, expiry/recovery, and propagated uncached exceptions. `Program.cs` requires an explicit empty disposable server and separates setup from the selected fixture DB.
- `.github/workflows/ci.yml` runs both modes in separate jobs and uploads their evidence even on failed checks. No benchmark or device run is implied. `.gitignore` excludes generated evidence.
- CONTRIBUTING, documentation index/map, owner monitoring guide, upgrade checklist, backlog and release notes link the current workflow and its limits.

## Measured local validation

On 28 October 2026, Windows 11 AMD64, Python 3.12.14, .NET SDK 9.0.315 targeting the existing net8.0 projects:

- All eight selected isolated feature suites passed. Greenhouse reported 65 assertions for that run; it is not an expected-count assertion.
- The new empty disposable MariaDB 10.11.16 instance on 127.0.0.1:33317 passed greenhouse policy plus SQL integration, reporting 83 assertions. Only synthetic data was used; the owned instance was shut down with its data-directory identity checked.
- An existing synthetic sentinel schema caused refusal before fixture SQL. The sentinel value remained unchanged and neither monitoring fixture schema was created. The production/development `.env` was not read.
- Six evidence-runner tests passed, including failed-check continuation, launch errors, timeout records, private-setting fingerprint exclusion and log hashes. A failed restricted-loopback attempt was retained as failed; the subsequent run with local networking available passed.
- GitHub workflow syntax was checked with actionlint (external shellcheck/pyflakes disabled). Python sources were parsed. Package inventory and documentation links were checked before delivery.

Final isolated run `20261028T085016Z-0900560f` and database run `20261028T085122Z-9d9b1596` both recorded source SHA-256 `e2ae3c8496f5af3d9b5a31ad729ab8a403fd39951fc0d566e0d80b0a442bf138` over 658 selected source/build files. Commands were `python scripts/run-feature-checks.py --output <local-evidence-parent>` and `python scripts/run-feature-checks.py --mode greenhouse-db --output <local-evidence-parent>`, from the review repository root; runtime versions and exact command argument arrays are in their local reports. These local logs are not distributed in the source ZIP. Reproduce with the actual merged revision in CI and retain its artifacts for release use.

Restores emitted NU1900 warnings because vulnerability-feed access was unavailable locally. Compilation/executable checks passed; this is not a current dependency vulnerability audit. GitHub CI, Linux runtime execution, dense benchmark, physical device, real provider, production/admin installer and representative older-release acceptance remain pending. See the [upgrade checklist](../upgrade-checklist.md) and separate historical installation task.

## Deployment impact and guide review

Subsequent [CHAT-R04 execution-mode correction](ci-greenhouse-modes.md) removes the repeated isolated greenhouse suites from database mode, adds explicit disjoint mode/suite evidence and retains all SQL coverage. The counts above describe the original combined execution, not expected totals for the new split execution. The same three CI jobs and commands remain.

No database artifact, applied migration, application feature code, monitoring switch, cache setting, normal development startup or credential contract changes. No Windows/Linux operator configuration is introduced. Release owners retain the current revision-specific reports alongside existing database/installer/native evidence and complete actual device acceptance. Windows and Linux Word installation/use guides were reviewed for impact; their user flows and screenshots are unchanged, so no Word edit/render was needed for this CI/test-only item.
