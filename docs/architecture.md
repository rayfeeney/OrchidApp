# Architecture

This document defines the architectural contract of OrchidApp.

It explains the structural boundaries, invariants, enforcement
mechanisms and operational guarantees that govern the system.

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
4.  **Operations Layer** --- backup, restore and deployment discipline

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

It must be reproducible, deterministic and resistant to drift.

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

## Stored Procedure Invocation Contract

The application must invoke stored procedures using a strict and
consistent EF Core execution model.

Two invocation patterns are permitted:

1. Command procedures (no result sets)

   These must be executed using:

       Database.ExecuteSqlRawAsync(...)

   This applies to all structural mutations, lifecycle operations,
   and invariant-enforcing transitions.

2. Result-set procedures

   Procedures that return rows must be executed using:

       DbSet/KeylessEntity.FromSqlRaw(...).<async materialiser>

   This applies to read projections, lookup retrieval and reporting
   queries implemented as stored procedures.

All database calls must be asynchronous.

Synchronous execution is not permitted.

Manual ADO.NET command execution is not permitted, as it bypasses
transactional coordination, logging consistency and architectural
enforcement boundaries.

Interpolated execution patterns are not part of the project standard.

Try/catch handling must only be used where database-level business rule
violations need to be translated into user-facing validation or workflow
messages.

Unexpected failures must be allowed to surface through the application’s
standard error pipeline.

This contract defines the application–database command boundary and must
remain uniform across the codebase.

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

# 8. UI Architecture — Navigation Contract

OrchidApp enforces a strict and consistent navigation layout across all
Razor Pages.

Navigation behaviour is considered part of the architectural contract.
It must not drift through ad hoc styling or per-page experimentation.

The UI layer must remain predictable, mobile-friendly and structurally
consistent.

### Navigation Design Principles

-   One primary action per page.
-   One exit action per page.
-   No duplicate navigation controls.
-   No mixed button sizing.
-   No contextual improvisation.

Layout consistency is enforced through shared Razor partials.

### Page Type A — Navigation List Pages

Examples include listing and index-style pages.

Rules:

-   A single Back control is permitted.
-   The Back control must appear at the bottom of the page.
-   It must be full-width.
-   It must use consistent sizing (`btn-lg`).
-   Duplicate top and bottom Back controls are not permitted.

These pages are navigation-focused and should not introduce competing
actions.

### Page Type B — Form Pages (Add / Edit / Remove)

Form pages follow a strict action layout:

-   Back action on the bottom left.
-   Save action on the bottom right.
-   Both buttons use consistent sizing (`btn-lg`).
-   Cancel buttons are not used.
-   Save represents the single primary action.

Back behaviour must use the `returnUrl` pattern where applicable.

Button placement must not vary between mobile and desktop layouts.

### Page Type C — Destructive Form Pages

Destructive operations (e.g. Split) follow the same structural layout
as Form Pages, with the following modification:

-   The primary action must use danger styling (`btn-danger`).

No additional warning buttons are permitted.

### Page Type D — Content Pages

Content-heavy pages (e.g. Photo browsing):

-   Present content first.
-   Provide a single full-width Back control beneath primary content.
-   Must not interrupt content flow with premature navigation controls.

### ReturnUrl Pattern

Pages that provide a Back control must support a `returnUrl`
parameter.

Rules:

-   Navigating pages must pass returnUrl explicitly.
-   Back controls must honour returnUrl when present.
-   A deterministic fallback must exist for deep links.
-   JavaScript-based navigation history is not permitted.

Navigation state must remain server-driven and explicit.

### Enforcement

Navigation layout must be implemented exclusively through shared
partials located under:

````
/Pages/Shared/
````

Per-page button markup duplication is not permitted.

Any new page must conform to one of the defined page types above.

------------------------------------------------------------------------

# 9. Automation Layer --- Enforcement Mechanism

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

# 10. Operations Layer --- State Protection

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

# 11. Non-Goals

This architecture does not aim to:

-   Optimise for rapid prototyping
-   Tolerate undocumented manual processes
-   Allow application logic to override data correctness
-   Reduce enforcement for convenience

Restrictions are intentional.

------------------------------------------------------------------------

# 12. Evolution Strategy

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
