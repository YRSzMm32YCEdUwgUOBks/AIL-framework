#!/bin/bash
set -euo pipefail

echo "Starting Lacus..."

# Apply Azure Redis patch before doing anything else
echo "Applying Azure Redis patches..."
/opt/lacus/lacus-azure-redis.patch

# Set environment variables  
export LACUS_HOME=/opt/lacus
export PYTHONPATH=/opt/lacus

# Check for Azure deployment
echo "Detected Azure deployment - configuring Redis connection..."

# Check if Azure Redis environment variables are provided
if [ -n "${REDIS_CACHE_HOST:-}" ] && [ -n "${REDIS_CACHE_PORT:-}" ] && [ -n "${REDIS_CACHE_PASSWORD:-}" ]; then
    echo "✅ Configuring Azure Redis connection..."
    
    # Create Lacus configuration for Azure Redis (JSON format)
    mkdir -p /opt/lacus/config
    cat > /opt/lacus/config/generic.json << EOF
{
    "loglevel": "INFO",
    "website_listen_ip": "0.0.0.0", 
    "website_listen_port": 7100,
    "systemd_service_name": "lacus",
    "concurrent_captures": 2,
    "max_capture_time": 3600,
    "expire_results": 36000,
    "max_retries": 3,
    "only_global_lookups": true,
    "tor_proxy": {
        "server": "socks5://tor_proxy:9050"
    },
    "global_proxy": {
        "enable": false,
        "server": "",
        "username": "",
        "password": ""
    },
    "allow_headed": false,
    "wireproxy_path": "/not/used/in/docker",
    "cache": {
        "host": "${REDIS_CACHE_HOST}",
        "port": ${REDIS_CACHE_PORT},
        "password": "${REDIS_CACHE_PASSWORD}",
        "ssl": true,
        "ssl_cert_reqs": null,
        "db": 0
    }
}
EOF
    echo "✅ Azure Redis configuration created at /opt/lacus/config/generic.json"
    
else
    echo "⚠️  Using default lacus configuration (no Azure Redis env vars)"
    # Copy the default configuration if it exists
    if [ -f "/opt/lacus/configs/lacus/docker.generic.json" ]; then
        mkdir -p /opt/lacus/config
        cp /opt/lacus/configs/lacus/docker.generic.json /opt/lacus/config/generic.json
        echo "✅ Copied default configuration"
    fi
fi

# Start backend (valkey/redis) - only if not using Azure Redis
if [ -z "${REDIS_CACHE_HOST:-}" ]; then
    echo "Start backend (redis)..."
    
    cd /opt/lacus/cache
    if [ -f "/opt/valkey/src/valkey-server" ]; then
        /opt/valkey/src/valkey-server ./cache.conf &
    else
        echo "Valkey server not found, using system redis"
        redis-server ./cache.conf &
    fi
    
    echo "Waiting on cache to start"
    sleep 2
    echo "done."
fi

# Change to lacus directory
cd /opt/lacus

# Test Azure Redis connection before starting services
if [ -n "${REDIS_CACHE_HOST:-}" ]; then
    echo "🔍 Testing Azure Redis connection..."
    poetry run python -c "
import redis
import os
try:
    r = redis.Redis(
        host=os.environ['REDIS_CACHE_HOST'],
        port=int(os.environ['REDIS_CACHE_PORT']),
        password=os.environ['REDIS_CACHE_PASSWORD'],
        ssl=os.environ.get('REDIS_SSL', 'true').lower() == 'true',
        ssl_cert_reqs=None,
        db=1
    )
    r.ping()
    print('✓ Azure Redis connection successful')
except Exception as e:
    print(f'✗ Azure Redis connection failed: {e}')
    exit(1)
"
fi

# Start Capture manager
echo "Start Capture manager..."
poetry run python bin/capture_manager.py &
echo "done."

# Start website
echo "Start website..."
poetry run python bin/start_website.py &
echo "done."

# Check for wireproxy
if [ -f "bin/wireproxy_manager.py" ]; then
    echo "Start wireproxy..."
    poetry run python bin/wireproxy_manager.py &
    echo "done."
else
    echo "Wireproxy executable missing, skipping."
fi

echo "Lacus services started. Monitoring processes..."

# Keep the container running and monitor processes
while true; do
    # Check if critical processes are still running
    if ! pgrep -f "capture_manager.py" > /dev/null; then
        echo "⚠️  Capture manager died, restarting..."
        poetry run python bin/capture_manager.py &
    fi
    
    if ! pgrep -f "start_website.py" > /dev/null; then
        echo "⚠️  Website died, restarting..."
        poetry run python bin/start_website.py &
    fi
    
    sleep 30
done
