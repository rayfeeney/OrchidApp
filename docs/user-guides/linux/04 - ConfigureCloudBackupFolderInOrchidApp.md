# OrchidApp

# Configure Cloud Backup Folder in OrchidApp

User guide for protecting your OrchidApp backups against total computer failure

**Applies to:** Windows 11

Use this guide after OrchidApp has been installed or upgraded using the Windows installer and OrchidApp has been opened successfully.

The OrchidApp Launcher includes a **Configure cloud backup** button.

---

# Purpose

OrchidApp keeps local backups on the computer.

This guide explains how to choose a cloud-synced folder where OrchidApp will also copy the latest successful backup.

This is the safest everyday recovery option because the backup is stored away from the computer running OrchidApp.

If the computer is lost, damaged or replaced, the backup can be downloaded again from the cloud provider and restored on a new machine.

---

# Important

A cloud backup is only useful after the cloud provider has finished syncing the backup file.

After configuring the folder, check that OneDrive, Google Drive, iCloud Drive or your chosen provider shows the backup as synced.

Do not manually edit, unpack or rename the backup ZIP file.

---

# Before you start

- Install or upgrade OrchidApp using the Windows installer.
- Open OrchidApp at least once so the OrchidApp Launcher starts.
- Make sure you are signed in to your cloud provider on the computer.
- Create or choose a folder that is synced to the cloud, such as OneDrive, Google Drive, iCloud Drive or another trusted provider.
- Use a clear folder name, such as `OrchidBackups`.
- Do not choose a temporary folder.
- Do not choose a folder that is not included in cloud sync.

---

# How OrchidApp cloud backup works

OrchidApp stores its normal local backups under:

`C:\ProgramData\OrchidApp\backups`

When a cloud backup folder is configured, OrchidApp also copies the latest successful backup to the selected cloud folder.

The cloud copy is normally named:

`OrchidAppDataBackup.zip`

This cloud copy is intended for disaster recovery. It gives you a recent backup that should still be available even if the original computer fails completely.

> **Note:**  
> When you start OrchidApp, it automatically checks when the last backup was made. If it was more than 7 days ago, OrchidApp creates a backup automatically without interrupting your use of the app.

---

# Quick checklist

- Close the OrchidApp browser tab if it is covering the launcher window.
- Open or bring forward the OrchidApp Launcher window.
- Select **Configure cloud backup**.
- Choose a folder that is synced by your cloud provider.
- Confirm that OrchidApp saves the cloud backup folder.
- Run **Back up now** or wait for the next automatic backup.
- Check that the cloud provider has synced the backup file.

---

# Step-by-step setup

# 1. Close the browser tab if required

If OrchidApp is open in your browser and the launcher is hidden behind it, close the browser tab or switch back to the launcher window.

Closing only the browser tab does not stop OrchidApp.

**Suggested screenshot:** Close the browser tab if you need to see the OrchidApp Launcher.

---

# 2. Bring the OrchidApp Launcher to the front

Select the OrchidApp icon on the taskbar to bring the launcher window to the front.

The launcher window must remain open while using OrchidApp.

**Suggested screenshot:** Select the OrchidApp icon on the taskbar to return to the launcher.

---

# 3. Choose Configure cloud backup

In the OrchidApp Launcher, select **Configure cloud backup**.

This opens a folder picker so you can choose where the latest cloud backup should be copied.

**Suggested screenshot:** Select Configure cloud backup from the OrchidApp Launcher.

---

# 4. Select a cloud-synced folder

Choose a folder that your cloud provider already syncs.

Examples include:

- OneDrive
- Google Drive
- iCloud Drive
- another trusted cloud-synced folder

You can use an existing folder or create a new one.

The important point is that the folder must be included in cloud sync.

**Suggested screenshot:** Choose a folder synced by OneDrive, Google Drive, iCloud Drive or another provider.

---

# 5. Confirm the folder

