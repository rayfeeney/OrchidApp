# C20 - reproducible feature checks and release evidence

Changes only: 11 modified and 4 added repository files, plus this CHANGELOG.md. No deletions or moves. No .env, credentials, collection data, runtime binaries, generated reports/logs or installers are included.

## Apply

1. Extract into the source repository root containing OrchidApp.sln, after the merged C18 and its CI correction. Replace only the listed files. Review/commit the resulting Git changes and run CI.
2. No database migration, schema export change, .env edit, development startup change or Windows/Linux application setting is needed for C20. Ordinary dotnet run remains unchanged.
3. This is a source/test/CI delivery, not a deployed installer or application update. No Program Files/data replacement is required to adopt its checks.

## Windows and Linux release actions

Run `python scripts/run-feature-checks.py` with Python 3/.NET 8 available. Retain generated report.json and per-suite logs under ignored artifacts/feature-checks/. CI uploads those artifacts even on failed checks. Review actual results, source revision, environment and every notRun category. Existing schema/lifecycle/native/backup/installer jobs must still pass; keep C18 artifact checksum/signature evidence and the completed docs/upgrade-checklist.md record alongside these results.

The greenhouse database job uses its own NEW EMPTY disposable MariaDB service on 127.0.0.1:33317. Manual integration requires GREENHOUSE_TEST_CONNECTION and GREENHOUSE_DISPOSABLE_INSTANCE=1, then `python scripts/run-feature-checks.py --mode greenhouse-db`. It refuses existing user schemas before fixture SQL. Its fixed orchids/EnergyMonitoring names belong only to that synthetic fixture. Never use the owner/development server from .env or a collection server. Default feature execution strips optional DB/benchmark variables; the runner never enables the dense benchmark. Read docs/testing-evidence.md before manual integration.

Physical device, provider/service, production installer and representative older-release acceptance remain separate. No benchmark/production/hardware certification is claimed. Record skipped cases explicitly; a passing feature report is not an installed-upgrade approval.

## Validation

- All eight selected feature suites passed locally. The greenhouse isolated run reported 65 assertions, as an observation rather than a frozen pass count.
- Real empty disposable MariaDB 10.11.16 integration passed, reporting 83 assertions. An existing synthetic sentinel schema was refused without alteration or fixture schema creation. The owned server was shut down after identity verification.
- Six evidence behavior tests passed, including failure continuation, timeout/launch reporting, optional-mode isolation, private-settings exclusion and log hashes.
- Workflow lint (actionlint; external shellcheck/pyflakes disabled), Python parsing, current changed-document links and ZIP content verification passed.
- All database artifacts, application code, app tools and Word guide bytes remain unchanged from the C20 baseline. Word guides required no edits because their user flows/screenshots did not change.
- Local reports identify Windows 11 AMD64, Python 3.12.14, .NET SDK 9.0.315 and installed runtimes. Extracted review source has no Git revision; its recorded source fingerprint is e2ae3c8496f5af3d9b5a31ad729ab8a403fd39951fc0d566e0d80b0a442bf138. GitHub will record the merged revision. Local restore warnings indicate unavailable vulnerability-feed access; no dependency audit is claimed.
- GitHub/Linux CI execution and actual installed/device/older-release acceptance remain pending.

## Exact file list

| File | Change | Purpose |
|---|---|---|
| `.github/workflows/ci.yml` | Modified | Run isolated feature and dedicated disposable greenhouse SQL jobs; retain evidence on failure. |
| `.gitignore` | Modified | Exclude generated feature-check evidence from source control. |
| `CONTRIBUTING.md` | Modified | Document curated checks, explicit DB opt-in and evidence boundaries. |
| `RELEASE_NOTES.md` | Modified | Describe C20 behavior and pending release acceptance. |
| `docs/code-change-backlog.md` | Modified | Align C20 status and recorded implementation/acceptance. |
| `docs/documentation-map.md` | Modified | Assign testing/evidence documentation ownership. |
| `docs/index.md` | Modified | Link the reproducible checks procedure and C20 evidence. |
| `docs/local-installation/greenhouse-monitoring.md` | Modified | Clarify disposable-instance guards, benchmark selection and current evidence. |
| `docs/maintenance/c20-reproducible-checks.md` | Added | Record measured validation, source identity, affected guides and remaining limits. |
| `docs/testing-evidence.md` | Added | Own commands, check inventory, JSON/log evidence and CI/device boundaries. |
| `docs/upgrade-checklist.md` | Modified | Add Windows/Linux release evidence actions; retain pending installed acceptance. |
| `scripts/run-feature-checks.py` | Added | Select intended fixtures; record commands/source/environment/results/log hashes without optional-mode leakage. |
| `tests/FeatureEvidence.Checks/checks.py` | Added | Verify failed/timeout/launch evidence, optional-mode isolation, private-file exclusion and log integrity. |
| `tests/GreenhouseCharts.Checks/PerformanceChecks.cs` | Modified | Distinguish cached domain-unavailable results, expiry/recovery and uncached exceptions. |
| `tests/GreenhouseCharts.Checks/Program.cs` | Modified | Require an explicitly empty disposable server before fixture SQL and select created fixture DB explicitly. |
