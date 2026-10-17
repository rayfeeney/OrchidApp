# OrchidApp - Installation & Upgrade Guide

MariaDB is the supported database engine. On Raspberry Pi OS, MariaDB uses
the distribution path `/etc/mysql/` and accepts the `[mysqld]` option group;
these names are expected and do not indicate a MySQL server installation.

## 1. Purpose

This document defines the **deterministic procedures** for:

* First-time installation on Raspberry Pi
* Rebuilding the system from scratch
* Performing safe application upgrades

A correct execution of this guide must always result in a working system.

If additional undocumented steps are required, the deployment model is considered broken.

---

## 2. Environment Model

| Environment | Platform     | Configuration Source           |
| ----------- | ------------ | ------------------------------ |
| Development | Windows PC   | `appsettings.Development.json` |
| Production  | Raspberry Pi | `/etc/orchidapp/orchidapp.env` |

Rules:

* Production never depends on Development configuration
* Secrets are never committed to Git
* All runtime configuration is externally supplied

##### needed to get Govee data in
GRANT SELECT, INSERT, UPDATE, EXECUTE
ON `orchids`.*
TO `orchidapp`@`localhost`;

GRANT DELETE
ON `orchids`.`environmentimportrow`
TO `orchidapp`@`localhost`;

FLUSH PRIVILEGES;


sudo apt install -y python3-venv libmariadb-dev build-essential

python3 -m venv /opt/orchidapp/infrastructure/environment-importer/.venv

/opt/orchidapp/infrastructure/environment-importer/.venv/bin/pip install mariadb

/opt/orchidapp/infrastructure/environment-importer/.venv/bin/python -c "import mariadb; print('mariadb connector ok')"


The systemd service must use the virtual environment Python:

/opt/orchidapp/infrastructure/environment-importer/.venv/bin/python

Do not install the MariaDB Python connector into the system Python environment.


---

## 3. Installation Strategies (Critical)

A database must be managed using **one and only one** strategy:

### Strategy A - Rebuild (Fresh Installation)

* Used for new environments
* Uses canonical schema export
* Does **not** use migrations

### Strategy B - Migration (Existing System)

* Used for upgrading an existing deployment
* Applies forward-only migrations
* Must not rebuild schema

These strategies must **never be combined on the same database**.

---

## 4. First-Time Installation (Fresh Raspberry Pi)

This procedure uses the **Rebuild strategy**.

---

### 4.1 Install Prerequisites

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl git powershell rclone
sudo apt install -y dotnet-sdk-8.0
sudo apt install -y mariadb-server
```

Enable MariaDB:

```bash
sudo systemctl enable mariadb
sudo systemctl start mariadb
```

---

### 4.2 Configure MariaDB (Required)

Edit:

```bash
sudo nano /etc/mysql/mariadb.conf.d/50-server.cnf
```

Ensure:

```ini
[mysqld]
character-set-server = utf8mb4
collation-server     = utf8mb4_unicode_ci
```

Restart:

```bash
sudo systemctl restart mariadb
```

Verify:

```sql
SHOW VARIABLES LIKE 'collation%';
```

Expected:

* `collation_server = utf8mb4_unicode_ci`

If this step is skipped, stored procedures and comparisons may fail.

---

### 4.3 Create Database and User

```sql
CREATE DATABASE orchids CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE USER 'orchidapp'@'localhost' IDENTIFIED BY 'STRONG_PASSWORD';

GRANT ALL PRIVILEGES ON orchids.* TO 'orchidapp'@'localhost';

FLUSH PRIVILEGES;
```

---

### 4.4 Clone Repository

```bash
sudo mkdir -p /opt/orchidapp
sudo chown $USER:$USER /opt/orchidapp
cd /opt/orchidapp

git clone <repo-url> .
```

---

### 4.5 Configure Environment

Create:

```bash
sudo mkdir -p /etc/orchidapp
sudo chmod 700 /etc/orchidapp
sudo nano /etc/orchidapp/orchidapp.env
```

Add:

```env
ConnectionStrings__OrchidDb=Server=127.0.0.1;Port=3306;Database=orchids;User=orchidapp;Password=STRONG_PASSWORD
Storage__UploadRoot=/opt/orchidapp/uploads
```

Secure:

```bash
sudo chmod 600 /etc/orchidapp/orchidapp.env
```

---

### 4.6 Configure Uploads Directory

```bash
sudo mkdir -p /opt/orchidapp/uploads
sudo chown <user>:<user> /opt/orchidapp/uploads
chmod 750 /opt/orchidapp/uploads
```

Requirements:

* Must exist before application start
* Must be writable by the application user
* Part of the canonical dataset

---

### 4.7 Install Image Processing Dependencies

```bash
sudo apt install -y libvips libheif1 libheif-dev
```

If missing, photo uploads will fail by design.

---

### 4.8 Initialise Database Schema (Rebuild)

From repository root:

```bash
pwsh ./database/scripts/rebuild.ps1
```

This:

* Drops and recreates the database schema
* Applies the canonical schema export
* Produces a deterministic, clean state

No manual SQL changes are permitted.

---

### 4.9 Create systemd Service

```bash
sudo nano /etc/systemd/system/orchidapp.service
```

```ini
[Unit]
Description=OrchidApp Web Application
After=network.target

