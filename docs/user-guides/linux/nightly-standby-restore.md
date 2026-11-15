# Pi 2 nightly standby restore — Block 2

Installed on pihole2, Debian 13 ARM64, MariaDB 11.8.6, Python 3.13.5, rclone 1.73.0 and private .NET/ASP.NET 8.0.34. Owner-run manual and scheduled restores, actual success/failure email and live two-set retention passed on 14 November 2026. Writable manual takeover rehearsal also passed through the documented finish command: both change flags true, 758 media hashes, two app starts and accepted pointer unchanged. Cleanup/resumed timers passed. Pi-hole and system MariaDB stayed active; root had 25 GB free. The accepted app stays stopped between checks; no production cutover or collector migration is claimed.

See [installed evidence](../../maintenance/pi2-standby-preparation.md), [manual takeover/rehearsal](pi2-manual-takeover.md), [Pi 1 backup](nightly-multi-database-backup.md) and [historical implementation details](../../history/pi2-standby-implementation-notes-2026-11-14.md). Earlier pending labels in the historical record are superseded by current evidence.

## Automatic operation

- Pi 1 backs up orchids, EnergyMonitoring, uploads and selected recovery settings/source files at 02:00 Europe/London. It verifies its encrypted OneDrive upload and publishes the completion record last.
- Pi 2's enabled `orchidapp-standby.timer` checks hourly at :15 local time. Only a newer completed set is restored. A quiet poll does no SQL import or repeat success email; a late upload is picked up next hour.
- The enabled `orchidapp-standby-monitor.timer` checks every 15 minutes and retries queued email. Missing acceptance or source recovery age over 30 hours queues OVERDUE at most once per UTC day. Monitoring has a separate lock from restore.
- Application/importer/EnergyMonitoring writers and SQL events stay off on Pi 2. There is no automatic live takeover or switch-back.

## Verification and acceptance

`standby_job.py` locks the operation and performs discovery, bounded download, complete archive validation, preparation, isolated data restore, application checks, stopped acceptance, retention and reporting. Cloud commands only list/read; the copied provider token itself is not claimed to be read-only.

Records must match collection, timestamp, snapshot, hash, length, database list and freshness. An invalid newest set fails rather than silently selecting an older one. Full file inventory/hashes, safe member types/paths and all required photo references are checked. Source settings/units stay inert; accounts.sql is not imported. Failures and partial imports retain durable state and block blind reuse.

Only newly owned orchidstandby data directories and exact Unix sockets are used. The controller verifies actual datadir/socket/server identity, networking disabled and events OFF before SQL. Neither system MariaDB, TCP 3306 nor /var/lib/mysql is replaced. Both selected logical dumps are imported, using reviewed utf8mb4/general_ci server/default-map settings.

UTC/London target IANA timezones are checked in winter/summer. Exactly six EnergyMonitoring views map the absent source definer to locked standby_energy_views@localhost with SELECT on both selected schemas, preserving definitions/attributes and verifying columns/reads. Govee/Tapo/location views require Orchid tables. There is no general definer rewrite or source-account import.

The ARM64/.NET 8 publication must match the backup's DLL fingerprint. Captured appsettings, .env, web.config and uploads are filtered out. Fresh Production settings disable monitoring; a clean environment names only the private socket/uploads. A generated standby_probe account has CRUD/EXECUTE on orchids, not global grants. The app runs as the non-login candidate user without supplementary groups. Its owned sole loopback listener, readiness, home and every required photo/thumbnail HTTP hash are checked across two starts.

Before acceptance, the application's separate database/uploads clone must match the untouched import's business-table counts/extended checksums and the backup's publication/upload hashes. Checksums compare same-version 11.8 imports, not 10.11 against 11.8; they are change detection alongside file SHA-256, not cryptographic proof of SQL data ([MariaDB limits](https://mariadb.com/docs/server/reference/sql-statements/table-statements/checksum-table)). After both owned processes stop, a private acceptance record and single atomic last-accepted.json pointer commit the new recovery point. Earlier failure preserves the previous accepted point. A private generated app password is retained for manual activation.

