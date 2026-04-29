# OrchidApp — Installation & Upgrade Guide

## 1. Purpose

This document defines the deterministic process for:

* First-time installation on Raspberry Pi
* Rebuilding the system from scratch
* Performing safe application upgrades

A correct execution of this guide must always result in a working system.

---

## 2. Environment Model

| Environment | Platform     | Configuration Source                     |
| ----------- | ------------ | ---------------------------------------- |
| Development | Windows PC   | `appsettings.Development.json`           |
| Production  | Raspberry Pi | systemd + `/etc/orchidapp/orchidapp.env` |

Rules:

* Production never depends on Development configuration
* Secrets are never committed to Git
* All runtime configuration is externally supplied

---

## 3. First-Time Installation (Fresh Raspberry Pi)

---

### 3.1 Install Prerequisites

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

### 3.2 Configure MariaDB (Required)

MariaDB must be configured before schema creation.

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

### 3.3 Create Database and User

```sql
CREATE DATABASE orchids CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE USER 'orchidapp'@'localhost' IDENTIFIED BY 'STRONG_PASSWORD';

GRANT ALL PRIVILEGES ON orchids.* TO 'orchidapp'@'localhost';

FLUSH PRIVILEGES;
```

---

### 3.4 Clone Repository

```bash
sudo mkdir -p /opt/orchidapp
sudo chown $USER:$USER /opt/orchidapp
cd /opt/orchidapp

git clone <repo-url> .
```

---

### 3.5 Configure Environment

Create:

```bash
sudo mkdir -p /etc/orchidapp
sudo chmod 700 /etc/orchidapp
sudo nano /etc/orchidapp/orchidapp.env
```

Add:

```env
ConnectionStrings__OrchidDb=Server=127.0.0.1;Port=3306;Database=orchids;User=orchidapp;Password=STRONG_PASSWORD
StorageSettings__UploadRoot=/opt/orchidapp/uploads
```

Secure:

```bash
sudo chmod 600 /etc/orchidapp/orchidapp.env
```

---

### 3.6 Configure Uploads Directory

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

### 3.7 Install Image Processing Dependencies

```bash
sudo apt install -y libvips libheif1 libheif-dev
```

If missing, photo uploads will fail by design.

---

### 3.8 Initialise Database Schema

From repo root:

```bash
pwsh ./database/scripts/rebuild.ps1
```

This:

* Drops and recreates schema
* Applies full schema export
* Produces a deterministic database state

No manual SQL changes are permitted.

---

### 3.9 Create systemd Service

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

### 3.10 First Publish

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

### 3.11 Configure Backups (Mandatory)

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

### 3.12 Validate Restore (Required)

```bash
mysql -u root -p orchids_test < backup.sql
```

Backups are only valid if restore succeeds.

---

## 4. Upgrade Procedure

---

### 4.0 Pre-Upgrade Backup (Mandatory)

```bash
/opt/orchidapp/infrastructure/backups/backup_orchids.sh
```

Upgrade must not proceed without a successful backup.

---

### 4.1 Apply Database Changes

```bash
cd /opt/orchidapp
git status
git pull
./database/scripts/apply-migrations.sh
```

Rules:

* Working tree must be clean
* Migrations must succeed without manual intervention

Migrations are expected to fail fast on error.

Partial application may occur and must be resolved before re-running.
The system does not attempt automatic rollback.

---

### 4.2 Upgrade Application

```bash
sudo systemctl stop orchidapp

dotnet publish src/OrchidApp.Web/OrchidApp.Web.csproj -c Release -o /opt/orchidapp/publish

sudo systemctl restart orchidapp
```

Rules:

* Never edit files in `publish/`
* Never manually copy binaries

---

## 5. Verification Checklist

After deployment:

```bash
sudo systemctl status orchidapp
```

Confirm:

* Service is running
* No startup errors
* Database connectivity successful

Then test:

* Pages load
* Data is visible
* Styling is present

---

## 6. Troubleshooting

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

* Correct variable name
* Correct credentials
* File permissions (600)

---

### Upload failures

Check:

* Upload directory exists
* Permissions are correct
* libvips is installed

---

## 7. Deterministic Deployment Contract

A correct deployment consists only of:

```bash
git pull
dotnet publish -c Release -o ./publish
sudo systemctl restart orchidapp
```

If additional steps are required, the deployment model is broken and must be corrected.
