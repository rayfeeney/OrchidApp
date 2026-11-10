# Raspberry Pi and Linux installation and upgrades

> For previous deployment evidence, see the [Pi 1 v1.4.0 record](../../maintenance/pi1-v1.4.0-upgrade-runbook.md).

This guide covers a general OrchidApp server using MariaDB and systemd. It does not install the owner's bespoke monitoring feeds/importer or EnergyMonitoring. Monitoring defaults off; leave Monitoring:Enabled absent or false. See the [activation boundary](../../environment-summary-platform.md).

Fresh creation uses canonical schema, required seeds and the generated baseline manifest, with no historical migration replay. The non-overwriting creation script is implemented; Linux/MariaDB and native-photo CI passed. Real installed Pi acceptance remains pending under the [current work list](../../current-state.md). Validate on a disposable target before deployment; see the [creation contract](../../database-creation.md) and [local evidence](../../maintenance/c01-c02-schema-baseline.md).

## Prerequisites and target

Use a maintainer-validated Raspberry Pi OS/Linux release and architecture, .NET 8 SDK for source publishing, MariaDB 10.11 server/client tools, PowerShell 7+, Git, native libvips image dependencies and systemd. Routine paired backups also need Python 3.9+, Bash and rclone. Pre-upgrade archives need Bash, rsync, tar/gzip and protected off-device storage. Package names/repositories differ by OS image; no universal apt list has been validated by this documentation cleanup. Track repeatable platform setup in [C16](../../history/code-change-backlog.md#c16).

Choose an application service account, app root (examples /opt/orchidapp), external configuration directory (/etc/orchidapp), MariaDB endpoint/account and uploads path. Use the same values throughout. Install/configure MariaDB with utf8mb4 and utf8mb4_unicode_ci; verify actual server/database settings with your administrative tools. Distribution paths such as /etc/mysql and option group mysqld are normal MariaDB compatibility names.

## Fresh environment

1. Install and verify the tools above on the chosen image; enable MariaDB and verify the intended endpoint.
2. Obtain the trusted repository in a source checkout separate from the deployed app. Use the agreed remote/release revision; do not publish an unknown checkout.
3. Select an absent/empty target and supply the seven explicit MARIADB_* values in the [schema-only creation contract](../../database-creation.md). Run pwsh ./database/scripts/rebuild.ps1 -ConfirmDatabase $env:MARIADB_DATABASE from the checkout root. The script resolves mariadb on PATH, refuses nonempty targets and records completion only after all seeds. Run the supplied isolated checks on your Linux image before treating platform acceptance as complete.
4. Configure the app's runtime account/connection and isolated durable uploads before starting. Runtime privileges and migration/admin privileges differ; do not run the web process as MariaDB root.
5. Build/publish and register the service below. Verify live application workflows and a real test-photo upload/reopen, then configure backups and validate an isolated recovery.

Creation bookkeeping must not read historical migration SQL. After creation, future compatible migrations are permitted; the prohibition is against replaying prior history into the assembled schema, not against upgrading that database later.

## External configuration and service

Create /etc/orchidapp with restricted ownership/access and a protected orchidapp.env using the operator's secure editor. Supply a correctly quoted complete ConnectionStrings__OrchidDb and Storage__UploadRoot. Keep passwords out of committed JSON, command arguments and copied support logs. A typical systemd value uses the form ConnectionStrings__OrchidDb="Server=127.0.0.1;Port=3306;Database=orchids;User=orchidapp;Password=..."; the ellipsis is a placeholder, not a password. Validate special-character quoting using the actual configuration mechanism. Use Storage__UploadRoot=/opt/orchidapp/uploads when that is the selected root.

The env file can be root-owned mode 600 because systemd reads it for a system service. The service account needs execute/traverse access to the published tree and writable upload storage, not permission to modify the secret file. The upload root must exist for readiness; protect it and include it in recovery. If a missing configured directory is repaired, uploads become available without restart; changing its configured path still requires restart.

After schema/native prerequisites pass, publish from the checkout root:

```bash
dotnet restore src/OrchidApp.Web/OrchidApp.Web.csproj --locked-mode
dotnet publish src/OrchidApp.Web/OrchidApp.Web.csproj -c Release --no-restore --self-contained false -p:UseAppHost=false -o /opt/orchidapp/publish
```

Require a successful exit. Create /etc/systemd/system/orchidapp.service, replacing the service-account placeholder and paths with the selected values:

```ini
[Unit]
Description=OrchidApp Web Application
After=network.target mariadb.service

[Service]
ExecStart=/usr/bin/dotnet /opt/orchidapp/publish/OrchidApp.Web.dll --urls http://0.0.0.0:5000
WorkingDirectory=/opt/orchidapp/publish
User=<service-account>
Environment=ASPNETCORE_ENVIRONMENT=Production
EnvironmentFile=/etc/orchidapp/orchidapp.env
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Confirm the installed dotnet path; /usr/bin/dotnet is an example, not a verified path for every image. Restrict network access to the intended trusted users; OrchidApp has no built-in multi-user authentication. Enable/start only after configuration is checked:

```bash
sudo systemctl daemon-reload
sudo systemctl enable orchidapp.service
sudo systemctl start orchidapp.service
systemctl is-active orchidapp.service
sudo journalctl -u orchidapp.service --since '2 minutes ago' --no-pager -n 60
```

Open the operator-provided URL (for the example listener, http://<pi-host>:5000). Service-active/listening status is not database/native readiness. Check lists, disposable test data, save/reopen, search, styling and photos. General installs leave monitoring disabled and require none of the owner monitoring objects.

## Upgrade an existing correctly baselined database

Follow these six steps in order. Stop at a failed command or failed check. The
Pi 2 example uses Debian 13 ARM64, .NET SDK 8.0.426, source in `~/OrchidApp`,
MariaDB database `orchids`, publish directory `/opt/orchidapp/publish` and
settings in `/etc/orchidapp/orchidapp.env`. Confirm the actual paths, units
and versions before downtime. Keep uploads and secrets outside publish.

### 1. Stop processes

Check the trusted Git origin, release tag and full approved commit, available
space, `uname -m`, `dotnet --version`, and `git status --short` before
stopping services. Review changes to `src/OrchidApp.Web/packages.lock.json`.
If a previous RID-specific restore generated the change, save the diff
outside the checkout, then restore that file from HEAD. Resolve other local
changes before continuing.

Record active services and timers. Pause scheduled backup jobs and stop
timers that can start writers, then stop the writers and the web app. The
bespoke importer units apply only where installed. Leave MariaDB running.

```bash
sudo systemctl stop orchidapp.service
systemctl show orchidapp.service -p ActiveState
```

Verify every stopped writer reports `ActiveState=inactive`. Keep them stopped
until the upgraded app passes validation.

### 2. Back up and verify recovery

Create a complete local recovery archive before applying database migrations or replacing application files. This backup is for **rolling back the current Linux installation to its pre-upgrade state**, not for the separate nightly OneDrive disaster-recovery process.

The following commands use the documented default installation paths. They are intended for Raspberry Pis and other supported Linux hosts following that layout.

Before executing, confirm:

- OrchidApp and all other database/upload writers are stopped, as described in Step 1.
- The actual uploads directory agrees with `Storage__UploadRoot` in the deployed configuration.
- The source checkout is `~/OrchidApp`, or change the initial `cd` accordingly.
- Local MariaDB administration works using `sudo mariadb --user=root`.
- There is sufficient free disk space for the file copies, database export and compressed archive.

**Run the following complete block in Bash:**

```bash
(
set -euo pipefail
cd ~/OrchidApp

revision=$(git rev-parse --verify HEAD)

sudo bash -s -- "$revision" <<'BACKUP'
set -euo pipefail
umask 077

revision=$1
publish_root=/opt/orchidapp/publish
upload_root=/opt/orchidapp/uploads
backup_root=/opt/orchidapp-rollbacks

echo "=== Validate backup sources ==="

test -f "$publish_root/OrchidApp.Web.dll"
test -d "$upload_root"
test -d /etc/orchidapp
test -f /etc/orchidapp/orchidapp.env

upload_root=$(realpath -e -- "$upload_root")
publish_root=$(realpath -e -- "$publish_root")

# Check against the deployed uploads configuration.
if grep -q '^Storage__UploadRoot=' /etc/orchidapp/orchidapp.env; then
    configured_root=$(sed -n 's/^Storage__UploadRoot=//p' \
        /etc/orchidapp/orchidapp.env | tail -n 1)
    configured_root=${configured_root#\"}
    configured_root=${configured_root%\"}
else
    configured_root=$(sed -nE \
        's/.*"UploadRoot"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' \
        "$publish_root/appsettings.json" | head -n 1)
fi

test -n "$configured_root"
test "$(realpath -e -- "$configured_root")" = "$upload_root"

# Reject filesystem roots and broad system directories.
case "$upload_root" in
    /|/bin|/boot|/dev|/etc|/home|/lib|/lib64|/mnt|/opt|/proc|/root|/run|/sbin|/srv|/sys|/tmp|/usr|/var)
        echo "ERROR: Unsafe uploads directory: $upload_root"
        exit 1
        ;;
esac

mkdir -p "$backup_root"
backup_root=$(realpath -e -- "$backup_root")

# Prevent copying a source into itself or its backup.
case "$backup_root/" in
    "$upload_root/"*|"$publish_root/"*)
        echo "ERROR: Backup destination overlaps a source"
        exit 1 ;;
esac

case "$upload_root/" in
    "$backup_root/"*|"$publish_root/"*)
        echo "ERROR: Upload directory overlaps backup or publish"
        exit 1 ;;
esac

case "$publish_root/" in
    "$upload_root/"*|"$backup_root/"*)
        echo "ERROR: Publish directory overlaps another source"
        exit 1 ;;
