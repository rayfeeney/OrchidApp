# MariaDB and uploads backup and recovery

This runbook covers Linux OrchidApp data backup and isolated recovery. Operators own scheduling, monitoring, credentials and restore verification. Application binaries are replaceable; the database, complete uploads, external configuration and required service/account settings must remain recoverable. Use the [full backup guide](Full-App-Backup-Pre-Upgrade.md) before upgrades.

## Current routine backup and its limits

infrastructure/backups/backup_orchids.sh dumps orchids through MariaDB's mysqldump alias with routines/triggers and a single-transaction snapshot, compresses it, copies it to orchidcrypt:, applies remote SQL retention of 14 days, syncs uploads to orchiduploadscrypt: and removes the successful local archive. It uses Bash pipefail/error handling. It does not implement continuous point-in-time log replay or versioned historical photo snapshots.

The SQL snapshot and current uploads mirror are not an atomic common snapshot while writes continue. An older SQL dump may refer to files absent from the current mirror. Do not describe any retained DB snapshot as guaranteed full historical collection recovery. [C17](../../code-change-backlog.md#c17) requires portable configuration and a paired DB/filesystem strategy. For an upgrade, use the full stopped-writer backup rather than rely solely on the mirror.

## Configure and test before scheduling

1. Choose the backup operator account and one installed script location. For consistency with the installation guide, the working example is /opt/orchidapp/infrastructure/backups/backup_orchids.sh; if installing a separate /usr/local/bin copy, record/update that copy and schedule explicitly.
2. Inspect the script's current fixed /home/raymond-23 paths and replace/configure the intended backup/log directories through a separately reviewed code change (C17). Ensure those directories are writable before its first log call. The shipped personal defaults are not portable setup.
3. Verify Bash, the MariaDB client/dump aliases, gzip and rclone. Configure DB credentials for the scheduling account using its protected client configuration or approved local secret mechanism; use mode 600 and the privileges required for the actual dump, not an assumed root account/password. Do not place secrets in command arguments/output.
4. Configure and test the encrypted rclone remotes orchidcrypt: for SQL and orchiduploadscrypt: for uploads using the selected provider. Preserve the protected rclone config/encryption keys off-device. Remote names alone do not create/configure encryption or prove upload completion.
5. Confirm the actual database endpoint/name and complete upload root. Test a backup, review exit/logs and verify the exact remote object. Test recovery in an isolated server before depending on it. Cron must run as the account whose credentials/config were tested.

**Do not schedule the unconfigured personal-path script.** Once those prerequisites and the reviewed script change are complete, a user crontab can invoke that exact installed script daily. Record its path/account and log destination, and monitor failures. No scheduled run exists merely because this guide contains an example. Configure rotation for the actual logs and permissions; do not blindly copy another user's home path.

## Select one exact recovery object

Use an isolated MariaDB instance/server for testing, not production. A dump can contain CREATE DATABASE/USE statements, routines and definers: a client database argument does not override SQL inside the dump. The routine script currently creates a single-database dump without --databases; the full pre-upgrade dump includes database-selection statements. Always inspect/trust the source and isolate the server regardless of format.

Choose one trusted filename from the remote. The routine script uses orchids_<date>_<time>.sql.gz, not backup.sql.gz. Substitute the exact object below; do not feed a wildcard of multiple backups into an import:

```bash
set -o pipefail
restore_dir="$(mktemp -d)"
chmod 700 "$restore_dir"
backup_name='orchids_YYYY-MM-DD_HH-MM-SS.sql.gz'
rclone copyto "orchidcrypt:${backup_name}" "$restore_dir/$backup_name"
gzip -t "$restore_dir/$backup_name"
gzip -dc "$restore_dir/$backup_name" > "$restore_dir/selected.sql"
```

Stop on every failed command; the filename above is a placeholder to replace, not a request to fetch all objects. Preserve the original archive. Verify its integrity/provenance and determine which upload snapshot matches it. A current mirror is not automatically the right match for an old DB snapshot.

## Isolated restore and acceptance

Provision a disposable MariaDB target and protected client credentials that cannot reach the live instance. Create an empty recovery database with utf8mb4/utf8mb4_unicode_ci if the chosen dump does not create its own. Import exactly selected.sql using the isolated endpoint and intended database; if its SQL selects orchids, isolate the whole instance rather than assuming orchids_restore_test overrides it.

Recover the matching complete uploads into a separate test directory, never sync over production as a test. Restore necessary account grants/configuration separately; database dumps do not generally include server accounts or OS services. Point an isolated compatible OrchidApp build at that data and check:

- Schema, required reference values, representative row counts and no import errors.
- Plants, tags, taxonomy, events/lineage, actual plant/taxon photos and writable paths.
- Correct settings, a successful restart and a new disposable save/reopen/photo operation.
- No unexpected monitoring dependency on a general install; bespoke feeds only on the owner's configured installation with explicit Monitoring:Enabled opt-in.

SHOW TABLES, a nonempty dump, matching hash or process success is not a full restore test. Preserve evidence and the trusted input until acceptance is recorded. Dispose of isolated fixtures through your approved local process only after verification; no production cleanup command is part of this guide.

## Recovery onto a replacement Linux system

Use the [installation guide](installation-upgrade.md) only for tools, account/configuration, compatible app publication and service registration. **Do not run its fresh schema creation over restored data.** Restore one selected DB/upload pair and external configuration into the replacement environment, re-establish required grants/service permissions, then start the compatible app and run the acceptance checks above. A subsequent upgrade is a separate controlled operation after recoverability is proven.

For a full pre-upgrade bundle, restore the app/config/service definitions appropriate to the captured revision in an isolated replacement environment, checking actual paths, ownership, service account and MariaDB grants. The bundle records effective units as text plus original local definitions; text output is reference material, not a drop-in service installer. Validate which metadata/symlink targets must be restored. Whole-machine recovery remains operational acceptance work, not an automated guarantee.

Protect backups and keys, verify off-device availability, review logs and test recovery at least quarterly and after backup/restore changes. Investigate missing files or partial recovery before using the recovered collection or replacing the only trusted backup. See [C17/C19](../../code-change-backlog.md) for pending consistency/readiness work.
