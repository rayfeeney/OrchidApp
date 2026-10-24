# OrchidApp v1.2.0

OrchidApp v1.2.0 introduces the new Windows installer-led installation and upgrade process.

This release is focused on making OrchidApp safer and simpler to install, upgrade and recover on Windows.

## Download

For Windows, download and run the OrchidApp installer.

Do **not** extract a ZIP file over an existing OrchidApp folder.

Do **not** copy new files manually over an older OrchidApp installation.

## What has changed

OrchidApp now separates the application files from your OrchidApp data.

Application files are installed under:

`C:\Program Files\OrchidApp`

Your OrchidApp data is stored under:

`C:\ProgramData\OrchidApp`

This includes:

- plant database
- uploaded photos and files
- backups
- cloud backup settings
- launcher settings
- support logs

This separation allows the application to be upgraded without overwriting your plant collection data.

## Installing OrchidApp

For a new installation:

1. Download the Windows installer.
2. Run the installer.
3. Open OrchidApp from the Start Menu or Desktop shortcut.
4. Follow the **Install or Upgrade OrchidApp on Windows** guide.

The first launch may take a few minutes while OrchidApp prepares the local database and supporting files.

## Upgrading OrchidApp

For an upgrade:

1. Close OrchidApp if it is already running.
2. Run the new Windows installer.
3. Open OrchidApp from the Start Menu or Desktop shortcut.
4. Check that your existing plants, photos and setup information are present.

Do not uninstall OrchidApp before upgrading unless the release instructions specifically tell you to.

Do not manually copy files into `C:\Program Files\OrchidApp`.

## Upgrading from an older extracted-folder version

Older OrchidApp versions used an extracted-folder layout where the application and data lived together.

OrchidApp v1.2.0 can detect this older layout and safely copy the data into the new Windows data location.

Before migration, OrchidApp creates a mandatory pre-upgrade backup.

The old legacy data is copied only. It is not deleted, moved or renamed.

## Backups

Local backups are stored under:

`C:\ProgramData\OrchidApp\backups`

Pre-upgrade backups are stored under:

`C:\ProgramData\OrchidApp\backups\pre-upgrade`

If a cloud backup folder is configured, OrchidApp also copies the latest successful backup to that folder.

## Windows security warning

The OrchidApp installer is currently unsigned.

Windows may show an unknown publisher or SmartScreen warning when the installer is opened.

Only continue if the installer came from this release page or from someone you trust.

## User guides

The v1.2.0 user guides are available with this release:

1. **Install or Upgrade OrchidApp on Windows**
2. **Prepare OrchidApp for First Use**
3. **Add and Manage Plants in OrchidApp**
4. **Configure Cloud Backup Folder in OrchidApp**
5. **Recover OrchidApp on a Replacement Windows Computer**

## Support

For support, email:

**OrchidApp@proton.me**

When asking for help, include:

- what you were trying to do
- whether this was a new install, an upgrade, backup or restore
- what happened
- any message shown by the OrchidApp Launcher or Windows

The OrchidApp Launcher support log is stored at:

`C:\ProgramData\OrchidApp\logs\launcher.log`

## Known limitation

The v1.2.0 upgrade safety work focuses on migration from the older extracted-folder layout into the new ProgramData layout.

A future release may add a stronger pre-upgrade backup gate for ProgramData-to-ProgramData upgrades.