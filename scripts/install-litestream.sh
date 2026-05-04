#!/bin/bash
set -e

echo "=== Installing Litestream ==="
echo "Current directory: $(pwd)"
echo "Build directory contents:"
ls -la

# Litestream version
LITESTREAM_VERSION="v0.3.13"

# Detect architecture
ARCH=$(uname -m)
case $ARCH in
  x86_64)
    LITESTREAM_ARCH="amd64"
    ;;
  aarch64|arm64)
    LITESTREAM_ARCH="arm64"
    ;;
  *)
    echo "Unsupported architecture: $ARCH"
    exit 1
    ;;
esac

# Download URL
LITESTREAM_URL="https://github.com/benbjohnson/litestream/releases/download/${LITESTREAM_VERSION}/litestream-${LITESTREAM_VERSION}-linux-${LITESTREAM_ARCH}.tar.gz"

echo "Downloading Litestream ${LITESTREAM_VERSION} for ${LITESTREAM_ARCH}..."
echo "URL: ${LITESTREAM_URL}"

# Create bin directory if it doesn't exist
mkdir -p bin
echo "Created bin directory at: $(pwd)/bin"

# Download and extract
curl -L "${LITESTREAM_URL}" | tar -xz -C bin

# Make executable
chmod +x bin/litestream

# Verify installation
if [ -f "bin/litestream" ]; then
  echo "✓ Litestream installed successfully at $(pwd)/bin/litestream"
  ./bin/litestream version
  echo ""
  echo "Final bin directory contents:"
  ls -la bin/
else
  echo "✗ Litestream installation failed"
  echo "bin directory contents:"
  ls -la bin/ || echo "bin directory not found"
  exit 1
fi
