# Windows backup source and archive contract

This is the maintained reference for the packaged Windows backup/restore tools. Use the launcher for ordinary operations. Keep a separate trusted recovery copy before deliberate replacement. Local C06/C07 and C08 checks cover the paths below; installed-machine and historical-release acceptance remain separate.

## Legacy source selection

The launcher first selects the single detected legacy installation. Before starting another database or copying raw data, it captures that source's data/mariadb, wwwroot/uploads and launcher-settings.json into a unique ProgramData migration-staging directory.

Capture rejects reparse points and holds read handles that deny writes/deletion to every source file while copying. A running MariaDB or another open source writer blocks capture. File/directory inventory changes during capture also fail. The original source is retained. Close the old application/database and seek support for a busy/changed source; the launcher does not stop an unrelated database to force migration.

The mandatory backup receives the captured root explicitly through LegacySourceRoot. Its executable/runtime location remains the installed application directory. The logical dump and the later raw-file migration therefore use the same captured source, even if the detected legacy installation and new application directory differ. The captured database must stop cleanly after dumping before raw migration may proceed. The launcher does not accept an exit-success result without the returned completed ZIP existing.

Staging and failed-attempt diagnostic folders are retained for review. They are not additional discovered legacy installations or a completion/retry policy. C10 still covers migration-state reconciliation and partial destinations.

## Database identity

Backup and restore use explicit TCP/port arguments and ignore native option files. Before dump/import, SELECT @@datadir must match the selected source or target directory. Merely finding a port listener is insufficient. An unrelated listener causes failure and is not shut down. The tools shut down only a process they started, recheck identity, require clean exit and never force-kill it to authorise copying raw files.

Normal backup uses the ProgramData database/uploads/settings paths. Unlike the captured legacy path, normal backup does not quiesce all application writes across SQL and file copying. A transactional SQL dump alone is not an atomic SQL/filesystem snapshot. General concurrent-write backup/recovery work remains separate.

## Archive version 2

New archives contain:

- orchids.sql: nonempty logical dump of orchids, including routines, triggers and events.
- uploads/: all copied categories, including plants and taxa, with an explicit empty directory when appropriate.
- launcher-settings/launcher-settings.json when settings were present.
- schemaversion.txt and manifest.json.

The manifest records formatVersion=2, source paths, original legacy source when captured, database/payload names, upload count, settings presence and each payload file's relative path, length and SHA-256. Logs stay outside the archive payload. A newly written ZIP is extracted and checked before backup reports success. No schema or applied migration history is rewritten by backup.

Backup checks that active database photo references have corresponding source files. Restore verifies the inventory and settings JSON before SQL import, then verifies the imported database's photo references against extracted uploads before replacing existing upload/settings files. Checks detect corrupt/incomplete payloads; they do not authenticate an untrusted ZIP.

## Older archive compatibility

Unversioned archives from the prior writer, and formatVersion=1, use the known orchids database/payload metadata and upload count. Both nested launcher-settings/launcher-settings.json and older root launcher-settings.json are supported. If both are present with different bytes, restore fails. A settings file must be a JSON object with the expected cloud-folder value type. Unsupported versions, wrong database/payload, missing declared settings and mismatched inventory/counts fail. If an older archive has no settings file and no explicit absence declaration, restore requires source review rather than silently claiming complete recovery.

An older archive may omit uploads only if its manifest explicitly declares uploadsIncluded=false and uploadsFileCount=0. Its imported database must also have no active missing photo references. An undeclared missing directory is rejected. Version 2 always requires uploads/, even when empty. These compatibility checks concern archive layouts; they do not prove upgrades/restores from actual older application releases.

Successful restore replaces the upload set rather than leaving unrelated photos mixed with the restored database. If the archive contains no settings, previous target settings are removed so the restored installation uses defaults. Keep custom photo locations and cloud-folder settings in mind when checking restored data.

## Failure and acceptance boundaries

