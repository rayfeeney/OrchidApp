# Architecture

- [Architecture](#architecture)
- [Architectural Summary](#architectural-summary)
  - [Environment Configuration Requirement](#environment-configuration-requirement)
  - [Application Health Requirement](#application-health-requirement)
  - [Logging Requirement](#logging-requirement)
  - [Security Model](#security-model)
- [1. Database Layer - Invariant Core](#1-database-layer---invariant-core)
    - [Authoritative Environment](#authoritative-environment)
- [2. Migration System - Controlled Evolution](#2-migration-system---controlled-evolution)
    - [Critical Rule - Database Creation vs Evolution](#critical-rule---database-creation-vs-evolution)
    - [Critical Design Constraint](#critical-design-constraint)
- [3. Schema Export - Deterministic Representation](#3-schema-export---deterministic-representation)
- [4. Temporal Model - Contractual Behaviour](#4-temporal-model---contractual-behaviour)
- [5. Lifecycle Model - Structural Rules](#5-lifecycle-model---structural-rules)
  - [Split Semantics](#split-semantics)
  - [Propagation Semantics](#propagation-semantics)
  - [Location History](#location-history)
- [6. Photo \& Hero Image Model](#6-photo--hero-image-model)
- [6A. Canonical Photo Ingestion Architecture](#6a-canonical-photo-ingestion-architecture)
    - [Processing Model](#processing-model)
    - [Canonical Output](#canonical-output)
    - [Operational Model](#operational-model)
- [7. Write Strategy - Responsibility Separation](#7-write-strategy---responsibility-separation)
  - [Atomic Entities](#atomic-entities)
  - [Structural Entities](#structural-entities)
- [8. Application Layer - Behavioural Orchestration](#8-application-layer---behavioural-orchestration)
- [9. UI Architecture - Navigation Contract](#9-ui-architecture---navigation-contract)
- [10. Versioning Contract](#10-versioning-contract)
- [11. Windows installer-led upgrade safety](#11-windows-installer-led-upgrade-safety)
- [12. Runtime Hosting Requirement](#12-runtime-hosting-requirement)
  - [12A. Packaged Application Model](#12a-packaged-application-model)
- [13. Automation Layer - Enforcement Mechanism](#13-automation-layer---enforcement-mechanism)
- [14. Operations Layer - State Protection](#14-operations-layer---state-protection)
  - [Upgrade Safety Requirement](#upgrade-safety-requirement)
- [15. User Documentation Requirement](#15-user-documentation-requirement)
- [16. Non-Goals](#16-non-goals)
- [Final Principle](#final-principle)

---

This document defines the **architectural contract** of OrchidApp.

It specifies the structural boundaries, invariants, enforcement
mechanisms and operational guarantees that govern the system.

This is not a how-to guide.
This is the non-negotiable design of the system.

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

## Environment Configuration Requirement

All runtime configuration must be provided externally via environment variables or configuration files (e.g. `.env`).

The application must not rely on hardcoded environment-specific values.

A valid deployment must ensure:

* All required configuration values are explicitly provided
* Missing or invalid configuration causes application startup failure
* File system paths (e.g. UploadRoot) are validated before use
* Database connection settings are externally configurable

Configuration is part of the deployment contract and must be consistent across environments.

---

## Application Health Requirement

OrchidApp must validate its operational readiness at startup and expose a clear health signal.

A valid deployment must ensure:

* Database connectivity is verified at startup
* Required filesystem paths (e.g. UploadRoot) are validated
* Critical dependencies required for core functionality are checked
* Startup must fail if required components are unavailable

The application should expose a simple health endpoint or equivalent mechanism where the hosting model supports it.

---

## Logging Requirement

OrchidApp must produce structured logs for all critical system operations.

A valid deployment must ensure:

* Application startup events are logged
* Configuration and dependency validation failures are logged
* Database connectivity and operational errors are logged
* File system operations (e.g. image ingestion) are logged
* Backup and restore processes produce verifiable logs

Logs must support diagnosis without exposing sensitive information.

Logging is a core operational capability.

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

Windows MySQL behaviour must not be relied upon.

---

# 2. Migration System - Controlled Evolution

Schema evolution for existing databases is controlled exclusively through deterministic migration files:

```
database/migrations/
```

Each migration:

* Follows naming format `YYYYMMDDHHMM_Name.sql`
* Is applied exactly once
* Is recorded in the `schemaversion` table
* Has its SHA256 checksum stored and enforced

The system prevents:

* Out-of-order execution
* Duplicate timestamps
* Silent historical modification
* Schema drift prior to execution

### Critical Rule - Database Creation vs Evolution

A database must be managed using **one and only one** of the following strategies:

* **Rebuild** - construct from canonical schema
* **Migrations** - evolve an existing database

These mechanisms must **never be combined on the same database**.

### Critical Design Constraint

Migrations are not a construction mechanism.

Fresh installations and rebuilds use the canonical schema export:

```
database/schema/
```

Historical migrations must never be edited after application.

The production database must never be modified outside this system.

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
All temporal invariants are database-enforced.

---

# 5. Lifecycle Model - Structural Rules

A plant has a single immutable lifecycle:

```
startDateTime → endDateTime
```

## Split Semantics

* A split ends the parent lifecycle
* Creates two or more new plants
* A plant may be split at most once
* Children are independent entities

## Propagation Semantics

* Propagation creates a new plant
* Parent lifecycle continues unchanged
* A plant may have at most one propagation record

## Location History

* Enforces strict temporal adjacency
* No overlaps permitted
* Structural updates must be performed via stored procedures
* UI remains dumb; SQL enforces invariants

These rules are database-enforced and non-negotiable.

---

# 6. Photo & Hero Image Model

Photos are attached only via Observation events.

Rules:

* Stored in `plantphoto`
* Each photo belongs to exactly one Observation
* Hero image selection is explicit (`isHero`)
* At most one active hero image per plant
* No automatic “latest photo” inference

---

# 6A. Canonical Photo Ingestion Architecture

Image ingestion is a data integrity concern.

All images are normalised into a single canonical representation.

### Processing Model

* **libvips (NetVips)**

### Canonical Output

* Max dimension: 3072px
* Format: JPEG
* Quality: 90
* Metadata removed
* Alpha flattened
* Multi-frame rejected

Original uploads are not retained.

### Operational Model

* Local filesystem only
* Included in backups
* No CDN
* No async pipelines

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

* Duplicate constraints
* Override lifecycle rules
* Reinterpret temporal behaviour

---

# 9. UI Architecture - Navigation Contract

UI follows strict patterns:

* One primary action per page
* One exit action per page
* No duplicated controls
* Mobile-first layout

Navigation is enforced through shared components.

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

If the public product version is unchanged during packaging, the internal build number is incremented.

If a new public product version is supplied during packaging, the internal build number resets to zero.

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

For the implemented v1.2 safety model, if both a data-bearing legacy layout and a ProgramData layout are detected, the launcher stops safely.

This conservative behaviour prevents accidental use of the wrong data layout.

Legacy migration is copy-only.

The launcher does not delete, move or rename the old legacy data.

Migration state is written to:

```
C:\ProgramData\OrchidApp\migration-state.json
```

The current implementation records migration completion after successful legacy data copy.

Post-copy MariaDB startup verification before marking migration complete is a post-v1.2 hardening follow-up.

A mandatory ProgramData-to-ProgramData pre-upgrade backup gate for future upgrades is also a post-v1.2 follow-up.


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

## 12A. Packaged Application Model

OrchidApp supports a packaged Windows deployment model.

In this model:

* Application files are replaceable
* User data is persistent
* Database files and uploaded images are canonical state
* Local launcher/application settings are runtime configuration
* Upgrades must preserve user data
* The installer owns application files only
* The launcher owns user-data safety

On Windows, replaceable application files are installed under:

```
C:\Program Files\OrchidApp
```

Durable user data is stored under:

```
C:\ProgramData\OrchidApp
```

Application binaries, runtime files and generated package contents must never be treated as equivalent to user data.

The packaged Windows application must not assume that user data is located beside the application binaries.

The launcher must pass resolved runtime paths to the web application where required.

For uploads, the packaged Windows launcher provides:

```
ORCHIDAPP_UPLOAD_ROOT
```

with the value:

```
C:\ProgramData\OrchidApp\uploads
```

ZIP-style or folder-based package output may remain for development and testing.

It is not the public Windows upgrade route.

---

# 13. Automation Layer - Enforcement Mechanism

Automation enforces architectural guarantees through:

* Pre-commit hooks
* Deterministic schema export
* SHA256 checksum enforcement
* CI rebuild validation in a clean MariaDB environment
* Application build and startup validation

CI validates:

* Schema can be rebuilt from committed artefacts
* Application builds and runs against that schema

CI does not replay historical migrations on rebuilt schema.

Migration correctness is validated through:

* The migration runner
* Checksum enforcement
* Controlled upgrade testing

GitHub CI is the authoritative automated validation environment.

Local validation scripts may exist for developer convenience, but they are not currently part of the architectural enforcement contract unless explicitly documented as maintained and equivalent to CI.

---

# 14. Operations Layer - State Protection

Windows packaged deployments support local backup creation, mandatory pre-upgrade backup before legacy migration and optional copy of the latest backup to a user-configured cloud-synchronised folder.

Normal Windows backups use:

```
C:\ProgramData\OrchidApp\data\mariadb
C:\ProgramData\OrchidApp\uploads
C:\ProgramData\OrchidApp\launcher-settings.json
```

Normal Windows backup ZIPs are written to:

```
C:\ProgramData\OrchidApp\backups
```

Legacy migration pre-upgrade backups are written to:

```
C:\ProgramData\OrchidApp\backups\pre-upgrade
```

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

For the implemented Windows v1.2 model, mandatory pre-upgrade backup is enforced before legacy app-root to ProgramData migration.

A mandatory ProgramData-to-ProgramData pre-upgrade backup gate for later application upgrades is a post-v1.2 follow-up.

Post-copy MariaDB startup verification before marking migration state as complete is also a post-v1.2 follow-up.

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
