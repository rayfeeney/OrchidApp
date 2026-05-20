# Windows upgrade contract

This document defines the Windows upgrade contract for OrchidApp.

It exists to prevent data loss when moving from the current v1.1.0-style ZIP-based layout to a future installer-led Windows layout.

---

## Purpose

Windows upgrades must be safe for a non-technical user.

A user must be able to install a newer OrchidApp release without:

- losing orchid data
- losing uploaded photos
- losing launcher settings
- manually moving files
- knowing where MariaDB stores its data
- knowing where OrchidApp stores uploaded images
- understanding the difference between application files and user data

This contract defines the boundary between installer-owned application files and user-owned data.

---

## Core contract

Public Windows upgrades are installer-led.

They are not ZIP-overwrite based.

The installer may install, replace or remove application files.

The installer must never overwrite user data.

User data must be treated as durable, user-owned state.

Application files are replaceable.

User data is not.

---

## Canonical Windows data root

The future canonical Windows data root is:

```text
C:\ProgramData\OrchidApp
```

This root is intended to hold durable machine-level OrchidApp data, including:

- MariaDB data
- uploaded plant photos
- launcher settings
- migration state
- backup and restore metadata where required

Application installation folders must not be treated as the long-term home for user data under the installer-led model.

---

## Existing v1.1.0-style layouts

Existing v1.1.0-style Windows layouts will contain live user data under the extracted application folder.

This is expected and valid for v1.1.0.

v1.1.0 cannot function with its data relocated elsewhere.

Therefore, legacy app-root layouts are valid v1.1.0 runtime layouts.

Under the installer-led model, those same layouts become migration sources only.

They must not remain the canonical data location after a successful installer-led migration.

---

## ProgramData precedence

A valid ProgramData layout takes precedence over legacy app-root layouts.

If `C:\ProgramData\OrchidApp` contains a valid authoritative layout, the launcher must:

- treat ProgramData as the runtime data root
- start MariaDB from ProgramData
- start OrchidApp using ProgramData-backed configuration
- ignore legacy app-root layouts for normal runtime resolution
- not attempt migration from legacy layouts

The presence of legacy app-root layouts after a valid ProgramData migration is not, by itself, an error.

Legacy layouts discovered after ProgramData has become authoritative may be logged for diagnostics, but they must not affect startup.

Once ProgramData authority has been established, later Windows upgrades should be normal application upgrades. They should not rerun the first-time legacy migration flow.

---

## Invalid or incomplete ProgramData layouts

If ProgramData exists but is incomplete, invalid or lacks valid migration state, the launcher must stop safely.

The launcher must not:

- guess between ProgramData and a legacy app-root layout
- fall back automatically to legacy data
- overwrite ProgramData with legacy data
- make an empty or partial ProgramData layout authoritative
- start OrchidApp against an unverified data layout

A valid legacy layout may still exist in this situation, but the presence of both an invalid ProgramData layout and a legacy layout is unsafe.

That state requires a safe stop and clear support wording.

---

## Layout decision model

The launcher should resolve layout state using this model:

```text
1. Detect ProgramData layout.

2. If ProgramData layout is valid:
   - treat ProgramData as authoritative
   - ignore legacy app-root layouts for runtime purposes
   - start MariaDB from ProgramData
   - start OrchidApp
   - do not attempt migration

3. If ProgramData layout is missing:
   - inspect legacy app-root layouts
   - if exactly one valid legacy layout exists, migration may proceed
   - if zero valid legacy layouts exist, handle as a clean first install
   - if multiple valid legacy layouts exist, stop safely

4. If ProgramData layout exists but is invalid or incomplete:
   - stop safely
   - do not fall back automatically to legacy data
   - do not overwrite or recreate ProgramData automatically
```

The distinction is important:

```text
Valid ProgramData + old legacy folder exists
= already migrated, start normally.

Invalid or incomplete ProgramData + legacy folder exists
= unsafe, stop safely.

No ProgramData + one valid legacy folder exists
= migration candidate.

No ProgramData + multiple valid legacy folders exist
= ambiguous, stop safely.
```

---

## Installer responsibilities

The installer owns application files only.

The installer is responsible for:

- installing the OrchidApp application files
- replacing application binaries during upgrades
- creating shortcuts where required
- installing launcher files
- installing static application content
- avoiding unsafe ZIP-overwrite upgrade patterns
- not deleting, replacing or resetting user data
- not making an empty data folder authoritative
- not attempting to infer which legacy data layout is correct

The installer must not directly migrate user data.

The installer must not copy MariaDB data, uploaded photos or launcher settings unless that action is explicitly delegated to a launcher-controlled migration flow.

---

## Launcher responsibilities

The Windows launcher owns layout detection, unsafe-state handling and upgrade migration orchestration.

The launcher is responsible for:

- detecting the current launcher location
- discovering possible legacy app-root layouts
- discovering possible ProgramData layouts
- de-duplicating candidate locations
- counting data-bearing legacy layouts
- detecting ambiguous layout states
- recognising when ProgramData is already authoritative
- starting normally from a valid ProgramData layout
- stopping safely when more than one plausible live data layout exists and ProgramData is not already authoritative
- creating a mandatory pre-upgrade backup before migration
- creating the ProgramData folder structure only as part of a controlled migration or clean first install
- copying or migrating legacy data into ProgramData
- verifying the migrated database before use
- writing `migration-state.json` only after successful migration
- starting MariaDB from the resolved canonical data path
- starting OrchidApp only after data layout resolution succeeds

