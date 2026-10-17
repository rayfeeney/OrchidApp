# Architecture

This document defines the **architectural contract** of OrchidApp.

It specifies the structural boundaries, invariants, enforcement
mechanisms and operational guarantees that govern the system.

This reference describes the current .NET 8 Razor Pages web application and
Windows launcher, reviewed against the v1.3.0 source configuration. It also states
requirements for future changes. Requirements are distinguished from implemented
checks and known gaps; they are not proof that every deployment satisfies them.
For operating commands, use the [documentation index](index.md).

---

# Architectural Summary

OrchidApp is a layered system built on a strict principle:

> Invariants live in the database.
> Behaviour lives in the application.
> Enforcement lives in automation.

Responsibility is deliberately separated across four layers:

1. **Database Layer** - structural integrity and lifecycle invariants
2. **Application Layer** - behavioural workflows
3. **Automation Layer** - reproducibility and enforcement
4. **Operations Layer** - backup, restore and deployment discipline

No layer may weaken another.

---

## Environment configuration

The web application uses ASP.NET Core configuration, including `appsettings.json`,
environment-specific settings, environment variables and command-line arguments.
Production secrets and deployment-specific paths must be supplied externally.
A systemd `EnvironmentFile` loads Pi settings; the web app does not itself parse
arbitrary `.env` files.

- The EF Core context uses `ConnectionStrings:OrchidDb` with Pomelo's MariaDB
  provider support and a collation interceptor. Provider names such as `UseMySql`
  and `MySqlConnector` are API names, not a different supported database engine.
- Desktop bootstrap separately reads `ConnectionStrings:DefaultConnection`.
  Desktop SQL client invocations still contain fixed local connection arguments;
  it is incorrect to claim that all runtime values are externally configurable.
- Upload services bind `Storage:UploadRoot` (environment form `Storage__UploadRoot`).
  In Desktop mode, `ORCHIDAPP_UPLOAD_ROOT` overrides this; otherwise the app creates
  a fallback under its runtime `wwwroot/uploads` directory. The packaged launcher
  supplies the ProgramData uploads path.
- Media processing options bind from `MediaIngestion`.

Production deployments must provide correct settings and writable storage. Current
configuration does not use comprehensive startup options validation.

---

## Application readiness

Readiness differs by host. In Desktop mode, bootstrap connects to MariaDB,
initialises a fresh schema or checks/applies pending migrations before serving
requests. The launcher starts the local database and web process and reports
startup failures.

The ordinary Linux/Production web host does not run an explicit database readiness
probe or comprehensive filesystem/native dependency validation before listening.
EF Core checks the connection setting and detects the server version when its
context configuration is resolved; a dependency failure can therefore surface on
a request rather than at process startup. External uploads are served only if
the configured directory exists at middleware setup.

There is no dedicated health endpoint registered in `Program.cs`. A running
systemd service or listening HTTP process alone does not prove database reads,
photo processing or environmental-summary queries work. Deployment verification
must exercise these workflows. Comprehensive fail-fast checks and a health
endpoint remain improvements, not current guarantees.

---

## Logging

The web host uses a mixture of console startup/SQL-tool messages and
`ILogger` logging, including structured photo-ingestion events. The Windows
launcher writes a persistent support log with rotation; systemd captures Linux
service output. Backup tooling also produces operational logs.

All critical workflows should produce useful diagnostics without exposing secrets.
The implementation does not guarantee uniform structured logging for every
operation. Review messages, connection arguments and exception output when
changing sensitive workflows.

---

## Security Model

OrchidApp is designed for deployment within a **trusted network environment**.

The system assumes:

* The application is not exposed directly to the public internet
* Access is restricted to trusted users
* No built-in authentication or authorisation is enforced

**This system is not designed for direct internet exposure.**

Operational security (firewalls, routing, access control) is the responsibility of the deployment environment.

---

# 1. Database Layer - Invariant Core

The MariaDB schema is the authoritative source of truth.

It is responsible for:

* Structural integrity
* Lifecycle enforcement
* Temporal adjacency rules
* Split and propagation semantics
* Preventing invalid state transitions

The database is treated as source code:

* Reproducible
* Deterministic
* Resistant to drift

### Authoritative Environment

MariaDB running on Linux is the authoritative validator for:

* Identifier casing
* Collation behaviour
* Stored procedure parsing
* Trigger semantics

