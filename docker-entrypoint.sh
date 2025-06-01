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

# Configure AIL based on deployment environment
case "${DEPLOYMENT_ENV:-dev-local}" in    "test-cloud"|"prod-cloud"|"azure")
        echo "${DEPLOYMENT_ENV^} Environment - using environment-specific configuration..."
          # Set the config file path directly to the environment-specific config
        ENV_CONFIG_FILE="/opt/ail/configs/environments/${DEPLOYMENT_ENV}.cfg"
        if [ -f "$ENV_CONFIG_FILE" ]; then
            echo "🔧 Using configuration file: $ENV_CONFIG_FILE"
            export AIL_CONFIG="$ENV_CONFIG_FILE"
            echo "✅ Environment-specific configuration set: $ENV_CONFIG_FILE"            
            # Validate critical environment variables are set for cloud environments
            if [ -n "${REDIS_CACHE_HOST:-}" ] && [ -n "${REDIS_CACHE_PORT:-}" ] && [ -n "${REDIS_CACHE_PASSWORD:-}" ]; then
                echo "✅ Azure Redis Cache configured: ${REDIS_CACHE_HOST}:${REDIS_CACHE_PORT}"
            else
                echo "⚠️  Warning: Missing Azure Redis environment variables for ${DEPLOYMENT_ENV}"
                echo "Required: REDIS_CACHE_HOST, REDIS_CACHE_PORT, REDIS_CACHE_PASSWORD"
            fi
            
            if [ -n "${LACUS_URL:-}" ]; then
                echo "✅ Lacus URL configured: ${LACUS_URL}"
            else
                echo "⚠️  Warning: LACUS_URL environment variable not set"
            fi
        else
            echo "⚠️  Warning: Environment config file not found: $ENV_CONFIG_FILE"
            echo "Available environment configs:"
            ls -la /opt/ail/configs/environments/ 2>/dev/null || echo "  No environment configs directory found"            
            # Fallback to azure.cfg if available (for backward compatibility)
            if [ -f "/opt/ail/configs/azure.cfg" ]; then
                echo "Falling back to legacy Azure config"
                export AIL_CONFIG="/opt/ail/configs/azure.cfg"
            else
                echo "❌ ERROR: No environment configuration available for ${DEPLOYMENT_ENV}!"
                exit 1
            fi
        fi
        ;;
    "dev-local"|*)
        echo "Development Local Environment - using environment-specific configuration..."
          # Set the config file path directly to the environment-specific config
        ENV_CONFIG_FILE="/opt/ail/configs/environments/${DEPLOYMENT_ENV:-dev-local}.cfg"
        if [ -f "$ENV_CONFIG_FILE" ]; then
            echo "🔧 Using configuration file: $ENV_CONFIG_FILE"
            export AIL_CONFIG="$ENV_CONFIG_FILE"
            echo "✅ Environment-specific configuration set: $ENV_CONFIG_FILE"
        else
            echo "⚠️  Warning: Environment config file not found: $ENV_CONFIG_FILE"
            echo "Available environment configs:"
            ls -la /opt/ail/configs/environments/ 2>/dev/null || echo "  No environment configs directory found"
            if [ -f "/opt/ail/configs/docker/core.cfg" ]; then
                echo "Falling back to Docker config"
                export AIL_CONFIG="/opt/ail/configs/docker/core.cfg"
            else
                echo "❌ ERROR: No fallback configuration available!"
                exit 1
            fi
        fi
        ;;
esac

echo "✅ AIL_CONFIG set to: ${AIL_CONFIG}"
echo "Starting AIL Framework..."
echo "Flask Host: ${FLASK_HOST}"
echo "Flask Port: ${FLASK_PORT}"

# Validate essential submodules are initialized
echo "Validating git submodules..."

# Check YARA rules directory
YARA_RULES_DIR="/opt/ail/bin/trackers/yara/ail-yara-rules/rules"
if [ ! -d "$YARA_RULES_DIR" ] || [ -z "$(ls -A "$YARA_RULES_DIR" 2>/dev/null)" ]; then
    echo "❌ ERROR: YARA rules not found!"
    echo ""
    echo "The AIL Framework requires git submodules to be initialized."
    echo "Please run these commands on your HOST machine (not in container):"
    echo ""
    echo "  git submodule init"
    echo "  git submodule update"
    echo "  docker-compose restart ail-app"
    echo ""
    echo "This downloads essential YARA rules and MISP data."
    echo "See README-Docker.md for complete setup instructions."
    exit 1
