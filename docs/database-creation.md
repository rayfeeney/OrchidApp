# Database creation and subsequent changes

Fresh databases are assembled from database/schema/ only, including reference seeds and bootstrap.json. Historical migration SQL is neither read nor executed for creation. Use the creation script for new databases and migration runners only for subsequent compatible changes.

## Schema manifest

The generated schema/bootstrap.json records formatVersion 1, an inclusive throughMigration timestamp (YYYYMMDDHHMM), and every schema SQL file in import order with its SHA-256 checksum. Hashes normalise CRLF/CR to LF so a Windows checkout and Linux checkout agree. The current snapshot includes history through 202606041820.

Import stages are tables, constraints, routines, dependency-ordered views, triggers and required reference seeds. The generator orders dependencies between quoted canonical view names and rejects cycles. Creation validates inventory, checksums, stage order, required seeds and safe relative paths before executing any SQL. Observation types, phonetic prefixes and propagation types are reference data; collection records are never seeded.

Only after all imports succeed is a row written to the existing schemaversion table: scriptName baseline:v1:<throughMigration>, checksum equal to the normalised manifest digest. That row identifies the database's own cut-off. Updating application files or exporting a newer schema never rewrites it. No new database table or forward DDL migration is needed for this bookkeeping contract.

## Explicit new target

Use PowerShell 7+ with MariaDB 10.11 client/server. Select an isolated target and securely supply all seven environment values in that terminal:

- MARIADB_HOST, MARIADB_PORT, MARIADB_USER and MARIADB_PASSWORD.
- MARIADB_DATABASE: the exact intended database identifier.
- MARIADB_CHARSET=utf8mb4 and MARIADB_COLLATION=utf8mb4_unicode_ci.

The client is resolved from MARIADB_EXE when explicitly supplied, otherwise PATH, then the MariaDB 10.11 Program Files location on Windows. Resolution selects one executable: the first application match in PATH order, even when both /usr/bin and /bin expose the command. Explicit overrides also resolve to a single executable. On Linux install mariadb on PATH. The script does not load .env files, change working directory or silently choose an endpoint.

From the repository root:

```powershell
pwsh ./database/scripts/rebuild.ps1 -ConfirmDatabase $env:MARIADB_DATABASE
```

Despite its retained legacy filename, rebuild.ps1 no longer drops databases. It creates an absent target, or imports into an existing completely empty target with the required collation. ConfirmDatabase must match the explicit target exactly. Any existing tables/views/routines cause refusal, including a partial previous import. Do not use it to upgrade, restore or repair collection data. DDL failures can leave partial objects; no completion marker is written after a failed import. Review/restore the target, or explicitly remove only a known disposable failed test database before retrying. Never erase an existing collection as a recovery shortcut.

## Desktop first use

Desktop startup loads the same schema manifest from the packaged database/schema directory. It requires an empty target for first import, uses the configured DefaultConnection endpoint/credentials for the MariaDB client, and records the completion marker last. It does not scan database/migrations for baseline bookkeeping. A schemaversion table with empty history is treated as incomplete setup rather than a valid upgraded database. The configured OrchidDb web connection must refer to the same application database; MARIADB_* variables alone do not set either app connection string.

## Future changes and existing databases

Desktop and both PowerShell migration runners recognise baseline:v1 markers. SQL files with timestamps at or before the database's recorded cut-off are already represented in that schema. Later files apply once and receive their ordinary per-file SHA-256 row. Recorded file checksums are checked before skipping. C04 now enforces duplicate timestamps, chronology, missing-file and checksum rules with durable incomplete markers; see [migration runners](migration-runners.md) for the baseline exceptions and recovery contract. This is not a universal schema-drift or DDL rollback guarantee.

Older Desktop databases retain their literal baseline/baseline row and recorded migration rows unchanged. Those rows continue to use their existing per-file checksums; the latest packaged manifest is never used to invent an earlier database's baseline. A legacy marker alone does not authorise skipping unrecorded SQL. Review incomplete legacy history rather than filling it by hand. Existing databases created by recorded migrations without a baseline marker retain that per-file path.

Create no empty database by running migrations. Do not manually delete, update or backfill applied history. Back up before upgrading; the Desktop backup gate remains in place. This change does not certify the separate backup/recovery paths.

## Export and maintenance

Export-MariaDBSchema.ps1 requires explicit MARIADB_HOST, MARIADB_PORT, MARIADB_DATABASE, MARIADB_USER and MARIADB_PASSWORD (no MYSQL aliases or endpoint defaults) and resolves mariadb/mariadb-dump from explicit MARIADB_EXE/MARIADB_DUMP_EXE or platform tools. It regenerates the manifest after schema export using the maximum recorded DB baseline/migration timestamp, never the newest file merely present in migrations/. An export with no usable history may retain the existing cut-off only if its manifest still validates the exported schema unchanged.

Do not hand-edit the generated manifest or canonical schema/checksums. For this initial manifest the generator was run against the reviewed canonical snapshot with the known inclusive cut-off:

```powershell
pwsh ./database/scripts/New-SchemaManifest.ps1 -ThroughMigration 202606041820
```

This is a maintainer generation step for an audited snapshot, not an operator command to guess a cut-off or repair a database. Future SQL fixes still require forward migrations and regenerated exports. Commit hook staging already includes database/schema, so it includes bootstrap.json.

## Checks and remaining acceptance

From the repository root:

```powershell
dotnet run --configuration Release --project tests/SchemaBaseline.Checks/SchemaBaseline.Checks.csproj
pwsh ./tests/SchemaBaseline.Checks/ToolResolution.Checks.ps1
pwsh ./tests/SchemaBaseline.Checks/Database.Checks.ps1
```

ToolResolution.Checks.ps1 needs no database. It tests duplicate PATH matches, executable invocation from paths containing spaces and override precedence; the Linux schema CI job runs it before export. Database.Checks.ps1 requires explicit credentials/endpoint for an isolated server with create/drop rights. It creates and drops only a generated orchids_contract_<guid> database and retains its small temporary fixture folder for inspection. Never point these checks at a live server.

See [C01/C02 evidence](maintenance/c01-c02-schema-baseline.md). Windows/MariaDB creation, actual Desktop first use, view queries, plant creation, future-only migration, legacy rows and failed-import handling were checked locally. Linux/MariaDB and full native-photo save/reopen acceptance remain pending. C04 and C05 still own broader runner enforcement and CI acceptance.
