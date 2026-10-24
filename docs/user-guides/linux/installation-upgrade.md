# Raspberry Pi and Linux installation and upgrades

This guide covers a general OrchidApp server using MariaDB and systemd. It does not install the owner's bespoke monitoring feeds/importer or EnergyMonitoring. [C03](../../code-change-backlog.md#c03) must isolate those queries by explicit opt-in; the current broad Linux ARM gate remains a general-installation blocker on Home until corrected.

Fresh database creation is from canonical schema and required seeds alone, never historical migration replay. Current fresh-creation automation has [C01/C02](../../code-change-backlog.md) blockers. This guide states the prerequisite rather than offering a broken copy-and-run rebuild command. Do not run migrations or a destructive rebuild against restored/live data to work around it.

## Prerequisites and target

Use a maintainer-validated Raspberry Pi OS/Linux release and architecture, .NET 8 SDK for source publishing, MariaDB 10.11 server/client tools, PowerShell 7+, Git, native libvips image dependencies and systemd. Backups also need Bash, rsync, tar/gzip, rclone and an off-device copy route such as SCP. Package names/repositories differ by OS image; no universal apt list has been validated by this documentation cleanup. Track repeatable platform setup in [C16](../../code-change-backlog.md#c16).

Choose an application service account, app root (examples /opt/orchidapp), external configuration directory (/etc/orchidapp), MariaDB endpoint/account and uploads path. Use the same values throughout. Install/configure MariaDB with utf8mb4 and utf8mb4_unicode_ci; verify actual server/database settings with your administrative tools. Distribution paths such as /etc/mysql and option group mysqld are normal MariaDB compatibility names.

## Fresh environment

1. Install and verify the tools above on the chosen image; enable MariaDB and verify the intended endpoint.
2. Obtain the trusted repository at the selected app root, owned appropriately for publishing. Use the agreed remote/release revision; do not publish an unknown checkout.
3. Provision the target database/account using the reviewed [schema-only creation contract](../../database-creation.md), including dependent views and reference seeds. It must work with the migrations directory absent. **Stop until that implementation is provided and validated.** The current Windows-specific rebuild script is not a Linux recipe. Record the schema baseline needed to accept only later migrations.
4. Configure the app's runtime account/connection and isolated durable uploads before starting. Runtime privileges and migration/admin privileges differ; do not run the web process as MariaDB root.
5. Build/publish and register the service below. Verify live application workflows and a real test-photo upload/reopen, then configure backups and validate an isolated recovery.

Creation bookkeeping must not read historical migration SQL. After creation, future compatible migrations are permitted; the prohibition is against replaying prior history into the assembled schema, not against upgrading that database later.

## External configuration and service

Create /etc/orchidapp with restricted ownership/access and a protected orchidapp.env using the operator's secure editor. Supply a correctly quoted complete ConnectionStrings__OrchidDb and Storage__UploadRoot. Keep passwords out of committed JSON, command arguments and copied support logs. A typical systemd value uses the form ConnectionStrings__OrchidDb="Server=127.0.0.1;Port=3306;Database=orchids;User=orchidapp;Password=..."; the ellipsis is a placeholder, not a password. Validate special-character quoting using the actual configuration mechanism. Use Storage__UploadRoot=/opt/orchidapp/uploads when that is the selected root.

The env file can be root-owned mode 600 because systemd reads it for a system service. The service account needs execute/traverse access to the published tree and writable upload storage, not permission to modify the secret file. The upload root must exist before middleware starts; protect it and include it in recovery.

After schema/native prerequisites pass, publish from the checkout root:

```bash
dotnet publish src/OrchidApp.Web/OrchidApp.Web.csproj -c Release -o /opt/orchidapp/publish
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

Open the operator-provided URL (for the example listener, http://<pi-host>:5000). Service-active/listening status is not database/native readiness. Check lists, disposable test data, save/reopen, search, styling and photos. General installs must not provision the owner's monitoring objects to make Home work; report C03 instead.

## Upgrade an existing correctly baselined database

Complete the [full pre-upgrade backup](Full-App-Backup-Pre-Upgrade.md), verify its off-device copy and a recovery route, then leave app/other writers stopped. The owner's importer must be stopped only on that bespoke installation. Never rebuild the restored or existing database.

Check checkout revision and clean tracked state, then obtain the intended update:

```bash
cd /opt/orchidapp
git status --short --branch
git log -1 --format='%h %s'
git pull --ff-only
```

Stop on conflicts or unexpected local changes. Preserve publish, uploads, imports and external configuration. Do not clean them away. Prepare migration credentials in the operator terminal through local secret management: MARIADB_HOST, MARIADB_PORT, MARIADB_DATABASE=orchids, MARIADB_USER and MARIADB_PASSWORD. Ensure every value refers to the selected target; the runtime connection string does not supply these variables automatically.

If using /etc/orchidapp/orchidapp-migrations.env, create it separately with restricted root/operator access and Bash-compatible quoted assignments, validate successful reading before sourcing it, and export its variables in a subshell. It is not automatically created or loaded by this repository, and a systemd env file is not automatically a safe Bash script. Do not invoke the runner after a failed/empty credential load or fall back to inherited targets.

With verified exported variables and compatible baseline, run:

```bash
pwsh ./database/scripts/Apply-Migrations.ps1
```

Require exit code 0 and review output before publishing. Historical checksum/order enforcement is incomplete; [C04](../../code-change-backlog.md#c04) records the required safeguards. DDL failures can leave partial state; do not blindly rerun or promise automatic rollback.

Publish as above, require success, start the app and repeat live checks. Resume only services/timers previously active; do not install an importer on other deployments. Keep the recovery set until the upgraded system has passed validation. Installer/ZIP copying is not a substitute for the maintained platform deployment process.

## Backup and recovery prerequisites

Follow the [routine backup/restore runbook](OrchidApp-MariaDB-Backup-and-Restore-Runbook.md) for account/path/remotes/scheduling checks and explicit backup selection. A fresh-source schema creation is different from restoring a backup. Recovery must not route a restored database through the destructive fresh-creation step. Restore app/configuration/service definitions and the compatible version, then publish/start only; apply only explicitly required subsequent migrations after a verified recovery copy.

For failures, inspect service/application logs without printing secret files into support output. Check selected endpoint, variable names, upload permissions and native libvips availability. Source-only validation and this guide do not certify a fresh machine or a backup restore; track acceptance with [C01–C05, C16/C17](../../code-change-backlog.md).
