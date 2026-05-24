# OrchidApp

# Recover OrchidApp on a Replacement Windows Computer

Step-by-step restore guide for a new, repaired or reinstalled Windows computer

**Applies to:** Windows 11 and a previous OrchidApp backup saved to a cloud-synced folder such as OneDrive, Google Drive or iCloud Drive.

---

# Purpose

Use this guide when the old computer has failed, been replaced or been reinstalled, and you need to restore OrchidApp on a Windows computer.

The safest recovery route is:

1. install OrchidApp using the Windows installer
2. sign in to the cloud provider that holds the backup
3. wait for the backup file to sync to the computer
4. restore the latest OrchidApp backup ZIP using the OrchidApp Launcher

---

# Start here

Follow the **01 - Install or Upgrade OrchidApp on Windows** guide first.

Install OrchidApp using the Windows installer before starting the restore steps in this guide.

Do not install OrchidApp by extracting a ZIP file or copying files over an older OrchidApp folder.

---

# Before you start

- Install OrchidApp on the new or repaired computer using the normal Windows installer.
- Open OrchidApp once so the OrchidApp Launcher starts.
- Sign in to the cloud service that contains the OrchidApp backup folder.
- Wait until the backup file has synced to the new computer.
- Use the OrchidApp backup ZIP.
- Close the OrchidApp browser tab before restoring.
- Leave the OrchidApp Launcher window open.

> **Important:**  
> Restoring a backup replaces the current OrchidApp database and uploaded files on this computer. Continue only when you are sure you have selected the correct backup file.

---

# Which backup file should I use?

Use the latest trusted OrchidApp backup ZIP.

The cloud copy is usually named:

`OrchidAppDataBackup.zip`

A dated local backup may have a name similar to:

`OrchidAppBackup_YYYYMMDD_HHMMSS.zip`

Only restore from a backup you trust.

Do not manually edit, unpack or rename the backup ZIP before restoring.

---

# Quick checklist

1. Install OrchidApp on the new computer using the Windows installer.
2. Open OrchidApp once so the launcher starts.
3. Close the browser tab, but keep the launcher open.
4. Sign in to the cloud provider that contains your backup.
5. Wait for the backup ZIP to sync to the computer.
6. Optional but recommended: configure the cloud backup folder again.
7. Choose **Restore from backup** in the OrchidApp Launcher.
8. Select the OrchidApp backup ZIP from the cloud backup folder.
9. Confirm the restore warning.
10. Wait for **Restore completed successfully**.
11. Close and reopen OrchidApp.
12. Check that your plants, photos and setup information are present.

---

# Step-by-step recovery

# 1. Install OrchidApp on the new computer

Begin with the **01 - Install or Upgrade OrchidApp on Windows** guide.

Use the Windows installer to install OrchidApp.

The installer places the application files under:

`C:\Program Files\OrchidApp`

Your OrchidApp data is stored separately under:

`C:\ProgramData\OrchidApp`

**Suggested screenshot:** OrchidApp Windows installer in File Explorer.

**Suggested screenshot:** OrchidApp Setup Wizard.

---

# 2. Start OrchidApp once

After installation, start OrchidApp from the Start Menu or Desktop shortcut.

The OrchidApp Launcher opens first.

OrchidApp may also open in your browser.

This first start makes sure the launcher is running and ready to perform the restore.

**Suggested screenshot:** OrchidApp Launcher running.

---

# 3. Close the browser tab before restoring

Close the OrchidApp browser tab before restoring.

This helps make sure the database and uploaded files can be safely replaced.

Do not close the OrchidApp Launcher window.

**Suggested screenshot:** Close the OrchidApp browser tab. Leave the launcher window open.

---

# 4. Bring the OrchidApp Launcher to the front

Select the OrchidApp icon on the taskbar to bring the launcher window to the front.

The restore is started from the launcher, not from the browser page.

**Suggested screenshot:** Bring the OrchidApp Launcher to the front.

---

# 5. Optional: configure the cloud backup folder on the new computer

If this is a new computer, it is sensible to configure the cloud backup folder again after the cloud provider has synced the backup folder locally.

This does not perform the restore by itself.

It prepares OrchidApp to keep saving future safety copies after recovery.

Use the guide:

**04 - Configure Cloud Backup Folder in OrchidApp**

**Suggested screenshot:** Select the folder that is synced by OneDrive, Google Drive, iCloud Drive or another cloud provider.

---

# 6. Start the restore

