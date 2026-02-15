# OrchidApp -- MariaDB & Uploads Backup & Restore Runbook

**System:** Raspberry Pi (PiForPiHole)\
**Database:** MariaDB -- `orchids`\
**Uploads Path:** `/opt/orchidapp/publish/wwwroot/uploads/plants`\
**Cloud Target:** Personal OneDrive\
**Encryption:** rclone `crypt` remotes\
**Created:** 15 Feb 2026\
**Status:** Production Ready

------------------------------------------------------------------------

# 1. Purpose

This document defines the complete setup and restore procedure for
backing up:

-   MariaDB database (`orchids`)
-   Application uploads folder

Backups are:

-   Compressed (database only)
-   Encrypted locally via rclone
-   Uploaded to OneDrive
-   Automatically retained (database snapshots)
-   Mirrored (uploads folder)

If the encryption passphrase is lost, backups are permanently
unrecoverable.

------------------------------------------------------------------------

# 2. Architecture Overview

## Database (Snapshot Model)

MariaDB → mysqldump → gzip → rclone crypt → OneDrive/db (encrypted
snapshots)

Retention: 14 days

## Uploads (Mirror Model)

Uploads folder → rclone sync → rclone crypt → OneDrive/uploads
(encrypted mirror)

Retention: Mirror only (no snapshots)

------------------------------------------------------------------------

# 3. OneDrive Folder Structure

    OrchidBackups/
        db/        ← encrypted DB snapshots
        uploads/   ← encrypted uploads mirror
        docs/      ← documentation (not encrypted)

------------------------------------------------------------------------

# 4. rclone Remotes

Configured remotes:

    onedrive:
    orchidcrypt:           → onedrive:OrchidBackups/db
    orchiduploadscrypt:    → onedrive:OrchidBackups/uploads

------------------------------------------------------------------------

# 5. Secure MariaDB Credentials

Create:

    nano ~/.my.cnf

Add:

    [client]
    user=root
    password=YOUR_DATABASE_PASSWORD

Secure it:

    chmod 600 ~/.my.cnf

------------------------------------------------------------------------

# 6. Production Backup Script

Location in repo:

    /infrastructure/backups/backup_orchids.sh

Deployment location:

    /usr/local/bin/backup_orchids.sh

The script performs:

1.  Dump database
2.  Compress
3.  Upload encrypted snapshot
4.  Apply 14-day retention
5.  Sync uploads folder (encrypted mirror)
6.  Log execution
7.  Exit with proper error codes

------------------------------------------------------------------------

# 7. Cron Configuration

User-level cron entry:

    0 2 * * * /usr/local/bin/backup_orchids.sh >> /home/raymond-23/orchid_backup_cron.log 2>&1

Verify:

    crontab -l

------------------------------------------------------------------------

# 8. Log Rotation

Create file:

    sudo nano /etc/logrotate.d/orchid_backup

Contents:

    /home/raymond-23/orchid_backup.log
    /home/raymond-23/orchid_backup_cron.log
    {
        monthly
        rotate 6
        compress
        missingok
        notifempty
        create 644 raymond-23 raymond-23
    }

Test configuration:

    sudo logrotate -d /etc/logrotate.d/orchid_backup

------------------------------------------------------------------------

# 9. Restore Procedure (Safe Test Method)

## Restore Database to Test DB

Create test database:

    mysql -e "CREATE DATABASE orchids_restore_test;"

Download backup:

    rclone copy orchidcrypt: ~/restore_test

Decompress:

    gunzip ~/restore_test/*.sql.gz

Restore:

    mysql orchids_restore_test < ~/restore_test/*.sql

Validate:

    mysql orchids_restore_test -e "SHOW TABLES;"

Cleanup:

    mysql -e "DROP DATABASE orchids_restore_test;"
    rm -rf ~/restore_test

------------------------------------------------------------------------

# 10. Disaster Recovery (New Pi)

1.  Install MariaDB
2.  Create empty database:

```{=html}
<!-- -->
```
    mysql -e "CREATE DATABASE orchids;"

3.  Install rclone (matching version)
4.  Recreate remotes
5.  Retrieve latest DB snapshot:

```{=html}
<!-- -->
```
    rclone copy orchidcrypt: .

6.  Decompress:

```{=html}
<!-- -->
```
    gunzip backup.sql.gz

7.  Restore:

```{=html}
<!-- -->
```
    mysql orchids < backup.sql

8.  Restore uploads mirror:

```{=html}
<!-- -->
```
    rclone sync orchiduploadscrypt: /opt/orchidapp/publish/wwwroot/uploads/plants

------------------------------------------------------------------------

# 11. Security Notes

-   Encryption passphrase must be stored in password manager
-   If lost, backups cannot be decrypted
-   rclone versions must match during OAuth authorisation
-   Uploads and DB are encrypted at rest in OneDrive

------------------------------------------------------------------------

# 12. Operational Validation

Quarterly:

-   Perform restore test
-   Validate schema and row counts
-   Confirm uploads files restore correctly

Backups are only real if restores work.

------------------------------------------------------------------------

# 13. System Status

✓ Encrypted database snapshots\
✓ Encrypted uploads mirror\
✓ Automated nightly execution\
✓ Retention policy enforced\
✓ Restore tested successfully\
✓ Logs rotated monthly\
✓ Script version-controlled in repo

Backup system complete.