esac

test "$(systemctl show orchidapp.service -p ActiveState --value)" = inactive
mariadb --user=root -e "SELECT 1" >/dev/null

# Conservative free-space allowance for copies and archive.
needed=$(du -sk "$publish_root" "$upload_root" /etc/orchidapp |
    awk '{total += $1} END {print total}')
available=$(df -Pk "$backup_root" | awk 'NR==2 {print $4}')

if (( available <= 3 * needed + 2097152 )); then
    echo "ERROR: Insufficient estimated backup space"
    exit 1
fi

backup="$backup_root/$(date -u +%Y%m%dT%H%M%SZ)"

echo "=== Create backup: $backup ==="

install -d -m 700 "$backup"
mkdir "$backup/publish" "$backup/uploads" \
      "$backup/systemd" "$backup/mariadb-config"

rsync -aHAX --numeric-ids \
    "$publish_root/" "$backup/publish/"

rsync -aHAX --numeric-ids \
    "$upload_root/" "$backup/uploads/"

cp -a /etc/orchidapp "$backup/configuration"

# Capture OrchidApp units and their drop-in directories.
find /etc/systemd/system -maxdepth 2 -name 'orchidapp*' \
    -exec cp -a --parents -t "$backup/systemd/" -- {} +

systemctl cat orchidapp.service > "$backup/systemd-effective.txt"

