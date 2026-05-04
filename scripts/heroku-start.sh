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

# Restore database from Backblaze B2 if it exists
if $LITESTREAM_BIN restore -if-replica-exists -config litestream.yml "$DB_PATH"; then
  echo "✓ Database restored from Backblaze B2"
else
  echo "No existing backup found. Starting with fresh database."
fi

# Start Litestream replication in background and run the app
echo "Starting Litestream replication and Next.js server..."
exec $LITESTREAM_BIN replicate -config litestream.yml -exec "npm run start"
