# Current state and fixed v1.4.0 work list

Last reconciled: 1 November 2026. This is the owner-agreed bounded work list, not evidence that pending tasks passed.

## Confirmed baseline

Verified 30 October 2026: source baseline `283eb06c9bcb3a9d8fc220b9d21e4c6fe7daecac`; [normal CI 40780100240 passed](https://github.com/rayfeeney/OrchidApp/actions/runs/40780100240). [Full historical Linux acceptance 40777537302 passed](https://github.com/rayfeeney/OrchidApp/actions/runs/40777537302) on PR head `0f5a3b825a52dc104b4d245f36c5e899356d7b34`, whose Git tree is identical to the merged baseline (`7cb0497de9716c141f2472c09ea81d15a5e141af`). This is isolated package/application/recovery evidence, not live Pi/systemd/provider/browser or Windows installed acceptance.

The owner designates this source baseline for the planned v1.4.0 release; that is a release plan, not a claim that v1.4.0 packages have been built or published. The checkout was clean and matched origin/main at verification. Source-baseline confirmation is closed. No product version is changed by this documentation delivery.

## C01–C20 status

All C01–C20 code changes are complete within the agreed scope; the [completed backlog](history/code-change-backlog.md) is archived as historical evidence. C05 is complete within its agreed current-schema seeded creation/future-migration CI scope. C16 is complete: implementation and Windows/Linux CI passed, and the owner accepted the clean Windows developer-PC setup on 1 November 2026. Remaining installed release and operational acceptance is tracked in the fixed work list below and the [upgrade checklist](upgrade-checklist.md). Source/CI success is not installed acceptance.

## Subsequent security maintenance

MySqlConnector GHSA-473q-m89c-ghf8: launcher 2.5.0 and Web transitive 2.4.0 updated in source to 2.6.1. Local build, configuration/policy checks, dependency audit and all 186 isolated SQL/HTTP tests passed. GitHub CI and rebuilt installed release acceptance remain pending. See [security update evidence and adoption](maintenance/mysqlconnector-security.md). This is new maintenance after closure of C01–C20.

## Fixed work list

Individual plant photo deletion: source implementation adds explicit confirmation/cancel, ownership and ended-plant checks, main-image replacement and database-first file cleanup with retained recovery evidence. No SQL migration/settings change. See [photo handling](photo-handling.md). Validation results are recorded in [deletion evidence](maintenance/plant-photo-deletion.md). Pending: hosted Windows/Linux CI, installed Windows/Pi/mobile browser acceptance, and corresponding updates/rendered review of the Windows 03/Linux 02 Word guides. Existing gallery screenshots remain useful but omit the new delete panel; do not treat them as complete deletion instructions.

1. **Procure the new Pi.**
2. **Complete — developer setup on the new PC (C16).** Owner accepted on 1 November 2026: schema-only database creation, source startup/basic database use, photo testing and libvips 8.18.2 native checks passed. The actual hook/schema export passed in a temporary Git fixture without changing the original index or schema. The setup guide is corrected; see [C16 closure evidence](maintenance/c16-developer-setup.md#closure-1-november-2026).
3. **Complete — reconcile status documents (1 November 2026).** C01–C20 code work is closed, including C05 and C16 within their agreed scopes. The backlog is archived with original evidence retained; current references point here for remaining release/operational work.
4. **Record the live Pi baseline.** Software versions, database schema/history, configuration, services, scheduled jobs and file locations.
5. **Create a complete recovery backup of the live Pi.** Matching database, photos, binaries, configuration and service definitions; verified off-device copy.
6. **Restore onto the empty new Pi.** Verify functionality/data/photos/services; disable standby scheduled jobs and external writers.
7. **Rehearse the restored Pi upgrade to v1.4.0.** Build the actual release package from the agreed baseline; record commit/checksum, resolve compatibility, verify functionality and data/photo preservation, and retain the proven procedure/results.
8. **Upgrade the live Pi.** Take a fresh recovery backup, follow the proven procedure and verify the result.
9. **Implement daily cloud-backup restoration to the second Pi.** Matching data/photos/configuration and compatible software; readiness/photo/disposable add-save-reopen checks; retain the last working recovery state on failure. Standby test writes must never reach live data or cloud backups.
10. **Monitor freshness and send failure alerts through GMX.** Confirm new scheduled backup/upload and restoration of that exact backup. Agree recipient and maximum age; report failed/overdue stages and last successful recovery point; test sending. Outgoing GMX configuration remains to be validated. Decide whether independent monitoring is needed when both Pis are offline.
11. **Complete operational acceptance.** Reboot/autostart, service/file permissions, usual browsers/devices and photo upload; Home Screen/installed web-app behavior where used; monitoring feeds/charts and scheduled backups during takeover.
12. **Document and rehearse takeover.** Isolate the former live Pi, switch access, enable required jobs and ensure only one Pi is live. Repair the former live Pi and establish it as the new warm standby; no automatic switch-back.
13. **Establish the v1.4.0 Windows baseline.** Actual installer on a clean PC; representative data, functionality/photos/restart/backup/recovery, and identify/retest the previously reported but unspecified Windows bugs. Record commit/checksum/signing status/results. Preserve a sanitised specimen, installer and records in GitHub for future upgrade/recovery CI. Earlier Windows upgrade paths are outside scope.

## Scope and accepted records

- Earlier Windows-to-v1.4.0 upgrades, including older legacy migration acceptance, are outside the agreed release scope. They are not recorded as passed. Future Windows CI upgrades start with the preserved v1.4.0 specimen.
- CHAT-R08: future capture free-space protection is deferred optional tooling. The original disk-full incident is resolved; no immediate recapture is required.
- CHAT-R09: clearer future build/source identity reporting is deferred. The frozen historical binary source remains unproven; preserve its exact bytes/checksums rather than invent provenance.
- CI action/runtime and runner-image notices are deferred routine maintenance; successful CI establishes no immediate failure.
- CHAT-D01: four absent photo references on inactive historical specimen records are accepted known data; no missing active reference was found. This is not a live-data repair instruction.
- The exact fixture adoption helper does not authorise a live Pi upgrade. Tasks 4–7 must establish compatibility and a supported procedure for the actual installation.

## Evidence and closure

Keep original maintenance reports and historical snapshots. Their counts, failures and delivery-stage pending statements remain historical; this dated reconciliation records later results without changing them. A new release must retain its exact package identities/signing status and completed per-machine [upgrade record](upgrade-checklist.md#per-upgrade-completion-record). Mark excluded cases inapplicable with a reason, not passed. When completing a task, record actual outcome and remaining limits; this list does not certify future upgrades or ongoing daily operations.
