# OrchidApp

OrchidApp is a self-hosted web application for managing an orchid collection with **database-enforced lifecycle integrity**.

It is a production-grade system backed by a rigorously designed, migration-controlled and operationally validated MariaDB schema.

The system is deliberately opinionated.

> Invariants live in the database.
> Behaviour lives in the application.
> Enforcement lives in automation.

---

## Production Status

* ASP.NET Core Razor Pages (.NET LTS)
* EF Core for atomic entities
* Stored procedures for structural entities
* MariaDB (Linux) authoritative environment
* Deterministic migration system with checksum enforcement
* Automated nightly encrypted backups (database + uploads)
* Restore process validated
* Mobile-first UI design
* Deterministic deployment model (systemd + environment file)

OrchidApp is deployed and operational on Raspberry Pi (Linux).

---

## System Guarantees

* The database schema can be rebuilt from scratch at any commit
* Production state is fully recoverable from backups
* Schema drift cannot occur silently
* Lifecycle invariants cannot be bypassed
* All structural changes are traceable via migrations

Correctness is enforced by design, not convention.

---

## State Model

The system has exactly two stateful components:

* MariaDB database (`orchids`)
* Uploads directory

Everything else is rebuildable from Git.

---

## Architecture Overview

The system is intentionally layered:

* **Database layer** — enforces invariants and lifecycle rules
* **Application layer** — orchestrates valid workflows
* **Automation layer** — enforces reproducibility and drift detection
* **Operations layer** — backup, restore and deployment discipline

No layer may weaken the guarantees of another.

---

## Environment Model

| Environment | Platform     | Configuration                            |
| ----------- | ------------ | ---------------------------------------- |
| Development | Windows PC   | `appsettings.Development.json`           |
| Production  | Raspberry Pi | systemd + `/etc/orchidapp/orchidapp.env` |

Rules:

* Production never depends on Development configuration
* Secrets are never committed to Git
* Production configuration is supplied via environment variables only

---

## Database Layer (MariaDB)

### Authoritative Environment

MariaDB running on Linux is the authoritative validator for:

* Identifier casing
* Collation behaviour
* Stored procedure parsing

Windows MySQL behaviour must not be relied upon.

---

### Required Configuration

MariaDB must be configured with:

```sql
character-set-server = utf8mb4
collation-server     = utf8mb4_unicode_ci
```

If this is not configured correctly, stored procedures and comparisons may fail.

---

### Core Principles

1. The schema is treated as source code
2. Every committed version can be rebuilt from scratch
3. Drift between environments is detected automatically
4. Structural invariants are enforced in the database

---

## Migration System

All structural schema changes are implemented via deterministic migration files:

```
database/migrations/
```

Each migration:

* Follows naming convention `YYYYMMDDHHMM_Name.sql`
* Is applied exactly once
* Is recorded in the `schemaversion` table
* Has its SHA256 checksum stored and enforced

The system prevents:

* Out-of-order migrations
* Duplicate timestamps
* Silent modification of historical migrations
* Schema drift prior to execution

Migrations are not intended to construct the database from scratch.
They apply only to existing databases created from the canonical schema.

Production databases must never be modified outside the migration system.

---

## Schema Export & Enforcement

Schema files under:

```
database/schema/
```

are generated artefacts.

They:

* Represent the full assembled schema
* Must never be edited manually
* Are regenerated deterministically
* Are validated in CI

Pre-commit hooks enforce export and validation.

The schema export represents the canonical database definition.

Rebuild uses this definition to construct a database from scratch.
Migrations evolve databases forward from that baseline.

---

## Lifecycle Model

A plant has a single immutable lifecycle:

```
startDateTime → endDateTime
```

Rules:

* A split ends a lifecycle and creates new plants
* A plant may be split at most once
* Propagation creates new plants without ending the parent
* A plant may have at most one propagation record
* Location history enforces strict temporal adjacency
* Structural lifecycle changes are executed exclusively via stored procedures

These invariants are database-enforced and non-negotiable.

---

## Photo & Hero Image Model

* Photos are attached only via Observation events
* Photos are stored in `plantphoto`
* Each photo belongs to exactly one Observation
* Hero image selection is explicit (`isHero` flag)
* At most one active hero image per plant
* No automatic “latest photo” inference

Heavy photo loading is isolated to dedicated pages.

---

## File Storage

Uploads are stored on the local filesystem.

### Configuration

```
StorageSettings__UploadRoot=/opt/orchidapp/uploads
```

### Behaviour

* Files are organised as:

```
plants/{plantId}
taxa/{taxonId}
```

### Requirements

* Directory must exist before startup
* Application must have read/write permissions
* Invalid configuration causes startup or upload failure

Uploads are part of the canonical dataset and included in backups.

---

## Canonical Image Pipeline

All uploaded images are normalised into a single canonical representation.

### Specification

* Max dimension: 3072px (longest side)
* Format: JPEG
* Quality: 90
* Metadata: stripped
* Colour profile: preserved
* Alpha: flattened to white
* Animated images: rejected
* Originals: not stored

### Processing

* **libvips (NetVips)** is used for all image processing

This ensures:

* Low memory usage
* Deterministic output
* Consistent rendering across platforms

### Error Handling

The pipeline must:

* Fail fast on invalid media
* Never create partial files
* Never leak temporary files

User-visible message:

> The photo could not be processed.

---

## Write Strategy

* Atomic entities (e.g. `plantevent`) may be written via EF Core
* Structural or temporal entities must be written via stored procedures

Stored procedures:

* Enforce invariants
* Execute atomically
* Reject invalid transitions

Triggers may enforce low-level invariants but must not implement domain behaviour.

---

## Web Application Layer

* ASP.NET Core Razor Pages
* Mobile-first UI
* Environment-driven configuration
* Explicit startup validation
* Database treated as authoritative

The application must not reinterpret or override database rules.

---

## Deployment Model

### Fresh Install

* Rebuild schema from exported artefacts
* No migrations applied

### Upgrade

* Apply migrations
* Publish application
* Restart service

---

### Deterministic Deployment

A correct application deployment consists only of:

```
git pull
dotnet publish -c Release -o ./publish
sudo systemctl restart orchidapp
```

Database changes must be applied separately via migrations.

---

## Backups

Nightly automated backup system:

* MariaDB snapshot (`mysqldump --single-transaction --routines --triggers`)
* gzip compression
* Encrypted via rclone
* Uploaded to OneDrive
* 14-day retention (database)
* Encrypted mirror of uploads directory

Backups are only valid if restore tests succeed.
Backups must include both the database and uploads directory.

---

## Restore Validation

After restore:

```sql
SELECT scriptName FROM schemaversion ORDER BY appliedAt;
```

Migration history must match repository state.

Application binaries are rebuilt from Git.

---

## Development Workflow

After cloning:

```
pwsh scripts/setup.ps1
```

Local validation:

```
pwsh scripts/ci-local.ps1
```

CI behaviour:

* Rebuilds schema in clean MariaDB instance
* Validates generated artefacts
* Detects drift

If it fails locally, it will fail in CI.

---

## What This Project Is

* A strict, reproducible, production-ready system
* A learning and reference implementation
* Designed for correctness over convenience

## What This Project Is Not

* A rapid prototyping sandbox
* Tolerant of undocumented manual changes
* Flexible about bypassing enforcement

---

## Architectural Principle

> Invariants live in the database.
> Behaviour lives in the application.
> Enforcement lives in automation.

Everything else follows from that.

---

## Third Party Licences

See `THIRD_PARTY_NOTICES.md`
