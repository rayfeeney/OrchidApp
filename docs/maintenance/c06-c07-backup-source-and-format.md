# C06 and C07 backup source and archive compatibility evidence

> Status reconciliation, 30 October 2026: this article preserves the original implementation/test record. Its earlier next-step, merge and CI-pending statements describe that delivery stage. See [current status and scope](../current-state.md) for confirmed later CI, the remaining machine acceptance, and the v1.4.0 Windows baseline decision. Original results and limitations below are retained.

## Implemented changes

The launcher previously invoked installed backup tools without passing the detected legacy root. A listener on the normal MariaDB port could be reused without proving its source directory. Backup wrote launcher-settings/launcher-settings.json but restore searched only the archive root.

The launcher now captures the selected source's database tree, uploads and settings into a unique staging root before backup or raw migration. Capture holds read handles that deny writes/deletion to every source file, rejects reparse points and checks inventory before/after copying. An active database or other open writer blocks capture. The work runs off the UI thread. The original source remains untouched by the capture/copy process.

Installed runtime paths and captured data paths are separate. The launcher passes LegacySourceRoot using structured process arguments, requires the returned completed ZIP to exist and copies raw data from that same captured root after backup has shut its database down cleanly. Backup/restore query the actual MariaDB data directory before dump/import, reject unrelated listeners and leave independently running processes alone. A process handle is retained so Windows PowerShell can verify clean exit rather than receiving an unavailable ExitCode. No forced shutdown authorises raw copying.

New version 2 archives include the SQL, schema-version export, uploads, optional nested settings and a manifest of relative payload paths, sizes and SHA-256 values. A new ZIP is extracted and validated before backup success. Restore supports the nested settings location and older root location, rejects conflicting settings and validates JSON/property types, format, required components and inventory before import. Missing uploads in known older archives require an explicit empty declaration and must agree with imported photo references. Ambiguous missing legacy settings require source review; version 2 records intentional absence explicitly. Successful restore replaces the upload set and restores settings, or resets absent settings to defaults.

The shared Backup-Contract.ps1 is copied with the existing tools directory by Windows packaging. The launcher now uses the script's declared SkipOldBackupPruning switch for the legacy gate; general retention remains unresolved C09. The script retains unique extracted input/logs rather than deleting a common restore-temp directory. Recovery orchestration, safety copies and atomic rollback are not claimed by these changes.

## Actual validation

Local Windows x64 tests used MariaDB 10.11.16, .NET SDK 9.0.315/.NET 8, PowerShell 7 and Windows PowerShell 5.1. Every database, source, destination, upload and settings fixture was generated in an isolated directory. The runtime executables were read from the installed MariaDB runtime; the live collection and real ProgramData data were not used.

- 13 C# source capture/migration checks passed: separate source/staging/target, byte-preserving database/photos/settings capture, open writer refusal, unchanged original, snapshot independence, actual migration helper, populated-target refusal and missing source.
- 24 payload policy checks passed under each PowerShell version. They cover versioned and known unversioned settings layouts, SQL/file hashes, missing uploads/settings, explicit empty/absent states, conflicting settings, malformed JSON/property types, wrong database, future/fractional versions, unsafe/duplicate paths and ZIP traversal before extraction.
- 24 Windows packaged backup/restore database checks passed. A running real source database blocked capture. An unrelated live listener was rejected without a safety ZIP or changes to that listener. Once stopped, the captured source produced a verified backup and a copied database that started successfully at its separate target.
- Version 2 and synthetic unversioned/root-settings archives round-tripped a stored-procedure-created plant, Unicode notes, plant/taxon photo and thumbnail file bytes, and launcher settings. The normal ProgramData backup/restore path also round-tripped. Corrupt SQL was rejected before import, proved by a preserved database witness. Missing referenced photos and omitted explicit source roots could not create another safety ZIP.
- Launcher and C# fixture Release builds passed with zero warnings/errors. The changed scripts parse, and actionlint workflow validation passed with ShellCheck/Pyflakes integrations disabled.

The database test uses named script files and JSON request data to return original exception messages. It does not embed generated scripts in encoded command strings. It runs the production tools under Windows PowerShell, matching the packaged launcher. Its source/target loopback ports are checked before use and its own database processes are shut down. Small fixture trees, SQL dumps and staging are retained for diagnosis outside the delivery.

Photo checks here prove stored-file integrity and reference pairing, not native image decoding or a browser photo workflow. The test image paths contain deterministic fixture bytes. Earlier C16 native/browser evidence is separate. Unversioned archive fixtures test format compatibility, not an actual historical database installation.

## Documentation verification

The maintained Windows source/archive contract, upgrade contract, backlog, index/map, architecture, contributor checks and release notes were updated. Windows Word guides 04 and 05 each received one targeted correction removing the settings-path defect warning while retaining recovery verification guidance.

All five embedded media items in each Word guide were byte-preserved. The guides were rendered with the packaged document page renderer using hidden native Word PDF export, because bundled LibreOffice is not available on this Windows host. All six pages of guide 04 and seven pages of guide 05 were visually inspected. Their existing screenshot-based procedures and layout were preserved; internal render PDFs/PNGs are not delivery files.

## Remaining limits and next step

New Windows CI steps compile/run the source checks, run payload checks under both shells and run the isolated database round trip before packaging. That GitHub Actions run is still unconfirmed. A real installer clean install/upgrade/recovery and real historical-installation fixtures have not been tested here.

SQL import, uploads and settings are not one transaction. Failure after import can leave partial state. Normal backup still does not quiesce all web writes across SQL and file copying. C08 owns recoverable failure handling and protection from later cloud-copy replacement; C09 owns retention; C10 owns incomplete/completed migration-state reconciliation; C18 owns installed-machine acceptance. Retained source/staging is a recovery input, not automatic rollback/resume.

All canonical schema, schema-checksum and applied migration SQL inputs remain unchanged. No database migration is required for this tooling change. Next in the agreed order is C08. Use the [Windows archive contract](../windows-backup-format.md) and [upgrade contract](../windows-upgrade-contract.md) for maintained operational details.
