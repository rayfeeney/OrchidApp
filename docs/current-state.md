# Current state and fixed v1.4.0 work list

Last reconciled: 7 November 2026. This is the owner-agreed bounded work list, not evidence that pending tasks passed.

## Confirmed baseline

Verified 30 October 2026: source baseline `283eb06c9bcb3a9d8fc220b9d21e4c6fe7daecac`; [normal CI 40780100240 passed](https://github.com/rayfeeney/OrchidApp/actions/runs/40780100240). [Full historical Linux acceptance 40777537302 passed](https://github.com/rayfeeney/OrchidApp/actions/runs/40777537302) on PR head `0f5a3b825a52dc104b4d245f36c5e899356d7b34`, whose Git tree is identical to the merged baseline (`7cb0497de9716c141f2472c09ea81d15a5e141af`). This is isolated package/application/recovery evidence, not live Pi/systemd/provider/browser or Windows installed acceptance.

The owner designates this source baseline for the planned v1.4.0 release; that is a release plan, not a claim that v1.4.0 packages have been built or published. The checkout was clean and matched origin/main at verification. Source-baseline confirmation is closed. No product version is changed by this documentation delivery.

## Subsequent security maintenance

MySqlConnector GHSA-473q-m89c-ghf8: launcher 2.5.0 and Web transitive 2.4.0 updated in source to 2.6.1. Local build, configuration/policy checks, dependency audit and all 186 isolated SQL/HTTP tests passed. GitHub CI and rebuilt installed release acceptance remain pending. See [security update evidence and adoption](maintenance/mysqlconnector-security.md). This is new maintenance after closure of C01–C20.

## Windows .NET 8 startup maintenance

An installed Windows build reset browser requests when EF Core tried to load DiagnosticSource 9. The web project targeted .NET 8, but Pomelo 9 resolved EF Core 9 and its logging dependencies. The package also published the launcher over the web app in a shared directory, where the launcher could replace shared runtime files. The installer copies that directory, including DLLs.

The candidate uses Pomelo 8.0.3, EF Core 8.0.33 and the existing patched MySqlConnector 2.6.1. The Windows build publishes the launcher first, skips its development content bundles and checks the final DiagnosticSource assembly. Package database cleanup uses a unique local named pipe with TCP disabled to isolate the staged copy from installed MariaDB. The repo selects SDK 8, checks project frameworks at build time and verifies the web lockfile in CI.

Local checks passed for locked restore, Release build, Linux ARM64 publish, Windows package inventory, unsigned Inno installer compilation and isolated application, migration-policy, installer-policy and native photo suites. The Windows package contains DiagnosticSource assembly version 8.0.0.0. Hosted CI and release-machine acceptance are pending. Record Windows clean install and v1.4.0 upgrade readiness, database and photo preservation, photo upload/reopen and restart on disposable fixtures. Confirm the Linux ARM64 build and readiness separately. See the [upgrade checklist](upgrade-checklist.md).

## Fixed work list

1. **Procure the new Pi.** Complete. Raspberry Pi 2 has been received and is available for the planned recovery, upgrade rehearsal and standby implementation. Installation and recovery acceptance remain covered by subsequent work-list items.
2. **Complete developer setup on the new PC.** Complete - 7 November 2026 reconciliation. New-PC development environment established and verified. Developer setup acceptance completed, closing the remaining C16 new-PC acceptance requirement.
3. **Reconcile status documents.** Complete. C05/C16 status, superseded pending statements and agreed scope decisions reconciled. Historical acceptance evidence preserved. Documentation changes applied and merged into `main`.
4. **Record the live Pi baseline.** Complete - 7 November 2026. Read-only evidence collected for hardware, operating system, software versions, published application, database schema and migration history, configuration structure, services, scheduled jobs, backup arrangements and file locations. See [Live Raspberry Pi Baseline](live-pi-baseline-2026-11-07.md). The deliberately absent test migration is an accepted exception. Exact binary provenance remains unverified. Remote backup objects were confirmed present, but backup integrity and restoration are reserved for item 5.
5. **Create a complete recovery backup of the live Pi.** Complete — 7 November 2026. Captured matching MariaDB database, photographs, deployed application binaries, configuration, service definitions and scheduled jobs while application writers were stopped. Original services were restored successfully. Archive integrity and local SHA-256 checks passed. All five recovery files (605.054 MiB) were uploaded to encrypted OneDrive storage at `orchidcrypt:recovery-2026-11-07`. Independent download-based verification confirmed five matching files and zero differences. Recovery functionality will be tested on Pi 2 under item 6.
6. **Restore onto the empty new Pi. — COMPLETE (7 November 2026).** Restored and verified the original OrchidApp application, database and photographs on Pi 2. Confirmed application functionality, existing data, photographs and services. Automatic startup, scheduled backups and environmental data imports are disabled; no external writers are active. Pi 1 remains live and unchanged.
7. **Rehearse the restored Pi upgrade to v1.4.0.** Build the actual release package from the agreed baseline; record commit/checksum, resolve compatibility, verify functionality and data/photo preservation, and retain the proven procedure/results.
8. **Upgrade the live Pi.** Take a fresh recovery backup, follow the proven procedure and verify the result.
9. **Implement daily cloud-backup restoration to the second Pi.** Matching data/photos/configuration and compatible software; readiness/photo/disposable add-save-reopen checks; retain the last working recovery state on failure. Standby test writes must never reach live data or cloud backups. Verify that historical database backups cannot be paired silently with incompatible or missing photographs. Recovery must preserve the last known working state and report incomplete or inconsistent backup pairs.
10. **Monitor freshness and send failure alerts through GMX.** Confirm new scheduled backup/upload and restoration of that exact backup. Agree recipient and maximum age; report failed/overdue stages and last successful recovery point; test sending. Outgoing GMX configuration remains to be validated. Decide whether independent monitoring is needed when both Pis are offline.
11. **Complete operational acceptance.** Reboot/autostart, service/file permissions, usual browsers/devices and photo upload; Home Screen/installed web-app behavior where used; monitoring feeds/charts and scheduled backups during takeover. Include representative plant lifecycle and history operations, transaction-failure and concurrency checks where appropriate, and photo metadata, orientation and consistency checks. Use existing automated evidence where sufficient; reserve installed-system testing for behaviour that requires it.
12. **Document and rehearse takeover.** Isolate the former live Pi, switch access, enable required jobs and ensure only one Pi is live. Repair the former live Pi and establish it as the new warm standby; no automatic switch-back.
13. **Establish the v1.4.0 Windows baseline.** Complete. Clean installation and independent offline restore passed, including the restart check. The sanitised Windows v1.4.0 specimen was established for future upgrade and recovery testing. Launcher backup/restore defects remain open. WIN-PHOTO-02 has a development candidate with Windows native checks; hosted Linux, installed Windows/Pi, and real phone acceptance remain pending. See [mobile photo evidence](maintenance/win-photo-02.md). Earlier Windows upgrade paths remain outside scope.

## Scope and accepted records

- Earlier Windows-to-v1.4.0 upgrades, including older legacy migration acceptance, are outside the agreed release scope. They are not recorded as passed. Future Windows CI upgrades start with the preserved v1.4.0 specimen.
- CHAT-R08: future capture free-space protection is deferred optional tooling. The original disk-full incident is resolved; no immediate recapture is required.
- CHAT-R09: clearer future build/source identity reporting is deferred. The frozen historical binary source remains unproven; preserve its exact bytes/checksums rather than invent provenance.
- CI action/runtime and runner-image notices are deferred routine maintenance; successful CI establishes no immediate failure.
- CHAT-D01: four absent photo references on inactive historical specimen records are accepted known data; no missing active reference was found. This is not a live-data repair instruction.
- The exact fixture adoption helper does not authorise a live Pi upgrade. Tasks 4–7 must establish compatibility and a supported procedure for the actual installation.

## Evidence and closure

Keep original maintenance reports and historical snapshots. Their counts, failures and delivery-stage pending statements remain historical; this dated reconciliation records later results without changing them. A new release must retain its exact package identities/signing status and completed per-machine [upgrade record](upgrade-checklist.md#per-upgrade-completion-record). Mark excluded cases inapplicable with a reason, not passed. When completing a task, record actual outcome and remaining limits; this list does not certify future upgrades or ongoing daily operations.
