# OrchidApp --- Installation & Upgrade Guide

## 1. Purpose

This document defines the complete, deterministic process for:

-   First-time installation on a Raspberry Pi
-   Rebuilding from scratch
-   Performing application upgrades safely

This guide assumes:

-   Repository root: `/opt/orchidapp`
-   Publish output: `/opt/orchidapp/publish`
-   Service name: `orchidapp`
-   Database name: `orchids`

The objective is that a clean install following this guide always
results in a working system.

------------------------------------------------------------------------

# 2. Environment Model

  Environment   Platform       Configuration Source
  ------------- -------------- ------------------------------------------
  Dev           Windows PC     `appsettings.Development.json`
  Production    Raspberry Pi   systemd + `/etc/orchidapp/orchidapp.env`

Production never depends on Development configuration.

Secrets are never committed to Git.

------------------------------------------------------------------------

# 3. First-Time Installation (Fresh Raspberry Pi)

## 3.1 Install Prerequisites

Update system:

    sudo apt update && sudo apt upgrade -y

Install curl (used for local validation and troubleshooting):

    sudo apt install -y curl

Install .NET runtime:

    sudo apt install -y dotnet-sdk-8.0

Install MariaDB:

    sudo apt install -y mariadb-server

Enable and start MariaDB:

    sudo systemctl enable mariadb
    sudo systemctl start mariadb

Verify:

    sudo systemctl status mariadb

Install supporting libraries for image processing:

    sudo apt install -y libglib2.0-dev libexpat1 libjpeg-dev libpng-dev libtiff5 libwebp-dev

These ensure libvips and HEIC processing operate correctly on Raspberry Pi systems.

Install image processing dependencies:

    sudo apt install -y libvips libheif1 libheif-dev imagemagick

These are required for:

- HEIC image decoding
- Canonical image processing via libvips

If these dependencies are missing, photo uploads will fail by design.

Install Git:

    sudo apt install -y git

Install PowerShell:

    sudo apt install -y powershell

Install rclone (required for encrypted off-device backups):

    sudo apt install -y rclone

------------------------------------------------------------------------

## 3.2 Create Production Database & User

Login:

    sudo mysql

Create database and user:

    CREATE DATABASE orchids CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
    CREATE USER 'orchidapp'@'localhost' IDENTIFIED BY 'STRONG_PASSWORD';
    GRANT ALL PRIVILEGES ON orchids.* TO 'orchidapp'@'localhost';
    FLUSH PRIVILEGES;
    EXIT;

------------------------------------------------------------------------

## 3.3 Clone Repository

    sudo mkdir -p /opt/orchidapp
    sudo chown raymond-23:raymond-23 /opt/orchidapp
    cd /opt/orchidapp
    git clone <your-repo-url> .

Confirm `.git` exists in `/opt/orchidapp`.

------------------------------------------------------------------------

## 3.4 Configure Production Secrets

Create secure directory:

    sudo mkdir -p /etc/orchidapp
    sudo chown root:root /etc/orchidapp
    sudo chmod 700 /etc/orchidapp

Create environment file:

    sudo nano /etc/orchidapp/orchidapp.env

Add:

    ConnectionStrings__OrchidDb=Server=127.0.0.1;Port=3306;Database=orchids;User=orchidapp;Password=STRONG_PASSWORD

Secure it:

    sudo chmod 600 /etc/orchidapp/orchidapp.env

------------------------------------------------------------------------

## 3.4A Configure Upload Storage

Create upload root directory:

    sudo mkdir -p /opt/orchidapp/uploads

Set ownership:

    sudo chown raymond-23:raymond-23 /opt/orchidapp/uploads

Set permissions:

    chmod 750 /opt/orchidapp/uploads

---

### Configure application setting

Ensure the upload path is configured via environment:

Add to `/etc/orchidapp/orchidapp.env`:

    StorageSettings__UploadRoot=/opt/orchidapp/uploads

---

### Validate

The directory must:

- exist before application startup
- be writable by the application user
- persist across restarts

If this path is missing or invalid, the application must fail or reject uploads.

------------------------------------------------------------------------

## 3.5 Create systemd Service

Create:

    sudo nano /etc/systemd/system/orchidapp.service

Contents:

    [Unit]
    Description=OrchidApp Web Application
    After=network.target

    [Service]
    ExecStart=/usr/bin/dotnet /opt/orchidapp/publish/OrchidApp.Web.dll --urls http://0.0.0.0:5000
    WorkingDirectory=/opt/orchidapp/publish
    User=raymond-23
    Environment=ASPNETCORE_ENVIRONMENT=Production
    EnvironmentFile=/etc/orchidapp/orchidapp.env
    Restart=on-failure
    RestartSec=10
    StandardOutput=journal
    StandardError=journal

    [Install]
    WantedBy=multi-user.target

Enable service:

    sudo systemctl daemon-reload
    sudo systemctl enable orchidapp

------------------------------------------------------------------------

