# Historical Linux package upgrade and recovery checks

These checks use the exact published frozen sanitised specimen. Database-only mode runs pinned Linux amd64 MariaDB 10.11.14. The explicit application mode executes real self-contained Linux ARM64 packages under Docker/QEMU, plant actions, app-only replacement and production paired backup/restore. Real Pi/systemd/provider/browser and Windows installed acceptance remain separate.

## Commands

Requirements: Python 3.9+, .NET SDK targeting net8.0, PowerShell 7+, and Docker running Linux containers. Run from the repository root:

```powershell
python tests/HistoricalUpgrade.Checks/checks.py
python tests/HistoricalUpgrade.Checks/preflight.py --specimen "C:/private-fixtures/OrchidApp-Pi-specimen-1.3.0-080ba9c-review.tar.gz"
python tests/HistoricalUpgrade.Checks/preflight.py --specimen "C:/private-fixtures/OrchidApp-Pi-specimen-1.3.0-080ba9c-review.tar.gz" --adopt-and-migrate
```

Replace the example specimen path. The private capture is never accepted. The default command reproduces the original canonical checksum refusal and returns nonzero. The explicit adoption command verifies the exact reviewed starting structure, preserves history and tests actual database migration. Neither command accepts a live endpoint or loads a development `.env`.

Database commands verify the outer size/hash, safe archive member set, inner checksums, synthetic-photo inventory, historical ledger digest and table counts. Only SQL is extracted in database-only mode; application mode additionally stages the verified old app and uploads. The new labelled database has network none, no published ports and no host bind mounts. A native ClientProxy transports the unchanged canonical runner commands into that identity-verified fixture. The operational runner, C# policy and migration SQL are unchanged.

## Reviewed adoption mode

`legacy-adoption.json` pins the reviewed historical schema metadata, provenance, baseline cut-off, original history and expected forward inventory. `schema_contract.py` checks all object sets, definitions, columns, indexes, constraints, security context, partitions and events. It accepts no blanket whitespace, index-name, definer or collation normalisation. Known historical differences were independently compared and documented in [adoption evidence](../../docs/maintenance/historical-linux-adoption.md).

The command first proves an extra unreviewed view is rejected without changing history, removes its own probe, and verifies the exact starting structure again. `legacy_adoption.py` stages a replacement ledger and uses one atomic RENAME TABLE to retain the original table as `schemaversion_legacy_pi_130` while making a contract-identified `baseline:v1:202606041820` active. All 245 old IDs, names, checksums and timestamps survive, including the local test entry. No DELETE/UPDATE of old ledger rows or replay of old migrations occurs. The original frozen archive remains unchanged.

The real canonical runner must then plan/apply the four expected current migrations, and a second apply must do nothing. The resulting schema is checked against the reviewed exact post-upgrade identity; all 23 application-table data-only dump bytes must match before/after, all counts must match, the archived ledger must match its original digest and the active ledger must contain the baseline plus the exact four current raw checksums. A mismatch fails the check.

This is fixture-only acceptance, not a general live adoption/repair command. It has no retry/force/bypass option. An interrupted/failed fixture is discarded and restored again; there is no claim of DDL rollback. A production adoption utility would additionally require an offline application, verified recovery set, target/account/collation mapping, pending-state handling and separate acceptance.

## Complete application/recovery command

First build two actual packages without changing tracked version properties (PowerShell, repository root):

```powershell
pwsh ./tests/HistoricalUpgrade.Checks/Packaging.Checks.ps1
pwsh ./scripts/package-linuxpi.ps1 -NoVersionStamp -OutputRoot "$PWD/artifacts/historical-upgrade/package-a" -InformationalVersionOverride 1.3.0+ci-upgrade-a
pwsh ./scripts/package-linuxpi.ps1 -NoVersionStamp -OutputRoot "$PWD/artifacts/historical-upgrade/package-b" -InformationalVersionOverride 1.3.0+ci-app-only-b
docker build --platform linux/arm64 -f tests/HistoricalUpgrade.Checks/Runtime.Dockerfile -t orchidapp-historical-acceptance:local tests/HistoricalUpgrade.Checks
python tests/HistoricalUpgrade.Checks/preflight.py --specimen "C:/private-fixtures/OrchidApp-Pi-specimen-1.3.0-080ba9c-review.tar.gz" --adopt-and-migrate --application-checks --package-a "$PWD/artifacts/historical-upgrade/package-a/OrchidApp-v1.3.0-RaspberryPi-Linux-arm64.zip" --package-b "$PWD/artifacts/historical-upgrade/package-b/OrchidApp-v1.3.0-RaspberryPi-Linux-arm64.zip" --runtime-image orchidapp-historical-acceptance:local
```

Explicit package output directories must be new/absent. Adjust ZIP filenames if the repository product version changes. Docker needs ARM64 execution support; GitHub configures QEMU automatically. Runtime construction requires registry/Debian access; the actual fixtures have no external network or host bind mounts. Package builds use the current reviewed source with distinct compiled test identities and identical SQL. They do not create a product release or modify Directory.Build.props.

The in-container driver runs the web process as UID 1654, verifies real HTTP forms/readiness, and uses the actual packaged Linux paired-backup/restore tool with held read locks and a real rclone crypt backend over isolated local storage. A fixture-only service-state adapter checks the actual child PID; real systemd/cloud are not simulated as passed. Recovery deliberately resets only the newly owned disposable database after verified snapshots, restores matching app/data/files/configuration and proves save/reopen. Injected SQL creates a real partial-DDL witness and pending marker; retry must fail before restoring the old compatible recovery set. No live target/credential parameters, force-retry or pending-marker deletion exists.

## Evidence and CI

Output defaults to ignored `artifacts/historical-upgrade/<time>-<id>/`. Reports identify database/application/app-only/recovery phases separately. A database-only success retains applicationExecuted=false and fullUpgradeAcceptance=not performed. Application mode records its bounded container acceptance and remaining platform limits. Original read-only failure is retained as evidence before reviewed admission.

Normal feature CI runs 23 pure checks and three packaging policy checks. The manual **Historical Linux package upgrade and recovery checks** workflow downloads the already published fixture release and defaults to both reviewed adoption and application checks. To run database-only, disable application checks. To reproduce original refusal, disable both. An incompatible selection, missing/wrong package, missing release asset, failed phase or cleanup fails the workflow.

CI retains explicit reports and selected logs, including application/action summaries and the injected failure/retry logs. It excludes staged SQL, app/package binaries, configuration, backup archives, encryption keys, raw metadata snapshots, private command/app logs and source runtime trees. Local diagnostics may include synthetic records; keep them separate from delivery. Only identity/label/network/mount-verified owned containers/volumes are removed. Forced termination can require checking recorded owned resources.

See [scope and results](../../docs/historical-linux-upgrade.md), [package/application/recovery evidence](../../docs/maintenance/historical-linux-application-recovery.md), [fixture review](../../docs/maintenance/historical-linux-fixture-review.md), [historical investigation](../../docs/maintenance/historical-ledger-compatibility.md) and [reviewed database adoption](../../docs/maintenance/historical-linux-adoption.md).