[Service]
ExecStart=/usr/bin/dotnet /opt/orchidapp/publish/OrchidApp.Web.dll --urls http://0.0.0.0:5000
WorkingDirectory=/opt/orchidapp/publish
User=<user>
Environment=ASPNETCORE_ENVIRONMENT=Production
EnvironmentFile=/etc/orchidapp/orchidapp.env
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Enable:

```bash
sudo systemctl daemon-reload
sudo systemctl enable orchidapp
```

---

### 4.10 First Publish

```bash
dotnet publish src/OrchidApp.Web/OrchidApp.Web.csproj -c Release -o /opt/orchidapp/publish
sudo systemctl start orchidapp
```

Verify:

```bash
sudo systemctl status orchidapp
```

Application should be accessible at:

```
http://<pi-ip>:5000
```

---

### 4.11 Configure Backups (Mandatory)

A deployment without backups is incomplete.

Install script:

```bash
chmod +x /opt/orchidapp/infrastructure/backups/backup_orchids.sh
```

Test:

```bash
/opt/orchidapp/infrastructure/backups/backup_orchids.sh
```

Schedule:

```bash
crontab -e
```

```bash
0 2 * * * /opt/orchidapp/infrastructure/backups/backup_orchids.sh
```

---

### 4.12 Validate Restore (Required)

Follow the [backup and restore runbook](OrchidApp-MariaDB-Backup-and-Restore-Runbook.md)
in an isolated test environment. A dump containing `CREATE DATABASE` or `USE`
statements can select its original database even when a different database name
is supplied to the client. Never test a restore against production.

Backups are only valid if restore succeeds.

---

## 5. Upgrade Procedure

This procedure uses the **Migration strategy**.

---

### 5.0 Pre-Upgrade Backup (Mandatory)

Complete the [full pre-upgrade backup](Full-App-Backup-Pre-Upgrade.md), including
application files, photos, database, external configuration and service settings.
Verify an off-device copy before proceeding. Leave the app and any importer stopped.

### 5.1 Update Source and Apply Migrations

```bash
cd /opt/orchidapp
git status --short --branch
git log -1 --format="%h %s"
git pull --ff-only
```

Tracked files must have no local changes. Preserve local `publish/`, `uploads/`
and `imports/` directories; never run a cleanup that deletes them. If Git reports
a conflict or an untracked file would be overwritten, stop and investigate.

Load migration credentials without displaying them and export them to PowerShell:

```bash
(
  set -a
  source <(sudo cat /etc/orchidapp/orchidapp-migrations.env)
  set +a
  pwsh ./database/scripts/Apply-Migrations.ps1
)
echo "Migration exit code: $?"
```

Require exit code `0`. Resolve any failure before continuing or re-running.
Use migrations for an existing database; never run the fresh-install rebuild.
The system does not attempt automatic rollback.

### 5.2 Publish and Start the Application

```bash
dotnet publish src/OrchidApp.Web/OrchidApp.Web.csproj -c Release -o /opt/orchidapp/publish
echo "Publish exit code: $?"
```

Require exit code `0` before starting:

```bash
sudo systemctl start orchidapp.service
systemctl is-active orchidapp.service
sudo journalctl -u orchidapp.service --since "2 minutes ago" --no-pager -n 60
```

Verify the browser checks below, then resume the importer timer if it was running
before the backup:

```bash
sudo systemctl start orchidapp-environment-importer.timer
systemctl list-timers --all orchidapp-environment-importer.timer --no-pager
```

Do not manually replace published binaries or configuration files.

---

## 6. Verification Checklist

After deployment:

```bash
sudo systemctl status orchidapp
```

Confirm:

* Service is running
* No startup errors
* Database connectivity successful

Then verify:

* Pages load
* Data is visible
* Styling is present
* Plant photos load
* Botanical name search returns expected results
* The environmental summary loads on the supported Raspberry Pi platform

---

## 7. Troubleshooting

### Application fails at startup

```bash
journalctl -u orchidapp -n 50
```

---

### Connection string issues

```bash
cat /etc/orchidapp/orchidapp.env
```

Check:

* Correct variable names
* Correct credentials
* File permissions (600)

---

### Upload failures

Check:

* Upload directory exists
* Permissions are correct
* libvips is installed

---

## 8. Deployment sequence

For an existing deployment, follow section 5 in order: full backup, source update,
migrations, publish, startup verification and resumption of scheduled imports.
Application data and external configuration must survive every upgrade.
