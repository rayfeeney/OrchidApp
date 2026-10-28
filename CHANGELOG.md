# Historical Linux application, app-only and recovery changes

## Apply this delivery

Apply AFTER merged PR #361 (383bec7d019c8f102802f5e61e19ef32989663d9). This is a delta from that exact merged source, not a full repository. Extract the 28 listed source/documentation files at the OrchidApp repository root, review overlapping newer edits, then create a PR and merge only after normal CI passes. Root CHANGELOG.md is delivery documentation; preserve/merge any existing project changelog. No files are deleted.

The existing specimen release/asset stays unchanged. No new specimen upload or GitHub release is needed. After merging, manually run Historical Linux package upgrade and recovery checks on main, leaving reviewed_adoption and application_checks true. The extended hosted job has not yet run; the earlier successful database-only job is not presented as full application acceptance.

This ZIP contains no fixture archive, private capture/credentials, SQL export, application binary/package, backup archive, native library, generated lockfile, runtime tree or private log. No SQL migration, generated schema, .gitattributes, canonical runner/Desktop policy, dependency-lock or tracked product version property is changed.

## Every added or modified file

- `.github/workflows/ci.yml`: Add Linux package policy checks to normal feature CI.
- `.github/workflows/historical-linux-preflight.yml`: Build/run actual ARM64 packages with QEMU; select full or database-only phases; retain bounded failure/recovery evidence.
- `CONTRIBUTING.md`: Document new commands, actual phase boundaries and existing published asset.
- `RELEASE_NOTES.md`: Record application/recovery tooling, photo regression fix and package failure handling.
- `docs/code-change-backlog.md`: Update R05/R07 scope and record R12/R13 findings, fixes and remaining acceptance.
- `docs/documentation-map.md`: Register ownership for historical package/application/recovery evidence.
- `docs/historical-linux-upgrade.md`: Describe the complete isolated workflow and platform limits.
- `docs/index.md`: Link current package/action/recovery evidence.
- `docs/maintenance/c15-c19-photo-handling.md`: Record later empty-photo-batch regression and native evidence.
- `docs/maintenance/historical-linux-adoption.md`: Link completed database phase to new application/recovery evidence without rewriting historical results.
- `docs/maintenance/historical-linux-fixture-review.md`: Record owner publication of exact reviewed artifact and verified identity.
- `docs/photo-handling.md`: Clarify no-photo requests create no recovery journal; preserve genuine recovery rules.
- `docs/testing-evidence.md`: Distinguish new package/action/recovery testing from prior hosted database-only success.
- `docs/upgrade-checklist.md`: Update Windows/Linux deployment, package flags, photo regression and remaining acceptance actions.
- `scripts/package-linuxpi.ps1`: Add non-stamping unattended build/output/identity options, explicit native failure detection and guarded output handling.
- `src/OrchidApp.Web/Services/PhotoWriteBatch.cs`: Avoid journal I/O for empty tracking lists and no-photo commit/rollback; retain genuine recovery behavior.
- `tests/DevelopmentNative.Checks/PhotoRecoveryChecks.cs`: Five regressions for empty lists, no-photo outcomes and later successful photo commits.
- `tests/HistoricalUpgrade.Checks/README.md`: Prerequisites, complete package/runtime commands, modes and evidence boundaries.
- `tests/HistoricalUpgrade.Checks/checks.py`: Expand pure checks from 17 to 21 with package/path/resource and application-namespace guards.
- `tests/HistoricalUpgrade.Checks/preflight.py`: Integrate baseline/current/action/app-only/failed-DDL recovery phases and partial-output timeout diagnostics.
- `tests/HistoricalUpgrade.Checks/Runtime.Dockerfile`: Pinned ARM64 .NET 8.0.33 base and libvips42 8.14.1 runtime with real backup tools.
- `tests/HistoricalUpgrade.Checks/application_stage.py`: Validate packages/owned resources, orchestrate phases and real canonical failure/retry refusal, collect scoped reports and clean up.
- `tests/HistoricalUpgrade.Checks/container_driver.py`: Run web child as UID 1654, real paired capture/restore, state comparison, broken-app recovery and historical rollback.
- `tests/HistoricalUpgrade.Checks/http_support.py`: Loopback-only actual cookie/antiforgery/multipart HTTP forms and synthetic image checks using standard library.
- `tests/HistoricalUpgrade.Checks/plant_actions.py`: 17 post-upgrade plant-action checks, including quick actions/photo/note, moving, flowering, repotting and split/lineage.
- `tests/HistoricalUpgrade.Checks/package_contract.py`: Reject unsafe/missing/duplicate/special/resource-exceeding complete Linux ZIPs.
- `tests/HistoricalUpgrade.Checks/Packaging.Checks.ps1`: Three meaningful real-script checks for publish failure, existing output protection and unchanged version properties.
- `docs/maintenance/historical-linux-application-recovery.md`: Implementation, actual results, issue reproduction, failures and explicit limits.

