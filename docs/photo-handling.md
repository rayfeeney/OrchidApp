# Photo handling and recovery

New plant and taxon photos are rotated upright before either JPEG is generated. `MediaIngestion:StripGpsMetadata` defaults to `true`: GPS, EXIF camera fields, XMP, IPTC and comments are removed from the saved photo and thumbnail. ICC colour profiles are retained. Setting it to `false` deliberately retains source metadata, while still normalizing orientation. Audit any explicit override before deploying. Existing photos are not rewritten and original uploads are not retained separately.

Uploads are limited to 10 MiB and 40 million pixels; detected animated/multipage images are rejected. Defaults remain a maximum 3072-pixel main image, JPEG quality 90, and a maximum 300-pixel thumbnail. Smaller images are not enlarged; transparency becomes white. Both outputs must succeed. There is no fallback that reports a failed thumbnail as success.

## Database and files

Deploy `202610271200_PhotoTaxonTransaction.sql` with the app. It changes `spUpdateTaxonDetails` to preserve the caller's transaction using a savepoint. Fresh creation uses the generated schema/bootstrap manifest with cutoff `202610271200`; it does not replay historical migrations. Never edit applied SQL or ledger rows. The new taxon write filter refuses an older or incomplete migration contract before invoking the routine.

Plant photo/observation writes and taxon add/edit writes use a request database transaction. A failed image, invalid handler result or database write rolls back that request and removes only its newly generated main, thumbnail and temporary files after confirmed rollback. Taxon replacement retains prior files and restores prior metadata on failure. Before publishing files, the app durably records their generated names under the upload root's `.photo-recovery` directory. Successful database commit clears that record. An uncertain commit, rollback, interrupted request or failed cleanup retains files and a recovery record for review. This is compensation across two storage systems, not one atomic database/filesystem transaction.

The app never automatically deletes orphan recovery records or assumes that a failed commit means SQL did not commit. Another photo upload is refused while unresolved records are present. Existing non-photo/read routes can still be available; stop all writers before recovery review. Recovery records and readiness probes are not served through `/uploads`.

## Readiness

`GET /health/live` returns 200 for a responding web process. `GET /health/ready` returns 200 only when these checks succeed; otherwise it returns 503 with sanitized boolean checks:

| Check | What it verifies |
| --- | --- |
| database | Explicit connection configuration, reachable database, photo tables and completed C19 migration contract |
| uploadRoot | Absolute existing upload root and an actual write/read/delete probe |
| nativePhotos | Native image processing saves and decodes a generated JPEG photo and thumbnail |
| photoFiles | Active plant/taxon metadata references have nonempty photo and thumbnail files; a legacy blank thumbnail uses the main file |
| photoRecovery | No inactive/unresolved recovery journal or temporary journal remains |

The Windows launcher waits for `/health/ready` before opening the app, including legacy migration startup. Linux operators must check it after service startup and restore, for example `curl --fail http://127.0.0.1:5000/health/ready` when port 5000 is the configured local endpoint. Use the actual listener address/port. A missing upload directory can be repaired without restarting the process; a configuration path change still requires restart. Ordinary Development `dotnet run` and its `.env` loading remain unchanged and do not apply migrations automatically.

These checks do not decode every historical photograph, certify all schema drift, prove backup consistency, or replace browser acceptance. File existence/nonzero length is the collection check; actual decoding uses the generated native probe. Readiness may change after the response. Native/process errors are logged without returning connection secrets in the response.

## Reviewing retained recovery records

1. Stop the app and every other writer. Preserve the database, matching upload root, recovery records, logs and a paired backup before changing anything. Do not blindly retry an uncertain save.
2. Run the read-only report against the verified database and actual absolute upload root. In a development checkout, use the existing `.env` credentials:

   ```powershell
   pwsh ./scripts/PhotoRecovery/review.ps1 -UploadsRoot <absolute-upload-directory> -UseRepositoryEnvironment
   ```

   On an installed/operational target omit `-UseRepositoryEnvironment` and supply its existing explicit `MARIADB_HOST`, `MARIADB_PORT`, `MARIADB_DATABASE`, `MARIADB_USER`, `MARIADB_PASSWORD` through protected operational configuration. Do not put passwords in command arguments or support logs. The development `.env` is not an installed configuration contract.
3. Review every row. The report never modifies SQL, files or journals:

   | Status | Required review |
   | --- | --- |
   | ReferencedPresent | Keep the file; confirm the committed record and its matching main/thumbnail pair |
   | ReferencedMissing | Preserve evidence and recover the matching files or paired SQL-and-upload backup; do not clear the journal to hide the missing file |
   | UnreferencedPresent | Confirm the correct database, stopped writers and known outcome before removing only the reported newly generated files; retain a backup first |
   | UnreferencedAbsent | No file removal is needed; still reconcile the whole record before clearing it |

   Counts include active and inactive photo metadata. A malformed/unreadable record requires support rather than forced cleanup. Reports recognize the generated paths used by this implementation; they are not a general-purpose legacy file repair tool.
4. Only after all rows are reconciled and the outcome is confirmed, remove the resolved journal and any associated journal temporary file. There is no automatic repair command. Preserve files that SQL references. Restart, require readiness 200, and reopen the affected photos and records before allowing new writes.

## Backups and deployment

Always pair SQL with the actual uploads, including `.photo-recovery`. Stop writers for a consistent recovery point. Windows Normal backup still does not stop every writer across its SQL dump and file copy; a verified ZIP alone does not certify a consistent concurrent snapshot. A journal copied during an active upload can require review after restore even if the live upload later succeeds. Linux C17 scheduled mode coordinates only its configured writer units. Retain the input archive and recovery records on restore; readiness must pass before collection acceptance.

See the [Windows/Linux upgrade checklist](upgrade-checklist.md), [Windows backup contract](windows-backup-format.md), [Linux backup runbook](user-guides/linux/OrchidApp-MariaDB-Backup-and-Restore-Runbook.md) and [C15/C19 validation evidence](maintenance/c15-c19-photo-handling.md). Installer backup safeguards remain C18; release-wide evidence work remains C20.
