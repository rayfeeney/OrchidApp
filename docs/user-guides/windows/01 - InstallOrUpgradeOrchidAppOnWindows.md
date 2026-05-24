# OrchidApp

# Install or Upgrade OrchidApp on Windows

Step-by-step installation and upgrade guide

**Applies to:** Windows 11

Use this guide when installing OrchidApp for the first time or upgrading OrchidApp to a newer version.

OrchidApp is installed using a Windows installer. The installer puts the application files in the normal Windows application folder and creates the Start Menu shortcut. You can also choose to create a Desktop shortcut.

---

## Before you start

- Download or copy the OrchidApp Windows installer onto the Windows computer.
- The installer file will usually be named something like `OrchidAppSetup-1.2.0.exe`.
- You do not need to extract a ZIP file.
- You do not need to create shortcuts manually.
- If OrchidApp is already installed, close OrchidApp before running the installer.
- If the OrchidApp Launcher is open, close it before upgrading.

> **Important:**  
> Do not upgrade OrchidApp by copying files over an older OrchidApp folder. Use the Windows installer. The installer and launcher are designed to protect your OrchidApp data during install and upgrade.

---

## If this is a new install

A new install is when OrchidApp has not been installed on this computer before.

The installer will install the application files. When OrchidApp is opened for the first time, the launcher will prepare the local database and supporting folders automatically.

---

## If this is an upgrade

An upgrade is when OrchidApp is already installed and you are installing a newer version.

Use the new Windows installer. It will replace the application files but keep your OrchidApp data.

Your plant database, uploaded photos, backups, settings and logs are stored separately from the application files.

> **Important:**  
> Do not uninstall OrchidApp before upgrading unless the release notes specifically tell you to. Run the new installer over the existing installation.

---

## What the installer does

The installer installs the OrchidApp application files here:

`C:\Program Files\OrchidApp`

Your OrchidApp data is kept separately here:

`C:\ProgramData\OrchidApp`

This means your plant database, uploaded photos, backups, settings and logs are not stored inside the application folder.

The installer does not delete your OrchidApp data when upgrading or uninstalling.

---

# 1. Find the OrchidApp installer

Open File Explorer and go to the folder containing the OrchidApp installer.

This is usually the **Downloads** folder unless you copied it somewhere else.

**Suggested screenshot:** File Explorer showing the downloaded `OrchidAppSetup.exe` installer.

---

# 2. Close OrchidApp if it is already running

If you are upgrading, close OrchidApp before continuing.

Close the browser tab and close the OrchidApp Launcher window.

If this is a new install, continue to the next step.

**Suggested screenshot:** OrchidApp Launcher window, showing the close button.

---

# 3. Start the installer

Double-click the OrchidApp installer.

If Windows asks whether you want to allow the app to make changes to your device, choose **Yes**.

> **Why Windows asks this:**  
> OrchidApp installs into `C:\Program Files\OrchidApp`, which is a protected Windows application folder.

**Suggested screenshot:** OrchidApp installer file selected in File Explorer.

---

# 4. If Windows shows an unknown publisher warning

Windows may warn that the publisher is unknown.

This can happen because OrchidApp is not code-signed.

Choose to continue only if the installer came from the trusted OrchidApp release page or from a person you trust.

If Windows SmartScreen appears, you may need to choose **More info**, then **Run anyway**.

> **Important:**  
> Only continue if you are sure this is the OrchidApp installer you intended to install.

**Suggested screenshot:** Windows SmartScreen or unknown publisher warning, if shown.

---

# 5. Follow the OrchidApp Setup Wizard

The OrchidApp Setup Wizard opens.

Choose **Next** to continue through the setup screens.

The installer uses the standard Windows application location:

`C:\Program Files\OrchidApp`

Most users should leave the default options unchanged.

**Suggested screenshot:** OrchidApp Setup Wizard welcome screen.

---

# 6. Choose shortcut options

The installer creates a Start Menu shortcut.

If the installer offers a Desktop shortcut option, leave it selected if you want OrchidApp to appear on the Desktop.

You can launch OrchidApp from either:

- the Start Menu
- the Desktop shortcut, if selected during setup

**Suggested screenshot:** Installer page showing shortcut options.

---

# 7. Install or upgrade OrchidApp

Choose **Install**.

Wait while the installer copies the OrchidApp application files.

For a new install, this installs OrchidApp for the first time.

For an upgrade, this replaces the old application files with the new version while keeping your OrchidApp data.

**Suggested screenshot:** Installer progress screen.

---

# 8. Finish setup

When setup is complete, choose **Finish**.

If the installer offers to launch OrchidApp, you can leave that option selected.

OrchidApp can also be opened later from the Start Menu or Desktop shortcut.

