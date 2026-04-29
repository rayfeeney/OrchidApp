#!/bin/bash
set -e

DB_NAME="orchids"

# Connection settings (defaults for local use)
DB_HOST=${DB_HOST:-localhost}
DB_PORT=${DB_PORT:-3306}
DB_USER=${DB_USER:-root}
DB_PASS=${DB_PASS:-}

# Resolve project root dynamically
BASE_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
MIGRATIONS_DIR="$BASE_DIR/database/migrations"

echo "Project root: $BASE_DIR"
echo "Migrations dir: $MIGRATIONS_DIR"
echo ""

echo "Using DB connection:"
echo "Host: $DB_HOST"
echo "Port: $DB_PORT"
echo "User: $DB_USER"
echo ""

MYSQL_CMD="mysql -h $DB_HOST -P $DB_PORT -u $DB_USER"
if [ -n "$DB_PASS" ]; then
    MYSQL_CMD="$MYSQL_CMD -p$DB_PASS"
fi

echo "Checking applied migrations..."

APPLIED=$($MYSQL_CMD "$DB_NAME" -N -e "SELECT scriptName FROM schemaversion;")

for file in $(ls "$MIGRATIONS_DIR"/*.sql | sort); do

    filename=$(basename "$file")

    if echo "$APPLIED" | grep -qx "$filename"; then
        echo "Skipping $filename (already applied)"
    else
        echo "Applying $filename..."

        $MYSQL_CMD "$DB_NAME" -e "source $file"

        checksum=$(sha256sum "$file" | awk '{print $1}')

        $MYSQL_CMD "$DB_NAME" -e "
            INSERT INTO schemaversion (scriptName, checksum, appliedAt)
            VALUES ('$filename', '$checksum', NOW());
        "

        echo "Applied $filename successfully."
    fi

done

echo ""
echo "All migrations complete."