fi

# Check MISP taxonomies
MISP_TAXONOMIES_DIR="/opt/ail/files/misp-taxonomies"
if [ ! -d "$MISP_TAXONOMIES_DIR" ] || [ -z "$(ls -A "$MISP_TAXONOMIES_DIR" 2>/dev/null)" ]; then
    echo "❌ ERROR: MISP taxonomies not found!"
    echo ""
    echo "Please run: git submodule init && git submodule update"
    echo "Then restart the container: docker-compose restart ail-app"
    exit 1
fi

# Check MISP galaxy
MISP_GALAXY_DIR="/opt/ail/files/misp-galaxy"
if [ ! -d "$MISP_GALAXY_DIR" ] || [ -z "$(ls -A "$MISP_GALAXY_DIR" 2>/dev/null)" ]; then
    echo "❌ ERROR: MISP galaxy not found!"
    echo ""
    echo "Please run: git submodule init && git submodule update"
    echo "Then restart the container: docker-compose restart ail-app"
    exit 1
fi

echo "✅ All required submodules found"

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

# Function to check if Redis is ready
wait_for_redis() {
    case "${DEPLOYMENT_ENV:-dev-local}" in
        "test-cloud"|"prod-cloud")
            if [ -n "${REDIS_CACHE_HOST:-}" ]; then
                echo "Waiting for Azure Redis Cache to be ready..."
                while ! python3 -c "import redis; r=redis.Redis(host='${REDIS_CACHE_HOST}', port=${REDIS_CACHE_PORT}, password='${REDIS_CACHE_PASSWORD}', ssl=True, ssl_cert_reqs=None); r.ping()"; do
                    echo "Azure Redis Cache not ready yet, waiting..."
                    sleep 2
                done
                echo "Azure Redis Cache is ready!"
            else
                echo "⚠️  Warning: ${DEPLOYMENT_ENV} environment but no Redis Cache configuration found"
            fi
            ;;
        *)
            echo "Waiting for local Redis to be ready..."
            while ! python3 -c "import redis; r=redis.Redis(host='redis-cache', port=6379); r.ping()"; do
                echo "Redis not ready yet, waiting..."
                sleep 2
            done
            echo "Redis is ready!"
            ;;
    esac
}

# Function to check if Kvrocks is ready
wait_for_kvrocks() {
    case "${DEPLOYMENT_ENV:-dev-local}" in
        "test-cloud"|"prod-cloud")
            echo "Azure Redis Cache will handle KVRocks functionality - skipping separate check"
            ;;
        *)
            echo "Waiting for Kvrocks to be ready..."
            while ! python3 -c "import redis; r=redis.Redis(host='kvrocks', port=6383); r.ping()"; do
                echo "Kvrocks not ready yet, waiting..."
                sleep 2
            done
            echo "Kvrocks is ready!"
            ;;
    esac
}

# Wait for databases to be ready
wait_for_redis
wait_for_kvrocks

# Initialize Lacus URL in KVRocks database (equivalent to init-lacus-url service in Docker Compose)
echo "Initializing Lacus URL in database..."
if [ -n "${LACUS_URL:-}" ]; then
    echo "Setting Lacus URL to: ${LACUS_URL}"    
    case "${DEPLOYMENT_ENV:-dev-local}" in
        "test-cloud"|"prod-cloud")
            if [ -n "${REDIS_CACHE_HOST:-}" ]; then
                # Using Azure Redis Cache for KVRocks functionality
                python3 -c "
import redis
r = redis.Redis(host='${REDIS_CACHE_HOST}', port=${REDIS_CACHE_PORT}, password='${REDIS_CACHE_PASSWORD}', ssl=True, ssl_cert_reqs=None, decode_responses=True)
r.hset('crawler:lacus', 'url', '${LACUS_URL}')
print('✅ Lacus URL stored in Azure Redis Cache:', '${LACUS_URL}')
"
            else
                echo "⚠️  Warning: ${DEPLOYMENT_ENV} environment but no Redis Cache configuration found"
            fi
            ;;
        *)
            # Using local KVRocks
            python3 -c "
import redis
r = redis.Redis(host='kvrocks', port=6383, decode_responses=True)
r.hset('crawler:lacus', 'url', '${LACUS_URL}')
print('✅ Lacus URL stored in KVRocks:', '${LACUS_URL}')
"
            ;;
    esac
else
    echo "⚠️  LACUS_URL environment variable not set, skipping Lacus URL initialization"
fi

