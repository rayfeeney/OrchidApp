# Activity 05 — Existing tests and specimen review

Review source: `34155de67f9634e70c389e81f518d0044fafc3b8`. The checkout was clean on main throughout the read-only review. The review covers the fixed T01–T16 scope in the [programme](automated-testing-mariadb118-plan.md).

## Existing checks and evidence

The [testing inventory](../testing-evidence.md) and [contribution guide](../../CONTRIBUTING.md) own current commands and prerequisites. The source inventory covered 107 tracked test paths in 17 directories and both workflow files. Reuse the .NET 8/Python feature runner, separate disposable greenhouse SQL mode, schema and migration runners, lifecycle SQL/HTTP checks, native photo checks, Windows backup and Inno fixtures, and Linux paired backup, historical and standby checks. PhotoDeletion.Checks is tracked and runs in Linux and Windows jobs despite its omission from the central inventory. Existing HTTP checks cover real writes and save/reopen. No Playwright or Selenium references were found within tests, scripts and workflow paths.

[OrchidApp CI](../../.github/workflows/ci.yml) runs on main pushes, pull requests and manual dispatch. All eight jobs passed at the review commit in [45707626790](https://github.com/rayfeeney/OrchidApp/actions/runs/45707626790). Its feature, greenhouse and installer evidence artifacts were listed as available at review, expiring 23 February 2027 at 21:48 UTC. Other standard jobs provide job logs. The [manual historical workflow](../../.github/workflows/historical-linux-preflight.yml) retains selected diagnostic reports. [40756892655](https://github.com/rayfeeney/OrchidApp/actions/runs/40756892655) passed database-only acceptance. [40777537302](https://github.com/rayfeeney/OrchidApp/actions/runs/40777537302) passed the full historical exercise, and [40780100240](https://github.com/rayfeeney/OrchidApp/actions/runs/40780100240) passed normal CI on an identical Git tree. Historical failures 40773954965 and 40775272083 also retained diagnostics. The three Pi-related CI runs cited in the inventory passed. Hosted conclusions and artifact listings were verified. Archive payloads were not inspected in that review. Installed Pi acceptance has separate [records](../current-state.md).

## Specimens and release inputs

| Input | Bytes | SHA-256 |
| --- | ---: | --- |
| OrchidApp-v1.4.0-Sanitised-Specimen.zip | 10,065,174 | `18a10fb72501cf412c3bc8a599dbc693069497665b59c00945f3740a11375786` |
| OrchidApp-Pi-specimen-1.3.0-080ba9c-review.tar.gz | 94,612,484 | `7ffd16949ae07238f31447ad7d64e1444e898a00248b8e14757533bcbf00f3b5` |
| OrchidAppSetup-1.4.1.exe | 149,514,313 | `4b116a69c37ef214215efd3fe5655cfece02f5e6d026346f9ab45ddd1ebdba4e` |
| OrchidApp-v1.4.1-RaspberryPi-Linux-arm64.zip | 75,676,945 | `c1524ee5cb2985972565d00d6bfa834a140cd0e06ae6b425dcf183a4548aac19` |
| OrchidAppSetup-1.4.1.exe.evidence.json | 422 | `407f06a272bd0470fe1507a47c9eec15a813c9c5fb25ebaa554eca5912aa6a05` |

The local Windows specimen hash and ZIP inventory matched the [v1.4.0 release](https://github.com/rayfeeney/OrchidApp/releases/tag/v1.4.0) and [historical restore record](Windows-v1.4.0-Baseline-Acceptance.md). It contains SQL, schema version, launcher settings and 20 JPEGs including thumbnails. Offline restore and restart passed historically. Launcher restore failed before SQL import in that exercise. Record-level expectations remain to be established.

The [published Linux fixture](https://github.com/rayfeeney/OrchidApp/releases/tag/ci-fixture-linux-arm64-1.3.0-080ba9c-v1) matches the [tracked manifest](../../tests/HistoricalUpgrade.Checks/fixture.json). Its captured ARM64 binary reports v1.3.0. The observed source checkout was `080ba9c377fc22b781640272d7d32ecc3ae46a42`, and exact binary provenance remains unverified. The fixture includes 798 synthetic images, 1,073 inventoried files, 149 plants, 125 taxa and 245 ledger entries. Four inactive photo references are expected to be missing. Use the [historical harness](../../tests/HistoricalUpgrade.Checks/README.md) for this format, and the [paired restore runbook](../user-guides/linux/OrchidApp-MariaDB-Backup-and-Restore-Runbook.md) for routine paired snapshots. Preserve both original specimens and use working copies in isolated targets.

The [latest stable release at review](https://github.com/rayfeeney/OrchidApp/releases/tag/v1.4.1) points to `5dc488812872b60e8655a67b5ef4676347b5e47a`. Its asset IDs are 725204309 (Windows), 725210494 (Linux) and 725208674 (sidecar). The published sidecar reports NotSigned and installed acceptance pending. Local v1.4.1 files under dist have different hashes. The tagged source declares version 1.4.0 and pins Windows MariaDB 10.11.16. Confirm the embedded product and database versions from the published installer. Obtain and retain checksum-verified published copies for baseline use. Linux baseline is Debian 12.15/MariaDB 10.11.19 and target is Debian 13.8/MariaDB 11.8.9. Record x64, emulated ARM64 and physical Pi evidence separately.

## Acceptance criteria and allocation

Activity 06 owns shared Playwright cases and reusable readiness, record and photo assertions. Activity 07 owns PowerShell and Windows Sandbox package/launcher orchestration. Activity 08 owns Debian deployment and Linux services. Both platform activities invoke the shared assertions through the installed application. Reuse existing fixtures where they provide the required evidence.

| Ref | Activity | Existing evidence and baseline pass condition |
| --- | --- | --- |
| T01 | 07, 08 | Installer fixtures and historical Linux packages exist. Verify published hashes, install/deploy through supported paths, record actual versions and confirm general installation works with monitoring disabled. |
| T02 | 06, 07, 08 | Reuse configuration and HTTP readiness checks. Start through the launcher or service, load the home page and require healthy database, upload and native photo readiness. A controlled missing prerequisite prevents readiness. |
| T03 | 07, 08 | Reuse schema-contract checks. Provision from schema and seeds without historical replay, verify baseline metadata and read/write a record. |
| T04 | 07, 08 | Reuse packaged migration policy and disposable DDL fixtures. Verify expected migrations and checksums, preserved data, no work on second run and retry refusal for incomplete DDL. |
| T05 | 07, 08 | Use exact verified specimens and applicable restore paths. Compare records, photos and settings, including Linux's documented inactive exceptions. Verify readiness and reopen after restart. |
| T06 | 06, 07, 08 | Reuse feature and SQL/HTTP assertions. Add shared Playwright search/navigation, plant create/edit/save/reopen, representative lifecycle action and invalid-input correction with unchanged saved state on rejection. |
| T07 | 06, 07, 08 | Reuse native and photo recovery assertions. Upload a representative large JPEG and HEIC through both packages, verify originals and thumbnails render and persist on reopen. |
| T08 | 07, 08 | Reuse Windows backup and Linux paired backup checks. Create from the installed launcher or Linux path. Verify manifest, entry hashes, SQL, active photos and applicable settings, and copy/read-back where exercised. |
| T09 | 07, 08 | Reuse interrupted replacement and historical recovery fixtures. Round-trip T08 to a separate disposable target. Verify records, media, settings, readiness and save/reopen after restart. |
| T10 | 06, 07, 08 | Reuse historical process and state assertions. Stop via launcher or systemd, confirm owned processes and listeners stop per contract, restart and reopen the same persisted record and photo. |
| T11 | 07 | Exercise published launcher Open, Close, Backup and Restore. Verify owned endpoint, managed-database backup, outcome and retained recovery input. Exercise OneDrive input where an isolated provider fixture is available. |
| T12 | 07 | Reuse Inno preservation assertions. Published uninstall removes managed application files and preserves database, uploads, settings and protected backups. |
| T13 | 08 | Extend historical process coverage to real systemd. Verify unit registration, service identity, start, stop, restart and readiness. |
| T14 | 08 | Extend downstream SQL and service wiring evidence. In an opt-in fixture, run the importer with controlled input, verify stored rows, result and timer wiring, and verify documented duplicate handling on repeat. |
| T15 | 08 | Reuse nightly, coordinator and native standby checks. Verify scheduled publication and recoverability, readiness/integrity before acceptance, repeat selection and preservation of the last accepted generation on candidate failure. |
| T16 | 07, 08 | Reuse Windows installer and historical Linux upgrade/recovery fixtures. Verify agreed application upgrade artifacts, recoverable backup, migrations, versions, records, media, settings, restart and bounded recovery. The actual 10.11-to-11.8 engine upgrade belongs to Activity 12 after Gate 1. |

Record artifact and specimen identities, commands, environments, runtime versions, expected and actual results, logs and limitations for Activity 09. Earlier CI, historical and installed evidence remains applicable within its stated scope. The current Windows and Linux programme baselines and Gate 1 approval remain pending.