MariaDB is the supported database engine on both Windows and Linux.
Linux MariaDB validation does not replace Windows runtime and packaging checks;
do not infer compatibility from testing against a different database engine.

---

# 2. Schema creation and evolution

The canonical assembled schema lives under `database/schema/`; reviewed changes
for existing installations live under `database/migrations/`. New migrations must
use unique `YYYYMMDDHHMM_Name.sql` filenames and must not modify applied history.

Fresh installations use the current canonical schema rather than replaying every
historical migration. Existing installations apply only pending migrations. A
database created from the schema must have migration history aligned with that
baseline before later upgrades; never replay historical DDL over a fresh schema.
Desktop bootstrap records a baseline and the packaged migrations as already
applied. Do not assume every rebuild script performs that same bookkeeping.

## Implemented migration paths

| Path | Current behaviour |
| --- | --- |
| `database/scripts/Apply-Migrations.ps1`, used by the Linux upgrade guide | Sorts files by name, skips recorded filenames and records checksums for new files. It does not compare checksums for skipped files or enforce timestamp uniqueness/order. |
| Desktop bootstrap in `src/OrchidApp.Web/Program.cs` | Checks recorded file checksums, collects pending migrations, requires a safety-backup script to succeed before applying them and verifies the new history records. |
| `database/scripts/Apply-MariaDBMigrations.ps1` | Separate developer runner with filename, missing-history-file, checksum and applied-history-gap checks. It has different defaults and export assumptions; it is not the runner named in the Linux upgrade guide. |

These paths are not interchangeable. The separate developer runner also expects
every recorded script name to have a matching file, which is incompatible with
Desktop's extra `baseline` history row without reconciliation. Its export script
path casing differs from the checked-in filename, so Linux compatibility must be
verified before adopting it.

No universal duplicate-timestamp prevention or pre-execution live schema drift
check is implemented across these paths. Review migration ordering and history
explicitly. Schema export checksums serve a different purpose from migration
file checksums.

Successful files are recorded in `schemaversion`; failures can leave partially
applied DDL because MariaDB DDL is not covered by an automatic rollback of the
whole upgrade. Backups and controlled upgrade testing are required. Production
schema changes must use the reviewed migration process.

---

# 3. Schema Export - Deterministic Representation

Schema files under:

```
database/schema/
```

are generated artefacts.

They:

* Represent the assembled schema
* Are regenerated deterministically
* Must never be edited manually
* Are validated in CI

The schema export is the **canonical database definition** used for:

* Fresh installations
* Full rebuilds
* CI validation

Rebuild validates the assembled schema.
Migrations evolve already-existing databases.

---

# 4. Temporal Model - Contractual Behaviour

Temporal behaviour is part of the architectural contract.

It is formally defined in:

```
docs/temporal-design.md
```

This includes:

* Narrative vs structural time
* Lifecycle boundaries
* Temporal ordering guarantees
* Mutability rules

The application must not reinterpret temporal behaviour.
Database constraints and stored procedures enforce structural lifecycle rules;
application handlers also assign or normalise event timestamps. Do not assume
every temporal rule is implemented solely by a database constraint.

---

# 5. Lifecycle Model - Structural Rules

A plant has a lifecycle interval; supported structural operations may close it:

```
plant.acquisitionDate → plant.endDate
```

## Split Semantics

* A split ends the parent lifecycle
* Creates two or more new plants
* A plant may be split at most once
* Children are independent entities

## Propagation Semantics

* Propagation creates a new plant
* Parent lifecycle continues unchanged
* Each child has at most one propagation origin (`plantpropagation.childPlantId`
  is unique); a parent can produce multiple propagated children

## Location History

* Enforces strict temporal adjacency
* No overlaps permitted
* Structural updates must be performed via stored procedures
* Page handlers collect and validate input; stored procedures own structural updates

These rules are database-enforced and non-negotiable.

---

# 6. Photos and image processing

Plant photos are represented by `plantphoto` metadata and linked to an Observation
event (`plantEventId`). The dedicated plant Photos page creates a photo Observation
when adding images. Image files live in the upload filesystem, not database blobs.

The schema uses `isHero` and a unique generated key to permit at most one active
hero per plant. When no active hero exists, upload handlers select the first
uploaded image as hero automatically. Display uses the stored selection rather
than inferring the newest photo on each request.

Taxon Add/Edit supports separate `taxonphoto` records with a primary-image flag.
These photos are not plant Observation attachments. Both use the shared pipeline.