Structural/archive validation happens before import. Restore first copies the selected ZIP into a unique ProgramData/OrchidApp/restore-recovery/<id>/recovery-input.zip, holding the selected file against writes/deletion while copying. It validates that retained copy and creates a verified normal-format safety ZIP in that operation's safety/ directory. A safety-copy failure stops replacement. These safety ZIPs are outside routine backup retention. A selected ZIP inside the uploads directory being replaced is refused. Close other OrchidApp instances and do not edit data during recovery.

Before the first SQL statement, restore writes restore-pending.json in the ProgramData OrchidApp root. The journal records the input, original safety copy, operation directory and phase: ImportingDatabase, VerifyingPhotos, ReplacingUploads, ReplacingSettings, StoppingDatabase or Completed. Updates use same-directory temporary files and replacement. A second restore process cannot acquire the restore lock while one is running. The marker survives process interruption; it is removed only after successful database/photo/settings restoration and clean shutdown of a database started by the tool.

While that marker exists, launcher startup stops before migration, database/web startup and automatic/cloud backup. Ordinary backup and ordinary restore invocations refuse to proceed. The launcher enables Restore from backup and explains the recovery choices. Yes restores the retained input; No restores the safety backup from before the first attempt; Cancel leaves everything for support. A recovery attempt retains the previous journal and original safety copy instead of backing up partial data. If a recovery file or journal is unavailable/corrupt, stop and obtain support; do not delete the pending marker to bypass the block.

Before streaming SQL, the journal also records the native import process ID and start time. Recovery refuses to compete with that same process if it survived an interrupted PowerShell/launcher session. Wait for it to exit and contact support if it does not; do not start a second import or force a retry. The launcher refuses an ordinary Close while its restore is running.

For support-led recovery with the launcher closed, use the installed tools directory and one explicit action:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ./restore-orchidapp.ps1 -RecoveryAction RestoreInput
# Or, to return to the collection before the original attempt:
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ./restore-orchidapp.ps1 -RecoveryAction RestoreSafety
```

The tool uses the pending record, not a newly supplied BackupZip. Normal selection still uses -BackupZip. Preserve operation folders, original ZIPs and launcher logs until plants, photo bytes, settings and a subsequent startup have been checked. No automatic rollback is claimed: SQL and files are replaced sequentially. A full disk, permission problem or unavailable recovery input can require support before either recovery option succeeds.

Completed operation journals remain. The launcher refuses to copy a later fixed-name cloud backup over any recorded original input, retained input or safety ZIP, including after restarting. Select a different future cloud folder after verification. An unreadable history record also stops the cloud copy. This protection starts when the recovery operation is recorded; before selecting a recovery file, preserve it separately and avoid backing up a fresh empty installation over your only cloud copy.

If web shutdown fails before restore starts, the launcher reports that no restore began and restores usable controls. If the web app has stopped but preflight fails, Open and Backup stay disabled and Restore remains available; close and reopen for normal startup when no pending marker exists. After a destructive failure, the persistent recovery state takes precedence.

Retention remains C09. The legacy invocation now passes the declared SkipOldBackupPruning switch; the existing general pruning condition is still unresolved and is not certified here.

Run the relevant checks from the repository root:

```powershell
dotnet run --configuration Release --project tests/BackupRestore.Checks/BackupRestore.Checks.csproj
pwsh ./tests/BackupRestore.Checks/Policy.Checks.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ./tests/BackupRestore.Checks/Policy.Checks.ps1
pwsh ./tests/BackupRestore.Checks/Database.Checks.ps1 -MariaDbRuntimeRoot ./app/runtime/mariadb/win-x64
```

The database suite requires Windows, an initialized build of its C# fixture utility and a complete MariaDB 10.11 runtime with mariadb-install-db.exe. It uses unique source/target/ProgramData fixtures and unused loopback ports, not the live collection. Use a short FixtureParent path because native Windows MariaDB dump paths remain length-limited. The suite exercises partial SQL, post-import photo and locked upload/settings failures and explicit recovery. It retains fixture directories and cleans up its own database processes. New Windows CI checks still require confirmation. See [C06/C07 evidence](maintenance/c06-c07-backup-source-and-format.md), [C08 recovery evidence](maintenance/c08-restore-recovery.md) and the [Windows upgrade contract](windows-upgrade-contract.md).