## Files, credentials and retention

Helpers live in `/usr/local/lib/orchidapp-standby`, root-owned mode 644. `/etc/orchidapp-standby` is root mode 700, with root mode-600 standby.json, rclone.conf, email.json and smtp-password. Password setup is local/hidden; never paste secrets, execute captured .env files or commit private data. Write configuration atomically with mode 600.

State is `/var/lib/orchidapp-standby` root mode 700. `/var/lib/orchidapp-standby-db` and `/var/lib/orchidapp-standby-apps` are orchidstandby mode 700. Settings name publication `/var/backups/orchidapp-standby/publication.tar.gz`, runtime `/opt/orchidapp-standby/dotnet-8.0.34/dotnet`, view policy energy-six-v1 and max_generations 5. Limits include 1 GiB reserve, 5 GiB archive and 20 GiB unpack; stages check working space too. A changed backup DLL requires a newly verified matching publication before refresh can succeed.

Retention keeps current and previous accepted sets. Only earlier accepted sets with matching ownership records, exactly one successful rehearsal, owned stopped database paths and the exact app workspace can expire. Every path is checked before deletion and must not overlap a protected point. Failed/unknown/manual-retry evidence remains. Cleanup trouble preserves acceptance and queues RETENTION WARNING. Capacity exhaustion or interrupted cleanup needs review; never broadly delete candidates, sockets or locks to bypass checks. Retention never deletes OneDrive sets.

## Routine operation and reporting

```bash
systemctl list-timers --all --no-pager --full | grep orchidapp-standby
systemctl show orchidapp-standby.service orchidapp-standby-monitor.service \
  -p Id -p ActiveState -p Result -p ExecMainStatus
sudo cat /var/lib/orchidapp-standby/restore-run.json
df -h /
```

Successful oneshots are inactive between runs with Result=success and status 0. restore-run.json is the latest attempt, including NO_NEW_BACKUP. New versions also retain last-restore-success.json, untouched by later quiet polls. Per-generation acceptance and last-accepted.json remain the durable recovery evidence. Use journalctl -u orchidapp-standby.service for systemd history.

An extra refresh through the installed unit is `sudo systemctl start orchidapp-standby.service`.

GMX sender: orchidappdata@gmx.co.uk; recipient: bloodandsand44@gmail.com. SUCCESS is queued only after acceptance and once per snapshot. FAILED includes a short phase, not raw SQL/secrets. SMTP acceptance is not inbox receipt; actual Gmail receipt was confirmed. Failed delivery stays in the private outbox for up to 12 attempts. Retries never reimport SQL. Inspect exhausted mail/stale locks explicitly.

```bash
sudo python3 /usr/local/lib/orchidapp-standby/standby_reporting.py \
  monitor --config /etc/orchidapp-standby/email.json
sudo python3 /usr/local/lib/orchidapp-standby/standby_reporting.py \
  retry-email --config /etc/orchidapp-standby/email.json
```

Refresh exit 0 means accepted success/no-new, 1 means setup/restore failure, 2 means accepted state is preserved but mail/bookkeeping needs attention. Monitor returns 1 for overdue/error and 2 for pending delivery. A failure after pointer commit is not falsely described as an unaccepted restore. Private reporting logs rotate daily/maxsize 1 MiB with 14 rotations; service output uses the journal.

## Failure, interruption and takeover

Preserve failed input, phase markers and private diagnostics; do not force reimport into a partial generation. Owned process cleanup handles interruption. Refresh has a two-hour timeout and control-group cleanup; monitoring runs independently. Coordinator test-failure was tested: exit 1, actual FAILED email and byte-identical accepted pointer. Native CI separately exercises actual partial-import failure and prior-state preservation.

Follow the [manual takeover runbook](pi2-manual-takeover.md) for a separate writable rehearsal, fencing Pi 1, private activation and protecting new Pi 2 data. The durable active-takeover.json marker blocks refresh even after a restart. Live failback needs preservation/reconciliation of Pi 2 writes; it is not an old OneDrive restore. No collector/public-route migration or automatic failover is implied by successful nightly recovery.
