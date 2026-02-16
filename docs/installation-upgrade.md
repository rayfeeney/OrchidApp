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

Install .NET runtime:

    sudo apt install -y dotnet-runtime-8.0

Install MariaDB:

    sudo apt install -y mariadb-server

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

## 3.6 First Publish

    cd /opt/orchidapp
    dotnet publish src/OrchidApp.Web/OrchidApp.Web.csproj -c Release -o ./publish
    sudo systemctl start orchidapp

Check status:

    sudo systemctl status orchidapp

Application should now be accessible at:

    http://<pi-ip>:5000

------------------------------------------------------------------------

# 4. Upgrade Procedure

Upgrades must always follow this sequence.

Never edit files inside `publish/`.

Never manually copy files.

## 4.1 Pull Latest Code

    cd /opt/orchidapp
    git pull

## 4.2 Publish

    dotnet publish src/OrchidApp.Web/OrchidApp.Web.csproj -c Release -o ./publish

## 4.3 Restart Service

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
