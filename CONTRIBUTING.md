# Contributing to OrchidApp

- [Contributing to OrchidApp](#contributing-to-orchidapp)
  - [Architectural Authority](#architectural-authority)
  - [Core Principles](#core-principles)
  - [Mandatory Setup](#mandatory-setup)
  - [Contribution Types](#contribution-types)
    - [1. Database Structural Changes](#1-database-structural-changes)
    - [2. Schema Export Generated Artefacts](#2-schema-export-generated-artefacts)
    - [3. Lifecycle and Structural Writes](#3-lifecycle-and-structural-writes)
    - [4. Stored Procedure Invocation Contract](#4-stored-procedure-invocation-contract)
    - [5. Application Layer Changes](#5-application-layer-changes)
    - [6. Temporal Behaviour](#6-temporal-behaviour)
    - [7. UI and Navigation Contract](#7-ui-and-navigation-contract)
    - [8. Windows Installer and Upgrade Safety](#8-windows-installer-and-upgrade-safety)
    - [9. Backup and Restore Behaviour](#9-backup-and-restore-behaviour)
    - [10. User Documentation](#10-user-documentation)
  - [Commits and Hooks](#commits-and-hooks)
  - [Database-Only Changes](#database-only-changes)
  - [GitHub CI Validation](#github-ci-validation)
  - [Pull Requests](#pull-requests)
  - [Operational Awareness](#operational-awareness)
  - [Not Permitted](#not-permitted)
  - [Architectural Reminder](#architectural-reminder)

---

OrchidApp is a production-grade system governed by a strict architectural contract.

Automation is not advisory.  
It is enforcement.

All contributions must preserve:

* Schema reproducibility
* Migration integrity
* Lifecycle invariants
* Temporal correctness
* Operational safety
* Backup validity
* Restore validity
* Upgrade safety
* User data preservation
* CI determinism

If a change weakens any of these, it will be rejected.

---

## Architectural Authority

The system is governed by:

```text
docs/architecture.md
```

This document defines the non-negotiable rules for the project.

Contributions must not reinterpret, duplicate or weaken these rules.

---

## Core Principles

All contributions must adhere to these principles:

1. **Database invariants are authoritative**
2. **Migrations control structural change**
3. **Generated artefacts are never edited manually**
4. **Local validation must mirror CI**
5. **Production behaviour must be reproducible**
6. **User data must survive upgrades**
7. **Backups and restores are part of the system contract**

---

## Mandatory Setup

After cloning the repository:

```powershell
pwsh scripts/setup.ps1
```

This:

* Verifies required tooling
* Installs enforced Git hooks
* Configures deterministic schema export

Commits made without setup are invalid and will fail CI.

---

## Contribution Types

---

### 1. Database Structural Changes

Structural changes must be implemented via migration files in:

```text
database/migrations/
```

Migration files must:

* Follow the naming format `YYYYMMDDHHMM_Name.sql`
* Be applied exactly once
* Never modify historical migrations
* Preserve existing user data unless an intentional, documented migration says otherwise

The system enforces:

* SHA256 checksum validation
* Ordering constraints
* Duplicate timestamp prevention
* Drift detection before execution

Direct modification of any live database is prohibited.

---

### 2. Schema Export Generated Artefacts

Files under:

```text
database/schema/
```

are generated artefacts.

They:

* Must never be edited manually
* Are regenerated during pre-commit
* Are validated locally and in CI

If you need to change the schema:

> Create a migration. Do not edit generated SQL.

---

### 3. Lifecycle and Structural Writes

Structural domains enforce lifecycle invariants and must be written via stored procedures.

Examples include:

* `plantlocationhistory`
* `plantsplit`
* propagation records
* structural taxonomy lifecycle changes

Rules:

* EF Core must not bypass structural invariants
* Stored procedures must enforce all lifecycle rules
* Invalid transitions must fail atomically
* Structural changes must remain transactionally safe

Atomic entities may be written via EF Core where this is already part of the project design.

Examples include:

* Observations
* Repotting events
* Flowering events

If unsure, default to stored procedures and discuss the design before implementation.

---

### 4. Stored Procedure Invocation Contract

Stored procedures must be invoked using project-standard patterns.

Command procedures with no result set:

```csharp
await Database.ExecuteSqlRawAsync(...);
```

Result-set procedures:

```csharp
await DbSet<TEntity>
    .FromSqlRaw(...)
    .ToListAsync();
```

Rules:

* All calls must be asynchronous
* Manual ADO.NET commands are not permitted in PageModels
* Interpolated SQL execution patterns are not permitted
* Try/catch is used only to translate database errors into user-facing validation messages
* Database behaviour remains authoritative

Exceptional output-parameter scenarios must use central infrastructure helpers only.

---

### 5. Application Layer Changes

The application layer:

* Orchestrates workflows
* Presents validation and error messages
* Must treat the database as authoritative
* Must not duplicate structural constraints as an alternative to database enforcement
* Must not override lifecycle rules
* Must not reinterpret temporal behaviour

Application convenience must never override correctness.

---

### 6. Temporal Behaviour

Temporal behaviour is part of the system contract.

Contributions must respect:

* Date-only user input where established
* Database `DATETIME` storage for ordering
* System-assigned time components
* Insertion-stable same-day ordering
* Stored procedure ownership of structural temporal boundaries

Do not introduce new temporal semantics without updating the formal temporal design documentation.

See:

```text
docs/temporal-design.md
```

---

### 7. UI and Navigation Contract

UI behaviour must comply with the established project patterns.

Rules:

* Use shared components under `/Pages/Shared/` where appropriate
* Do not duplicate button layouts unnecessarily
* Use the `returnUrl` pattern where navigation context matters
* Follow established mobile-first page patterns
* Keep operational UI terminology user-friendly
* Do not expose internal database terminology where user-facing labels already exist

UI consistency is part of the product contract.

---

### 8. Windows Installer and Upgrade Safety

The Windows installer-led app is part of the project’s supported delivery model.

Changes affecting packaging, installer behaviour, launcher behaviour, local settings, bundled components or data folders must preserve upgrade safety.

Rules:

* Public Windows upgrades must use the installer, not ZIP overwrite
* User data must not be deleted during install, uninstall, package replacement or upgrade
* Database files and uploaded images must be treated as persistent state
* Application files must be treated as replaceable
* The installer owns application files only
* The launcher owns layout detection, backup, migration and runtime data-path resolution
* Upgrade workflows must take or require a backup before migration or destructive/structural changes
* Data-folder moves must be layout-aware and documented
* Failure during upgrade must not leave the user without a recoverable path
* Windows ProgramData paths must remain consistent with `docs/windows-upgrade-contract.md`

Any change that affects packaged layout must consider the implemented installer-led distribution model.

---

### 9. Backup and Restore Behaviour

Backup and restore are part of the system contract.

Changes affecting any of the following must include corresponding validation and documentation updates:

* Backup creation
* Backup location selection
* Cloud-folder copy behaviour
* Restore process
* Upload preservation
* Database restore
* Packaged app data layout

Backups are only valid if restore succeeds.

A backup feature that cannot be restored is not complete.

---

### 10. User Documentation

User-facing behaviour changes must update user-facing documentation where relevant.

This includes changes to:

* Installation
* Upgrade
* Backup configuration
* Disaster recovery
* About page information
* Privacy statement
* Support instructions
* Release assets and packaged documents

Developer-facing correctness is not enough if the user workflow changes.

---

## Commits and Hooks

Pre-commit hooks are enforced.

They:

* Regenerate schema exports
* Stage generated artefacts
* Fail on validation errors

Bypassing hooks with `--no-verify` is not permitted.

---

## Database-Only Changes

If changes are database-only:

```bash
git commit --allow-empty
```

This triggers schema export through the pre-commit hook.

Do not manually stage generated schema files.

---

## GitHub CI Validation

GitHub CI is the authoritative automated validation environment.

All pull requests must pass GitHub CI before merge.

CI validates:

* Application build behaviour
* Database schema consistency
* Migration ordering
* Migration checksum integrity
* Generated artefact consistency
* Packaging or release checks where applicable

A change is not considered valid until CI passes.

Local scripts may be used for developer convenience, but they are not currently the authoritative validation mechanism.

---

## Pull Requests

Each pull request must clearly state its scope:

* Database-focused
* Application-focused
* UI-focused
* Packaging-focused
* Documentation-focused
* Operational
* Cross-cutting

Structural, packaging, backup and restore changes receive heightened scrutiny.

Pull requests that weaken invariants, bypass enforcement or risk user data loss will be rejected.

---

## Operational Awareness

Changes affecting operational behaviour must include documentation and validation updates.

This includes:

* Migrations
* Backup scripts
* Restore procedures
* Deployment behaviour
* Windows packaging
* Raspberry Pi deployment
* Cloud-folder backup copy
* Upgrade behaviour
* Data-folder layout

Operational changes must be safe, repeatable and recoverable.

---

## Not Permitted

The following are strictly disallowed:

* Editing generated schema files manually
* Modifying historical migrations
* Bypassing stored procedures for structural entities
* Introducing undocumented manual steps
* Applying schema changes directly to production
* Weakening checksum enforcement
* Weakening drift enforcement
* Removing backup or restore safeguards without replacement
* Deleting or overwriting user data during upgrade
* Treating packaged application files and user data as the same kind of state
* Shipping user-facing workflow changes without updating documentation
* Recommending ZIP-overwrite as the public Windows upgrade route

---

## Architectural Reminder

OrchidApp is not optimised for speed of development.

It is optimised for:

* Reproducibility
* Determinism
* Invariant safety
* Upgrade safety
* Restore confidence
* Long-term maintainability

If a workflow feels strict, that strictness is intentional.

