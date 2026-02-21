#!/usr/bin/env bash

# ============================================================
# OrchidApp MariaDB Backup Script
# Encrypted upload to OneDrive via rclone (orchidcrypt)
# ============================================================

set -Eeuo pipefail

# ---------- CONFIGURATION ----------
DB_NAME="orchids"
BACKUP_DIR="/home/raymond-23/orchid_backups"
LOG_FILE="/var/log/orchid_backup.log"
REMOTE="orchidcrypt:"
RETENTION_DAYS=14

TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
BASENAME="${DB_NAME}_${TIMESTAMP}"
SQL_FILE="${BACKUP_DIR}/${BASENAME}.sql"
ARCHIVE_FILE="${SQL_FILE}.gz"

# ---------- LOGGING ----------
log() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") | $1" | tee -a "$LOG_FILE"
}

# ---------- ERROR HANDLER ----------
error_handler() {
    log "ERROR: Backup failed at line ${BASH_LINENO[0]}"
    exit 1
}
trap error_handler ERR

# ---------- START ----------
log "Starting OrchidApp backup"

# Ensure backup directory exists
mkdir -p "$BACKUP_DIR"

# ---------- DUMP DATABASE ----------
log "Dumping database"
mysqldump --single-transaction --routines --triggers "$DB_NAME" > "$SQL_FILE"

if [[ ! -s "$SQL_FILE" ]]; then
    log "ERROR: SQL dump file is empty"
    exit 1
fi

log "Database dump complete"

# ---------- COMPRESS ----------
log "Compressing backup"
gzip "$SQL_FILE"

if [[ ! -s "$ARCHIVE_FILE" ]]; then
    log "ERROR: Compression failed"
    exit 1
fi

log "Compression complete"

# ---------- UPLOAD ----------
log "Uploading encrypted backup to OneDrive"
rclone copy "$ARCHIVE_FILE" "$REMOTE"

log "Upload complete"

# ---------- RETENTION ----------
log "Applying retention policy (${RETENTION_DAYS} days)"
rclone delete "$REMOTE" --min-age "${RETENTION_DAYS}d" --include "*.sql.gz"

log "Retention cleanup complete"

# ---------- SYNC UPLOADS ----------
UPLOADS_PATH="/opt/orchidapp/uploads"

log "Syncing uploads folder"
rclone sync "$UPLOADS_PATH" orchiduploadscrypt:

log "Uploads sync complete"

# ---------- CLEAN LOCAL ----------
log "Removing local archive"
rm -f "$ARCHIVE_FILE"

log "Backup completed successfully"
exit 0
