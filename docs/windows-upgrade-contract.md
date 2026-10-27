# Windows upgrade contract

This reference describes the installer-led Windows model in the current v1.3.0
source. It distinguishes required data-safety rules from implemented checks and
known gaps. It is not certification of an existing installer or a successful
end-to-end migration/restore test.

See [architecture](architecture.md), [contribution guidance](../CONTRIBUTING.md)
and the [Windows user guides](user-guides/windows/) for related responsibilities
and operating instructions.

## Core requirements

- Public Windows upgrades use the installer; users must not overwrite an existing
  installation with a ZIP or package folder.
- Application binaries are replaceable. Database contents, photos and user settings
  are durable state and must survive installation, upgrade and uninstall.
- The installer manages application files and shortcuts. The launcher resolves
  runtime data paths and orchestrates legacy migration. Desktop web bootstrap
  manages fresh schema setup and pending database migrations.
- Ambiguous data layouts must stop startup rather than select a source by guesswork.
- Data-changing upgrades need recoverable backups. A completed copy or backup
  process does not establish database readiness or successful restoration.

These are requirements; the implementation limitations below must not be hidden
behind claims that all failure paths are already safe.

## Installed files and persistent paths

The Inno Setup installer defaults to `C:\Program Files\OrchidApp` on a standard
Windows installation. It requires administrative installation and supports
x64-compatible Windows. The installed package contains the launcher, web app,
bundled runtimes, MariaDB/libvips binaries, SQL files, tools and static assets.
Treat the actual selected install directory as the app root, not a fixed path
that every installation must use.

`WindowsProgramDataPaths` resolves `CommonApplicationData` and appends `OrchidApp`.
On a standard installation, persistent locations are:

```text
C:\ProgramData\OrchidApp\data\mariadb
C:\ProgramData\OrchidApp\uploads
C:\ProgramData\OrchidApp\backups
C:\ProgramData\OrchidApp\backups\pre-upgrade
C:\ProgramData\OrchidApp\logs
C:\ProgramData\OrchidApp\launcher-settings.json
C:\ProgramData\OrchidApp\migration-state.json
```

The PowerShell backup/restore tools resolve their corresponding root through
`$env:ProgramData`. The launcher creates required directories before layout
detection. Empty folders alone do not establish that an existing database is valid.

The launcher starts bundled MariaDB using the ProgramData data directory and the
local connection model on port 3308. It supplies `ORCHIDAPP_UPLOAD_ROOT` and both
`ConnectionStrings__DefaultConnection` and `ConnectionStrings__OrchidDb` to the
web process in `Desktop` mode. Local connection defaults remain fixed in several
code paths; do not describe them as fully configurable at runtime.

MariaDB is the supported database engine. Provider identifiers such as
`MySqlConnector` are library names, not support for a separate database server.

## Installer boundary

`installer/windows/OrchidApp.iss` copies the packaged application tree, creates
Start Menu/optional Desktop shortcuts and offers a post-install launch. Its stable
AppId identifies the product across installer upgrades. The build script passes
the packaged launcher's public version to Inno Setup and names the output
`OrchidAppSetup-<version>.exe`.

The installer excludes mutable package contents matching:

```text
data\*
wwwroot\uploads\*
uploads\*
backups\*
logs\*
launcher.log
launcher-settings.json
migration-state.json
```

It has no ProgramData migration operation or deletion rule. Its uninstall message
states that plant data, photos, backups and settings are preserved. The
`[UninstallDelete]` section is intentionally empty; uninstall removes installed
application files and shortcuts while leaving ProgramData alone.

`CloseApplications=no` leaves process shutdown with the operator. The pre-install helper refuses active/unclear processes rather than force-closing a database.
C18 now requires a verified offline snapshot before replacing any existing application/persistent files, including app-only upgrades. [Installer backup and recovery](windows-installer-recovery.md) defines the gate and its distinct archive format. The checked-in installer
configuration has no signing configuration; do not claim a particular distributed
binary is signed without inspecting that artefact. An unsigned installer may show
an unknown publisher.

## Layout detection

`OrchidAppLayoutResolver` examines the current launcher root, Desktop folders,
shortcut targets, selected common locations and bounded fallback searches.
It de-duplicates paths and excludes recognised ProgramData aliases. This is not
an exhaustive search of every disk or account. Unreadable candidates can be skipped.

