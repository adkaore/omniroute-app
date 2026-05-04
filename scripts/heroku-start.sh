#!/bin/bash
set -e

echo "=== OmniRoute Heroku Startup with Litestream ==="

# Set DATA_DIR to a writable location on Heroku
export DATA_DIR="/app/.omniroute"
mkdir -p "$DATA_DIR"

DB_PATH="$DATA_DIR/storage.sqlite"

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
if litestream restore -if-replica-exists -config litestream.yml "$DB_PATH"; then
  echo "✓ Database restored from Backblaze B2"
else
  echo "No existing backup found. Starting with fresh database."
fi

# Start Litestream replication in background and run the app
echo "Starting Litestream replication and Next.js server..."
exec litestream replicate -config litestream.yml -exec "npm run start"