**Suggested screenshot:** Final setup screen with Finish button.

---

# 9. Open OrchidApp

Open OrchidApp from the Start Menu or Desktop shortcut.

The OrchidApp Launcher opens first.

On first use, the launcher may need to prepare OrchidApp. This can include creating the local database and starting the web application. This may take a few minutes but will report progress as it proceeds.

After an upgrade, the launcher may check the existing data and prepare anything needed for the new version.

Wait until OrchidApp opens in your browser.

> **Important:**  
> Keep the OrchidApp Launcher window open while using OrchidApp. If you close the launcher, OrchidApp will stop.

**Suggested screenshot:** OrchidApp Launcher starting.

---

# 10. Check OrchidApp opens correctly

When OrchidApp opens in your browser, check that the Home page appears.

If this is a new install, continue with the next guide:

**02 - Prepare OrchidApp for First Use**

If this is an upgrade, check that your existing plants, photos and setup information are still present.

**Suggested screenshot:** OrchidApp Home page open in the browser.

---

# After installing or upgrading

- Use the Start Menu or Desktop shortcut to open OrchidApp.
- Keep the OrchidApp Launcher window open while using OrchidApp.
- Do not move files in `C:\Program Files\OrchidApp`.
- Do not manually edit files in `C:\ProgramData\OrchidApp`.
- Use OrchidApp’s backup and restore buttons instead of copying database folders manually.

Your plant database, uploaded photos, backups, settings and logs are stored under:

`C:\ProgramData\OrchidApp`

---

# First-use performance note

After installing or upgrading OrchidApp, the first few page changes may feel a little slower than usual.

This is normally nothing to worry about. OrchidApp starts its local web application, connects to the local database and may prepare some parts of the app the first time they are used. It can feel quicker after you have moved around the app for a short while.

If OrchidApp becomes very slow, does not respond, or shows an error message, close OrchidApp and open it again from the Start Menu. If the problem continues, contact support.

---

# Important upgrade notes

Use the Windows installer for upgrades.

Do not:

- extract a new ZIP over an old OrchidApp folder
- copy new files into `C:\Program Files\OrchidApp` manually
- move or rename the ProgramData folder
- manually edit the database or uploads folders

During an upgrade, OrchidApp is designed to keep your data separate from the installed application files.

If OrchidApp needs to migrate older data, the launcher will handle this safely and create a pre-upgrade backup first.

---

# Uninstalling OrchidApp

If you uninstall OrchidApp, the application files are removed from:

`C:\Program Files\OrchidApp`

Your OrchidApp data is preserved under:

`C:\ProgramData\OrchidApp`

This includes:

- plant database
- uploaded photos
- backups
- launcher settings
- migration state
- support logs

> **Important:**  
> Uninstalling OrchidApp does not delete your plant collection data.

---

# Getting support

If OrchidApp does not install, upgrade or open correctly, email:

**OrchidApp@proton.me**

When asking for help, include:

- what you were trying to do
- whether this was a new install, an upgrade or a restore
- what happened
- any message shown by the OrchidApp Launcher or Windows
- the launcher support log, if requested

The launcher support log is stored at:

`C:\ProgramData\OrchidApp\logs\launcher.log`

---

# Troubleshooting

| Problem | What to do |
|---|---|
| Windows warns that the publisher is unknown | Continue only if the installer came from the trusted OrchidApp release page or from someone you trust. |
| Windows SmartScreen blocks the installer | Choose **More info**, then **Run anyway**, only if you trust the installer. |
| I cannot find OrchidApp after installation | Open the Start Menu and search for **OrchidApp**. |
| I did not create a Desktop shortcut | Open OrchidApp from the Start Menu. You can reinstall and choose the Desktop shortcut option if needed. |
| OrchidApp opens in the browser but then stops working | Check that the OrchidApp Launcher window is still open. |
| The app does not open after upgrading | Close OrchidApp fully, open it again from the Start Menu, and check the launcher messages. |
| My plants are not visible after upgrading | Do not add new data. Close OrchidApp and ask for support. |
| I need support | Email `OrchidApp@proton.me`. Include what you were doing, what happened, and any launcher message. The support log is stored at `C:\ProgramData\OrchidApp\logs\launcher.log`. |
| OrchidApp feels slow when I first open it | This can be normal just after installing, upgrading or starting OrchidApp. Move around the app for a short while. If it stays very slow or shows an error, close OrchidApp and open it again. |

---

# Installation or upgrade complete

OrchidApp is ready when:

- OrchidApp appears in the Start Menu
- the OrchidApp Launcher opens
- OrchidApp opens in your browser

For a new install, continue with:

**02 - Prepare OrchidApp for First Use**

For an upgrade, check your existing plants and photos before adding new information.
