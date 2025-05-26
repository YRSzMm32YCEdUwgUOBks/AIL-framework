#!/usr/bin/env bash
set -euo pipefail

# Allow overriding the HTTP host binding
: "${FLASK_HOST:=0.0.0.0}"
: "${FLASK_PORT:=7000}"

# Set AIL environment variables
export AIL_HOME=/opt/ail
export AIL_BIN=/opt/ail/bin
export AIL_FLASK=/opt/ail/var/www
export PYTHONPATH=/opt/ail/bin:/opt/ail

# Ensure configuration file exists (use Docker-specific config)
echo "Using Docker-specific configuration..."
cp /opt/ail/configs/docker/core.cfg /opt/ail/configs/core.cfg

# Create symbolic link for config in root directory if it doesn't exist
if [ ! -f /opt/ail/core.cfg ]; then
    ln -sf /opt/ail/configs/core.cfg /opt/ail/core.cfg
fi

# Point AIL config at our core.cfg
export AIL_CONFIG="/opt/ail/core.cfg"

echo "Starting AIL Framework..."
echo "Flask Host: ${FLASK_HOST}"
echo "Flask Port: ${FLASK_PORT}"

# Change to AIL directory
cd /opt/ail

# Create virtual environment directory if it doesn't exist
mkdir -p AILENV/bin
ln -sf /usr/local/bin/python3 AILENV/bin/python || true

# Make sure LAUNCH.sh is executable (in case it lost permissions)
chmod +x /opt/ail/bin/LAUNCH.sh

# Initialize database if needed
echo "Initializing AIL databases..."
python3 ${AIL_BIN}/AIL_Init.py

# Wait for Redis and Kvrocks to be ready
echo "Waiting for Redis and Kvrocks services..."
sleep 10

# Start the Flask web interface directly
echo "Starting AIL Flask web interface..."
cd ${AIL_FLASK}
exec python3 Flask_server.py
