# Contributing to OrchidApp

OrchidApp is a production-grade system built on strict architectural guarantees.

Automation is not advisory. It is the contract.

This document defines how contributions must be made in order to preserve:

* Schema reproducibility
* Migration integrity
* Lifecycle invariants
* Operational safety
* Backup validity
* CI determinism

If a change weakens any of these, it will be rejected.

---

## Core Principles

All contributions must respect:

1. **Database invariants are authoritative**
2. **Migrations control structural change**
3. **Generated artefacts are never edited manually**
4. **Local validation must mirror CI**
5. **Production behaviour must be reproducible**

---

## Mandatory Setup

After cloning the repository, you must run:

```bash id="m9v2qk"
pwsh scripts/setup.ps1
```

This:

* Verifies required tooling
* Installs enforced Git hooks
* Configures deterministic schema export

Commits made without running setup are invalid and will fail CI.

---

## Contribution Types

### 1. Database (Structural) Changes

Structural changes must:

* Be implemented via migration files in:

```id="l2r7dz"
database/migrations/
```

* Follow naming format `YYYYMMDDHHMM_Name.sql`
* Be applied exactly once
* Never modify historical migrations

The system enforces:

* SHA256 checksum validation
* Ordering constraints
* Drift detection prior to execution

Direct modification of any live database is prohibited.

---

### 2. Schema Export (Generated Artefacts)

Files under:

```id="o1d0px"
database/schema/
```

are generated artefacts.

They:

* Must never be edited manually
* Are regenerated during pre-commit
* Are validated in CI

If you need to change the schema:

> Create a migration — do not edit generated SQL.

---

### 3. Lifecycle & Structural Writes

Certain entities enforce structural invariants and must be written via stored procedures.

Examples:

* `plantlocationhistory`
* `plantsplit`
* propagation records

Rules:

* EF Core must not bypass structural invariants
* Stored procedures must enforce all lifecycle rules
* Invalid transitions must fail atomically

Atomic entities (e.g. `plantevent`) may be written via EF Core.

If unsure, default to stored procedures.

---

### 4. Stored Procedure Invocation Contract

Stored procedures must be invoked using the project-standard patterns:

**Command procedures (no result set):**

```csharp id="9d3mqa"
Database.ExecuteSqlRawAsync(...)
```

**Result-set procedures:**

```csharp id="u9r8kb"
DbSet<TEntity>.FromSqlRaw(...).ToListAsync()
```

Rules:

* All calls must be asynchronous
* Manual ADO.NET commands are not permitted
* Interpolated execution patterns are not permitted
* Try/catch is used only to translate database errors into user-facing messages

Database behaviour must remain authoritative.

---

### 5. Web Application Changes

The application layer:

* Orchestrates workflows
* Must treat the database as authoritative
* Must not duplicate database constraints
* Must not override lifecycle rules

Application convenience must never override data correctness.

---

### 6. UI Navigation Contract

All Razor Pages must comply with the navigation contract defined in:

```id="3h8xmk"
docs/architecture.md
```

Rules:

* Use shared partials under `/Pages/Shared/`
* Do not duplicate button layouts per page
* Use the `returnUrl` pattern for navigation
* Conform to defined page types (list, form, destructive, content)

UI consistency is an architectural constraint, not a preference.

---

## Commits & Hooks

Pre-commit hooks are enforced.

They:

* Regenerate schema exports
* Stage generated artefacts
* Fail on validation errors

Bypassing hooks (`--no-verify`) is not permitted.

---

## Database-Only Changes

If changes are database-only:

```bash id="w6g1sk"
git commit --allow-empty
```

This triggers schema export via the pre-commit hook.

Do not manually stage generated files.

---

## Local CI Validation

Before opening a pull request:

```bash id="qk2z0x"
pwsh scripts/ci-local.ps1
```

This:

* Spins up a clean MariaDB instance
* Rebuilds schema from committed artefacts
* Detects drift and ordering issues

If it fails locally, it will fail in CI.

---

## Pull Requests

Each PR must clearly state whether it is:

* Database-focused
* Application-focused
* Cross-cutting
* Operational

Structural changes receive heightened scrutiny.

PRs that weaken invariants or bypass enforcement will be rejected.

---

## Operational Awareness

Changes affecting:

* Migrations
* Backup scripts
* Restore procedures
* Deployment behaviour

must include corresponding documentation updates.

Backups are only valid if restore succeeds.

---

## Not Permitted

The following are explicitly disallowed:

* Editing generated schema files
* Modifying historical migrations
* Bypassing stored procedures for structural entities
* Introducing undocumented manual steps
* Applying schema changes directly to production
* Weakening checksum or drift enforcement

---

## Architectural Reminder

OrchidApp is not optimised for speed of development.

It is optimised for:

* Reproducibility
* Determinism
* Invariant safety
* Long-term maintainability

If a workflow feels strict, that strictness is intentional.