## Actual validation

- Full local Linux ARM64 package/application/recovery run returned zero and passed all phases (28 October 2026, 20:45-20:56 UTC). Actual complete self-contained ARM64 ZIPs were built with distinct compiled informational identities from the same reviewed functional source/SQL.
- Verified frozen input: 1,073 files, 798 synthetic image hashes and original 245-row history; pre-upgrade actual paired snapshot plus matching old application/configuration/uploads recovery set verified. Input SHA-256 remains 7ffd16949ae07238f31447ad7d64e1444e898a00248b8e14757533bcbf00f3b5.
- Exact structural admission, archived original history, all four actual forward migrations and zero-work repeat passed. Pre-workflow application data remained SHA-256 6b8b8350197dc87b0a56cc145942ce162ef9596347cbb9dd4e7d49d4bb94cec6; final upgraded structure matched the unchanged reviewed contract.
- Current readiness/core pages/existing photo and all 17 HTTP action cases passed. Source monitoring flag was disabled and current build made no owner-energy queries. Full state survived restart.
- App-only distinct build passed readiness, unchanged database schema/history/data, uploads/settings before test writes, and save/reopen. Deliberately broken DLL failed startup; actual production paired restore recovered exact current snapshot/app/files/configuration and passed readiness/photo/save/reopen.
- Actual injected canonical SQL left partial DDL and a durable pending checksum; retry was rejected. Original historical app/data/files/settings/schema/history were recovered through production paired restore, followed by working save/reopen. No pending marker was deleted to retry. Both owned containers/volumes were removed.
- Real C17 backup read locks and actual rclone crypt upload/read-back ran over isolated local storage. ARM64 .NET 8.0.33 and libvips42 8.14.1 used; backup client 10.11.19 and database server 10.11.14 are recorded separately.
- 21 pure checks and three real-script packaging policy checks passed. Windows native checks passed 611 metadata/orientation/colour and 37 recovery assertions, including five new regressions. NuGet vulnerability metadata was unavailable (NU1900); no complete vulnerability audit is claimed.
- Python compilation, workflow actionlint (optional shellcheck/pyflakes disabled) and 285 local documentation links passed. ZIP member inventory and source bytes verified.

## Issues corrected and failed attempts retained

CHAT-R12: the pre-fix current ARM64 build created an empty false recovery journal after no-photo save and then blocked a real photo. Empty batches now avoid journal I/O; true failed/uncertain photo recovery remains unchanged. No existing journal is automatically removed and no new setting/migration is introduced.

CHAT-R13: Linux packaging prompted/stamped source and ignored native publishing failure. Optional unattended non-stamping builds and protected explicit outputs now support CI; failed publish stops before ZIP creation. Existing normal release stamping remains.

Other nonpassing local attempts exposed Docker overlay directory staging behavior (corrected in the harness), plus one unexplained canonical command timeout. They were not counted as successful application acceptance. Partial timeout output/process-state diagnostics are now retained; the final fresh full run passed without relaxing checks.

## Limits

All destructive replacement/recovery is inside new owned disposable containers with no host bind mounts, published ports or external runtime network. No live Pi/collection is touched. The application is actual ARM64 under emulation; MariaDB runs amd64. A PID-derived fixture service-state adapter is used instead of real systemd. The encrypted backend is real rclone crypt over private local storage, not a cloud provider. HTTP forms do not execute browser JavaScript or certify mobile/visual behavior. Windows specimen/installer, real Pi service/account/permissions/provider and general live adoption acceptance remain separate. A failed fixture is discarded/restored rather than force-retried.

Authoritative source/test, photo, historical upgrade, checklist, backlog, contributor/release/index/ownership documentation is updated. Existing Word user flows did not change, so no Word edits/rendering were needed. See docs/maintenance/historical-linux-application-recovery.md for full evidence and tests/HistoricalUpgrade.Checks/README.md for commands.