The launcher must not guess which data layout is correct when multiple candidate data layouts exist.

Ambiguity must stop the upgrade safely.

---

## Application responsibilities

The OrchidApp web application is responsible for normal application behaviour after the launcher has resolved the runtime layout.

The application is responsible for:

- using the configured database connection provided by the runtime environment
- using the configured upload path provided by the runtime environment
- displaying application version information
- preserving existing database invariants
- preserving existing photo and upload behaviour
- not deciding Windows upgrade layout state
- not performing launcher-level migration decisions

The application must not assume that user data is located beside the application binaries.

---

## Database responsibilities

The database remains authoritative for data integrity and lifecycle invariants.

The database is responsible for:

- preserving existing schema constraints
- preserving stored procedure behaviour
- preserving migration history
- remaining restorable from backup
- being verifiable after copy or migration

Database verification must happen before a migrated ProgramData layout is treated as authoritative.

A copied database that cannot be started or verified must not become the active runtime database.

---

## Documentation responsibilities

Documentation must explain the Windows upgrade model in user-safe language.

Documentation is responsible for:

- warning users not to upgrade by extracting a ZIP over an existing installation
- explaining that Windows upgrades are installer-led
- explaining that user data is kept separate from application files
- documenting the canonical Windows data root
- explaining what happens on first launch after installing an upgrade
- explaining what happens on later launches after ProgramData is already authoritative
- explaining what to do if the launcher reports multiple possible data locations
- documenting recovery from backup

User documentation must not require users to manually inspect MariaDB folders unless they are following a support or recovery procedure.

---

## Mandatory pre-upgrade backup

No migration may proceed without a successful pre-upgrade backup.

The backup must be created before any legacy data is copied, moved or made inactive.

If backup creation fails, migration must stop.

A failed backup must leave the existing v1.1.0-style layout untouched and usable.

A backup is required for migration from a legacy app-root layout into ProgramData.

A backup is not part of normal startup when ProgramData is already authoritative.

---

## High-level first-time migration order

The first-time installer-led migration flow must follow this order:

1. Detect layout.
2. Confirm that ProgramData is not already authoritative.
3. Identify exactly one valid legacy source layout.
4. Create mandatory pre-upgrade backup.
5. Create ProgramData structure.
6. Copy or migrate legacy data.
7. Verify migrated database.
8. Write `migration-state.json`.
9. Start MariaDB from ProgramData.
10. Start OrchidApp.

The order is significant.

ProgramData must not be treated as authoritative until migration and verification have completed successfully.

---

## Normal post-migration startup order

After ProgramData has become authoritative, startup should follow the normal runtime path:

1. Detect ProgramData layout.
2. Validate ProgramData authority.
3. Start MariaDB from ProgramData.
4. Start OrchidApp.

Legacy app-root layouts must not trigger a new migration during normal post-migration startup.

---

## Safe-stop conditions

Failed or ambiguous upgrades must stop safely.

The launcher must stop without starting OrchidApp when it detects:

- more than one data-bearing legacy layout and no authoritative ProgramData layout
- both an invalid or incomplete ProgramData layout and one or more legacy data layouts
- a failed mandatory backup
- a failed copy or migration
- a failed database verification
- an incomplete or invalid `migration-state.json`
- a partially created ProgramData layout that has not been verified

A safe stop must not destroy or overwrite the existing legacy layout.

A safe stop must not make an empty or partial ProgramData layout authoritative.

A safe stop must produce clear logs and user-facing support wording.

---

## ProgramData authority

`C:\ProgramData\OrchidApp` becomes authoritative only after all of the following are true:

- the legacy source layout has been identified unambiguously, where migration is required
- a mandatory pre-upgrade backup has completed successfully, where migration is required
- required ProgramData folders have been created
- legacy data has been copied or migrated successfully, where migration is required
- the MariaDB database in ProgramData has been started and verified
- required uploads and settings have been copied or created safely
- `migration-state.json` has been written successfully, where migration has occurred

Until these conditions are met, ProgramData is not authoritative.

Once ProgramData has become authoritative, subsequent launches and upgrades resolve runtime data from ProgramData first.

Legacy app-root layouts are no longer migration candidates during normal startup after ProgramData authority has been established.

---

## Legacy layout handling after migration

A successful migration does not require the legacy app-root layout to be immediately deleted.

The legacy layout may remain on disk as a historical source or fallback reference.

However, after successful migration, the launcher must resolve runtime data from ProgramData, not from the legacy app-root layout.

Any later detection of legacy layouts may be logged for diagnostics.

It must not cause migration to rerun while ProgramData remains valid and authoritative.

---

## Non-goals for this contract

This contract does not define the final installer technology.

This contract does not define exact folder names below ProgramData.

This contract does not define the detailed backup file format.

This contract does not define the exact schema of `migration-state.json`.

Those details belong to later implementation issues.

This contract defines the safety boundary and responsibility split that those later issues must follow.
