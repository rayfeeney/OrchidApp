# C04 - migration runner validation and evidence

24 October 2026. Changes are in the local review-work/OrchidApp source copy. No live installation, production database, production grants or owner configuration was changed.

## Implemented contract

Apply-Migrations.ps1 is the canonical PowerShell runner. Apply-MariaDBMigrations.ps1 delegates to it. dev-runner.ps1 applies with that same runner, then exports for review. All require an explicit host, port, database and account/password; conflicting endpoint defaults and the pre-upgrade comparison against the newest schema were removed. PlanOnly is available through all three routes and writes no marker, SQL or exports.

Desktop uses MigrationHistory.Plan, matching PowerShell rules. Entire packages/history are validated before SQL and before Desktop backup: valid calendar filenames, lowercase .sql, unique timestamps across files/history, valid raw-byte SHA-256 records, supplied-file immutability, required missing files and pending chronology. Fresh schema boundaries permit covered historic payload to be absent or reintroduced without replay. Legacy baseline rows and complete per-file ledgers are preserved; no baseline is guessed for an incomplete ledger. Both policy checks also validate all 244 current packaged migration files with a synthetic complete ledger.

A single migration:pending row in the existing unique-key history table serialises cooperating runners. Each owner rechecks history after acquiring it and uses the captured SQL/checksum. Successful applied-row insertion and marker removal share a history transaction. The table must already exist and use InnoDB. A failed/uncertain script leaves its pending marker, with no new successful row, and blocks subsequent runners including PlanOnly. The exporter checks for incomplete history before changing generated files. None of this promises transactional DDL or blind rollback.

No schema definition, bootstrap manifest, schema checksum or historical migration changed. No new DDL migration is required: bookkeeping uses the existing schemaversion columns and unique key. Existing applied/baseline rows are not updated or deleted. Pending-marker cleanup before SQL only removes the caller's own unexecuted marker; after uncertain SQL there is no automatic retry/cleanup.

## Verification completed locally

- Release web build: succeeded, zero warnings/errors.
- Shared policy fixtures: 24 scenarios passed in C# and 24 in PowerShell. Both also validated all 244 real packaged migration filenames/checksums against a synthetic ledger.
- MigrationHistory.Checks/Database.Checks.ps1: 53 checks passed against disposable Windows MariaDB 10.11.16. Both operational entry points passed PlanOnly, once-only future migration, complete checksum preflight, duplicate timestamps, backdated/missing-file rejection and preserved legacy rows. Failed SQL left observable partial DDL, stopped later statements, retained a pending marker and blocked retries. Competing canonical/alias processes produced one applied change. A pending marker blocked export without changing its staged canonical files. The developer wrapper was tested with a separate full schema/source fixture and exported only after success. Missing explicit endpoint and nontransactional history engine were rejected.
- MigrationHistory.Checks/Desktop.Checks.ps1: 12 actual staged Windows application checks passed. Tested baseline startup without a migration folder, future migration once, restart, preflight rejection before backup, nontransactional history engine, failed SQL retaining its marker, and retry blocked before another backup.
- SchemaBaseline.Checks: 18 policy checks and 28 disposable creation/baseline checks passed after initial C04 changes. Monitoring regression: 163 checks passed. Tool resolution: 8 checks passed, retaining the prior Linux CI fixes. NuGet vulnerability lookup was unavailable locally (NU1900) on the monitoring check; it did not prevent the passing check.
- PowerShell syntax, documentation links, unchanged schema/migration content and delivery ZIP contents were checked.

Desktop checks copied Release output and a MariaDB client into a uniquely named temporary stage. A synthetic successful-backup command was written only inside that disposable stage to exercise the gate; it is not returned as app code and does not prove real backup/recovery. All generated databases were dropped by their suites; unique fixture folders remain for diagnosis outside the delivery.

## CI and remaining limits

The workflow now runs the C# policy/inventory check in the build job and PowerShell policy/inventory plus disposable database checks in schema-contract. These new Linux steps have not been run locally and must be confirmed in the CI run for this delivery. Previous CI success reported in this chat concerned the preceding C01/C02/tool-resolution changes, not these new C04 steps. No local Linux MariaDB engine was available.

The rules protect cooperating updated runners, not old clients or arbitrary manual changes to SQL/history. Checksums are raw-byte hashes; preserve trusted artifacts and line endings rather than changing stored digests. An inclusive schema cut-off cannot identify a newly invented filename below it: never add backdated schema-covered changes. Live structural drift, the historical DDL corpus on representative real backups, installer/hardware acceptance and real recovery remain separate work. Restore or obtain maintainer review for incomplete migration state; do not delete a marker to force replay.

See [migration runners](../migration-runners.md) for commands, exact exceptions and recovery handling. C04 is implemented and locally verified with Linux CI acceptance pending. Next agreed implementation step is C16, developer setup, followed by C05 CI database acceptance.