# Retain relevant MariaDB server configuration.
for path in /etc/mysql /etc/my.cnf /etc/my.cnf.d; do
    if test -e "$path"; then
        cp -a --parents "$path" "$backup/mariadb-config/"
    fi
done

printf '%s\n' "$revision" > "$backup/source-revision.txt"
printf '%s\n' "$upload_root" > "$backup/upload-root.txt"

echo "=== Export MariaDB ==="

mariadb-dump --user=root \
    --single-transaction \
    --routines --triggers --events --hex-blob \
    --databases orchids > "$backup/orchids.sql"

# Retain user/grant definitions for recovery reference.
mariadb-dump --user=root --system=users mysql \
    > "$backup/mariadb-grants.sql"

test -s "$backup/orchids.sql"
test -s "$backup/mariadb-grants.sql"
tail -n 5 "$backup/orchids.sql" | grep -q "Dump completed"

echo "=== Verify file copies ==="

rsync -aHAXnc --delete --numeric-ids --itemize-changes \
    "$publish_root/" "$backup/publish/" \
    > "$backup/publish-check.txt"

rsync -aHAXnc --delete --numeric-ids --itemize-changes \
    "$upload_root/" "$backup/uploads/" \
    > "$backup/uploads-check.txt"

test ! -s "$backup/publish-check.txt"
test ! -s "$backup/uploads-check.txt"

echo "=== Create and verify archive ==="

tar --acls --xattrs -czpf "$backup.tar.gz" \
    -C "$backup_root" "$(basename "$backup")"

tar -tzf "$backup.tar.gz" >/dev/null

sha256sum "$backup.tar.gz" > "$backup.tar.gz.sha256"
sha256sum -c "$backup.tar.gz.sha256"

echo "=== BACKUP COMPLETED ==="
echo "Archive: $backup.tar.gz"
echo "Checksum: $backup.tar.gz.sha256"

