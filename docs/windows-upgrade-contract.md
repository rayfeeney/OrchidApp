# Windows upgrade contract

This document defines the Windows upgrade contract for OrchidApp.

It describes the implemented installer-led Windows model delivered through Issues 1-10.

The purpose of this contract is to prevent data loss when moving from the older ZIP-era Windows layout to the installer-led Windows layout.

---

- [Windows upgrade contract](#windows-upgrade-contract)
  - [Purpose](#purpose)
  - [Core contract](#core-contract)
  - [Implemented Windows layout](#implemented-windows-layout)
  - [Existing ZIP-era Windows layouts](#existing-zip-era-windows-layouts)
  - [Installer responsibilities](#installer-responsibilities)
  - [Installer package exclusions](#installer-package-exclusions)
  - [Launcher responsibilities](#launcher-responsibilities)
  - [Application responsibilities](#application-responsibilities)
  - [Database responsibilities](#database-responsibilities)
  - [Layout decision model](#layout-decision-model)
    - [Clean first install](#clean-first-install)
    - [Existing ProgramData layout](#existing-programdata-layout)
    - [Legacy layout requiring migration](#legacy-layout-requiring-migration)
    - [Multiple legacy layouts](#multiple-legacy-layouts)
    - [Legacy and ProgramData both found](#legacy-and-programdata-both-found)
  - [Mandatory pre-upgrade backup for legacy migration](#mandatory-pre-upgrade-backup-for-legacy-migration)
  - [Backup contents](#backup-contents)
  - [Legacy migration flow](#legacy-migration-flow)
  - [Migration copy behaviour](#migration-copy-behaviour)
  - [Migration state](#migration-state)
  - [Normal post-migration startup](#normal-post-migration-startup)
  - [Normal backup behaviour](#normal-backup-behaviour)
  - [Launcher settings](#launcher-settings)
  - [Launcher logging](#launcher-logging)
  - [Safe-stop conditions](#safe-stop-conditions)
  - [Uninstall behaviour](#uninstall-behaviour)
  - [Unsigned installer limitation](#unsigned-installer-limitation)
  - [ZIP/package output](#zippackage-output)
  - [Documentation responsibilities](#documentation-responsibilities)
  - [Post-v1.2 follow-ups](#post-v12-follow-ups)
    - [ProgramData-to-ProgramData upgrade backup gate](#programdata-to-programdata-upgrade-backup-gate)
    - [Post-copy MariaDB verification before marking migration complete](#post-copy-mariadb-verification-before-marking-migration-complete)
    - [Stronger ProgramData authority model](#stronger-programdata-authority-model)
  - [Final rule](#final-rule)

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

## Implemented Windows layout

The implemented Windows application install location is:

```text
C:\Program Files\OrchidApp
```

This folder contains replaceable application files, including:

- launcher files
- web application files
- bundled runtime files
- MariaDB binaries
- libvips binaries
- database setup scripts
- static application content

The implemented Windows user-data root is:

```text
C:\ProgramData\OrchidApp
```

This folder contains durable user-owned data and operational state.

Implemented ProgramData paths are:

```text
C:\ProgramData\OrchidApp\data\mariadb
C:\ProgramData\OrchidApp\uploads
C:\ProgramData\OrchidApp\backups
C:\ProgramData\OrchidApp\backups\pre-upgrade
C:\ProgramData\OrchidApp\logs
C:\ProgramData\OrchidApp\launcher-settings.json
C:\ProgramData\OrchidApp\migration-state.json
```

The launcher support log is written to:

```text
C:\ProgramData\OrchidApp\logs\launcher.log
```

Log rotation keeps at most:

```text
launcher.log
launcher.previous.log
```

When `launcher.log` exceeds 1 MB at launcher startup, it is moved to `launcher.previous.log` and a fresh `launcher.log` is started.

---

## Existing ZIP-era Windows layouts

Older ZIP-era Windows layouts contain live user data under the extracted application folder.

This is expected and valid for those older releases.

The older layout may contain:

```text
<legacy-root>\data\mariadb
<legacy-root>\wwwroot\uploads
<legacy-root>\backups
<legacy-root>\launcher-settings.json
<legacy-root>\launcher.log
```

Under the installer-led model, these layouts are migration sources only.

They must not remain the canonical runtime data location after a successful move to ProgramData.

Legacy data is detected from the data layout itself, not from application version metadata.

A data-bearing legacy layout is one where the actual MariaDB `orchids` database folder exists and contains data:

```text
<legacy-root>\data\mariadb\orchids
```

The mere existence of `data\mariadb` is diagnostic only. It does not make a layout upgrade-sensitive.

This supports unversioned legacy installs and avoids relying on old package metadata.

---

## Installer responsibilities

The installer owns application files only.

The installer is responsible for:

- installing OrchidApp application files
- replacing application binaries during upgrades
- creating Start Menu shortcuts
- optionally creating a Desktop shortcut
- optionally launching OrchidApp after install
- avoiding ZIP-overwrite upgrade patterns
- not deleting, replacing or resetting user data
- not making an empty data folder authoritative
- not attempting to infer which legacy data layout is correct

The installer must not directly migrate user data.

The installer must not copy MariaDB data, uploaded photos, backups, logs or launcher settings.

The installer must not create or modify:

```text
C:\ProgramData\OrchidApp
```

ProgramData is created and managed by the launcher.

---

## Installer package exclusions

The Windows installer package must exclude mutable runtime data from the application source folder.

The installer must not include:

```text
data
uploads
wwwroot\uploads
backups
logs
launcher.log
launcher-settings.json
migration-state.json
```

This prevents stale development, test or legacy user data from being installed as application files.

---

## Launcher responsibilities

The Windows launcher owns layout detection, unsafe-state handling, migration orchestration and runtime data-path resolution.

The launcher is responsible for:

- creating the ProgramData folder structure when needed
- detecting the current launcher location
- discovering possible legacy app-root layouts
- discovering ProgramData state
- de-duplicating candidate locations
- counting data-bearing legacy layouts
- detecting ambiguous layout states
- creating a mandatory pre-upgrade backup before legacy migration
- copying legacy data into ProgramData
- writing migration state
- starting MariaDB from ProgramData
- passing the upload root to the web application
- logging layout and startup decisions
- stopping safely rather than guessing

The launcher must not guess which data layout is correct when multiple candidate data layouts exist.

Ambiguity must stop startup safely.

---

## Application responsibilities

The OrchidApp web application is responsible for normal application behaviour after the launcher has resolved the runtime layout.

The web application is responsible for:

- using the database connection supplied by the runtime environment
- using the upload path supplied by the runtime environment
- displaying application version information
- preserving database invariants
- preserving photo and upload behaviour
- running first-use database setup where required
- running database update checks where required

The web application must not decide Windows upgrade layout state.

The web application must not assume that user data is located beside the application binaries.

On packaged Windows, the launcher passes the upload root to the web application using:

```text
ORCHIDAPP_UPLOAD_ROOT
```

The expected upload root is:

```text
C:\ProgramData\OrchidApp\uploads
```

---

## Database responsibilities

The database remains authoritative for data integrity and lifecycle invariants.

The database is responsible for:

- preserving schema constraints
- preserving stored procedure behaviour
- preserving migration history
- remaining restorable from backup

On Windows, MariaDB binaries are installed with the application files.

MariaDB data is stored under ProgramData:

```text
C:\ProgramData\OrchidApp\data\mariadb
```

The launcher starts MariaDB using:

- the MariaDB executable from the installed application folder
- the MariaDB data directory under ProgramData

This separates replaceable runtime binaries from durable user data.

---

## Layout decision model

The implemented launcher layout model is conservative.

The launcher classifies layouts using statuses including:

```text
NewInstall
ProgramDataLayoutInPlace
OldLayoutRequiresMigration
MultipleLegacyLayoutsFound
LegacyAndProgramDataFound
```

### Clean first install

If no valid ProgramData layout exists and no data-bearing legacy layout exists, the launcher treats the system as a new install.

The launcher then:

1. Creates the ProgramData folder structure.
2. Initialises MariaDB data under ProgramData.
3. Creates the `orchids` database.
4. Starts OrchidApp using ProgramData paths.

### Existing ProgramData layout

If ProgramData already contains a valid OrchidApp database and no conflicting data-bearing legacy layout is detected, the launcher treats ProgramData as the runtime data root.

The launcher then:

1. Starts MariaDB from ProgramData.
2. Starts OrchidApp.
3. Passes the ProgramData upload root to the web application.

### Legacy layout requiring migration

If exactly one data-bearing legacy layout exists and ProgramData is not already authoritative, the launcher treats the legacy layout as a migration source.

The launcher then follows the legacy migration flow.

### Multiple legacy layouts

If more than one data-bearing legacy layout exists, the launcher stops safely.

It must not guess which layout is correct.

### Legacy and ProgramData both found

For the implemented v1.2 safety model, if both a data-bearing legacy layout and a ProgramData layout are detected, the launcher stops safely.

This conservative behaviour prevents accidental use of the wrong data layout.

A future version may relax this once ProgramData authority tracking is strengthened, but the current implemented behaviour is safe stop.

---

## Mandatory pre-upgrade backup for legacy migration

No legacy migration may proceed without a successful pre-upgrade backup.

The backup is controlled by the launcher, not the installer.

For legacy migration, the backup source is the detected legacy app-root layout.

The backup destination is:

```text
C:\ProgramData\OrchidApp\backups\pre-upgrade
```

If backup creation fails:

- migration does not run
- ProgramData is not made authoritative
- existing legacy data remains untouched
- startup stops safely
- the failure is logged

This is the core migration safety rule:

```text
No successful pre-upgrade backup, no legacy migration.
```

A mandatory ProgramData-to-ProgramData pre-upgrade backup gate for future application upgrades is not part of the current implemented v1.2 model. That is a post-v1.2 follow-up.

---

## Backup contents

A Windows pre-upgrade backup protects the currently authoritative source layout for the operation being performed.

For legacy migration, the backup includes:

- MariaDB database backup
- the resolved uploads folder and everything beneath it
- launcher settings where present
- a backup manifest

The uploads backup must include the whole uploads tree.

It must not assume there is only one upload subfolder.

Legacy uploads may include folders such as:

```text
plants
taxa
```

and future upload categories may be added.

---

## Legacy migration flow

The implemented first-time legacy migration flow is:

1. Detect layout.
2. Confirm exactly one data-bearing legacy source layout.
3. Create mandatory pre-upgrade backup.
4. Stop safely if backup fails.
5. Copy legacy MariaDB data into ProgramData.
6. Copy the full legacy uploads tree into ProgramData.
7. Copy legacy launcher settings into ProgramData, if present.
8. Write migration state.
9. Start MariaDB from ProgramData.
10. Start OrchidApp using ProgramData paths.

The migration copies data.

It does not move, delete or rename the old legacy data.

This means the legacy source remains available after migration as a historical safety copy.

---

## Migration copy behaviour

Legacy MariaDB data is copied from:

```text
<legacy-root>\data\mariadb
```

to:

```text
C:\ProgramData\OrchidApp\data\mariadb
```

Legacy uploads are copied from:

```text
<legacy-root>\wwwroot\uploads
```

to:

```text
C:\ProgramData\OrchidApp\uploads
```

Legacy launcher settings are copied from:

```text
<legacy-root>\launcher-settings.json
```

to:

```text
C:\ProgramData\OrchidApp\launcher-settings.json
```

if the legacy settings file exists.

Migration is blocked if ProgramData already contains any of the following:

```text
C:\ProgramData\OrchidApp\data\mariadb\orchids
C:\ProgramData\OrchidApp\uploads
C:\ProgramData\OrchidApp\launcher-settings.json
```

where those paths indicate existing user data or settings that could be overwritten.

---

## Migration state

Migration state is written to:

```text
C:\ProgramData\OrchidApp\migration-state.json
```

The implemented migration state records:

- schemaVersion
- migrationStatus
- migrationStartedAtUtc
- migrationCompletedAtUtc
- failedAtUtc
- sourceLegacyRootPath
- targetProgramDataRootPath
- applicationProductVersion
- applicationInformationalVersion
- preUpgradeBackupPath
- migratedMariaDbData
- migratedUploads
- migratedLauncherSettings
- errorMessage

Clean first install does not write migration state.

Legacy migration writes `Started` only after the mandatory pre-upgrade backup succeeds.

Legacy migration writes `Completed` after the legacy data copy succeeds.

Legacy migration writes `Failed` and stops startup if migration throws.

The current v1.2 implementation does not wait until post-copy MariaDB startup verification before writing `Completed`.

That stricter behaviour is a post-v1.2 follow-up. The current safety model remains acceptable because migration is copy-only and the legacy data remains untouched.

---

## Normal post-migration startup

After ProgramData is in use, normal startup uses ProgramData paths.

The launcher:

1. Verifies the ProgramData folder structure.
2. Detects the layout.
3. Starts MariaDB from ProgramData.
4. Passes the ProgramData upload root to the web application.
5. Starts OrchidApp.

Expected paths include:

```text
MariaDB DataDir: C:\ProgramData\OrchidApp\data\mariadb
Web upload root: C:\ProgramData\OrchidApp\uploads
Desktop UploadRoot: C:\ProgramData\OrchidApp\uploads Source: Environment
```

The application folder remains replaceable application code.

---

## Normal backup behaviour

Normal Windows backups use ProgramData as the data source.

Normal backup source paths include:

```text
C:\ProgramData\OrchidApp\data\mariadb
C:\ProgramData\OrchidApp\uploads
C:\ProgramData\OrchidApp\launcher-settings.json
```

Normal backup ZIPs are written to:

```text
C:\ProgramData\OrchidApp\backups
```

Pre-upgrade backup ZIPs are written to:

```text
C:\ProgramData\OrchidApp\backups\pre-upgrade
```

The optional cloud-folder copy writes the latest backup as:

```text
OrchidAppDataBackup.zip
```

in the user-configured cloud-synchronised folder.

Cloud backup copy failure is logged as a warning and does not invalidate a successful local backup.

---

## Launcher settings

Launcher settings are stored at:

```text
C:\ProgramData\OrchidApp\launcher-settings.json
```

They are not stored beside the application binaries.

This includes the configured cloud backup folder path.

---

## Launcher logging

The launcher writes persistent support logs to:

```text
C:\ProgramData\OrchidApp\logs\launcher.log
```

The log records startup, layout detection, backup, migration, MariaDB startup and web application launch decisions.

If `launcher.log` exceeds 1 MB at launcher startup, it is moved to:

```text
C:\ProgramData\OrchidApp\logs\launcher.previous.log
```

A fresh `launcher.log` is then started.

Only these two launcher log files are retained.

The launcher must not write `launcher.log` to the installed application folder.

---

## Safe-stop conditions

The launcher must stop safely when it detects an unsafe or ambiguous layout state.

Safe-stop conditions include:

- more than one data-bearing legacy layout
- both a data-bearing legacy layout and a ProgramData layout
- failed mandatory pre-upgrade backup
- failed legacy data copy
- failed migration-state write
- missing required runtime dependencies
- failed MariaDB startup
- missing or unusable ProgramData MariaDB data after migration

A safe stop must not delete, rename or overwrite the legacy layout.

A safe stop must not make an empty or partial ProgramData layout authoritative.

A safe stop must produce clear logs for support diagnosis.

---

## Uninstall behaviour

Uninstall removes application files and shortcuts.

Uninstall must not delete:

```text
C:\ProgramData\OrchidApp
```

Therefore uninstall preserves:

- plant database
- uploaded photos
- backups
- launcher settings
- migration state
- launcher logs

The installer uninstall prompt must tell users that their plant data, uploaded photos, backups and settings are preserved.

---

## Unsigned installer limitation

The Windows installer is currently unsigned.

Windows may therefore show:

```text
Publisher: Unknown
```

when the installer is run.

This is an accepted limitation.

Code signing requires a paid certificate or paid signing service and is not cost-effective for OrchidApp at this stage.

This does not affect the data layout, backup behaviour, migration safety or ProgramData preservation model.

---

## ZIP/package output

ZIP-style or folder-based Windows package output may remain for development and testing.

It is not the public Windows upgrade route.

Public Windows upgrades must use the installer.

Users must not upgrade by extracting a new ZIP or package folder over an existing OrchidApp folder.

---

## Documentation responsibilities

Documentation must explain the Windows upgrade model in user-safe language.

Documentation must state that:

- public Windows upgrades use the installer
- users must not upgrade by extracting a ZIP over an existing OrchidApp folder
- user data is stored separately from application files
- ProgramData is the Windows mutable data root
- uninstall preserves user data
- the launcher log is available for support
- the installer may show Unknown publisher because it is unsigned

User documentation must not require users to manually inspect MariaDB folders unless they are following a support or recovery procedure.

---

## Post-v1.2 follow-ups

The following items are not part of the implemented Issues 1-10 model and are intentionally deferred.

### ProgramData-to-ProgramData upgrade backup gate

Future upgrades should add a mandatory pre-upgrade backup gate when ProgramData is already authoritative and the application version changes.

This will require launcher state tracking such as:

```text
C:\ProgramData\OrchidApp\launcher-state.json
```

The future state may record:

- lastSuccessfulProductVersion
- lastSuccessfulInformationalVersion
- lastSuccessfulStartupAtUtc

The launcher should then create a pre-upgrade backup before allowing upgrade-sensitive startup under a changed application version.

### Post-copy MariaDB verification before marking migration complete

Future migration hardening may delay `migration-state.json` status `Completed` until the copied ProgramData MariaDB data has started successfully and the database has been verified.

The current implementation records migration completion after successful copy.

This is accepted for v1.2 because legacy migration is copy-only and old data remains untouched.

### Stronger ProgramData authority model

A future version may allow valid ProgramData to take precedence over leftover legacy app-root data without safe-stopping.

That requires stronger authority tracking and support wording.

The current v1.2 implementation uses a conservative safe stop when both data-bearing legacy and ProgramData layouts are detected.

---

## Final rule

The installer owns application files.

The launcher owns user-data safety.

The database owns invariants.

User data must survive upgrade failure.
