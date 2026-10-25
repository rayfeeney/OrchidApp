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

`CloseApplications=yes` asks Inno Setup to handle affected running applications;
it is not an implemented database backup or complete migration-readiness check.
No unconditional pre-install backup gate is defined. The checked-in installer
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

Uploads and launcher settings are also recorded during discovery, but they do
not make ProgramData authoritative in this status calculation. Migration performs
additional checks: a nonempty target orchids folder, nonempty target uploads
folder or existing target settings file blocks copying. Empty target folders are
permitted. Partial system-database files or other residual state need support
review rather than assumptions based only on these statuses.

The current startup path does not use saved migration state to choose a canonical
layout. A preserved legacy source can therefore conflict with ProgramData on a
later launch. Do not promise automatic precedence for ProgramData or advise users
to delete old folders merely to clear the conflict.

## Legacy migration

Legacy sources use these paths relative to the detected root:

```text
data\mariadb
wwwroot\uploads
launcher-settings.json
```

The sequence is discovery, quiescent source capture, successful safety backup,
migration-state `Started`, copy from that capture to ProgramData, migration-state `Completed`, then local database
and web startup. Backup failure aborts before the copy. Copy failure is reported
and the launcher attempts to write `Failed` state before stopping.

`LegacyDataMigrationService` copies the complete MariaDB data tree, the complete
legacy `wwwroot\uploads` tree when present, and settings when present. It does not
overwrite existing files, delete the source or migrate the old backups/logs tree.
It does not discover arbitrary alternate legacy upload roots.

Copying is not transactional. Failure can leave a partial ProgramData destination;
there is no automatic cleanup, rollback or resume/reconciliation policy. Source
preservation provides a recovery option, not proof that the partial destination
cannot affect later discovery. Raw MariaDB files must be copied from a quiescent
source. The launcher now captures the source while denying file writes/deletion,
rejects an active database/writer or changing inventory, and uses the same staged
data for backup and copying. The migration service alone does not stop a live
database; callers must use the captured source. C10 still owns reconciliation.

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

A clean first install does not create legacy migration state. `Started` is saved
after the backup command succeeds. `Completed` is saved after file copying,
before the copied database has started or the web app has passed functional checks.
The flags describe copying/source presence; they are not content checksums.

State writes use direct file replacement, without a transactional file-write
protocol. State-save failures can stop startup but may also leave incomplete
diagnostic state. There is no implemented `launcher-state.json` tracking the last
successfully started product version.

## Fresh setup and same-layout upgrades

For a fresh ProgramData deployment, the launcher initialises MariaDB as needed
and starts the web process. Desktop bootstrap creates the current canonical
schema and records its schema-contained baseline without scanning historical migrations.

For an existing database, Desktop bootstrap compares recorded migration checksums,
collects pending files and invokes the normal backup tool before applying them.
Backup failure aborts SQL migration. New records are verified after successful
application. This is distinct from the legacy PreUpgrade backup path.

An app-version change without pending SQL does not trigger an unconditional
same-layout pre-upgrade backup. Do not describe this as a backup gate for every
installer update. SQL application can leave partial DDL on failure; neither
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

The legacy launcher now passes the declared `SkipOldBackupPruning` switch.
General retention remains C09: the script still tests an undeclared
`PruneOldBackups` variable. Do not claim that the nominal
`BackupsToKeep` setting is reliably enforced until corrected and tested.

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

Source-bound capture/backup and archive settings compatibility (C06/C07), plus explicit restore recovery (C08), are implemented with local checks. New CI and installed-machine acceptance remain pending. [C09, C10 and C18](code-change-backlog.md) retain retention, migration-state reconciliation and installed-upgrade work. Preserve a verified off-computer recovery copy before upgrading and obtain support for busy/ambiguous legacy sources or partial targets.

Before restoring on a replacement PC, preserve the trusted ZIP separately and do not run a new empty-data backup into the only fixed-name cloud copy. A cloud destination is not required to select a restore ZIP. Configure future cloud backups only after verifying plants, photos, settings and subsequent startup. Included settings now restore through the supported archive layouts; verify them before enabling future backups.

Fresh Desktop creation uses the [schema-only contract](database-creation.md) implemented in C01/C02. Bespoke monitoring is not a Windows/general-install dependency.