BACKUP
)
```

**Acceptance requirements**

The backup succeeds only when all commands complete without error, the MariaDB export contains its completion marker, both rsync checksum comparisons contain no differences, and the recovery archive passes integrity and SHA-256 verification.

The `rsync` verification uses dry-run mode (`-n`), so `--delete` reports unexpected destination files without deleting them.

The archive contains application binaries, matching uploads, external application configuration, OrchidApp systemd definitions, MariaDB data, grants and available MariaDB configuration. Custom auxiliary units not named `orchidapp*`, and their external configuration, must be identified in Step 1 and added to the recovery set where necessary.

Keep the backup directory, archive and checksum until the upgrade is accepted. Do not delete the previous working application's recovery set.

Copy the archive and checksum to protected off-device storage, verify the copied archive's SHA-256, and restrict access because the backup contains photographs, database content and credentials.

**Archive integrity does not itself prove successful restoration.** Verify the rollback process on an isolated Linux host and MariaDB instance before relying on it for production recovery. See [Recover a pre-upgrade archive](#recover-a-pre-upgrade-archive).

The application runtime and operating system are not included as complete installations. Rollback requires the compatible .NET 8 runtime, native dependencies and MariaDB server to remain available.

### 3. Pull the latest main branch

Update the local source checkout to the latest committed code on GitHub's `main` branch.

The Linux upgrade process always uses the current `origin/main`, rather than a release tag or pinned version. The checkout remains in detached HEAD mode.

```bash
cd ~/OrchidApp
set -e
test -z "$(git status --porcelain)"
git fetch origin main
git switch --detach origin/main
git log -1 --format='%h %s'
git status --short --branch
```

Confirm that the working tree is clean and HEAD matches the latest `origin/main` commit.

Record the resulting commit SHA for the upgrade record. The pre-upgrade backup retains the previous source revision for rollback.

### 4. Migrate

Export explicit `MARIADB_HOST`, `MARIADB_PORT`, `MARIADB_DATABASE`,
`MARIADB_USER` and `MARIADB_PASSWORD` from secure operator credentials.
Use the migration account. The systemd environment file is for the app.
Check the plan against the release and confirm its target before applying.

```bash
pwsh -NoProfile -File ./database/scripts/Apply-Migrations.ps1 -PlanOnly
# Continue after verifying the target and pending list.
pwsh -NoProfile -File ./database/scripts/Apply-Migrations.ps1
pwsh -NoProfile -File ./database/scripts/Apply-Migrations.ps1 -PlanOnly
```

Require zero pending after applying. The [runner contract](../../migration-runners.md)
describes ledger and checksum validation. If it rejects a historical ledger,
stop for [compatibility review](../../historical-linux-upgrade.md). If SQL
fails, keep services stopped and preserve diagnostics and any
`migration:pending` marker. DDL can be partially applied. Use verified
recovery before retrying.

### 5. Publish and deploy

Use the committed portable NuGet lock with a framework-dependent DLL on
the ARM64 .NET 8 host. The installed runtime and native libvips supply
platform dependencies. Treat a locked restore failure as a release issue.

```bash
project=src/OrchidApp.Web/OrchidApp.Web.csproj
stage=$(mktemp -d)
dotnet restore "$project" --locked-mode
dotnet publish "$project" -c Release --no-restore --self-contained false -p:UseAppHost=false -o "$stage"
test -s "$stage/OrchidApp.Web.dll"
test -z "$(git status --porcelain)"

incoming=$(sudo mktemp -d /opt/orchidapp/.publish-next.XXXXXXXX)
previous="${incoming/.publish-next./.publish-before.}"
sudo rsync -a "$stage/" "$incoming/"
sudo chmod 755 "$incoming"
sudo test ! -e "$previous"
```

Check that the service account can traverse and read the staged tree and
that the existing publish directory is a regular directory on the same
filesystem. Then replace it while the service is stopped.

```bash
sudo mv -T /opt/orchidapp/publish "$previous"
sudo mv -T "$incoming" /opt/orchidapp/publish
```

If a move fails, inspect both paths before restarting. If migrations ran,
recover matching SQL, uploads, configuration and app binaries together.

### 6. Start processes and verify

```bash
sudo systemctl start orchidapp.service
systemctl is-active orchidapp.service
curl --fail --show-error http://127.0.0.1:5000/health/ready
sudo journalctl -u orchidapp.service --since '5 minutes ago' --no-pager
```

Allow startup to complete and use the actual listener. Verify a representative
read and disposable save/reopen. Open existing plant and taxon photos,
upload a disposable photo, reopen its thumbnail and full image, then delete
it and confirm existing photos still open. See [photo handling](../../photo-handling.md)
for native decoder checks and recovery records. Resume only previously active
auxiliary services, timers and backup jobs after validation. Record the
deployed commit, SDK and results and retain the verified recovery set.

## Recover a pre-upgrade archive

Verify SHA-256 and extract into a private scratch directory with ACLs and
extended attributes preserved. On a separate host and MariaDB instance,
restore `orchids.sql` into an empty instance with no existing `orchids`
database. The dump selects that database by name. Recreate the needed
grants, including routine definers. Restore the captured publish tree,
service definitions, configuration and matching uploads from the archive.
Use isolated credentials and paths for the rehearsal and preserve required
file ownership. Follow the [application acceptance checks](OrchidApp-MariaDB-Backup-and-Restore-Runbook.md#application-and-replacement-acceptance).
For production recovery, stop writers and preserve failed-upgrade state
before restoring the same compatible set. Never run fresh schema creation
over the recovered collection.

The [routine backup and restore runbook](OrchidApp-MariaDB-Backup-and-Restore-Runbook.md)
covers scheduled paired snapshots and their separate restore format.