## Processing

`PhotoPipeline` uses NetVips/libvips, buffers uploads with a 10 MiB limit and
rejects decoded images over 40 megapixels. It checks multi-page/animation metadata
and rejects detected multi-frame inputs. Canonical output is JPEG, with default
maximum dimension 3072 pixels and quality 90, configurable through
`MediaIngestion`. Alpha is flattened onto white and smaller images are not enlarged.

It also produces a thumbnail with maximum dimension 300 pixels. If thumbnail
generation fails, it logs the failure and uses the main image as the thumbnail.
Files use generated names beneath `plants/<id>` or `taxa/<id>` in the upload root.
Original uploads are not retained as separate files. Processing occurs within the
request workflow, without a background job queue or image CDN.

## Metadata and consistency limits

Although `MediaIngestionOptions` exposes `StripGpsMetadata`, the current pipeline
does not read it or explicitly strip metadata in the JPEG saver. Metadata removal
must not be presented as a verified privacy guarantee. The code also does not
explicitly autorotate images from orientation metadata.

Filesystem writes and database updates do not form one atomic transaction. A
failed request can leave files or an Observation without the complete intended
photo set. Backups must preserve both database metadata and the actual upload
root. Validate native image dependencies and image behaviour on each platform.

---

# 7. Write Strategy - Responsibility Separation

## Atomic Entities

May be written via EF Core.

## Structural Entities

Must be written via stored procedures.

Stored procedures:

* Enforce invariants
* Execute atomically
* Reject invalid transitions

---

# 8. Application Layer - Behavioural Orchestration

The application:

* Orchestrates workflows
* Invokes stored procedures for structural changes
* Uses EF Core for atomic writes
* Treats the database as authoritative

The application must not:

* Replace database enforcement with application-only checks
* Override lifecycle rules
* Reinterpret temporal behaviour

---

# 9. Web interface and shared services

The web interface uses ASP.NET Core Razor Pages and shared partials. Prefer a
clear primary action and exit action, mobile-friendly layouts and consistent
labels; these are design guidelines rather than a ban on every repeated control.
For example, botanical search appears in both the header and results form.

`AppNavigation` validates local return destinations and supplies fallbacks and
completion routes. `NavigationPageFilter` normalises page ReturnUrl values;
links, forms and shared buttons preserve query/anchor context. Successful edits
normally show Details while retaining the originating list/report. Browser Back
remains browser-controlled. See [navigation](navigation.md).

Formatted genus and taxon notes use locally bundled Quill, a shared editor script
and server-side HTML sanitisation. Marked HTML is distinguished from historical
literal text, with input/storage limits. See [formatted notes](rich-notes.md).

`BotanicalNameSearch` provides read-only, paged searches over genus names and
combined taxon display names and undeleted plants without an end date using
EF Core. Results are grouped by genus, taxa and plants; plant tags and optional
plant names are searchable, while notes remain excluded. See [name search](name-search.md).

The home-page environmental summary queries its database views only when the
server runs Linux ARM/ARM64. Other platforms skip the query and section; the
visiting browser's OS is irrelevant. Schema/bootstrap policy remains separate
from this display/query guard. See [platform support](environment-summary-platform.md).

---

# 10. Versioning Contract

OrchidApp uses a single product version for each release.

The public product version uses three numbers:

```
Major.Minor.Patch
```
Example:

```
1.2.0
```
The internal packaged build version may include build metadata for diagnostics and support.

Only the public product version is shown to users in normal UI, release notes and documentation.

Internal build and informational version metadata may be used in:

* launcher logs
* support diagnostics
* migration state
* installer/package diagnostics
* operational troubleshooting

The launcher version is authoritative for Windows packaging, migration and operational decisions.

The web application carries matching version metadata for display and diagnostics only. Web application version metadata must not drive Windows upgrade layout logic.

Version metadata is baked into the application at build/package time.

Runtime user data must not be used as the source of application version information.

The packaging process is responsible for updating version metadata before building release artefacts.

If Enter is pressed at the packaging version prompt, the current public version
is retained and the internal build number is incremented.

If a version is explicitly entered at the prompt, the internal build number resets
to zero, including when the entered version equals the previous public version.

Skipped internal build numbers are acceptable and expected. They may represent failed, abandoned or test packaging runs.

Release artefacts, release notes and user documentation identify the public product version.

