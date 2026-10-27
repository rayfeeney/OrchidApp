# Linux paired backup and recovery

Routine backups now keep SQL, complete uploads and external configuration in one snapshot. An older snapshot carries its own older photos; it does not depend on the current uploads mirror. Keep `backup_orchids.sh`, `restore_orchids.sh` and their shared `orchid_backup.py` together under `infrastructure/backups/`. Required tools are Python 3.9+, Bash, MariaDB 10.11 client/dump, systemd and rclone. All must be on the scheduling account's PATH.

This is data recovery, not a whole-machine image. Retain compatible app binaries/source, OS/service definitions, MariaDB grants and encryption keys separately. Use the [full pre-upgrade guide](Full-App-Backup-Pre-Upgrade.md) for application/service rollback. See [C17 evidence](../../maintenance/c17-linux-paired-backup.md) for local checks and pending Linux/Pi acceptance.

## Configure one account and collection

Choose the operator account, often root when service control and protected settings require it. Test as that account. Copy `infrastructure/backups/backup.example.json` to an absolute private path such as `/etc/orchidapp/backup.json`, owned by root/operator and mode 600. The example must be edited before use.

- Generate a stable UUID once with `python3 -c 'import uuid; print(uuid.uuid4())'` and set `collection_id`. Keep it with the collection/recovery records; different collections require different identities.
- Set explicit database, `client_defaults_file`, `uploads_root`, `configuration_root`, `backup_root` and `log_file`. Source trees must be separate from backup/log storage and each other. Source directories must exist. Symlinks and special files are rejected; consolidate external targets deliberately.
- `configuration_root` holds the external settings/secrets to capture as bytes. Include other required files separately if outside that tree. The restore script stages these settings without activating them.
- Set an explicit private `rclone_config` and existing dedicated remote directory such as `orchidcrypt:paired`. Configure/test the provider and crypt remote first. Name/access checks do not prove encryption was configured correctly. Preserve the crypt keys and provider credentials off-device.
- List every writer service and timer in `writer_units`, including importers only where actually installed. Pause other accounts' jobs and ad hoc writers too. Do not list MariaDB itself: it must remain running. Unknown, unloaded, running, failed or transitioning units block manual capture.
- `keep_local` defaults to 14 and must be at least 1. `timeout_seconds` defaults to 600 per tool/read-lock acquisition. `max_unpack_bytes` defaults to 20 GiB; raise it deliberately for larger collections. Archives allow at most one million entries and 16 MiB of manifest metadata.

The backup root must be owned by root/operator and mode 700. Config JSON, MariaDB defaults, rclone config and logs must be mode 600 or stricter. Missing backup/log directories are created before logging, with private permissions; broad existing permissions fail validation. Protect parent directories from untrusted writers. Allow space for copied payload, archive, extraction and downloaded verification copy. Retention extracts one candidate at a time.

Use options understood by both MariaDB client and dump in the shared defaults file:

```ini
[client]
protocol=tcp
host=127.0.0.1
port=3306
user=YOUR_BACKUP_ACCOUNT
password="YOUR_PRIVATELY_CONFIGURED_PASSWORD"
```

These are placeholders; use MariaDB option-file escaping for real values. Do not put client-only options in shared `[client]`. The backup account needs tested access to tables/views/routines/triggers/events and permission to acquire a global read lock. Runtime app grants are insufficient. Validate the actual grants on an isolated server. Passwords come from the protected file, never command arguments or routine logs.

## Capture and scheduling

For an installation where you already stopped all writers:

```bash
sudo bash /opt/orchidapp/infrastructure/backups/backup_orchids.sh \
  --config /etc/orchidapp/backup.json --writers-stopped
```

The flag confirms all writers, including unsupervised jobs, are stopped. Configured units must be loaded, inactive and dead before and after capture. Alternatively, `--stop-writers` stops configured units and restores only those previously active. Timers stop before services; services restart before timers. Previously inactive units remain inactive. A restart failure returns nonzero even when an archive already exists; inspect unit state. The script does not start an optional importer that was absent/inactive.

One persistent MariaDB connection holds `FLUSH TABLES WITH READ LOCK` throughout file copying/hashing, active plant/taxon photo/thumbnail checks and SQL export including routines, triggers and events. It blocks database writes/DDL across the selected server, so plan the outage. Upload/config inventories are compared before copying, against the copies, and again after export. Missing/changed files/references or a lost lock prevent a completed snapshot. Closing the connection releases its own lock even on failure.

This remains a stopped-writer operating contract: direct filesystem writers outside the configured units must be paused. Before/after hashes cannot prove no transient write was made and reverted. Do not run it as an online backup while uploads continue. A killed process or host shutdown can leave units stopped and a stale `.paired-operation.lock`; inspect the owner, processes and temporary directories before manually clearing it. Stale locks are never removed automatically.

After manual capture and isolated recovery pass, a root crontab could use:

```cron
0 2 * * * /bin/bash /opt/orchidapp/infrastructure/backups/backup_orchids.sh --config /etc/orchidapp/backup.json --stop-writers
```

This does not install a schedule. Set/test the cron PATH, service-control rights and failure notification, rotate the configured log and test with a minimal environment as the scheduling account. Absolute credentials/rclone config keep interactive and scheduled runs consistent. Check the latest run's exit and remote read-back/restart messages; an old successful log line proves nothing about today's job. Real cron/systemd/Pi acceptance remains required.

## Snapshot format, remote verification and retention