In the OrchidApp Launcher, choose **Restore from backup**.

This starts the recovery process.

**Suggested screenshot:** Choose Restore from backup in the OrchidApp Launcher.

---

# 7. Select the backup ZIP file

Browse to the cloud backup folder and choose the OrchidApp backup ZIP.

The file may be named:

`OrchidAppDataBackup.zip`

or it may have a dated backup name if you copied it from a local backups folder.

Choose **Open** after selecting the backup file.

**Suggested screenshot:** Select OrchidAppDataBackup.zip from the cloud backup folder, then choose Open.

---

# 8. Confirm the restore warning

OrchidApp warns that restoring a backup will replace the current OrchidApp database and uploaded files.

Choose **Yes** only when you are sure you have selected the correct backup file.

**Suggested screenshot:** Restore warning confirmation.

---

# 9. Wait for the restore to complete

Wait until OrchidApp reports that the restore completed successfully.

Do not close the launcher while the restore is running.

When the restore is complete, choose **OK**.

**Suggested screenshot:** Restore completed successfully message.

---

# 10. Close and reopen OrchidApp

Close OrchidApp fully.

Then open OrchidApp again from the Start Menu or Desktop shortcut.

This makes sure OrchidApp starts using the restored data.

---

# 11. Check your data

When OrchidApp opens, check that your information is present.

Check:

- plant records
- Plant Tags
- plant photos
- plant groups / genera
- species / hybrids
- growing locations
- growth media
- observations
- movements
- flowering records
- repotting records
- splitting, propagation and heritage

If anything looks wrong, do not add new data immediately.

Close OrchidApp and restore again from the correct backup file.

---

# What the restore brings back

| Restored item | What this means |
|---|---|
| Plant records | Plant names, Plant Tags, acquisition details and active or ended plant status. |
| Setup data | Plant groups, species / hybrids, locations and growth media. |
| Plant history | Observations, movements, flowering, repotting, splitting, propagation and heritage. |
| Uploaded files | Plant photos and other uploaded files, if they were present in the backup. |
| Settings included in the backup | Relevant launcher and backup settings included in the backup file. |

---

# Important safety notes

- Restoring replaces the OrchidApp data currently on the computer.
- Only restore from a backup you trust.
- Keep the OrchidApp backup ZIP in a folder that is synced by your cloud provider.
- After recovery, configure cloud backup again so future backups are copied to the cloud folder.
- Do not edit or unpack the backup ZIP manually.
- Do not copy database folders manually.
- Do not copy files into `C:\Program Files\OrchidApp` manually.

---

# After recovery

After recovery is complete:

- keep using the Start Menu or Desktop shortcut to open OrchidApp
- keep the OrchidApp Launcher window open while using OrchidApp
- check that cloud backup is configured
- run **Back up now** after confirming the restored data is correct
- check that the cloud provider syncs the new backup copy

---

# Troubleshooting

| Problem | What to do |
|---|---|
| I cannot find the backup file | Check that you are signed in to the correct cloud account and that the cloud folder has finished syncing. |
| The Restore from backup button is unavailable | Close the OrchidApp browser tab and wait for the launcher to return to the normal running state. |
| The restore completed but photos are missing | Check that the backup selected was the complete OrchidApp backup ZIP and not a partial or manually edited file. |
| I selected the wrong backup | Restore again using the correct backup file. Do this before adding new information. |
| The app does not open after restore | Close OrchidApp fully, reopen it from the shortcut and check the launcher messages. If needed, restore again from the latest trusted backup. |
| My plants are not visible after restore | Do not add new data. Close OrchidApp and restore again using the latest trusted backup. |
| The backup file is in the cloud but not on this computer | Wait for the cloud provider to finish syncing, or download the backup file from the cloud provider’s website. |
| I need support | Email `OrchidApp@proton.me`. Include what you were doing, what happened, and any launcher message. |

---

# Getting support

If recovery does not behave as expected, email:

**OrchidApp@proton.me**

When asking for help, include:

- what you were trying to do
- whether this is a new computer, repaired computer or Windows reinstall
- which cloud provider you are using
- the name of the backup ZIP file you selected
- what happened during the restore
- any message shown by the OrchidApp Launcher

The launcher support log is stored at:

`C:\ProgramData\OrchidApp\logs\launcher.log`

---

# Recovery complete

Recovery is complete when OrchidApp opens and your plant records are visible.

Keep the cloud backup folder configured so the next backup is copied to the cloud automatically.
