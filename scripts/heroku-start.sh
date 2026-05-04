#!/bin/bash
set -e

echo "=== OmniRoute Heroku Startup with Litestream ==="

# Set DATA_DIR to a writable location on Heroku
export DATA_DIR="/app/.omniroute"
mkdir -p "$DATA_DIR"

DB_PATH="$DATA_DIR/storage.sqlite"
LITESTREAM_BIN="/app/bin/litestream"

# Check if Litestream binary exists
if [ ! -f "$LITESTREAM_BIN" ]; then
  echo "WARNING: Litestream binary not found at $LITESTREAM_BIN"
  echo "Checking if heroku-postbuild ran successfully..."
  ls -la /app/bin/ || echo "bin directory not found"
  echo ""
  echo "Running without backups. Database will be lost on dyno restart!"
  exec npm run start
fi

# Check if Litestream is configured
if [ -z "$LITESTREAM_B2_BUCKET" ]; then
  echo "WARNING: LITESTREAM_B2_BUCKET not set. Running without backups."
  echo "Database will be lost on dyno restart!"
  exec npm run start
fi

echo "Litestream configuration detected."
echo "Bucket: $LITESTREAM_B2_BUCKET"
echo "Endpoint: $LITESTREAM_B2_ENDPOINT"

# Try to restore database from Backblaze B2 with multiple attempts
MAX_RESTORE_ATTEMPTS=5
RESTORE_ATTEMPT=1
RESTORE_SUCCESS=false

while [ $RESTORE_ATTEMPT -le $MAX_RESTORE_ATTEMPTS ]; do
  echo "Restore attempt $RESTORE_ATTEMPT of $MAX_RESTORE_ATTEMPTS..."

  # Remove any partial/corrupted database files
  rm -f "$DB_PATH" "$DB_PATH-shm" "$DB_PATH-wal" "$DB_PATH.tmp"

  if $LITESTREAM_BIN restore -if-replica-exists -config litestream.yml "$DB_PATH"; then
    echo "✓ Database restored from Backblaze B2 on attempt $RESTORE_ATTEMPT"
    RESTORE_SUCCESS=true
    break
  else
    echo "✗ Restore attempt $RESTORE_ATTEMPT failed"

    if [ $RESTORE_ATTEMPT -lt $MAX_RESTORE_ATTEMPTS ]; then
      WAIT_TIME=$((RESTORE_ATTEMPT * 5))
      echo "Waiting ${WAIT_TIME}s before retry..."
      sleep $WAIT_TIME
    fi
  fi

  RESTORE_ATTEMPT=$((RESTORE_ATTEMPT + 1))
done

if [ "$RESTORE_SUCCESS" = false ]; then
  echo "WARNING: All restore attempts failed. Starting with fresh database."
  echo "Database will be lost on dyno restart!"
fi

# Start Litestream replication in background and run the app
echo "Starting Litestream replication and Next.js server..."
exec $LITESTREAM_BIN replicate -config litestream.yml -exec "npm run start"
