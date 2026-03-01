#!/bin/bash
set -e

DB_NAME="orchids"
DB_USER="orchid_migrator"

# Resolve project root dynamically
BASE_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
MIGRATIONS_DIR="$BASE_DIR/database/migrations"

echo "Project root: $BASE_DIR"
echo "Migrations dir: $MIGRATIONS_DIR"
echo ""

echo "Checking applied migrations..."

APPLIED=$(mysql -u $DB_USER -N -e "USE $DB_NAME; SELECT scriptName FROM schemaversion;")

for file in $(ls "$MIGRATIONS_DIR"/*.sql | sort); do

    filename=$(basename "$file")

    if echo "$APPLIED" | grep -qx "$filename"; then
        echo "Skipping $filename (already applied)"
    else
        echo "Applying $filename..."

        mysql -u $DB_USER $DB_NAME < "$file"

        checksum=$(sha256sum "$file" | awk '{print $1}')

        mysql -u $DB_USER $DB_NAME -e "
            INSERT INTO schemaversion (scriptName, checksum, appliedAt)
            VALUES ('$filename', '$checksum', NOW());
        "

        echo "Applied $filename successfully."
    fi

done

echo ""
echo "All migrations complete."