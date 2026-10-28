# Historical Linux database checks

These checks use the exact frozen sanitised ARM64 specimen. Database tests run on pinned Linux amd64 MariaDB 10.11.14; they do not execute the ARM64 application or certify a packaged upgrade/recovery.

## Commands

Requirements: Python 3.9+, .NET SDK targeting net8.0, PowerShell 7+, and Docker running Linux containers. Run from the repository root:

```powershell
python tests/HistoricalUpgrade.Checks/checks.py
python tests/HistoricalUpgrade.Checks/preflight.py --specimen "C:/private-fixtures/OrchidApp-Pi-specimen-1.3.0-080ba9c-review.tar.gz"
python tests/HistoricalUpgrade.Checks/preflight.py --specimen "C:/private-fixtures/OrchidApp-Pi-specimen-1.3.0-080ba9c-review.tar.gz" --adopt-and-migrate
```

Replace the example specimen path. The private capture is never accepted. The default command reproduces the original canonical checksum refusal and returns nonzero. The explicit adoption command verifies the exact reviewed starting structure, preserves history and tests actual database migration. Neither command accepts a live endpoint or loads a development `.env`.

Both commands verify the outer size/hash, safe archive member set, inner checksums, synthetic-photo inventory, historical ledger digest and table counts. Only SQL is extracted. The new labelled database has network none, no published ports and no host bind mounts. A native ClientProxy transports the unchanged canonical runner commands into that identity-verified fixture. The operational runner, C# policy and migration SQL are unchanged.

## Reviewed adoption mode

`legacy-adoption.json` pins the reviewed historical schema metadata, provenance, baseline cut-off, original history and expected forward inventory. `schema_contract.py` checks all object sets, definitions, columns, indexes, constraints, security context, partitions and events. It accepts no blanket whitespace, index-name, definer or collation normalisation. Known historical differences were independently compared and documented in [adoption evidence](../../docs/maintenance/historical-linux-adoption.md).

The command first proves an extra unreviewed view is rejected without changing history, removes its own probe, and verifies the exact starting structure again. `legacy_adoption.py` stages a replacement ledger and uses one atomic RENAME TABLE to retain the original table as `schemaversion_legacy_pi_130` while making a contract-identified `baseline:v1:202606041820` active. All 245 old IDs, names, checksums and timestamps survive, including the local test entry. No DELETE/UPDATE of old ledger rows or replay of old migrations occurs. The original frozen archive remains unchanged.

The real canonical runner must then plan/apply the four expected current migrations, and a second apply must do nothing. The resulting schema is checked against the reviewed exact post-upgrade identity; all 23 application-table data-only dump bytes must match before/after, all counts must match, the archived ledger must match its original digest and the active ledger must contain the baseline plus the exact four current raw checksums. A mismatch fails the check.

This is fixture-only acceptance, not a general live adoption/repair command. It has no retry/force/bypass option. An interrupted/failed fixture is discarded and restored again; there is no claim of DDL rollback. A production adoption utility would additionally require an offline application, verified recovery set, target/account/collation mapping, pending-state handling and separate acceptance.

## Evidence and CI

Output defaults to ignored `artifacts/historical-upgrade/<time>-<id>/`. `report.json` identifies the phase and actual results. The original read-only failure remains explicit even when later reviewed database adoption succeeds. `applicationExecuted=false` and `fullUpgradeAcceptance` stay explicit.

Reports/logs include ledger diagnostics, pre/post schema checks, original/adopted plans, first/second apply, proxy build and data hashes. Local stage SQL, binaries and full metadata snapshots are not uploaded. The tool removes only its ownership-verified container/volume; cleanup failures fail the result. Forced termination may leave owned local resources requiring inspection.

Normal feature CI runs the 17 pure unit checks without a fixture. The manual **Historical Linux database upgrade checks** workflow downloads the fixed sanitised release asset and defaults to reviewed adoption; disable `reviewed_adoption` to reproduce the original refusal. Missing/unpublished assets fail. No release asset has been published by this work and no remote CI run is claimed.

See [current scope and remaining C18 stages](../../docs/historical-linux-upgrade.md), [fixture review](../../docs/maintenance/historical-linux-fixture-review.md), [historical investigation](../../docs/maintenance/historical-ledger-compatibility.md) and [reviewed adoption](../../docs/maintenance/historical-linux-adoption.md).
