# C18 installer backup and acceptance evidence

> Status reconciliation, 30 October 2026: this article preserves the original implementation/test record. Its earlier next-step, merge and CI-pending statements describe that delivery stage. See [current status and scope](../current-state.md) for confirmed later CI, the remaining machine acceptance, and the v1.4.0 Windows baseline decision. Original results and limitations below are retained.

C18 now requires a new verified offline snapshot before an installer replaces existing application/persistent files, even when only application code changes and no SQL migration is pending. [Installer backup and recovery](../windows-installer-recovery.md) owns the format/procedure and [the upgrade checklist](../upgrade-checklist.md) owns Windows/Linux adoption actions.

## Implementation

The Inno `PrepareToInstall` event extracts the incoming trusted helper before payload copying. It refuses active/unclear OrchidApp/database processes, unreadable source paths, links/reparse points and unresolved migration/restore/photo-recovery records. It captures the selected old app and ProgramData roots with read handles that deny writes/deletion on each inventoried file, verifies every archive entry's length/SHA-256, repeats source-inventory/process/recovery checks and only then publishes a unique verified ZIP. Failure leaves a possible `.partial` file and stops before replacement. No database process is force-killed, no database is started by this helper, and there is no migration-dependent backup exemption. Even one existing file requires backup. A truly empty new install initializes no database or fake backup.

The snapshot includes prior app/runtime and raw stopped database/upload/settings/state bytes; existing top-level backup trees are excluded and stay in place. Local snapshots under `backups/pre-install` are not automatically pruned. These are not normal logical backup ZIPs and cannot be passed to Restore from backup. The new review tool validates without writing, or extracts only to an absent staging directory. It never overwrites active data or automatically rolls back a failed install/schema migration. ACLs/installer registration and supported runtime compatibility require operator review before activation.

The production AppId and administrator installation model stay in place. `CloseApplications=no` avoids forced shutdown; the operator keeps all writers stopped through installation. The helper is embedded separately from the old installed scripts, so an old app-only installation does not need to contain this new gate. Existing C06-C10/C19 migration/restore/readiness behavior remains separate.

Packaging requires all three new tools. Installer build rejects stale/missing packaged helpers and writes actual artifact SHA-256 and Authenticode status to `.evidence.json`. `-RequireValidSignature` enforces that requirement without signing the artifact. CI compiles the actual production package and retains its report; the repository itself has no signing key/configuration.

## Local validation completed

| Check | Result |
| --- | --- |
| Windows PowerShell 5.1 snapshot policy | 28 checks passed |
| PowerShell 7 snapshot policy | Same 28 checks passed |
| Actual Inno fixture installation | 22 checks passed: clean install, payload data exclusions, recovery-state/writer rejection, app-only upgrade, verified prior-state snapshot, non-overwriting extraction and uninstall preserving durable data/backups |
| Real MariaDB 10.11.16 snapshot recovery | 9 checks passed: running native database locks reject capture; stopped snapshot verifies; a new isolated recovered DB restores prior row/ledger and excludes simulated later partial DDL; matching photo/settings/app marker recover while failed-state evidence stays unchanged |
| Installer build and evidence | 5 checks passed using a temporary miniature package and the real compiler: artifact creation/hash/signature evidence, stale helper rejection and unsigned artifact refusal when valid signing is required |
| Word guides | Windows installation remains 12 pages and recovery remains 7 pages. All 19 pages inspected; a dangling data-location label was corrected and re-rendered. All 16 embedded media files remain byte-identical |

The local Inno compiler is the installed Inno Setup 7. All compiled fixture artifacts were inspected and reported `NotSigned`; they are not signed release artifacts. The production-identity miniature artifact was compiled only, not installed. The actual install/uninstall tests use a randomly generated unrelated per-user product identity, no shortcuts/post-install launch, and unique temporary app/persistent roots. They substitute only process enumeration so unrelated host database services are not touched. Controlled policy rows separately prove strict production rejection of unidentified databases, selected app processes and database command lines targeting the selected durable root. Real native sharing locks are exercised without substituting file/database operations.

The MariaDB fixture uses a generated database name, unused loopback port 53342 by default, explicit synthetic credentials and canonical schema-only creation. It identifies its data directory before shutdown and stops only its own process. It never loads the owner's `.env` or touches a development/collection database. Recovery is tested with the same supported runtime into a new target; this is not compatibility evidence for arbitrary older runtime versions.

Workflow validation, changed PowerShell parsing and current Markdown links are checked with delivery. No C18 migration or setting is introduced; all existing database SQL/checksums/bootstrap assets, C15/C19 application code and development helpers remain unchanged. No application build was needed for those unchanged paths. The build-evidence test uses the already-built Release launcher executable for version metadata and does not republish the application.

## Remaining release acceptance

Run the new CI job on the exact merged revision. Build the full release distribution, inspect the actual delivered artifact/signing status, and test the administrator installer/launcher on an isolated representative older installation. The separately planned historical-installation fixture remains required. Local miniature packages and synthetic version markers do not establish full app launch, Start Menu/UAC/system registration, physical power-loss behavior, low-disk recovery or real collection restoration.

Keep writers stopped from capture through completed installation. Per-file locks/process checks are not a hostile-writer or OS snapshot service and do not guarantee against an independently restarted writer after preflight exits. An offline capture of an unhealthy/crash-stopped database is evidence, not certification that it can recover. Preserve normal off-computer backups, previous trusted installer and failed-state evidence. Windows snapshot success does not certify Linux/Pi; Linux retains its existing stopped-writer paired-backup and prior app/configuration preservation contract for app-only upgrades too. C20 remains next.

Implementation uses Inno's documented [pre-install event](https://jrsoftware.org/ishelp/topic_scriptevents.htm) and [temporary-file extraction](https://jrsoftware.org/ishelp/topic_isxfunc_extracttemporaryfile.htm); local compilation and installer execution verify this integration.
