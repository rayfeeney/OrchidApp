# Release Notes

- [Release Notes](#release-notes)
  - [v1.1.0 - Windows now supported 2026-05-16](#v110---windows-now-supported-2026-05-16)
    - [Highlights](#highlights)
    - [Added](#added)
    - [Changed](#changed)
    - [Fixed](#fixed)
    - [Known Notes](#known-notes)
  - [OrchidApp v1.0.0 - General Availability](#orchidapp-v100---general-availability)
  - [What’s Included](#whats-included)
    - [Lifecycle Model (Complete)](#lifecycle-model-complete)
    - [Deterministic Database System](#deterministic-database-system)
    - [Temporal Model](#temporal-model)
    - [Photo \& Media System](#photo--media-system)
    - [Application Layer](#application-layer)
    - [Backup \& Recovery](#backup--recovery)
    - [Deployment Model](#deployment-model)
  - [System Guarantees](#system-guarantees)
  - [Architectural Contract](#architectural-contract)
  - [Notes](#notes)
  - [Status](#status)

---

## v1.1.0 - Windows now supported 2026-05-16

### Highlights

* Windows ZIP release added
* Raspberry Pi package updated
* Backup and restore documentation completed
* Third-party notices included

### Added

* Cloud backup folder configuration
* Latest-backup copy to configured cloud folder
* About page with support and privacy information
* User documentation for backup and disaster recovery

### Changed

* Packaging scripts now produce release-ready artefacts
* Release documentation improved for non-GitHub users

### Fixed

* Corrected packaging output paths
* Excluded transient `.lscache` files from packaged artefacts

### Known Notes

* Windows release is currently ZIP-based
* Future work will focus on safer upgrade mechanics and installer preparation

---

## OrchidApp v1.0.0 - General Availability

OrchidApp is now considered **production-ready**.

This release establishes the complete system contract across database, application, automation, and operations.

---

## What’s Included

### Lifecycle Model (Complete)

* Single immutable plant lifecycle (`startDateTime → endDateTime`)
* Split lifecycle (parent termination + child creation)
* Propagation model (independent lifecycle origin)
* Strict location history with temporal adjacency enforcement
* Narrative event model (observations, repotting, flowering)

All lifecycle invariants are enforced at the **database level**.

---

### Deterministic Database System

* Canonical schema export (`database/schema/`)
* Forward-only migration system (`database/migrations/`)
* SHA256 checksum enforcement
* Drift detection prior to migration execution

The database is treated as **source code**.

---

### Temporal Model

* Date-led user experience with system-assigned time precision
* Stable same-day ordering using DATETIME
* Clear separation of narrative vs structural time
* Database-enforced temporal consistency

Temporal behaviour is formally defined and enforced.

---

### Photo & Media System

* Observation-driven photo model
* Explicit hero image selection (no implicit “latest” behaviour)
* Canonical image processing via **libvips (NetVips)**
* Normalised output (JPEG, 3072px max, metadata stripped)

Original uploads are not retained.

---

### Application Layer

* ASP.NET Core Razor Pages (.NET LTS)
* EF Core for atomic entities
* Stored procedures for all structural operations
* Mobile-first UI design
* Consistent navigation and event model

The application orchestrates behaviour but does not enforce invariants.

---

### Backup & Recovery

* Automated nightly encrypted backups (database + uploads)
* Database snapshots with retention policy
* Encrypted uploads mirror
* Restore process validated end-to-end

Backups are only considered valid if restore succeeds.

---

### Deployment Model

* Raspberry Pi (Linux) as primary production target
* systemd-managed application hosting
* Environment-driven configuration
* Deterministic rebuild and upgrade procedures

Deployment is fully reproducible.

---

## System Guarantees

This release guarantees:

* The database can be rebuilt from committed artefacts at any time
* Production state is recoverable from backups
* Schema drift cannot occur silently
* Lifecycle invariants cannot be bypassed
* All structural changes are traceable and enforced

Correctness is enforced by design.

---

## Architectural Contract

OrchidApp is built on a strict separation of responsibility:

* **Database** - invariants and lifecycle enforcement
* **Application** - behavioural orchestration
* **Automation** - reproducibility and validation
* **Operations** - backup, restore and deployment discipline

> Invariants live in the database.
> Behaviour lives in the application.
> Enforcement lives in automation.

---

## Notes

* This system is designed for trusted network environments
* It is not intended for direct exposure to the public internet
* Backup operation and validation remain the responsibility of the deployment operator

---

## Status

OrchidApp v1.0.0 is considered **stable and production-ready**.
