# OrchidApp v1.4.0 upgrade runbook for Pi 1

This runbook records the Pi 2 rehearsal and the checks to repeat on Pi 1. Pi 1 still needs its own maintenance window, baseline, recovery evidence and migration account verification.

**Recovery gate.** Before any ledger or migration writes, prove that the stopped Pi 1 installation can be recovered from its own matching SQL and file backups. After any migration starts, recover the database and application as a set. Restoring the previous publish directory alone cannot undo database changes.

## 1. Identify the target and stage the release

- Record Pi 1's hostname, service unit, service user, working directory, active environment, upload root, MariaDB version and local listener. Confirm the server identity over the local socket. Keep credentials out of command history and logs.
- Verify the Raspberry Pi ARM64 ZIP against the checksum published for the chosen release. For the exact v1.4.0 ZIP used on Pi 2, the published SHA-256 was `c26eb89f642fece83ff69d09901dd967e7abcae90aba88d509d48f98cbcadae0`.
- Extract the release's `OrchidApp/database/` and `OrchidApp/app/` into a fresh staging directory. Confirm that PowerShell and the MariaDB client are available. Confirm the migration account can authenticate over the intended loopback TCP connection and can read the ledger. Check its privileges against the migration SQL before the write window.

## 2. Stop writers and prove recovery

1. Stop OrchidApp and confirm systemd reports the unit loaded and inactive. Exclude timers, migration jobs, other operators and database writers until verification is complete. A point-in-time session check cannot prevent a later connection.
2. Capture and hash a consistent Pi 1 recovery set. Include the database and its routines, triggers and events, the installed application, the service unit and any drop-ins, protected configuration and the effective upload root including any photo recovery records. Confirm archive members cover these paths and compare the archived files with the stopped installation. Independently captured backups can have different hashes. Verify each against its own recorded hash.
3. Restore SQL in an isolated instance of the matching MariaDB version. Pi 2 used a temporary instance without containers, initialized as the operator with a private data directory and Unix socket and started with networking disabled. Before importing, query `@@datadir`, `@@socket` and `@@skip_networking` through that socket and require all three to match. If the dump lacks database creation and selection statements, create `orchids` on the isolated instance using the original charset and collation, then explicitly select it for import. Check the dump hash and require the entire decompression/import pipeline to succeed.
4. Compare all 13 schema categories and the original ledger fingerprint between the stopped server and the isolated restore. Keep the isolated restore available for the after-migration data comparison. Record both backup hashes and the successful restore result before proceeding.

## 3. Prepare and adopt the Pi 1 historical ledger

- Capture Pi 1's full schema identity and original ledger row count and SHA-256. Review any differences from the historical reference explicitly and justify the baseline cutoff from the historical evidence. The Pi 2 cutoff was `202606041820` with 245 original records. Establish both values independently for Pi 1.
- Build and review a Pi 1-specific contract and command with pinned host, schema and ledger fingerprints. Use the [historical adoption design](historical-linux-adoption.md) and [fixture adoption implementation](../../tests/HistoricalUpgrade.Checks/legacy_adoption.py) as design references. Pi 2's host guard, contract hash, schema hash and approved column-metadata difference are scoped to Pi 2.
- Run the read-only preflight first. Require the target, exact schema, complete ledger and expected table inventory to match. Stage a replacement InnoDB ledger with a single versioned baseline marker and the Pi 1 contract hash. Recheck the original schema and history immediately before one atomic multi-table rename.
- Independently verify the active marker and the complete archive, including IDs, script names, original checksums and timestamps. If interrupted, inspect the actual table inventory and fingerprints before deciding whether to resume or restore. A client timeout can occur after a statement commits.

## 4. Plan, apply and verify the database migrations

Use the verified release's unchanged `Apply-Migrations.ps1`, `Migration-History.ps1` and migration folder. Explicitly configure the Pi 1 loopback target and its migration account. Check the TCP endpoint is the same instance verified through the socket.

Run `-PlanOnly` first. For the reviewed historical baseline, require exactly these four entries in order and compare their reported hashes with the verified release files:

| Migration | SHA-256 |
|---|---|
| `202610261200_AtomicManualPlantClosure.sql` | `f21af6b18a0cf641c2bccee27163b6569874f1eb66675af7457a47858bc26afd` |
| `202610261800_EndedPlantReadOnly.sql` | `b7eebb3cdde34b0029395eab9e5a4d8cf94d96f652984c2682b69e9a843e99ff` |
| `202610262000_StructuralTransactions.sql` | `84f8017a8a0c08b351f0ab0211302cd407d663408c9d66605807ad7ff60c72cd` |
| `202610271200_PhotoTaxonTransaction.sql` | `b736d92b502c47cd30cc44d08eec89122196d2340d481a444202116cb1d81686` |

**Pi 2 troubleshooting.** The runner reported that `schemaversion` must use InnoDB, even though the migration account saw it as InnoDB. The client exited zero and PowerShell received two lines because the runner merges stderr with stdout. The extra line was:

    WARNING: option --ssl-verify-server-cert is disabled, because of an insecure passwordless login.

A passwordless probe was denied. The Pi 2 workaround was a temporary client wrapper passed through `-MariaDbExe`. It required the verified loopback endpoint, forwarded stdout unchanged, and filtered only the exact warning from stderr on success. It forwarded all stderr on failure and preserved the exit status. It left the release scripts and TLS settings intact. Diagnose Pi 1 independently before using that workaround, and stop if the endpoint or warning differs.

After the plan passes, apply once with the same runner, client and endpoint, removing `-PlanOnly`. Then require:

- A second `-PlanOnly` reports zero pending.
- The active ledger contains exactly the pinned baseline marker and four release hashes. The archive still matches the complete pre-upgrade ledger.
- The expected schema and routine changes are present. The application table inventory and data match the isolated restore. Pi 2 compared ordered data-only dumps of the same base-table list using `--compact --no-create-info --skip-triggers --skip-lock-tables --single-transaction --order-by-primary --hex-blob`, excluding both ledger tables. All 23 application tables matched.
- On failure, keep the application stopped and preserve the output and any `migration:pending` record. Inspect before retrying. If the database state cannot be verified, use the proven pre-upgrade recovery set.

## 5. Switch the application and check readiness

1. Stage the application in a sibling of the current publish directory. Verify the launcher is ARM64, set its execute permission, and check ownership and access against the installed service identity. The Pi 2 ZIP extracted the launcher without execute permission.
2. Compare Production settings by key without printing credentials. Check the effective database configuration and upload root. On Pi 2 the base settings added `Monitoring:Enabled`, the database connection came from the existing service environment file, and uploads stayed at `/opt/orchidapp/uploads`.
3. With the service stopped, rename the old publish directory to a retained sibling, then rename the staged directory into place. If the second rename fails, restore the original directory before starting the service.
4. Start OrchidApp and verify systemd reports it running. Request `/health/ready` on the actual local listener. Require HTTP 200 and passing database, upload root, native photo, referenced photo and photo recovery checks. Open an existing plant in the Pi 1 browser and verify its record, thumbnail and full-size photo.
5. Record the endpoint, release hash, backup and restore evidence, migration plan and apply results, ledger and data checks, readiness and browser result. Retain the recovery set and old publish tree. Shut down the isolated instance through its private socket after verification.

## Pi 2 rehearsal result

Pi 2 completed ledger adoption and all four migrations, with zero pending afterward. The archive preserved 245 original rows, all 23 application tables matched the isolated restore, and all five readiness checks and the browser smoke test passed. Pi 1 was untouched during that rehearsal.