The Windows installer receives the packaged app public product version and uses it for installer identity and output filename.

Migration state records the public product version and informational version involved in migration.

Backup manifests are not currently required to record application version metadata.

---

# 11. Windows installer-led upgrade safety

Windows upgrades are governed by an installer-led upgrade contract.

Public Windows upgrades must use the installer.

Public Windows upgrades must not be performed by extracting a ZIP or package folder over an existing OrchidApp folder.

The installer owns application files only.

The launcher owns user-data safety.

The installer may install, replace or remove application files, but must never overwrite user data.

The implemented Windows application install location is:

```text
C:\Program Files\OrchidApp
```

This folder contains replaceable application files, including:

* launcher files
* web application files
* bundled runtime files
* MariaDB binaries
* libvips binaries
* database setup scripts
* static application content

The implemented Windows user-data root is:

```
C:\ProgramData\OrchidApp
```

Implemented ProgramData paths are:

```
C:\ProgramData\OrchidApp\data\mariadb
C:\ProgramData\OrchidApp\uploads
C:\ProgramData\OrchidApp\backups
C:\ProgramData\OrchidApp\backups\pre-upgrade
C:\ProgramData\OrchidApp\logs
C:\ProgramData\OrchidApp\launcher-settings.json
C:\ProgramData\OrchidApp\migration-state.json
```

The launcher support log is written to:

```
C:\ProgramData\OrchidApp\logs\launcher.log
```

Log rotation keeps at most:

```
launcher.log
launcher.previous.log
```

Existing ZIP-era Windows layouts may contain live user data under the extracted application folder.

Under the installer-led model, those layouts are migration sources only.

A data-bearing legacy layout is one where the actual MariaDB orchids database folder exists and contains data:

```
<legacy-root>\data\mariadb\orchids
```

The mere existence of data\mariadb is diagnostic only and does not make a layout upgrade-sensitive.

The Windows launcher owns:

* ProgramData folder creation
* layout detection
* unsafe-state handling
* mandatory pre-upgrade backup before legacy migration
* copy-only legacy migration
* migration-state recording
* MariaDB startup from ProgramData
* upload-root resolution
* persistent launcher logging
* safe stops when layout ambiguity is detected

In the current layout safety model, if both a data-bearing legacy layout and a ProgramData layout are detected, the launcher stops safely.

This conservative behaviour prevents accidental use of the wrong data layout.

Legacy migration is copy-only.

The launcher does not delete, move or rename the old legacy data.

Migration state is written to:

```
C:\ProgramData\OrchidApp\migration-state.json
```

The current implementation records migration completion after successful legacy data copy.

Migration completion currently describes file-copy completion, not verified
post-copy MariaDB startup. This distinction still applies in the reviewed source.

An unconditional backup gate for every ProgramData-to-ProgramData application
upgrade is not implemented. Desktop database migrations separately require the
safety-backup script before pending SQL is applied.

---

# 12. Runtime Hosting Requirement

Runtime hosting depends on deployment model.

For Raspberry Pi/Linux deployments, the application must:

* Run continuously
* Start on boot
* Be network accessible
* Restart automatically on failure

For packaged desktop deployments, the application must:

* Start predictably through the launcher
* Validate required local dependencies
* Preserve local user data between runs
* Fail clearly if the database or required paths are unavailable

The Windows launcher supplies `ORCHIDAPP_UPLOAD_ROOT` as the ProgramData uploads
path. Durable settings and image/database state remain separate from replaceable
package contents as described in section 11. ZIP/folder output is for development
or packaging; it is not the public Windows upgrade procedure.

---

# 13. Automation and validation

The pre-commit hook exports the configured development database schema, stages
the schema/checksum artefacts and aborts on export failure. Hook activation is a
local setup requirement, not something CI can prove happened on a developer PC.

The current GitHub CI workflow:

- Builds and publishes the web app for `linux-arm64` and checks the DLL exists.
- Reconstructs a disposable MariaDB 10.11 schema from committed artefacts,
  re-exports it and detects schema drift.
- Restores Windows runtime dependencies and creates a Windows package.

It does not start the web app against that schema, replay historical migrations,
run the four executable feature-check projects, build the Inno Setup installer or
exercise backup/restore on deployed devices. Cross-publishing is not a hardware
test. There is no universal migration checksum enforcement through CI.

