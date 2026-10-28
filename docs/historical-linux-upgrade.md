# Historical Linux upgrade acceptance

The published immutable specimen and merged database checks now have an extended package/application/recovery harness. Local validation status is recorded in [application/recovery evidence](maintenance/historical-linux-application-recovery.md); merging/running the extended hosted workflow remains separate from the already successful [database-only run](https://github.com/rayfeeney/OrchidApp/actions/runs/40756892655).

## Input and platforms

Asset: `OrchidApp-Pi-specimen-1.3.0-080ba9c-review.tar.gz`, SHA-256 `7ffd16949ae07238f31447ad7d64e1444e898a00248b8e14757533bcbf00f3b5`, published by the owner under `ci-fixture-linux-arm64-1.3.0-080ba9c-v1`. Its observed checkout and 1.3.0 application metadata remain separately identified; exact binary source revision is unproven. No private capture or original photo pixels are used.

The actual schema/history/data are restored, not rebuilt from historical migration replay. The database is pinned Linux amd64 MariaDB 10.11.14; the actual historical and new application binaries run as Linux ARM64 under emulation. The runtime pins .NET 8.0.33 and libvips42 8.14.1-3+deb12u3, recording built image/native tool/package identities. Other Debian dependencies are recorded, not a claim of bit-for-bit Pi OS replication.

## Checks

[Commands and prerequisites](../tests/HistoricalUpgrade.Checks/README.md) cover three modes: original read-only refusal; verified database adoption/migration; or complete isolated package/application/recovery. Normal feature CI runs 23 pure verification/ownership/package checks plus three package policy checks. Heavy acceptance remains manually dispatched, using the published fixed release asset. Missing/unreviewed inputs and incomplete phases fail.

The database phase admits only the exact independently reviewed schema/history, preserves all original records in an audit table, establishes the verified historical cut-off and runs the four real forward migrations with no work on a second apply. All pre-workflow application data and exact final schema are checked. The unmodified runner/Desktop policy and raw-byte checks remain intact; see [adoption evidence](maintenance/historical-linux-adoption.md) and [original provenance investigation](maintenance/historical-ledger-compatibility.md).

The application phase builds actual complete Linux ZIPs through the maintained package script, verifies a running historical baseline and consistent recovery set, deploys the current package, checks core pages/readiness/photo bytes and 17 real HTTP form scenarios. These include observation quick actions, note/photo, movement, flowering, repotting, selected validation messages and two-child split/lineage. It verifies restart persistence and a distinct compiled app-only build without SQL/data/files/configuration changes before intentional test writes.

Recovery uses the actual Linux paired-backup/restore implementation, actual read lock and actual rclone crypt read-back over private local storage. It saves matching application trees separately. A broken app-only package must fail startup, then recover a matching current app/data/files/configuration set. A real failing canonical migration must leave partial DDL and a durable marker that blocks retry, then recover the compatible original historical set with working save/reopen. No marker is deleted to force retry. See [full evidence and limits](maintenance/historical-linux-application-recovery.md).

## Findings and boundaries

The pre-fix current package exposed CHAT-R12: a non-photo save could create a false recovery journal and block a later photo. Empty photo batches now perform no journal I/O; five native regressions and the ARM64 photo/action case cover it, preserving genuine recovery safeguards. CHAT-R13 adds a non-stamping unattended packaging path, explicit publish failure detection and existing-output protection. No new database migration, production setting or normal startup change is introduced.

All writes/replacement/destructive recovery target newly owned, labelled containers sharing a network-none namespace, with no host binds/published ports. The driver additionally requires the matching fixture ownership context. The frozen archive stays unchanged. Bounded reports/logs are retained; raw backups, staged SQL/settings/binaries/private logs are excluded from CI uploads and changes ZIPs.

The service-state adapter tracks the actual web child process; real systemd/cron/importer/account/permissions, provider credentials and Pi hardware are not certified. Direct HTTP submissions do not execute browser JavaScript or replace mobile/visual acceptance. Windows needs its own reviewed specimen and installer scenarios. A production adoption utility remains separate from this exact fixture admission. C05 fresh-current-schema creation remains a different check.

Use the existing [upgrade checklist](upgrade-checklist.md), [photo recovery/readiness contract](photo-handling.md) and [technical specimen review](maintenance/historical-linux-fixture-review.md). The Linux user installation/publish and recovery procedures remain the deployment owner; the harness is not a new general production updater.