## 3.5A Initialise Database Schema

From the repository root:

    cd /opt/orchidapp

Run the database rebuild script:

    pwsh ./database/scripts/rebuild.ps1

This creates the required database schema from the repository export files.

No manual SQL changes are allowed during first-time installation.

Confirm the database contains the expected objects before starting the application.

------------------------------------------------------------------------

## 3.6 First Publish

    cd /opt/orchidapp
    dotnet publish src/OrchidApp.Web/OrchidApp.Web.csproj -c Release -o ./publish
    sudo systemctl start orchidapp

Check status:

    sudo systemctl status orchidapp

Application should now be accessible at:

    http://<pi-ip>:5000

------------------------------------------------------------------------

## 3.7 Configure Backups

Backups are mandatory. A deployment without a working backup process is incomplete.

### 3.7.1 Install backup script

Ensure the backup script exists:

    /opt/orchidapp/infrastructure/backups/backup_orchids.sh

Make executable:

    chmod +x /opt/orchidapp/infrastructure/backups/backup_orchids.sh

---

### 3.7.2 Configure storage target

Ensure backup destination (e.g. OneDrive via rclone) is configured.

If using rclone:

    rclone config

Confirm encrypted remote (e.g. `orchidcrypt`) is available.

---

### 3.7.3 Test backup manually

Run:

    /opt/orchidapp/infrastructure/backups/backup_orchids.sh

Confirm:

- Backup file created
- File uploaded successfully (if remote configured)

---

### 3.7.4 Schedule automatic backups

Edit crontab:

    crontab -e

Add:

    0 2 * * * /opt/orchidapp/infrastructure/backups/backup_orchids.sh

---

### 3.7.5 Validate restore (required)

Backups are only valid if restore succeeds.

Test restore into a temporary database:

    mysql -u root -p orchids_test < backup.sql

Confirm:

- Schema restored
- Data present

### 3.7.6 Uploads Backup

The uploads directory must be included in the backup process.

Ensure:

- `/opt/orchidapp/uploads` is backed up alongside the database
- The backup destination includes both database and uploads
- Restores include both components to maintain consistency

Failure to back up uploads will result in permanent loss of image data.

------------------------------------------------------------------------

# 4. Upgrade Procedure

## 4.0 Pre-Upgrade Backup (Mandatory)

Before applying any upgrade:

Run:

    /opt/orchidapp/infrastructure/backups/backup_orchids.sh

Confirm:

- Backup completes successfully
- Backup file exists and is valid

Upgrades must not proceed without a successful backup.

This provides the only supported rollback mechanism.

Upgrades must always follow this sequence.

## 4.1 SQL Maria DB objects upgrade

If SQL objects are included in the upgrade, these must be applied first. 

### 4.1.1 Confirm tree is clean

    cd /opt/orchidapp
    git status

If the working tree is clean, proceed.

If not, resolve the issues before  proceeding.

### 4.1.2 Pull Latest Code
    
    git pull

### 4.2.3 Apply the updated SQL objects

To apply the new and updated objects,

    ./database/scripts/apply-migrations.sh

## 4.2 Web app upgrade 

Never edit files inside `publish/`.

Never manually copy files.

### 4.2.1 Confirm tree is clean

    cd /opt/orchidapp
    git status

If the working tree is clean, proceed.

If not, resolve the issues before  proceeding.

### 4.2.2 Stop the service

    sudo systemctl stop orchidapp

### 4.2.3 Pull Latest Code
    
    git pull

### 4.2.4 Publish

    dotnet publish src/OrchidApp.Web/OrchidApp.Web.csproj -c Release -o /opt/orchidapp/publish

### 4.2.5 Restart Service

    sudo systemctl restart orchidapp

------------------------------------------------------------------------

# 5. Verification Checklist

After any deployment:

    sudo systemctl status orchidapp

Confirm:

-   Service is active (running)
-   No startup exceptions
-   No connection string errors

Then test in browser:

-   Pages load
-   Styling present
-   Database queries succeed

------------------------------------------------------------------------

# 6. Troubleshooting

## Connection String Missing

    sudo cat /etc/orchidapp/orchidapp.env

Verify:

-   Correct variable name: `ConnectionStrings__OrchidDb`
-   Correct password
-   File permissions: 600

Reload:

    sudo systemctl daemon-reload
    sudo systemctl restart orchidapp

------------------------------------------------------------------------

## Application Fails at Startup

    journalctl -u orchidapp -n 50

------------------------------------------------------------------------

## Styling Missing

Verify Bootstrap assets exist in:

    src/OrchidApp.Web/wwwroot/lib/bootstrap/dist/

Never depend on CDN or manual copying.

------------------------------------------------------------------------

# 7. Deterministic Deployment Contract

A correct deployment always consists of:

    git pull
    dotnet publish -c Release -o ./publish
    sudo systemctl restart orchidapp

If additional steps are required, the deployment model is broken and
must be corrected.