A data-bearing database candidate is a nonempty `data\mariadb\orchids` folder.
That filesystem heuristic does not open MariaDB, check tables or prove that the
database is complete, current or recoverable.

| Data-bearing legacy candidates | Nonempty ProgramData orchids folder | Result |
| --- | --- | --- |
| None | No | `NewInstall` |
| None | Yes | `ProgramDataLayoutInPlace` |
| One | No | `OldLayoutRequiresMigration` |
| One | Yes | `LegacyAndProgramDataFound`: stop |
| More than one | Either | `MultipleLegacyLayoutsFound`: stop |

The table describes layouts without recognised migration ownership. A version 2
state record, matching target ownership token and readiness completion allow the
verified ProgramData target to take precedence over its exact preserved source.
The source path and SHA-256 inventory fingerprint must still match when that
source exists. A changed source or unrelated discovered source stops startup.
No source is deleted to resolve a conflict. Missing targets or ownership tokens
also stop; a saved status alone cannot authorise recreating a missing collection.

Empty target folders are permitted for new copying. Any existing MariaDB files,
including partial system databases, uploads or launcher settings block a new
migration. An interrupted operation may resume only under its recorded ownership
and file inventory, as described below. Empty, corrupt or version 1 state requires
support review; old copy-only completion is not treated as readiness evidence.

## Legacy migration

Legacy sources use these paths relative to the detected root:

```text
data\mariadb
wwwroot\uploads
launcher-settings.json
```

The sequence is discovery, quiescent source capture, successful safety backup,
version 2 state `Started`/`Copying`, verified copy to ProgramData,
`AwaitingReadiness`, database identity/bootstrap and successful web response,
then `Completed`. Backup failure aborts before copying. Failures preserve their
last phase and original input. The launcher attempts to record `Failed` without
destroying the last valid atomic state if that write also fails.

`LegacyMigrationCoordinator` copies the complete MariaDB data tree, the complete
legacy `wwwroot\uploads` tree when present, and settings when present. It does not
overwrite existing files, delete the source or migrate the old backups/logs tree.
It does not discover arbitrary alternate legacy upload roots.

Copying is not a cross-directory transaction. Each file is copied to unique work
space, checked and moved into place without replacing an existing destination.
After interruption, the launcher offers to resume the recorded operation. All
existing target components must be exact inventory members with matching hashes;
missing files may then be copied from the same unchanged capture. Changed or
unrelated destination files stop the operation. No automatic deletion or rollback
of partial data is attempted. Retain original data, captured input, work files,
state and the verified safety ZIP until acceptance; support must review conflicts.

Raw database files are copied only from the quiescent capture used for backup.
The original source fingerprint is recorded while its capture read locks are held.
Do not run the old installation again: its raw engine files/settings may change,
invalidating preserved-source identity and requiring review even if its logical
plant records appear unchanged. An empty uploads root is represented explicitly
when the captured source has no uploads.

### Source-bound safety backup

The installed backup tool receives the captured root explicitly as
`-LegacySourceRoot`, separately from its installed runtime location. The original
legacy path is recorded in capture/backup metadata. Both backup and restore check
the listener's actual MariaDB data directory before dump/import. An unrelated
listener fails the operation and is not shut down. Raw copying proceeds only
after the captured database stops cleanly and a verified completed ZIP exists.
See the [backup source/archive contract](windows-backup-format.md) and
[C06/C07 local evidence](maintenance/c06-c07-backup-source-and-format.md).

## Migration state and completion

`MigrationStateService` serialises the state object to `migration-state.json`
using its property names, such as `SchemaVersion`, `MigrationStatus`,
`SourceLegacyRootPath`, `TargetProgramDataRootPath`,
`ApplicationProductVersion`, `ApplicationInformationalVersion`,
`PreUpgradeBackupPath` and copied-component flags. Start/completion/failure times
are recorded in UTC. The current serializer does not apply camel-case naming.

A clean first install does not create legacy migration state. Version 2 adds
`Phase`, `OperationId`, `SnapshotRootPath`, `SourceFingerprint` and a
`CopyManifest` with SHA-256 file hashes/directory entries. `migration-target-id`
binds the target to that operation. State writes flush a temporary file and use
same-directory atomic replacement. An exclusive migration lock prevents concurrent
migration attempts; ordinary Close is refused while copying/readiness runs.

