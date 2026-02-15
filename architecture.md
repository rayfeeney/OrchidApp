# Architecture

This document defines the architectural contract of OrchidApp.

It explains the structural boundaries, invariants, enforcement
mechanisms, and operational guarantees that govern the system.

This is not a how-to guide.\
It is the non-negotiable design philosophy of the system.

------------------------------------------------------------------------

# Architectural Summary

OrchidApp is a layered system built around a strict principle:

> Invariants live in the database.\
> Behaviour lives in the application.\
> Enforcement lives in automation.

The architecture deliberately separates responsibility across four
layers:

1.  **Database Layer** --- structural integrity and lifecycle invariants
2.  **Application Layer** --- behavioural workflows
3.  **Automation Layer** --- reproducibility and validation
4.  **Operations Layer** --- backup, restore, and deployment discipline

No layer may weaken another.

------------------------------------------------------------------------

# 1. Database Layer --- Invariant Core

The MariaDB schema is the authoritative source of truth.

It is responsible for:

-   Structural integrity
-   Lifecycle enforcement
-   Temporal adjacency rules
-   Split and propagation semantics
-   Preventing invalid state transitions

The database is treated as source code.

It must be reproducible, deterministic, and resistant to drift.

## Authoritative Environment

MariaDB running on Linux is the authoritative validator for:

-   Identifier casing
-   Collation behaviour
-   Stored procedure parsing
-   Trigger semantics

Windows MySQL behaviour must not be relied upon.

------------------------------------------------------------------------

# 2. Migration System --- Controlled Evolution

Schema evolution is controlled exclusively through deterministic
migration files:

    database/migrations/

Each migration:

-   Follows naming format `YYYYMMDDHHMM_Name.sql`
-   Is applied exactly once
-   Is recorded in the `schemaversion` table
-   Has its SHA256 checksum stored and enforced

The migration system prevents:

-   Out-of-order execution
-   Duplicate timestamps
-   Silent historical modification
-   Schema drift prior to execution

The production database must never be modified outside this system.

------------------------------------------------------------------------

# 3. Schema Export --- Deterministic Representation

Schema files under:

    database/schema/

are generated artefacts.

They:

-   Represent the assembled schema
-   Are regenerated deterministically
-   Must never be edited manually
-   Are validated in CI

Generated artefacts are inputs to validation, not authoring surfaces.

------------------------------------------------------------------------

# 4. Lifecycle Model --- Structural Rules

A plant has a single immutable lifecycle:

    startDateTime → endDateTime

## Split Semantics

-   A split ends the parent lifecycle
-   Creates two or more new plants
-   A plant may be split at most once
-   Children are independent entities with new identities

## Propagation Semantics

-   Propagation creates a new plant
-   Parent lifecycle continues unchanged
-   A plant may have at most one propagation record
-   Supports one or two parent plants
-   Designed for future extensibility without breaking invariants

## Location History

-   Enforces strict temporal adjacency
-   No overlaps permitted
-   Structural updates must be performed via stored procedures
-   UI must remain "dumb"; SQL enforces invariants

These rules are enforced at the database level and are non-negotiable.

------------------------------------------------------------------------

# 5. Photo & Hero Image Model

Photos are attached only via Observation events.

Rules:

-   Stored in `plantphoto`
-   Each photo belongs to exactly one Observation
-   Hero image selection is explicit (`isHero` flag)
-   At most one active hero image per plant
-   No automatic "latest photo" inference
-   Heavy image browsing isolated to dedicated photo pages

The database enforces ownership and uniqueness constraints. The
application controls selection behaviour only within those constraints.

------------------------------------------------------------------------

# 6. Write Strategy --- Responsibility Separation

## Atomic Entities

Entities without cross-row invariants (e.g. `plantevent`) may be written
via EF Core.

## Structural / Temporal Entities

Entities that enforce adjacency, lifecycle termination, or identity
branching must:

-   Be written exclusively via stored procedures
-   Encapsulate invariant logic inside SQL
-   Reject invalid transitions atomically

Examples include:

-   plantlocationhistory
-   plantsplit
-   propagation records

Triggers may enforce absolute invariants, but must not implement domain
behaviour.

------------------------------------------------------------------------

# 7. Application Layer --- Behavioural Orchestration

The ASP.NET Core Razor Pages application:

-   Orchestrates valid workflows
-   Presents lifecycle and taxonomy concepts
-   Invokes stored procedures for structural changes
-   Uses EF Core for atomic writes
-   Respects environment separation (Development vs Production)

The application must not:

-   Duplicate database constraints
-   Override lifecycle rules
-   Compensate for invalid state in application code

Correctness is enforced at the data layer.

------------------------------------------------------------------------

# 8. Automation Layer --- Enforcement Mechanism

Automation enforces architectural guarantees through:

-   Pre-commit hooks
-   Deterministic schema export
-   Migration validation
-   SHA256 checksum enforcement
-   CI rebuild validation via Docker

Local validation mirrors CI exactly.

If validation fails locally, it will fail in CI.

Automation is not optional. It is architectural enforcement.

------------------------------------------------------------------------

# 9. Operations Layer --- State Protection

OrchidApp maintains two stateful components:

-   MariaDB database (`orchids`)
-   Uploads directory

The system includes:

-   Nightly encrypted database snapshots
-   Encrypted uploads mirror
-   14-day retention for database backups
-   Quarterly restore validation requirement

Application binaries are rebuilt from Git. Only database and uploads
represent persistent state.

Backups are only considered valid if restores succeed.

------------------------------------------------------------------------

# 10. Non-Goals

This architecture does not aim to:

-   Optimise for rapid prototyping
-   Tolerate undocumented manual processes
-   Allow application logic to override data correctness
-   Reduce enforcement for convenience

Restrictions are intentional.

------------------------------------------------------------------------

# 11. Evolution Strategy

Change is permitted, but not everywhere equally.

-   Database layer changes are high impact and cautious.
-   Application layer changes may evolve more rapidly.
-   Migration discipline must never be weakened.
-   Documentation must reflect operational reality.

Architecture is stable, but implementation may refine.

------------------------------------------------------------------------

# Final Principle

OrchidApp is designed for:

-   Determinism
-   Invariant safety
-   Operational resilience
-   Long-term maintainability

Correctness is preferred over convenience. Reproducibility is preferred
over speed. Explicitness is preferred over ambiguity.

------------------------------------------------------------------------