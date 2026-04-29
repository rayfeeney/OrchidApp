# Architecture

This document defines the architectural contract of OrchidApp.

It explains the structural boundaries, invariants, enforcement
mechanisms and operational guarantees that govern the system.

This is not a how-to guide.
It is the non-negotiable design philosophy of the system.

---

# Architectural Summary

OrchidApp is a layered system built around a strict principle:

> Invariants live in the database.
> Behaviour lives in the application.
> Enforcement lives in automation.

The architecture deliberately separates responsibility across four
layers:

1. **Database Layer** — structural integrity and lifecycle invariants
2. **Application Layer** — behavioural workflows
3. **Automation Layer** — reproducibility and validation
4. **Operations Layer** — backup, restore and deployment discipline

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

Configuration is considered part of the deployment contract and must be consistent across environments.

---

## Application Health Requirement

OrchidApp must validate its operational readiness at startup and expose a clear health signal.

A valid deployment must ensure:

* Database connectivity is verified at startup
* Required filesystem paths (e.g. UploadRoot) are validated
* Critical dependencies required for core functionality are checked
* Startup must fail if required components are unavailable

The application must provide a simple health endpoint or equivalent mechanism to confirm that the system is operational.

---

## Logging Requirement

OrchidApp must produce structured logs for all critical system operations.

A valid deployment must ensure:

* Application startup events are logged
* Configuration and dependency validation failures are logged
* Database connectivity and operational errors are logged
* File system operations (e.g. image ingestion) are logged
* Backup and restore processes produce verifiable logs

Logs must provide sufficient detail for diagnosis without exposing sensitive information.

Logging is considered a core operational capability of the system.

---

## Security Model

OrchidApp is designed for deployment within a trusted home network environment.

The system assumes:

* The application is not exposed directly to the public internet
* Access is restricted to trusted users within the local network
* No built-in authentication or authorisation mechanisms are enforced by default

Operational responsibility for network-level security lies with the deployment environment (e.g. router configuration, firewall rules).

---

# 1. Database Layer — Invariant Core

The MariaDB schema is the authoritative source of truth.

It is responsible for:

* Structural integrity
* Lifecycle enforcement
* Temporal adjacency rules
* Split and propagation semantics
* Preventing invalid state transitions

The database is treated as source code.

It must be reproducible, deterministic and resistant to drift.

### Authoritative Environment

MariaDB running on Linux is the authoritative validator for:

* Identifier casing
* Collation behaviour
* Stored procedure parsing
* Trigger semantics

Windows MySQL behaviour must not be relied upon.

---

# 2. Migration System — Controlled Evolution

Schema evolution for existing installations is controlled exclusively through deterministic migration files:

```
database/migrations/
```

Migrations are the only permitted mechanism for upgrading a running database.

Each migration:

* Follows naming format `YYYYMMDDHHMM_Name.sql`
* Is applied exactly once
* Is recorded in the `schemaversion` table
* Has its SHA256 checksum stored and enforced

The migration system prevents:

* Out-of-order execution
* Duplicate timestamps
* Silent historical modification
* Schema drift prior to execution

### Critical Design Constraint

Migrations are not a database construction mechanism.

Fresh installations and rebuilds use the canonical schema export under:

```
database/schema/
```

Historical migrations must not be edited after they have been applied to any real environment.

The production database must never be modified outside this system.

---

# 3. Schema Export — Deterministic Representation

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

The schema export represents the complete canonical database definition used for:

* Fresh installations
* Full rebuilds
* CI validation

It is intentionally separate from migrations.

Rebuild validates the assembled schema.
Migrations evolve already-existing databases.

---

# 4. Lifecycle Model — Structural Rules

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

# 5. Photo & Hero Image Model

Photos are attached only via Observation events.

Rules:

* Stored in `plantphoto`
* Each photo belongs to exactly one Observation
* Hero image selection is explicit (`isHero`)
* At most one active hero image per plant
* No automatic “latest photo” inference

---

# 5A. Canonical Photo Ingestion Architecture

Image ingestion is a data integrity concern.

All images are normalised into a single canonical representation.

### Processing Model

Photo ingestion uses a single imaging engine:

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

# 6. Write Strategy — Responsibility Separation

## Atomic Entities

May be written via EF Core.

## Structural Entities

Must be written via stored procedures.

Stored procedures:

* Enforce invariants
* Execute atomically
* Reject invalid transitions

---

# 7. Application Layer — Behavioural Orchestration

The application:

* Orchestrates workflows
* Invokes stored procedures for structural changes
* Uses EF Core for atomic writes
* Treats database as authoritative

The application must not:

* Duplicate constraints
* Override lifecycle rules

---

# 8. UI Architecture — Navigation Contract

UI follows strict, consistent patterns:

* One primary action per page
* One exit action per page
* No duplicated controls
* Mobile-first layout

Navigation is enforced through shared partials.

---

# 9. Runtime Hosting Requirement

The application must:

* Run continuously
* Start on boot
* Be network accessible
* Restart automatically on failure

---

# 10. Automation Layer — Enforcement Mechanism

Automation enforces architectural guarantees through:

* Pre-commit hooks
* Deterministic schema export
* SHA256 checksum enforcement
* CI rebuild validation in a clean MariaDB environment
* Application build and startup validation

CI validates:

* The schema can be rebuilt from committed artefacts
* The application builds and runs against that schema

CI does not replay historical migrations on top of the rebuilt schema.

Migration correctness is validated through:

* the migration runner
* checksum enforcement
* controlled upgrade testing

Local validation mirrors CI exactly.

---

# 11. Operations Layer — State Protection

Stateful components:

* MariaDB database
* Uploads directory

The system includes:

* Encrypted backups
* Retention policy
* Restore validation

Backups are only valid if restores succeed.

---

# 12. Non-Goals

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
