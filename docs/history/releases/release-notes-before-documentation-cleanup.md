# Release Notes

- [Release Notes](#release-notes)
  - [v1.2.0 — Windows installer-led upgrade safety 2026-05-24](#v120--windows-installer-led-upgrade-safety-2026-05-24)
    - [Summary](#summary)
    - [Main user-facing change](#main-user-facing-change)
    - [Implemented layout](#implemented-layout)
  - [v1.1.0 - Windows now supported 2026-05-16](#v110---windows-now-supported-2026-05-16)
    - [Highlights](#highlights)
    - [Added](#added)
    - [Changed](#changed)
    - [Fixed](#fixed)
    - [Known Notes](#known-notes)
    - [Completed upgrade-safety work](#completed-upgrade-safety-work)
    - [Installer packaging](#installer-packaging)
    - [Legacy migration behaviour](#legacy-migration-behaviour)
    - [Backup behaviour](#backup-behaviour)
    - [MariaDB runtime behaviour](#mariadb-runtime-behaviour)
    - [Documentation](#documentation)
    - [Known limitations and deferred follow-ups](#known-limitations-and-deferred-follow-ups)
    - [Developer notes](#developer-notes)
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

## v1.2.0 — Windows installer-led upgrade safety 2026-05-24

### Summary

v1.2.0 introduces the Windows installer-led installation and upgrade model.

The application is now installed under:

`C:\Program Files\OrchidApp`

Mutable user data is stored under:

`C:\ProgramData\OrchidApp`

This release replaces the previous ZIP/extracted-folder distribution model for Windows users and establishes the safety boundary between application files and user data.

### Main user-facing change

Windows users should now install and upgrade OrchidApp using the Windows installer.

Users should not:

- extract a new ZIP over an existing OrchidApp folder
- copy new application files over an old install
- manually move MariaDB data
- manually move uploads
- manually edit files under `C:\ProgramData\OrchidApp`

### Implemented layout

Application files:

`C:\Program Files\OrchidApp`

ProgramData layout:

```
C:\ProgramData\OrchidApp
  data\mariadb
  uploads
  backups
  backups\pre-upgrade
  logs
  launcher-settings.json
  migration-state.json
```

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

Launcher support log:

```
C:\ProgramData\OrchidApp\logs\launcher.log
C:\ProgramData\OrchidApp\logs\launcher.previous.log
```

Log rotation keeps only the current and previous launcher logs.

### Completed upgrade-safety work

The following Windows installer-led upgrade safety issues are complete for v1.2.0:

1. Shared application version metadata.
2. Windows layout resolver.
3. Installer-led upgrade contract.
4. Hardwired pre-upgrade backup service.
5. ProgramData folder structure.
6. Legacy data migration.
7. Migration state.
8. Start MariaDB from resolved data path.
9. Clean first install under new layout.
10. Installer packaging.
11. User documentation and release notes.

### Installer packaging

The Windows installer is built with Inno Setup.

Installer project/script locations:

```
installer/windows/OrchidApp.iss
scripts/build-windows-installer.ps1
```

Installer behaviour:

* installs application files to C:\Program Files\OrchidApp
* creates a Start Menu shortcut
* optionally creates a Desktop shortcut
* can launch OrchidApp after install
* excludes mutable data from the install payload
* does not create, delete or modify C:\ProgramData\OrchidApp
* preserves ProgramData on uninstall
* shows an uninstall prompt explaining that plant data, uploaded photos, backups and settings are preserved

The installer is currently unsigned. Windows may show unknown publisher or SmartScreen warnings.

### Legacy migration behaviour

v1.2.0 supports migration from the old extracted-folder layout.

Legacy source layout is treated as data-bearing only when it contains the actual orchids database folder:

```
<legacy-root>\data\mariadb\orchids
```

Migration behaviour:

* requires a successful mandatory pre-upgrade backup before migration
* copies legacy data into ProgramData
* does not move, delete or rename old legacy data
* copies MariaDB data from <legacy-root>\data\mariadb
* copies uploads from <legacy-root>\wwwroot\uploads
* copies legacy launcher-settings.json if present
* writes migration state to C:\ProgramData\OrchidApp\migration-state.json

Accepted limitation:

* Completed migration state is written after successful copy, not after post-copy MariaDB verification.

### Backup behaviour

Normal backups use ProgramData paths:

```
C:\ProgramData\OrchidApp\data\mariadb
C:\ProgramData\OrchidApp\uploads
C:\ProgramData\OrchidApp\launcher-settings.json
C:\ProgramData\OrchidApp\backups
```

Pre-upgrade backups for v1.2 legacy migration remain legacy-source aware and write to:

```
C:\ProgramData\OrchidApp\backups\pre-upgrade
```

Cloud backup folder configuration remains launcher-managed.

After a successful local backup, the latest backup is copied to the configured cloud folder as:

```
OrchidAppDataBackup.zip
```

Cloud copy failure is logged as a warning and does not invalidate the successful local backup.

### MariaDB runtime behaviour

The launcher starts MariaDB using the packaged MariaDB binaries from the application/runtime folder.

The MariaDB data directory is resolved to:

```
C:\ProgramData\OrchidApp\data\mariadb
```

Clean install behaviour:

* detects missing/empty ProgramData MariaDB data directory
* initialises MariaDB under ProgramData using bundled MariaDB tools
* creates the orchids database with utf8mb4
* creates/grants the required application and shutdown users
* allows OrchidApp.Web first-use schema setup to complete

### Documentation

v1.2.0 documentation has been aligned to the installer-led model.

User-facing guides:

```
01 - Install or Upgrade OrchidApp on Windows
02 - Prepare OrchidApp for First Use
03 - Add and Manage Plants in OrchidApp
04 - Configure Cloud Backup Folder in OrchidApp
05 - Recover OrchidApp on a Replacement Windows Computer
```

User guides are maintained as Markdown for editing, then converted through Word to PDF for release publication.

Support email documented for users:

```
OrchidApp@proton.me
```

### Known limitations and deferred follow-ups

Deferred beyond v1.2.0:

* ProgramData-to-ProgramData pre-upgrade backup gate.
* Optional future verification before marking migration Completed.
* Stronger ProgramData authority model where valid ProgramData may take precedence over leftover legacy app-root data.
* Code signing, because signing cost is not justified at this stage.

### Developer notes

Do not reintroduce ZIP-overwrite upgrade instructions for Windows users.

Do not store mutable user data under C:\Program Files\OrchidApp.

Do not make the installer responsible for ProgramData creation, deletion or migration. ProgramData preparation, layout detection, backup and migration remain launcher responsibilities.

Do not treat a mere data\mariadb folder as data-bearing. Upgrade-sensitive detection requires the actual data\mariadb\orchids database folder with content.

The launcher remains the authority for:

* layout detection
* legacy migration
* pre-upgrade backup
* MariaDB startup
* clean first-use ProgramData initialisation
* backup/restore
* cloud backup folder configuration

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