`orchidpair-<UTC timestamp>-<UUID>.tar.gz` contains `manifest.json`, `database.sql`, `uploads/` and `configuration/`. Hidden files and empty directories are included. SHA-256/size inventories and active photo references are checked after archive creation. Older unsupported photo schemas fail rather than skipping reference checks. OS ownership/modes/ACLs are not restored.

The exact archive is uploaded with `rclone copyto --immutable`, downloaded again and compared byte-for-byte by SHA-256 before success or pruning. Upload/read-back failure returns nonzero and retains the verified local archive. The tool never syncs/deletes the current uploads mirror. Hashes detect corruption, not authenticity: accept only trusted snapshots from protected storage.

Local retention runs only after verified remote read-back. It keeps the current and newest verified same-collection snapshots up to `keep_local`; candidates must be direct files matching the new generated pattern. Each is privately extracted and verified, then rehashed immediately before deletion. Unknown, corrupt, foreign-collection, nested and legacy files remain. A sibling `<archive>.keep` pins a snapshot outside the count. Restore automatically pins a direct input inside its configured backup root before SQL changes. Remove pins only after recovery acceptance and another trusted copy exist. The count is not a disk-space cap.

There is no automatic remote deletion. Review provider capacity and manually retain/remove complete paired objects according to the recovery policy, preserving recovery inputs and verified off-device copies. The previous 14-day remote SQL deletion is removed. Legacy SQL objects and the old uploads mirror are untouched and are not retroactively historical pairs.

## Restore one exact trusted snapshot

Provision an isolated MariaDB server unreachable by the live application, disable its event scheduler, and create an empty database with the same name as the snapshot. SQL may contain qualified routines/definers; passing another client database name does not redirect arbitrary SQL. Never test on the live server, and never run fresh schema creation over recovered data.

Create a separate protected target JSON: source collection UUID/database name, isolated target client defaults, target's stopped writer units, a private backup/scratch root and log. Restore uses those common fields; source upload/configuration/remotes are not used. Fetch one exact object with the explicit protected rclone config and preserve it:

```bash
rclone --config /etc/orchidapp/rclone.conf copyto \
  'orchidcrypt:paired/EXACT_SELECTED_SNAPSHOT.tar.gz' \
  '/private/recovery/EXACT_SELECTED_SNAPSHOT.tar.gz'

bash /opt/orchidapp/infrastructure/backups/restore_orchids.sh \
  --config /private/recovery/target.json \
  --archive /private/recovery/EXACT_SELECTED_SNAPSHOT.tar.gz \
  --destination /private/recovery/recovered-data \
  --confirm-isolated --confirm-database orchids
```

Replace placeholders/database name explicitly; never use wildcards. Destination must be absent, with an existing parent, separate from archive/backup storage. Existing uploads/settings are never overwritten. Target database must already exist and have no tables/views/routines/events. Isolation confirmation is the operator's assertion, not automatic proof of network isolation.

Before import, restore rejects traversal, duplicate/link/special entries, oversized metadata/payloads, unsupported formats, hash/inventory mismatches, missing active photos, wrong collection or database name, and an input that changes during validation. It creates private plain files/directories and ignores archived owners/modes.

`RESTORE-PENDING.json` is written in the new destination before SQL import. Failure preserves input and marker and returns nonzero with a warning that SQL may be partially applied. DDL is not automatically rolled back. Inspect the disposable target/input before any retry; do not clear a marker and retry into partial tables. Private tool stderr is retained in mode-600 `.tool-error-*.log` files under the scratch/backup root; it can contain secrets/SQL and must be reviewed privately before sharing.

Successful file/import/reference checks rename the marker to `RESTORED-VERIFY-APPLICATION.json`. This means data was staged, not that the application is ready. Settings remain in `destination/configuration`: privately adjust endpoint/upload/account paths and deploy only the needed settings. Do not activate captured source credentials against the live installation. Recreate database grants/service definitions and appropriate ownership/modes separately. Backup credentials, OS ACLs/xattrs and MariaDB server accounts are not automatically installed.

## Application and replacement acceptance

Point a compatible isolated publication at the recovered database and `destination/uploads`. Check required seeds, representative rows and procedures, plant/taxon photos/thumbnails, settings, restart and a new disposable save/upload/reopen. Re-establish runtime permissions; files initially belong to the backup operator. Keep monitoring off on general installations; bespoke feeds belong only to the owner's installation.

Keep input/pin/evidence until another verified recovery route exists. An old paired archive carries its own files; old standalone `.sql.gz` files require separate proof of matching uploads and remain a manual recovery format. Use the [installation guide](installation-upgrade.md) for replacement tools/accounts/compatible binaries and service registration without schema creation over restored data. Apply later migrations only as a separate controlled upgrade after recovery acceptance.

Test recovery quarterly and after changing scripts, credentials, providers or runtime. Process success, hashes and row counts alone do not certify whole-machine recovery.

## C15/C19 photo recovery acceptance

Include the actual uploads and their private `.photo-recovery` records with SQL in a paired recovery point. Stop all writers for a consistent snapshot; a SQL dump or verified archive is not end-to-end application acceptance. Windows Normal backup does not quiesce every writer, and Linux scheduled coordination covers only configured units. Preserve any copied journals on restore even if they came from an upload that later succeeded on the original machine.

After restore/start, require `/health/ready` to return 200 and reopen representative plant/taxon photos and thumbnails. Unresolved journals or missing active files return 503. Keep the input archive, matching files, SQL and logs; stop writers and follow [photo handling and read-only recovery review](../../photo-handling.md) before clearing any record. Never delete a journal just to force startup. C19 does not make concurrent SQL/file backups atomic or certify an installed recovery.