# Create default user for development (only if it doesn't exist)
echo "Creating default user for development..."
if ! python3 -c "import sys; sys.path.append('/opt/ail/bin'); from lib import User; u = User.User(); exit(0 if u.exist_user('ail@ail.test') else 1)" 2>/dev/null; then
    echo "Creating default user: ail@ail.test"
    python3 ${AIL_FLASK}/create_default_user.py
    echo "Default user created successfully!"
else
    echo "Default user already exists, skipping creation."
fi

# Launch the AIL processing modules in the background
echo "Starting AIL processing modules..."
cd ${AIL_BIN}

# Initialize AIL
python3 ./AIL_Init.py

# Start core modules in the background using nohup since screen may not work well in Docker
echo "Starting core modules..."
nohup python3 ./core/ail_2_ail_server.py > /opt/ail/logs/ail_2_ail_server.log 2>&1 &
nohup python3 ./core/Sync_importer.py > /opt/ail/logs/sync_importer.log 2>&1 &
nohup python3 ./core/Sync_manager.py > /opt/ail/logs/sync_manager.log 2>&1 &
nohup python3 ./importer/ZMQImporter.py > /opt/ail/logs/zmq_importer.log 2>&1 &
nohup python3 ./importer/FeederImporter.py > /opt/ail/logs/feeder_importer.log 2>&1 &
nohup python3 ./core/D4_client.py > /opt/ail/logs/d4_client.log 2>&1 &
nohup python3 ./update-background.py > /opt/ail/logs/update_background.log 2>&1 &

# Start processing modules
echo "Starting processing modules..."
nohup python3 ./modules/Mixer.py > /opt/ail/logs/mixer.log 2>&1 &
nohup python3 ./modules/Global.py > /opt/ail/logs/global.log 2>&1 &
nohup python3 ./modules/Categ.py > /opt/ail/logs/categ.log 2>&1 &
nohup python3 ./modules/Tags.py > /opt/ail/logs/tags.log 2>&1 &
nohup python3 ./modules/SubmitPaste.py > /opt/ail/logs/submit_paste.log 2>&1 &

# Start the critical Crawler module
echo "Starting Crawler module..."
nohup python3 ./crawlers/Crawler.py > /opt/ail/logs/crawler.log 2>&1 &

# Start other essential modules
nohup python3 ./core/Sync_module.py > /opt/ail/logs/sync_module.log 2>&1 &
nohup python3 ./modules/ApiKey.py > /opt/ail/logs/apikey.log 2>&1 &
nohup python3 ./modules/Credential.py > /opt/ail/logs/credential.log 2>&1 &
nohup python3 ./modules/CreditCards.py > /opt/ail/logs/creditcards.log 2>&1 &
nohup python3 ./modules/Cryptocurrencies.py > /opt/ail/logs/cryptocurrency.log 2>&1 &
nohup python3 ./modules/CveModule.py > /opt/ail/logs/cve.log 2>&1 &
nohup python3 ./modules/Decoder.py > /opt/ail/logs/decoder.log 2>&1 &
nohup python3 ./modules/Duplicates.py > /opt/ail/logs/duplicates.log 2>&1 &
nohup python3 ./modules/Mail.py > /opt/ail/logs/mail.log 2>&1 &
nohup python3 ./modules/Onion.py > /opt/ail/logs/onion.log 2>&1 &
nohup python3 ./modules/Languages.py > /opt/ail/logs/languages.log 2>&1 &
nohup python3 ./modules/Hosts.py > /opt/ail/logs/hosts.log 2>&1 &
nohup python3 ./modules/DomClassifier.py > /opt/ail/logs/domclassifier.log 2>&1 &
nohup python3 ./modules/Urls.py > /opt/ail/logs/urls.log 2>&1 &

# Start tracker modules
echo "Starting tracker modules..."
nohup python3 ./trackers/Tracker_Term.py > /opt/ail/logs/tracker_term.log 2>&1 &
nohup python3 ./trackers/Tracker_Regex.py > /opt/ail/logs/tracker_regex.log 2>&1 &
nohup python3 ./trackers/Tracker_Yara.py > /opt/ail/logs/tracker_yara.log 2>&1 &
nohup python3 ./trackers/Retro_Hunt.py > /opt/ail/logs/retro_hunt.log 2>&1 &

echo "All AIL modules started! Check logs in /opt/ail/logs/ for any issues."

# Start the Flask web interface in the foreground (this keeps the container running)
echo "Starting AIL Flask web interface..."
cd ${AIL_FLASK}
exec python3 Flask_server.py