Select the folder, then choose **Select Folder**.

OrchidApp saves the selected folder as the cloud backup location.

**Suggested screenshot:** OrchidApp confirms when the cloud backup folder has been saved.

---

# 6. Check the backup log

After the folder is saved, the launcher log should show that the cloud backup folder has been configured.

When a backup completes, OrchidApp creates the local backup first, then copies the latest backup to the configured cloud folder.

If the log says the cloud backup folder is not configured, repeat the steps above and select the cloud-synced folder again.

---

# 7. Run a backup now

After choosing the cloud backup folder, it is sensible to run a backup straight away.

In the OrchidApp Launcher, select **Back up now**.

Wait until the launcher reports that the backup completed.

Then check the selected cloud folder for the backup ZIP file.

**Suggested screenshot:** Launcher showing backup completed successfully.

---

# Choosing a good cloud backup folder

| Good choice | Avoid |
|---|---|
| `OneDrive\Documents\OrchidBackups` | Downloads |
| `Google Drive\OrchidBackups` | Desktop, unless it is definitely synced |
| `iCloud Drive\OrchidBackups` | Temporary folders |
| A clearly named cloud-synced backup folder | External drives that are often unplugged |

---

# How to check the backup is protected

- Open the cloud folder in File Explorer and check that `OrchidAppDataBackup.zip` or an OrchidApp backup ZIP is present.
- Check the cloud sync status icon. It should show that the file is synced or available in the cloud.
- Open your cloud provider on another device or in a web browser and confirm that the backup file is visible there.
- Do not manually edit the backup ZIP file.

---

# What is stored in the backup

An OrchidApp backup is intended to protect the OrchidApp data needed for recovery.

This includes:

- the plant database
- setup data such as plant groups, species / hybrids, locations and growth media
- plant history
- uploaded photos and files included in the backup
- relevant launcher settings

---

# What the cloud backup is for

The cloud backup is for disaster recovery.

Use it if:

- the computer fails
- the computer is replaced
- Windows is reinstalled
- the local OrchidApp data is lost

For recovery steps, use:

**05 - Recover OrchidApp on Replacement Machine**

---

# Troubleshooting

| Problem | What to do |
|---|---|
| I cannot see the OrchidApp Launcher | Select the OrchidApp icon on the taskbar or close the browser tab to reveal the launcher. |
| The log says the cloud backup folder is not configured | Select **Configure cloud backup** again and choose a cloud-synced folder. |
| The backup file is in the folder but not in the cloud | Wait for your cloud provider to sync. Check that you are signed in and that syncing is not paused. |
| I moved or renamed the cloud folder | Open the OrchidApp Launcher and configure the cloud backup folder again. |
| The cloud copy fails but local backup succeeds | Your local backup still exists. Fix the cloud folder or sync problem, then run **Back up now** again. |
| I cannot find the cloud backup on another computer | Check that you are signed in to the same cloud account and that the folder has fully synced. |
| I need support | Email `OrchidApp@proton.me`. Include what you were doing, what happened, and any launcher message. |

---

# Cloud backup checklist

- The OrchidApp Launcher shows the cloud backup folder has been configured.
- A backup has completed successfully.
- The backup ZIP exists in the selected cloud folder.
- The cloud provider shows the file as synced.
- You know where to find the cloud backup if the computer fails.

---

# Getting support

If cloud backup does not behave as expected, email:

**OrchidApp@proton.me**

When asking for help, include:

- what you were trying to do
- which cloud provider you are using
- whether the local backup completed successfully
- whether the backup file appears in the cloud folder
- any message shown by the OrchidApp Launcher

The launcher support log is stored at:

`C:\ProgramData\OrchidApp\logs\launcher.log`

---

# Keep this simple

The best backup is one that runs automatically and is easy to find later.

Use one obvious cloud-synced folder and let OrchidApp keep the latest cloud copy there.
