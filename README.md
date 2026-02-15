# OrchidApp

OrchidApp is a production-grade web application backed by a rigorously
designed, migration-controlled, and operationally validated MariaDB
database schema.

The system is deliberately opinionated. Invariants live in the database.
Behaviour lives in the application. Enforcement lives in automation.

------------------------------------------------------------------------

## Production Status

-   ASP.NET Core Razor Pages (.NET LTS)
-   EF Core for atomic entities
-   Stored procedures for structural entities
-   MariaDB (Linux) authoritative environment
-   Deterministic migration system with checksum enforcement
-   Automated nightly encrypted backups (database + uploads)
-   Restore process validated
-   Mobile-first UI design

OrchidApp is deployed and operational on Raspberry Pi (Linux).

------------------------------------------------------------------------

# Architecture Overview

The system is layered intentionally:

-   **Database layer** --- enforces invariants and lifecycle rules
-   **Application layer** --- orchestrates valid workflows
-   **Automation layer** --- enforces reproducibility and drift
    detection
-   **Operations layer** --- backup, restore, and deployment discipline

No layer may weaken the guarantees of another.

------------------------------------------------------------------------

# Database Layer (MariaDB)

## Authoritative Environment

MariaDB running on Linux is the authoritative validator for:

-   Identifier casing
-   Collation behaviour
-   Stored procedure parsing

Windows MySQL behaviour must not be relied upon.

------------------------------------------------------------------------

## Core Principles

1.  The schema is treated as source code.
2.  Every committed version can be rebuilt from scratch.
3.  Drift between environments is detected automatically.
4.  Structural invariants are enforced in the database, not the
    application.

------------------------------------------------------------------------

# Migration System

All structural schema changes are implemented via deterministic
migration files:

    database/migrations/

Each migration file:

-   Follows naming convention `YYYYMMDDHHMM_Name.sql`
-   Is applied exactly once
-   Is recorded in the `schemaversion` table
-   Has its SHA256 checksum stored and enforced

The system prevents:

-   Out-of-order migrations
-   Duplicate timestamps
-   Silent modification of historical migrations
-   Schema drift prior to migration execution

Migrations are applied by piping directly into `mysql`, mirroring
production behaviour.

The production database must never be modified outside the migration
system.

------------------------------------------------------------------------

# Schema Export & Enforcement

Schema files under:

    database/schema/

are generated artefacts.

They:

-   Represent the full assembled schema
-   Must never be edited manually
-   Are regenerated deterministically
-   Are validated in CI

Pre-commit hooks enforce export and validation. Bypassing hooks is not
permitted.

------------------------------------------------------------------------

# Lifecycle Model

A plant has a single immutable lifecycle:

    startDateTime → endDateTime

Rules:

-   A split ends a lifecycle and creates new plants
-   A plant may be split at most once
-   Propagation creates new plants without ending the parent
-   A plant may have at most one propagation record
-   Location history enforces strict temporal adjacency
-   Structural lifecycle changes are executed exclusively via stored
    procedures

These invariants are database-enforced and non-negotiable.

------------------------------------------------------------------------

# Photo & Hero Image Model

-   Photos are attached only via Observation events
-   Photos are stored in `plantphoto`
-   Each photo belongs to exactly one Observation
-   Hero image selection is explicit (`isHero` flag)
-   At most one active hero image per plant
-   No automatic "latest photo" inference

Heavy photo loading is isolated to dedicated pages.

------------------------------------------------------------------------

# Write Strategy

-   Atomic entities (e.g. `plantevent`) may be written via EF Core
-   Temporal or structural entities (e.g. `plantlocationhistory`,
    `plantsplit`, propagation) must be written via stored procedures
-   Triggers may enforce absolute invariants but must not implement
    domain behaviour

------------------------------------------------------------------------

# Web Application Layer

-   ASP.NET Core Razor Pages
-   Mobile-first UI patterns
-   Environment-based configuration (Development / Production)
-   Stored procedures invoked where structural invariants are required
-   Database treated as authoritative

The application must not reinterpret or override database rules.

------------------------------------------------------------------------

# Operations

## Backups

Nightly automated backup system:

-   MariaDB snapshot
    (`mysqldump --single-transaction --routines --triggers`)
-   gzip compression
-   Encrypted via rclone crypt
-   Uploaded to OneDrive
-   14-day retention (database)
-   Encrypted mirror for uploads folder
-   Quarterly restore validation required

Backups are only considered valid if restore tests succeed.

------------------------------------------------------------------------

## Restore Validation

After restore:

    SELECT scriptName FROM schemaversion ORDER BY appliedAt;

Migration history must match repository state.

Application binaries are rebuilt from Git. Only database and uploads are
stateful.

------------------------------------------------------------------------

# Development Workflow

After cloning:

    pwsh scripts/setup.ps1

This configures tooling and installs enforced Git hooks.

Local CI validation:

    pwsh scripts/ci-local.ps1

If it fails locally, it will fail in CI.

------------------------------------------------------------------------

# What This Project Is

-   A strict, reproducible, production-ready system
-   A learning and reference implementation
-   Designed for correctness over convenience

# What This Project Is Not

-   A rapid prototyping sandbox
-   Tolerant of undocumented manual changes
-   Flexible about bypassing enforcement

------------------------------------------------------------------------

# Architectural Principle

> Invariants live in the database.\
> Behaviour lives in the application.\
> Enforcement lives in automation.

Everything else follows from that.

------------------------------------------------------------------------