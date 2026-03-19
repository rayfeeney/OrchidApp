#!/usr/bin/env bash
set -euo pipefail

# -------------------------------------------------------
# Resolve repository root (script must work from anywhere)
# -------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

# -------------------------------------------------------
# Validate required environment variables
# -------------------------------------------------------
require_env() {
  var="$1"
  if [ -z "${!var:-}" ]; then
    echo "Missing required environment variable: $var"
    exit 1
  fi
}

require_env MARIADB_HOST
require_env MARIADB_PORT
require_env MARIADB_USER
require_env MARIADB_PASSWORD
require_env MARIADB_DATABASE

echo "Applying OrchidApp baseline schema"
echo "Target: $MARIADB_HOST:$MARIADB_PORT / $MARIADB_DATABASE"

echo "Schema application order:"
echo "  1. tables"
echo "  2. views"
echo "  3. routines"
echo "  4. triggers"
echo "  5. constraints"
echo "  6. seeds (optional)"

# -------------------------------------------------------
# Apply required schema directories
# -------------------------------------------------------
apply_required_dir () {
  dir="$1"

  if [ ! -d "$dir" ]; then
    echo "Expected schema directory missing: $dir"
    exit 1
  fi

  files=$(find "$dir" -type f -name "*.sql" | sort)

  if [ -z "$files" ]; then
    echo "Required schema directory has no SQL files: $dir"
    exit 1
  fi

  echo "Applying schema directory: $dir"

  while IFS= read -r f; do
    echo "  → $f"
    mariadb \
      --default-character-set=utf8mb4 \
      -h "$MARIADB_HOST" \
      -P "$MARIADB_PORT" \
      -u "$MARIADB_USER" \
      -p"$MARIADB_PASSWORD" \
      "$MARIADB_DATABASE" < "$f"
  done <<< "$files"
}

# -------------------------------------------------------
# Apply optional schema directories (e.g. seeds)
# -------------------------------------------------------
apply_optional_dir () {
  dir="$1"

  if [ ! -d "$dir" ]; then
    echo "Optional schema directory missing (skipped): $dir"
    return
  fi

  files=$(find "$dir" -type f -name "*.sql" | sort)

  if [ -z "$files" ]; then
    echo "Optional schema directory empty (skipped): $dir"
    return
  fi

  echo "Applying optional schema directory: $dir"

  while IFS= read -r f; do
    echo "  → $f"
    mariadb \
      --default-character-set=utf8mb4 \
      -h "$MARIADB_HOST" \
      -P "$MARIADB_PORT" \
      -u "$MARIADB_USER" \
      -p"$MARIADB_PASSWORD" \
      "$MARIADB_DATABASE" < "$f"
  done <<< "$files"
}

# -------------------------------------------------------
# Apply schema in deterministic dependency order
# -------------------------------------------------------
apply_required_dir database/schema/tables
apply_required_dir database/schema/views
apply_required_dir database/schema/routines
apply_required_dir database/schema/triggers
apply_required_dir database/schema/constraints
apply_optional_dir database/schema/seeds

echo "Baseline schema applied successfully"