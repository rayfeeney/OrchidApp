# Architecture

This reference describes the .NET 8 Razor Pages app, MariaDB data model and Windows launcher in the supplied v1.3.0 source. It separates owner requirements from current enforcement and pending fixes. Operating commands belong in the [indexed platform guides](index.md); temporal details belong in [temporal design](temporal-design.md).

## Responsibilities

The database owns structural integrity and intended lifecycle operations. The app collects/validates input and orchestrates workflows. Tooling exports schema, builds packages and performs checks. Operators configure trusted access, back up durable state and validate recovery. A rule is not proven merely because it is assigned to a layer.

Structural lifecycle operations use stored procedures; narrative writes use EF Core. C13 adds rollback handlers and caller-preserving savepoints to move/edit/remove location, split, propagation and hero-photo selection. Normal plant POST handlers hold the same parent-row lock until their database transaction completes, coordinating them with manual closure. Direct administrative writes remain outside this protocol. [C11â€“C14](code-change-backlog.md) track implementation and platform acceptance; see [C13 evidence](maintenance/c13-structural-transactions.md).

## Configuration and readiness

ASP.NET Core loads shared/environment-specific JSON, environment variables and command-line settings. Production secrets/paths belong in external local configuration. The web app does not parse arbitrary .env files; a systemd EnvironmentFile is loaded by systemd.

- EF Core uses ConnectionStrings:OrchidDb (environment: ConnectionStrings__OrchidDb), Pomelo MariaDB provider support and a collation interceptor. Library API names containing MySql do not imply a supported MySQL deployment.
- Desktop bootstrap separately reads ConnectionStrings:DefaultConnection. Some local SQL-client arguments remain fixed; not every endpoint is externally configurable.
- Upload services bind Storage:UploadRoot. Desktop overrides it with ORCHIDAPP_UPLOAD_ROOT or falls back to runtime wwwroot/uploads; the packaged launcher supplies ProgramData uploads.
- Media options bind from MediaIngestion; StripGpsMetadata defaults true and removes private metadata while retaining ICC colour profiles. Both photo outputs are autorotated. See [photo handling](photo-handling.md).

Development does not run Desktop schema bootstrap or automatically apply migrations. Ordinary Development dotnet run reads the repository .env. Production and Desktop expose separate liveness/readiness endpoints; the launcher waits for database, upload, native photo, referenced-file and recovery-record checks. Configured external uploads become available when their directory exists, including after a missing directory is repaired. See [photo handling and recovery](photo-handling.md) and [developer setup](development-setup.md).

## Database creation and evolution

A fresh database must be built from database/schema/ and required seeds alone. It must not need historic migration SQL, including for baseline bookkeeping. Migrations apply only to changes after creation. The [creation contract](database-creation.md) is authoritative. Baseline metadata belongs with the schema export so a fresh installation can later accept only subsequent compatible changes.

Creation now validates schema/bootstrap.json, imports required seeds in dependency order and records a completion marker last. The retained rebuild.ps1 filename creates only absent/empty targets and never drops a database. Desktop no longer scans historic SQL for creation. See [C01/C02 evidence and remaining platform acceptance](maintenance/c01-c02-schema-baseline.md). Do not manually edit applied history or use creation as an upgrade.

## Implemented migration paths

| Path | Current behaviour and limit |
| --- | --- |
| database/scripts/Apply-Migrations.ps1 | Canonical runner with full history preflight, duplicate/chronology/checksum/missing-file validation and durable incomplete markers. Requires an explicit target; no Git/export dependency. |
| Desktop in src/OrchidApp.Web/Program.cs | Matching C# policy; schema-only first use, legacy ledger preservation and backup before pending SQL. |
| database/scripts/Apply-MariaDBMigrations.ps1 | Compatibility entry point delegating to the canonical runner. |
| database/scripts/dev-runner.ps1 | Maintainer apply-then-export workflow; generated differences are reviewed rather than treated as failed SQL. |

See [migration runners](migration-runners.md) for exact baseline exceptions, parameters, pending-marker recovery and intentional backup/export differences. These rules validate history, not universal live schema drift; DDL failures can leave partial state. Cooperating runners use the existing schemaversion unique key and pending marker; no new schema table or rewritten applied history is needed.

