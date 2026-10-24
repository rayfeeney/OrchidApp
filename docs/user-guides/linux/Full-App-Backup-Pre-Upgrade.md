# Full Raspberry Pi backup before upgrading

This procedure backs up `/opt/orchidapp` (including uploads/photos), the `orchids`
database, `/etc/orchidapp` configuration and the effective systemd definitions.
It assumes these are your deployment paths. Check any other upload paths,
symlinks or external mounts separately: `rsync -a` preserves symlinks rather than
copying their external targets.

For routine encrypted cloud backups and database recovery, use the
[backup and restore runbook](OrchidApp-MariaDB-Backup-and-Restore-Runbook.md).
This full application backup complements that process.

Run Pi commands in the same Bash terminal so `backup_dir` remains available.
Stop at any failed command. Never proceed to an upgrade with an incomplete backup.

## Execution prerequisites

Use Bash with pipefail enabled so a failed source command in a pipeline is visible:

```bash
set -o pipefail
```

Verify rsync (including metadata preservation support), MariaDB dump/client tools, tar/gzip, sudo access, sufficient storage and an off-device SCP route. Check every exit result and stop on failure; do not treat the final successful command in a multi-command block as proof earlier steps worked. Preserve the trusted source/archive until full acceptance. These commands are not run by the documentation update.

The importer below belongs only to the owner's bespoke local installation. General OrchidApp installations omit it. For whole-bundle restoration and acceptance, follow the [runbook recovery section](OrchidApp-MariaDB-Backup-and-Restore-Runbook.md#recovery-onto-a-replacement-linux-system), never a fresh schema rebuild over restored data.

## 1. Check paths and available space

```bash
systemctl list-unit-files | grep -i orchid
systemctl show orchidapp.service -p WorkingDirectory
df -h /opt
sudo du -sh /opt/orchidapp /opt/orchidapp/uploads
sudo ls -ld /opt/orchidapp/uploads
sudo readlink -f /opt/orchidapp/uploads
```

Allow room for both an uncompressed copy and its archive, plus the database dump
and build output. Record which services and timers were active before stopping
them. Include additional deployment-specific units if present.

## 2. Stop application writes

Only for the owner’s local deployment with its bespoke environment importer:

```bash
sudo systemctl stop orchidapp-environment-importer.timer
sudo systemctl stop orchidapp-environment-importer.service
sudo systemctl stop orchidapp.service
systemctl is-active orchidapp.service orchidapp-environment-importer.timer orchidapp-environment-importer.service
```

Expect three `inactive` results; `is-active` returns a nonzero status for inactive
units. Omit importer commands if it is not installed. Leave MariaDB running for
the logical database export. Stop any other writers to this database or uploads.

## 3. Copy application, photos and configuration

```bash
backup_dir="/opt/orchidapp-rollbacks/$(date +%Y-%m-%d-%H%M%S)-pre-upgrade"
sudo install -d -m 700 "$backup_dir"
sudo mkdir -p "$backup_dir/orchidapp" "$backup_dir/systemd"
echo "Backup folder: $backup_dir"

sudo rsync -aHAX --numeric-ids /opt/orchidapp/ "$backup_dir/orchidapp/"
sudo cp -a /etc/orchidapp "$backup_dir/etc-orchidapp"

for unit in orchidapp.service orchidapp-environment-importer.service orchidapp-environment-importer.timer; do
  systemctl cat "$unit" | sudo tee "$backup_dir/systemd/$unit.txt" >/dev/null
done
```

Omit absent importer units. The text files record effective unit definitions,
including drop-ins, for reference. Also preserve original locally maintained unit
files and overrides for recovery:

```bash
sudo find /etc/systemd/system -maxdepth 1 -name 'orchidapp*' \
  -exec cp -a -t "$backup_dir/systemd/" -- {} +
```

The configuration includes passwords; do not share its contents. Record the Git
revision so the source version can be identified:

```bash
git -C /opt/orchidapp rev-parse HEAD | sudo tee "$backup_dir/source-revision.txt" >/dev/null
```

## 4. Export the database

Use the MariaDB root password when prompted, not the Pi login password:

```bash
sudo bash -c 'umask 077; mariadb-dump --user=root --password --single-transaction --routines --triggers --events --hex-blob --databases orchids > "$1"' _ "$backup_dir/orchids.sql"
echo "Database export exit code: $?"
```

Require exit code `0`. A failed export may leave an empty or partial file; it is
not a usable backup. This exports the database, views, routines, triggers and
events. It does not export MariaDB user accounts/grants or server configuration;
retain those separately if rebuilding the entire machine. Single-transaction
consistency applies to transactional tables; keep other writers and schema changes
paused throughout this backup.

## 5. Verify the copy and export

```bash
sudo ls -lh "$backup_dir/orchids.sql"
sudo tail -n 5 "$backup_dir/orchids.sql"
sudo rsync -aHAXnc --numeric-ids --itemize-changes /opt/orchidapp/ "$backup_dir/orchidapp/"
echo "Backup comparison exit code: $?"
sudo du -sh /opt/orchidapp "$backup_dir/orchidapp"
```

Expect a nonempty SQL file ending with `Dump completed`, no rsync changes and
comparison exit code `0`. These are integrity checks, not a restore test. Validate
restoration in an isolated database/server using the runbook before relying on
the backup for recovery. The dump includes `CREATE DATABASE`/`USE orchids`; do not
import it into a live server as a test or assume a different command-line database
name redirects those statements.

## 6. Archive and verify

```bash
sudo bash -c 'umask 077; tar -czpf "$1.tar.gz" -C "$(dirname "$1")" "$(basename "$1")"' _ "$backup_dir"
echo "Archive creation exit code: $?"
sudo tar -tzf "${backup_dir}.tar.gz" >/dev/null
echo "Archive verification exit code: $?"
sudo sha256sum "${backup_dir}.tar.gz"
sudo ls -lh "${backup_dir}.tar.gz"
```

Require both archive exit codes to be `0`. Make the archive readable only by your
Pi login account so it can be copied with SCP:

```bash
sudo chown "$(id -un):$(id -gn)" "${backup_dir}.tar.gz"
sudo chmod 600 "${backup_dir}.tar.gz"
echo "${backup_dir}.tar.gz"
```

## 7. Copy off the Pi

In Windows PowerShell, replace the account, hostname and timestamp below with
your values from the preceding output:

```powershell
scp <pi-user>@<pi-host>:/opt/orchidapp-rollbacks/<timestamp>-pre-upgrade.tar.gz "$HOME\Downloads\"
Get-FileHash "$HOME\Downloads\<timestamp>-pre-upgrade.tar.gz" -Algorithm SHA256
```

The Windows hash must match the Pi hash (letter case does not matter). Keep the
archive private because it contains credentials and application data. A copy on
the same SD card alone does not protect against SD-card failure.

## 8. Continue or resume service

For an immediate upgrade, leave the app and importer stopped and continue with
the [upgrade procedure](installation-upgrade.md#upgrade-an-existing-correctly-baselined-database).
If postponing the upgrade, restart the units that were active before the backup:

```bash
sudo systemctl start orchidapp.service
sudo systemctl start orchidapp-environment-importer.timer
systemctl list-timers --all orchidapp-environment-importer.timer --no-pager
```

Only restart the importer timer if it was previously enabled/running. Do not
manually start the importer service just to resume its schedule.
