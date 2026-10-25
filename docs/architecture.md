# Architecture

This reference describes the .NET 8 Razor Pages app, MariaDB data model and Windows launcher in the supplied v1.3.0 source. It separates owner requirements from current enforcement and pending fixes. Operating commands belong in the [indexed platform guides](index.md); temporal details belong in [temporal design](temporal-design.md).

## Responsibilities

The database owns structural integrity and intended lifecycle operations. The app collects/validates input and orchestrates workflows. Tooling exports schema, builds packages and performs checks. Operators configure trusted access, back up durable state and validate recovery. A rule is not proven merely because it is assigned to a layer.

Structural operations should use stored procedures; other entities use established EF Core patterns. Not every procedure is fully failure-atomic or every lifecycle restriction independently enforced in SQL. [C11–C14](code-change-backlog.md) track confirmed defects, policy decisions and integration work. Treat transactional/rollback claims as testable behaviour, not consequences of a START TRANSACTION statement alone.

## Configuration and readiness

ASP.NET Core loads shared/environment-specific JSON, environment variables and command-line settings. Production secrets/paths belong in external local configuration. The web app does not parse arbitrary .env files; a systemd EnvironmentFile is loaded by systemd.

- EF Core uses ConnectionStrings:OrchidDb (environment: ConnectionStrings__OrchidDb), Pomelo MariaDB provider support and a collation interceptor. Library API names containing MySql do not imply a supported MySQL deployment.
- Desktop bootstrap separately reads ConnectionStrings:DefaultConnection. Some local SQL-client arguments remain fixed; not every endpoint is externally configurable.
- Upload services bind Storage:UploadRoot. Desktop overrides it with ORCHIDAPP_UPLOAD_ROOT or falls back to runtime wwwroot/uploads; the packaged launcher supplies ProgramData uploads.
- Media options bind from MediaIngestion, but StripGpsMetadata is currently unused by the image saver.

Development does not run Desktop schema bootstrap. The supported source-run wrapper now aligns app/script configuration and probes native photo save/reopen before startup; see [developer setup](development-setup.md). Ordinary Production hosting lacks comprehensive startup database/filesystem/native readiness checks and a dedicated health endpoint. EF server autodetection and errors may occur when a request resolves the context. External uploads are served only if the configured directory exists at middleware setup. A listening HTTP service is not proof of working database pages or photo processing. [C16/C19](code-change-backlog.md) cover setup and readiness work.

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

Keep parameterised values, trusted procedure identifiers, async I/O and shared procedure-execution infrastructure. Surface expected validation errors appropriately and log operational failures without exposing secrets.

## Files and photos

Durable state includes the database and actual uploads, plus the configuration/settings required to operate/recover them. Plant photos attach to observation metadata; taxon photos are separate. A plant has at most one active hero via schema support, and upload flows choose an initial hero where absent.

PhotoPipeline uses NetVips/libvips with 10 MiB buffering and a 40-megapixel limit; detected animations/multipage inputs are rejected. Default JPEG output is at most 3072 pixels, quality 90, alpha on white; smaller images are not enlarged. It creates 300-pixel thumbnails with logged fallback to the main image. Originals are not retained separately.

Metadata removal and autorotation are not explicitly implemented in the current saver, despite the exposed StripGpsMetadata option. Do not claim verified GPS stripping; [C15](code-change-backlog.md#c15) requires a decision and output tests. Filesystem and DB updates are not one atomic transaction; failures can leave incomplete metadata/files. Backups must pair the DB with the actual upload root. [C19](code-change-backlog.md#c19) tracks consistency/readiness work.

## UI and bespoke monitoring

Use [return navigation](navigation.md), [rich notes](rich-notes.md) and [name search](name-search.md) contracts. Feature checks supplement live workflows; they do not prove device behaviour.

Environmental summaries, greenhouse charts and net-cost reporting are bespoke to the owner's one local installation. General installations must not query or provision their tables, grants, feeds or importers. Monitoring:Enabled defaults false and additionally requires Linux ARM/ARM64. Disabled Home skips monitoring queries and omits markup/scripts. See [current scope](environment-summary-platform.md) and the [local guide](local-installation/greenhouse-monitoring.md).

## Windows and Linux operations

The Windows installer owns replaceable app files, normally under Program Files, using the actual selected root. The launcher resolves ProgramData data/settings paths and legacy migration; Desktop web startup handles database setup/upgrades. Normal local backups are logical SQL plus uploads/settings, not a raw live database archive. The [Windows contract](windows-upgrade-contract.md) records source-selection, retention, restore-format and partial-migration gaps; app-only updates do not universally trigger a backup gate.

Linux uses externally managed MariaDB and systemd. The general install does not include the owner's importer/monitoring feeds. Routine backup currently uses SQL snapshots plus a current uploads mirror, which is not a guaranteed matched historical recovery set. The [Linux runbook](user-guides/linux/OrchidApp-MariaDB-Backup-and-Restore-Runbook.md) and [full backup](user-guides/linux/Full-App-Backup-Pre-Upgrade.md) distinguish present tooling from required validation.

Keep trusted-network access: there is no built-in multi-user authentication, and direct public exposure is outside the intended model. Console/ILogger/launcher/systemd logs provide diagnostics but are not uniformly structured or proof of full safety. Confirm backup source identity, retained recovery input and working restoration before destructive operations.

## Versions and validation

Directory.Build.props currently carries public version 1.3.0 and internal build metadata. Launcher version metadata drives Windows packaging/operational decisions; matching web metadata is for display/diagnostics. Package scripts update versions before building; empty version input increments the internal build, while explicit input resets it. Do not derive app version from user data or invent a release date from a documentation review.

CI cross-publishes linux-arm64, reconstructs/exports a MariaDB 10.11 schema and builds a Windows package. It does not run all executable feature check projects, prove schema-only seeded first run, test all migration history, build the Inno installer or perform device recovery. Requirements and acceptance remain in [the code backlog](code-change-backlog.md). Code changes must update the affected [document owner](documentation-map.md) in the same change.