Schema and checksum files are generated; do not edit them manually. The hook exports/stages the configured development DB on every commit. CI reconstructs/exports a schema and is now configured for C04 policy and disposable runner checks. Broader seeded application first-use/upgrade acceptance and representative history replay remain separate. See [contributor checks](../CONTRIBUTING.md) and [C05](code-change-backlog.md#c05).

## Lifecycle and writes

Plant acquisition/end timestamps describe a correctable collection history, not a universally immutable event log. A split closes one parent and creates at least two independently tagged children; propagation creates a child without ending its parent. Location changes adjust intended contiguous intervals. DB unique keys, constraints and procedures enforce important parts of these rules; handlers also perform checks, with documented gaps. Use [temporal design](temporal-design.md) for exact date/time and rollback limits.

C12 makes ended plants read-only through normal application workflows: details, events, photos and lifecycle dates cannot be changed or reactivated. Their history/photos remain viewable. C14 orders history by newest stored timestamp, then event type ascending, then record ID descending within each type; see [history ordering](maintenance/c14-history-ordering.md). Corrections on unended plants retain existing times when changing calendar dates; handler ownership and date checks apply before writes. C13 serializes plant writes with closure through a shared parent-row lock; error/validation pages roll back request database changes. C19 coordinates photo files with the request transaction through compensation and retained recovery journals; see [photo recovery](photo-handling.md).

Keep parameterised values, trusted procedure identifiers, async I/O and shared procedure-execution infrastructure. Surface expected validation errors appropriately and log operational failures without exposing secrets.

## Files and photos

Durable state includes the database and actual uploads, plus the configuration/settings required to operate/recover them. Plant photos attach to observation metadata; taxon photos are separate. A plant has at most one active hero via schema support, and upload flows choose an initial hero where absent.

PhotoPipeline enforces 10 MiB/40-million-pixel limits, rejects detected animations/multipage inputs, normalizes orientation, preserves ICC colour profiles and flattens transparency onto white. Defaults remain 3072-pixel JPEG quality 90 and separate 300-pixel thumbnails. StripGpsMetadata defaults true and now removes private camera metadata from both outputs; false deliberately retains it. Both files must succeed, and existing photos are not rewritten.

Plant and taxon photo writes enlist in a request database transaction. Newly generated files are removed only after confirmed rollback; uncertain outcomes or cleanup failures retain durable private journals. The C19 migration makes taxon detail updates preserve caller transactions. This is not a single atomic filesystem/SQL transaction. Readiness checks current active references and native save/decode, and refuses unresolved journals. Backups must pair SQL, uploads and recovery records. [Photo handling](photo-handling.md) owns the policy, readiness limits and operator recovery procedure.

## UI and bespoke monitoring

Use [return navigation](navigation.md), [rich notes](rich-notes.md) and [name search](name-search.md) contracts. Feature checks supplement live workflows; they do not prove device behaviour.

Environmental summaries, greenhouse charts and net-cost reporting are bespoke to the owner's one local installation. General installations must not query or provision their tables, grants, feeds or importers. Monitoring:Enabled defaults false and additionally requires Linux ARM/ARM64. Disabled Home skips monitoring queries and omits markup/scripts. See [current scope](environment-summary-platform.md) and the [local guide](local-installation/greenhouse-monitoring.md).

## Windows and Linux operations

The Windows installer owns replaceable app files, normally under Program Files, using the actual selected root. The launcher resolves ProgramData data/settings paths and legacy migration; Desktop web startup handles database setup/upgrades. Normal local backups are logical SQL plus uploads/settings, not a raw live database archive. C06/C07 add a quiescent captured legacy source, database-directory identity checks and versioned archive/settings validation; see the [Windows backup contract](windows-backup-format.md). Recovery, retention, state reconciliation and installed-upgrade limits remain in the [Windows contract](windows-upgrade-contract.md); app-only updates do not universally trigger a backup gate.

Linux uses externally managed MariaDB and systemd. The general install does not include the owner's importer/monitoring feeds. Routine backup currently uses SQL snapshots plus a current uploads mirror, which is not a guaranteed matched historical recovery set. The [Linux runbook](user-guides/linux/OrchidApp-MariaDB-Backup-and-Restore-Runbook.md) and [full backup](user-guides/linux/Full-App-Backup-Pre-Upgrade.md) distinguish present tooling from required validation.

Keep trusted-network access: there is no built-in multi-user authentication, and direct public exposure is outside the intended model. Console/ILogger/launcher/systemd logs provide diagnostics but are not uniformly structured or proof of full safety. Confirm backup source identity, retained recovery input and working restoration before destructive operations.

## Versions and validation

Directory.Build.props currently carries public version 1.3.0 and internal build metadata. Launcher version metadata drives Windows packaging/operational decisions; matching web metadata is for display/diagnostics. Package scripts update versions before building; empty version input increments the internal build, while explicit input resets it. Do not derive app version from user data or invent a release date from a documentation review.

CI cross-publishes linux-arm64, reconstructs/exports a MariaDB 10.11 schema and builds a Windows package. It does not run all executable feature check projects, prove schema-only seeded first run, test all migration history, build the Inno installer or perform device recovery. Requirements and acceptance remain in [the code backlog](code-change-backlog.md). Code changes must update the affected [document owner](documentation-map.md) in the same change.