Only `Copying` may resume file copying. Once `AwaitingReadiness` is saved, subsequent
launches retry database/web readiness against the copied target and never recopy
raw database files that startup may have changed. Occupied database/web ports
stop migration startup. The launcher starts MariaDB with explicit basedir/datadir
and no option files, verifies `@@datadir` before bootstrap and waits for web success
before saving completion, opening the browser or enabling automatic backup.
A failed completion write leaves readiness pending. This is startup readiness,
not proof of every plant/photo workflow or installed-device acceptance.

Version 1 records cannot be automatically promoted because they lack source/target
ownership and readiness evidence. Preserve all files for support-led reconciliation;
do not delete state or old folders to force a new install. There is no implemented
`launcher-state.json` tracking the last successfully started product version.

## Fresh setup and same-layout upgrades

For a fresh ProgramData deployment, the launcher initialises MariaDB as needed
and starts the web process. Desktop bootstrap creates the current canonical
schema and records its schema-contained baseline without scanning historical migrations.

For an existing database, Desktop bootstrap compares recorded migration checksums,
collects pending files and invokes the normal backup tool before applying them.
Backup failure aborts SQL migration. New records are verified after successful
application. This is distinct from the legacy PreUpgrade backup path.

The Desktop SQL backup remains conditional on pending migrations. C18 adds a
separate mandatory offline installer snapshot before replacing existing files,
including same-layout app-only updates. See [installer recovery](windows-installer-recovery.md).
SQL application can leave partial DDL on failure; neither
installer rollback nor data-copy preservation automatically reverses schema changes.
See [migration paths](architecture.md#implemented-migration-paths).

## Backup format and normal operation

Normal backups read ProgramData and produce a ZIP containing:

- `orchids.sql`: a logical dump with database selection, routines, triggers and
  events, including database/table replacement statements for restore.
- `uploads/`: copied upload contents across all categories, such as plants/taxa.
- `launcher-settings/launcher-settings.json`, when settings exist.
- `manifest.json` and `schemaversion.txt`.

This is not a raw archive of the running MariaDB data directory. Normal ZIPs go
under `backups`; legacy PreUpgrade ZIPs go under `backups/pre-upgrade`. The launcher
offers manual backup and attempts an automatic backup when none exists or the
latest is more than 168 hours old; that is not a continuous scheduler or a
version-change gate.

The normal backup flow does not stop web writes for the entire database-and-file
copy. A single-transaction dump protects transactional database reads but does
not establish a common snapshot with uploads. Concurrent changes need explicit
consistency testing and operational control.

Routine backup now retains three verified unprotected archives by default,
always including the new current ZIP. `BackupsToKeep` must be at least one;
`SkipOldBackupPruning` disables deletion. PreUpgrade backups and protected
recovery directories never participate in routine pruning. Recorded restore
inputs and migration/safety copies are pinned; unrelated, unsupported or corrupt
files remain for review. These extras may exceed the requested count.
See the [retention contract](windows-backup-format.md#routine-backup-retention).

The Desktop database-update backup goes to `backups/pre-migration` with pruning
disabled. Routine retention cannot remove those safety copies. Archive creation
also preserves empty upload directories and hidden payload files.

After a successful normal local backup, the launcher can copy the latest ZIP to
the configured cloud-synchronised folder as `OrchidAppDataBackup.zip`, replacing
that copy. A copy failure is logged without invalidating the local ZIP. This
copies to a local folder; it does not verify remote cloud upload or availability.

## Restore format and validation

The launcher asks for explicit confirmation that restore replaces current data,
then stops its web process and invokes `tools/restore-orchidapp.ps1`. The script
validates manifest/version, payload inventory, settings and uploads before SQL
import. Version 2 requires a checksummed payload and an uploads directory even
when empty. A known older archive may declare omitted uploads empty; imported
photo references must agree before existing upload files are replaced.

Restore reads `launcher-settings/launcher-settings.json` and supports the older
root-level file. Conflicting files or missing declared components fail. Successful
restore replaces the upload set and restores included settings; absent settings
reset the target to defaults. See [archive compatibility](windows-backup-format.md).

Restore retains the selected input and requires a verified safety backup before replacement.
A persistent pending marker blocks normal startup/backups after destructive interruption;
the launcher offers explicit recovery from retained input or original safety copy.
It does not provide atomic rollback across SQL, uploads and settings. See the
[recovery procedure](windows-backup-format.md#failure-and-acceptance-boundaries). A success message is not a substitute
for checking restored plants, photos, settings and subsequent startup.

## Logging and failure handling

The launcher writes `logs/launcher.log`. At startup, a log larger than 1,048,576
bytes is moved to `launcher.previous.log`, replacing the prior rotated log.
This is startup rotation, not a continuous size limit. Backup and database tools
can create additional diagnostic logs; the two-file rule concerns launcher logs.

The launcher reports ambiguous layouts, failed backup/copy/state writes and
runtime startup failures. A reported failure must not be interpreted as proof that
all destination state is untouched. Retain source data, logs, backups and state
files for diagnosis; support must inspect partial targets before retrying.

## Validation required for changes

Changes must preserve application/user-data separation and include relevant
integration tests for clean install, same-layout upgrade, legacy discovery,
ambiguous sources, backup failure, interrupted copy, post-copy database failure,
uninstall/reinstall and complete restore.

Test source identity when an unrelated database is already listening, complete
uploads across categories, settings restoration, retained legacy sources after
migration, insufficient permissions/space and compatible migration history.
Use isolated fixtures, never production data for destructive validation.

CI currently creates a Windows package; it does not compile the Inno Setup
installer or exercise these installed-machine workflows. User documentation must
describe only supported, validated behaviour and provide recovery/support guidance
for the known gaps above.

## Implementation references

- `installer/windows/OrchidApp.iss`
- `scripts/build-windows-installer.ps1`
- `src/OrchidApp.Launcher/OrchidAppLayoutResolver.cs`
- `src/OrchidApp.Launcher/OrchidAppLauncherForm.cs`
- `src/OrchidApp.Launcher/Infrastructure/WindowsProgramDataPaths.cs`
- `src/OrchidApp.Launcher/Infrastructure/LegacyDataMigrationService.cs`
- `src/OrchidApp.Launcher/Infrastructure/MigrationStateService.cs`
- `src/OrchidApp.Web/Program.cs`
- `app/tools/backup-orchidapp.ps1`
- `app/tools/restore-orchidapp.ps1`

## Required follow-up and current operator boundary

Source-bound capture/backup and archive settings compatibility (C06/C07), explicit restore recovery (C08), migration reconciliation (C10) and protected routine retention (C09) are implemented with local checks. C18 adds real isolated Inno install/upgrade/uninstall, snapshot policy and disposable database recovery checks. CI and representative older-release/administrator installer acceptance remain pending; see [C18 evidence](maintenance/c18-installer-upgrades.md). Preserve a verified off-computer recovery copy before upgrading and obtain support for busy/ambiguous sources, changed partial targets or unsupported old state. See [C10 evidence](maintenance/c10-migration-reconciliation.md) and [C09 evidence](maintenance/c09-backup-retention.md).

Before restoring on a replacement PC, preserve the trusted ZIP separately and do not run a new empty-data backup into the only fixed-name cloud copy. A cloud destination is not required to select a restore ZIP. Configure future cloud backups only after verifying plants, photos, settings and subsequent startup. Included settings now restore through the supported archive layouts; verify them before enabling future backups.

Fresh Desktop creation uses the [schema-only contract](database-creation.md) implemented in C01/C02. Bespoke monitoring is not a Windows/general-install dependency.

## C15/C19 photo recovery acceptance

Include the actual uploads and their private `.photo-recovery` records with SQL in a paired recovery point. Stop all writers for a consistent snapshot; a SQL dump or verified archive is not end-to-end application acceptance. Windows Normal backup does not quiesce every writer, and Linux scheduled coordination covers only configured units. Preserve any copied journals on restore even if they came from an upload that later succeeded on the original machine.

After restore/start, require `/health/ready` to return 200 and reopen representative plant/taxon photos and thumbnails. Unresolved journals or missing active files return 503. Keep the input archive, matching files, SQL and logs; stop writers and follow [photo handling and read-only recovery review](photo-handling.md) before clearing any record. Never delete a journal just to force startup. C19 does not make concurrent SQL/file backups atomic or certify an installed recovery.
