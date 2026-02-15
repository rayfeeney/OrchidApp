# Contributing to OrchidApp

OrchidApp is a production-grade system built on strict architectural
guarantees.

Automation is not advisory. It is the contract.

This document defines how contributions must be made in order to
preserve:

-   Schema reproducibility
-   Migration integrity
-   Operational safety
-   Lifecycle invariants
-   Backup validity
-   CI determinism

If a change weakens any of these, it will be rejected.

------------------------------------------------------------------------

# Core Principles

All contributions must respect:

1.  **Database invariants are authoritative**
2.  **Migrations control structural change**
3.  **Generated artefacts are never edited manually**
4.  **Local validation must mirror CI**
5.  **Production behaviour must be reproducible**

------------------------------------------------------------------------

# Mandatory Setup

After cloning the repository, you must run:

    pwsh scripts/setup.ps1

This:

-   Verifies required tooling
-   Installs enforced Git hooks
-   Configures deterministic schema export

Commits made without running setup are invalid and will fail CI.

------------------------------------------------------------------------

# Types of Contributions

## 1. Database (Structural) Changes

Structural schema changes must:

-   Be implemented via migration files in `database/migrations/`
-   Follow naming format `YYYYMMDDHHMM_Name.sql`
-   Never modify historical migrations
-   Pass drift detection before application

Migrations are recorded in the `schemaversion` table with SHA256
checksums. Checksum modification or timestamp duplication will fail
validation.

Direct modification of the Production database is prohibited.

------------------------------------------------------------------------

## 2. Schema Export (Generated Artefacts)

Files under:

    database/schema/

Are generated automatically.

They:

-   Must never be edited manually
-   Are regenerated during pre-commit
-   Are validated in CI

If you need to change the schema, create a migration --- do not edit
generated SQL.

------------------------------------------------------------------------

## 3. Lifecycle & Structural Writes

Certain domain entities enforce structural invariants and must be
written exclusively via stored procedures.

Examples include:

-   plantlocationhistory
-   plantsplit
-   propagation records

EF Core must not bypass these invariants.

Atomic entities (e.g. plantevent) may be written directly via EF Core.

If uncertain, default to stored procedures.

------------------------------------------------------------------------

## 4. Web Application Changes

The web application:

-   Must treat the database as authoritative
-   Must not reinterpret or override invariants
-   Must not duplicate constraint logic already enforced in SQL
-   Must respect environment separation (Development vs Production)

Application convenience must never override data correctness.

------------------------------------------------------------------------

# Commits & Hooks

This repository enforces pre-commit validation.

The hook:

-   Exports schema deterministically
-   Stages regenerated artefacts
-   Fails on validation errors

Bypassing hooks (`--no-verify`) is not permitted.

GitHub Desktop may not support all workflows. Git Bash is required for
database-only commits.

------------------------------------------------------------------------

# Database-Only Changes

If changes were made only in the database:

    git commit --allow-empty

This triggers schema export and staging via the pre-commit hook.

Do not manually stage generated files.

------------------------------------------------------------------------

# Local CI Validation

Before opening a pull request:

    pwsh scripts/ci-local.ps1

This spins up a disposable MariaDB instance via Docker and rebuilds the
schema from committed artefacts only.

If it fails locally, it will fail in CI.

------------------------------------------------------------------------

# Pull Requests

Each PR must clearly state whether it is:

-   Database-focused
-   Web application-focused
-   Cross-cutting
-   Operational (backup / infrastructure)

Structural changes require heightened scrutiny.

Pull requests that weaken enforcement, reduce guarantees, or bypass
invariants will be rejected.

------------------------------------------------------------------------

# Operational Awareness

Changes that affect:

-   Migrations
-   Backup scripts
-   Restore procedures
-   Deployment behaviour

Must include documentation updates.

Backups are only valid if restores succeed. Restore discipline is part
of architectural enforcement.

------------------------------------------------------------------------

# Not Permitted

The following are explicitly disallowed:

-   Editing generated schema files
-   Modifying historical migrations
-   Bypassing stored procedures for structural entities
-   Introducing undocumented manual steps
-   Applying schema changes directly in Production
-   Weakening checksum or drift enforcement

------------------------------------------------------------------------

# Architectural Reminder

OrchidApp is not optimised for speed of development.

It is optimised for:

-   Reproducibility
-   Determinism
-   Invariant safety
-   Long-term maintainability

If a workflow feels strict, that strictness is intentional.

------------------------------------------------------------------------