# OrchidApp - Backup & Restore Runbook

**System:** Raspberry Pi
**Database:** MariaDB (`orchids`)
**Uploads Path:** `/opt/orchidapp/uploads`
**Cloud Target:** OneDrive (encrypted via rclone)
**Status:** Production Ready

---

# 1. Purpose

This document defines the **authoritative operational procedure** for:

* Backing up the MariaDB database
* Backing up the uploads directory
* Restoring the system in both test and disaster scenarios

Backups are only valid if **restore succeeds**.

---

# 2. Operational Responsibility

Backup execution, monitoring and validation are the responsibility of the **deployment operator**.

The system provides tooling.
It does not guarantee that backups are running or valid.

A deployment without verified backups is considered **unsafe and incomplete**.

---

# 3. Backup Architecture

## Database (Snapshot Model)

```
MariaDB → mysqldump → gzip → rclone crypt → OneDrive/db
```

* Encrypted snapshots
* 14-day retention
* Point-in-time recovery

---

## Uploads (Mirror Model)

```
/opt/orchidapp/uploads → rclone sync → rclone crypt → OneDrive/uploads
```

* Encrypted mirror
* No historical snapshots
* Represents current filesystem state

---

## OneDrive Structure

```
OrchidBackups/
    db/        ← encrypted database snapshots
    uploads/   ← encrypted uploads mirror
    docs/      ← optional documentation
```

---

# 4. rclone Configuration

Configured remotes:

```
onedrive:
orchidcrypt:           → onedrive:OrchidBackups/db
orchiduploadscrypt:    → onedrive:OrchidBackups/uploads
```

### Critical Requirements

* rclone configuration must be preserved
* Remote names must remain consistent
* Encryption keys must be retained securely

If encryption configuration is lost, backups are unrecoverable.

---

# 5. MariaDB Credentials

Create:

```bash id="1g6u2d"
nano ~/.my.cnf
```

Add:

```ini id="m0r1h2"
[client]
user=root
password=YOUR_DATABASE_PASSWORD
```

Secure:

```bash id="2m8kfd"
chmod 600 ~/.my.cnf
```

Credentials must not be exposed or committed.

---

# 6. Backup Script

Canonical script location (repository):

```
/infrastructure/backups/backup_orchids.sh
```

Deployment location:

```
/usr/local/bin/backup_orchids.sh
```

### Script Responsibilities

The script must:

1. Dump database (`mysqldump`)
2. Compress output
3. Upload encrypted snapshot
4. Enforce retention policy
5. Sync uploads directory (encrypted mirror)
6. Log execution
7. Exit with correct error codes

Failure at any stage must produce a non-zero exit code.

---

# 7. Scheduling (Cron)

Example user-level cron:

```bash id="r9qk2h"
0 2 * * * /usr/local/bin/backup_orchids.sh >> /home/<user>/orchid_backup_cron.log 2>&1
```

Verify:

```bash id="v4o8j1"
crontab -l
```

### Requirements

* Backups must run daily
* Failures must be visible in logs
* Logs must be reviewed periodically

---

# 8. Log Rotation

Create:

```bash id="2y4gfp"
sudo nano /etc/logrotate.d/orchid_backup
```

Contents:

```text id="5c9d1r"
/home/<user>/orchid_backup.log
/home/<user>/orchid_backup_cron.log
{
    monthly
    rotate 6
    compress
    missingok
    notifempty
    create 644 <user> <user>
}
```

Test:

```bash id="7t1z6m"
sudo logrotate -d /etc/logrotate.d/orchid_backup
```

---

# 9. Restore Procedure (Validation Test)

Regular restore testing is mandatory.

## Step 1 - Create Test Database

```bash id="x2n7kf"
mysql -e "CREATE DATABASE orchids_restore_test;"
```

---

## Step 2 - Retrieve Backup

```bash id="m6o9zt"
rclone copy orchidcrypt: ~/restore_test
```

---

## Step 3 - Decompress

```bash id="p1w8de"
gunzip ~/restore_test/*.sql.gz
```

---

## Step 4 - Restore

```bash id="q4c7jh"
mysql orchids_restore_test < ~/restore_test/*.sql
```

---

## Step 5 - Validate

```bash id="n8l2vb"
mysql orchids_restore_test -e "SHOW TABLES;"
```

Validation must confirm:

* Schema is complete
* Tables exist
* No restore errors occurred

---

## Step 6 - Cleanup

```bash id="d3h6kf"
mysql -e "DROP DATABASE orchids_restore_test;"
rm -rf ~/restore_test
```

---

# 10. Disaster Recovery (New System)

## Step 1 - Install Base System

* Install MariaDB
* Install rclone
* Recreate rclone remotes
* Ensure matching rclone version

---

## Step 2 - Create Empty Database

```bash id="k9o3lp"
mysql -e "CREATE DATABASE orchids;"
```

---

## Step 3 - Retrieve Backup

```bash id="x8n4zc"
rclone copy orchidcrypt: .
```

---

## Step 4 - Decompress

```bash id="c2m7rf"
gunzip backup.sql.gz
```

---

## Step 5 - Restore Database

```bash id="h5t1qw"
mysql orchids < backup.sql
```

---

## Step 6 - Restore Uploads

```bash id="z7k3ns"
rclone sync orchiduploadscrypt: /opt/orchidapp/uploads
```

---

## Step 7 - Re-deploy Application

Follow:

```
docs/installation-upgrade.md
```

---

# 11. Failure Modes

## Encryption Key Loss

* Backups cannot be decrypted
* Data is permanently lost

## rclone Misconfiguration

* Backups may silently fail or upload incorrectly
* Must be validated during restore testing

## Credential Issues

* Database dump may fail
* Script must exit with error

## Partial Backups

* Must be treated as invalid
* Restore validation will expose failure

---

# 12. Operational Validation

The following must be performed regularly:

* Restore test (at least quarterly)
* Validate schema and row counts
* Confirm uploads restore correctly

Backups are only real if restore succeeds.

---

# 13. System Status Requirements

A valid backup system must satisfy:

* Encrypted database snapshots
* Encrypted uploads mirror
* Automated scheduled execution
* Retention policy enforced
* Restore tested successfully
* Logs available and rotated

If any of these conditions are not met, the backup system is not valid.
