# OrchidApp v1.2.0 Release Notes

## Overview

OrchidApp v1.2.0 introduces the new Windows installer-led installation and upgrade process.

This release is mainly focused on making OrchidApp safer and simpler to install, upgrade and recover on Windows. It separates the application files from your OrchidApp data, so future upgrades can replace the app without overwriting your plant database, uploaded photos, backups or settings.

## Main change: Windows installer

OrchidApp is now installed using a Windows installer.

The installer places the application files in:

`C:\Program Files\OrchidApp`

Your OrchidApp data is stored separately in:

`C:\ProgramData\OrchidApp`

This means the app and your data are no longer kept together in an extracted ZIP folder.

## What this means for users

For a new installation, download and run the OrchidApp Windows installer.

For an upgrade, run the new installer. Do not extract a ZIP file over an older OrchidApp folder, and do not manually copy files into the application folder.

The installer creates a Start Menu shortcut and can optionally create a Desktop shortcut.

## Data is preserved during upgrade

Your OrchidApp data is stored under:

`C:\ProgramData\OrchidApp`

This includes:

- plant database
- uploaded photos and files
- backups
- cloud backup settings
- launcher settings
- migration state
- support logs

Uninstalling OrchidApp removes the application files but leaves your OrchidApp data in place.

## Safe migration from older OrchidApp layouts

Older OrchidApp versions used an extracted folder layout where the application files and data lived together.

OrchidApp v1.2.0 can detect this older layout and safely copy the data into the new ProgramData location.

Before migration, OrchidApp creates a mandatory pre-upgrade backup.

The old legacy data is copied only. It is not deleted, moved or renamed.

## Backup improvements

OrchidApp continues to support local backups and cloud backup folder configuration.

Local backups are stored under:

`C:\ProgramData\OrchidApp\backups`

Pre-upgrade backups are stored under:

`C:\ProgramData\OrchidApp\backups\pre-upgrade`

If a cloud backup folder is configured, OrchidApp also copies the latest successful backup to that folder.

## Launcher support log

The OrchidApp Launcher now keeps a support log at:

`C:\ProgramData\OrchidApp\logs\launcher.log`

If the log grows large, OrchidApp rotates it and keeps:

- `launcher.log`
- `launcher.previous.log`

This helps with support if installation, upgrade, backup or restore does not behave as expected.

## Windows unknown publisher warning

The OrchidApp installer is currently unsigned.

This means Windows may show an unknown publisher or SmartScreen warning when you run the installer.

Only continue if the installer came from the trusted OrchidApp release page or from someone you trust.

## Updated user guides

The Windows user guides have been updated for v1.2.0:

1. Install or Upgrade OrchidApp on Windows
2. Prepare OrchidApp for First Use
3. Add and Manage Plants in OrchidApp
4. Configure Cloud Backup Folder in OrchidApp
5. Recover OrchidApp on a Replacement Windows Computer

## Known limitation

The v1.2.0 upgrade safety work focuses on migration from the older extracted-folder layout into the new ProgramData layout.

A future release may add a stronger pre-upgrade backup gate for ProgramData-to-ProgramData upgrades.

## Support

For support, email:

**OrchidApp@proton.me**

When asking for help, include:

- what you were trying to do
- whether this was a new install, an upgrade, backup or restore
- what happened
- any message shown by the OrchidApp Launcher or Windows
- the launcher support log, if requested

The launcher support log is stored at:

`C:\ProgramData\OrchidApp\logs\launcher.log`