Local executable checks cover notes, navigation, name search and environmental
platform policy. They supplement CI, with isolated/substitute-data limits described
in the feature guides. Live database workflows, platform dependencies, installation
and recovery require relevant integration/manual checks. See
[CONTRIBUTING.md](../CONTRIBUTING.md) for commands and current enforcement limits.

---

# 14. Operations Layer - State Protection

Windows packaged deployments support local backup creation, mandatory pre-upgrade backup before legacy migration and optional copy of the latest backup to a user-configured cloud-synchronised folder.

Normal Windows backups read the database and uploads from these runtime locations
(and include launcher settings when present):

```
C:\ProgramData\OrchidApp\data\mariadb
C:\ProgramData\OrchidApp\uploads
C:\ProgramData\OrchidApp\launcher-settings.json
```

The backup script creates a logical `orchids.sql` dump, copies uploads and
settings, and records schema-history/manifest details. It does not simply archive
the running MariaDB data directory. Normal backup ZIPs are written to:

```
C:\ProgramData\OrchidApp\backups
```

Legacy migration pre-upgrade backups are written to:

```
C:\ProgramData\OrchidApp\backups\pre-upgrade
```

Linux deployments use externally managed MariaDB, systemd hosting and optional
environment-importer services/timers. Routine backups use the shell/rclone
workflow; full pre-upgrade backups also preserve the deployed app, uploads,
`/etc/orchidapp` and service configuration, with a verified off-device copy.
See the [Linux backup guide](user-guides/linux/Full-App-Backup-Pre-Upgrade.md).

Archive/hash verification detects copy corruption; it does not establish that a
database and filesystem backup can be restored successfully. Validate recovery in
an isolated environment before relying on a backup for production recovery.

## Upgrade Safety Requirement

All upgrade paths must protect user data.

A valid upgrade must ensure:

* A backup exists or is created before upgrade actions begin
* Existing database state is evolved through migrations only
* Uploaded images are preserved
* Application files may be replaced
* User data must not be deleted, overwritten or silently moved without version-aware handling
* Failure during upgrade must leave a recoverable path

Upgrade safety is part of the operational contract.

The launcher requires the legacy pre-upgrade backup command to succeed before
copying legacy app-root data to ProgramData. Its invocation still supplies
`-PruneOldBackups 0`, while the script declares `SkipOldBackupPruning` and tests an
undeclared `PruneOldBackups` variable internally. Backup retention controls are
therefore inconsistent in the source and require correction/testing; do not claim
that configured pruning is reliably enforced.

There is no unconditional gate before every same-layout app update. Desktop
startup separately invokes a safety backup when SQL migrations are pending; it
aborts those migrations if the backup fails.

Legacy migration state is still marked complete after copying, before later
MariaDB startup validation. Do not interpret this record as a complete readiness
or restore test.

---

# 15. User Documentation Requirement

User-facing workflows must be documented when they affect installation, backup, restore, upgrade, privacy, support or data ownership.

Documentation is part of the operational contract.

A feature that changes how users install, protect or recover their data is incomplete until the relevant user documentation is updated.

---

# 16. Non-Goals

The system does not aim to:

* Optimise for rapid prototyping
* Allow manual undocumented changes
* Sacrifice correctness for convenience

---

# Final Principle

OrchidApp is designed for:

* Determinism
* Invariant safety
* Operational resilience
* Long-term maintainability

Correctness is preferred over convenience.

## Implementation references

| Concern | Main implementation |
| --- | --- |
| Web host, configuration and Desktop bootstrap | `src/OrchidApp.Web/Program.cs` |
| Database mappings and procedure execution | `src/OrchidApp.Web/Data/OrchidDbContext.cs`, `src/OrchidApp.Web/Infrastructure/StoredProcedureExecutor.cs` |
| Image processing | `src/OrchidApp.Web/Services/PhotoPipeline.cs` |
| Layout detection and legacy migration | `src/OrchidApp.Launcher/OrchidAppLayoutResolver.cs`, `src/OrchidApp.Launcher/OrchidAppLauncherForm.cs` |
| Windows backup/restore | `app/tools/backup-orchidapp.ps1`, `app/tools/restore-orchidapp.ps1` |
| Product/build version metadata | `Directory.Build.props`, `scripts/package-windows.ps1`, `scripts/package-linuxpi.ps1` |
| CI coverage | `.github/workflows/ci.yml` |

This review checks source consistency. It does not certify a previously built
installer, production database or full device recovery. Recheck the affected
sections whenever these implementations change.
