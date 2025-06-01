#!/bin/bash
set -euo pipefail

# Azure Container Apps startup script for AIL Framework
echo "Starting AIL Framework Azure configuration..."

# Set AIL environment variables
export AIL_HOME=/opt/ail
export AIL_BIN=/opt/ail/bin
export AIL_FLASK=/opt/ail/var/www
export PYTHONPATH=/opt/ail/bin:/opt/ail

# Ensure directories exist
mkdir -p /opt/ail/logs
mkdir -p /opt/ail/PASTES
mkdir -p /opt/ail/HASHS
mkdir -p /opt/ail/crawled
mkdir -p /opt/ail/CRAWLED_SCREENSHOT
mkdir -p /opt/ail/CRAWLED_SCREENSHOT/screenshot
mkdir -p /opt/ail/IMAGES
mkdir -p /opt/ail/FAVICONS
mkdir -p /opt/ail/Blooms
mkdir -p /opt/ail/Dicos
mkdir -p /opt/ail/var/www/static/csv

# Validate Redis connection environment variables
if [ -z "${REDIS_CACHE_HOST:-}" ] || [ -z "${REDIS_CACHE_PORT:-}" ] || [ -z "${REDIS_CACHE_PASSWORD:-}" ]; then
    echo "ERROR: Missing required Redis environment variables"
    echo "Required: REDIS_CACHE_HOST, REDIS_CACHE_PORT, REDIS_CACHE_PASSWORD"
    exit 1
fi

echo "[SUCCESS] Redis configuration validated: ${REDIS_CACHE_HOST}:${REDIS_CACHE_PORT}"

# Create Azure-specific configuration with proper Redis settings
cat > /opt/ail/configs/azure.cfg << EOF
[Directories]
base = /opt/ail
bloomfilters = Blooms
dicofilters = Dicos
pastes = PASTES
hash = HASHS
crawled = crawled
har = CRAWLED_SCREENSHOT
screenshot = CRAWLED_SCREENSHOT/screenshot
images = IMAGES
favicons = FAVICONS
crawled_screenshot = CRAWLED_SCREENSHOT/

wordtrending_csv = var/www/static/csv/wordstrendingdata
wordsfile = files/wordfile
protocolstrending_csv = var/www/static/csv/protocolstrendingdata
protocolsfile = files/protocolsfile
tldstrending_csv = var/www/static/csv/tldstrendingdata
tldsfile = faup/src/data/mozilla.tlds
domainstrending_csv = var/www/static/csv/domainstrendingdata

[Redis_Cache]
host = ${REDIS_CACHE_HOST}
port = ${REDIS_CACHE_PORT}
db = 0
password = ${REDIS_CACHE_PASSWORD}
ssl = ${REDIS_CACHE_SSL:-true}

[Redis_Log]
host = ${REDIS_LOG_HOST:-${REDIS_CACHE_HOST}}
port = ${REDIS_LOG_PORT:-${REDIS_CACHE_PORT}}
db = 1
password = ${REDIS_LOG_PASSWORD:-${REDIS_CACHE_PASSWORD}}
ssl = ${REDIS_LOG_SSL:-true}

[Redis_Queues]
host = ${REDIS_WORK_HOST:-${REDIS_CACHE_HOST}}
port = ${REDIS_WORK_PORT:-${REDIS_CACHE_PORT}}
db = 2
password = ${REDIS_WORK_PASSWORD:-${REDIS_CACHE_PASSWORD}}
ssl = ${REDIS_WORK_SSL:-true}

[Redis_Log_submit]
host = ${REDIS_LOG_HOST:-${REDIS_CACHE_HOST}}
port = ${REDIS_LOG_PORT:-${REDIS_CACHE_PORT}}
db = 1
password = ${REDIS_LOG_PASSWORD:-${REDIS_CACHE_PASSWORD}}
ssl = ${REDIS_LOG_SSL:-true}

[Redis_Process]
host = ${REDIS_WORK_HOST:-${REDIS_CACHE_HOST}}
port = ${REDIS_WORK_PORT:-${REDIS_CACHE_PORT}}
db = 2
password = ${REDIS_WORK_PASSWORD:-${REDIS_CACHE_PASSWORD}}
ssl = ${REDIS_WORK_SSL:-true}

[Redis_Mixer_Cache]
host = ${REDIS_WORK_HOST:-${REDIS_CACHE_HOST}}
port = ${REDIS_WORK_PORT:-${REDIS_CACHE_PORT}}
db = 1
password = ${REDIS_WORK_PASSWORD:-${REDIS_CACHE_PASSWORD}}
ssl = ${REDIS_WORK_SSL:-true}

##### KVROCKS #####

[Kvrocks_DB]
host = ${KVROCKS_HOST:-${REDIS_CACHE_HOST}}
port = ${KVROCKS_PORT:-${REDIS_CACHE_PORT}}
db = 3
password = ${KVROCKS_PASSWORD:-${REDIS_CACHE_PASSWORD}}
ssl = ${KVROCKS_SSL:-true}

[Kvrocks_Duplicates]
host = ${KVROCKS_HOST:-${REDIS_CACHE_HOST}}
port = ${KVROCKS_PORT:-${REDIS_CACHE_PORT}}
db = 4
password = ${KVROCKS_PASSWORD:-${REDIS_CACHE_PASSWORD}}
ssl = ${KVROCKS_SSL:-true}

[Kvrocks_Correlations]
host = ${KVROCKS_HOST:-${REDIS_CACHE_HOST}}
port = ${KVROCKS_PORT:-${REDIS_CACHE_PORT}}
db = 5
password = ${KVROCKS_PASSWORD:-${REDIS_CACHE_PASSWORD}}
ssl = ${KVROCKS_SSL:-true}

[Kvrocks_Crawler]
host = ${KVROCKS_HOST:-${REDIS_CACHE_HOST}}
port = ${KVROCKS_PORT:-${REDIS_CACHE_PORT}}
db = 6
password = ${KVROCKS_PASSWORD:-${REDIS_CACHE_PASSWORD}}
ssl = ${KVROCKS_SSL:-true}

[Kvrocks_Languages]
host = ${KVROCKS_HOST:-${REDIS_CACHE_HOST}}
port = ${KVROCKS_PORT:-${REDIS_CACHE_PORT}}
db = 7
password = ${KVROCKS_PASSWORD:-${REDIS_CACHE_PASSWORD}}
ssl = ${KVROCKS_SSL:-true}

[Kvrocks_Objects]
host = ${KVROCKS_HOST:-${REDIS_CACHE_HOST}}
port = ${KVROCKS_PORT:-${REDIS_CACHE_PORT}}
db = 8
password = ${KVROCKS_PASSWORD:-${REDIS_CACHE_PASSWORD}}
ssl = ${KVROCKS_SSL:-true}

[Kvrocks_Relationships]
host = ${KVROCKS_HOST:-${REDIS_CACHE_HOST}}
port = ${KVROCKS_PORT:-${REDIS_CACHE_PORT}}
db = 9
password = ${KVROCKS_PASSWORD:-${REDIS_CACHE_PASSWORD}}
ssl = ${KVROCKS_SSL:-true}

[Kvrocks_Timeline]
host = ${KVROCKS_HOST:-${REDIS_CACHE_HOST}}
port = ${KVROCKS_PORT:-${REDIS_CACHE_PORT}}
db = 10
password = ${KVROCKS_PASSWORD:-${REDIS_CACHE_PASSWORD}}
ssl = ${KVROCKS_SSL:-true}

[Kvrocks_Stats]
host = ${KVROCKS_HOST:-${REDIS_CACHE_HOST}}
port = ${KVROCKS_PORT:-${REDIS_CACHE_PORT}}
db = 11
password = ${KVROCKS_PASSWORD:-${REDIS_CACHE_PASSWORD}}
ssl = ${KVROCKS_SSL:-true}

[Kvrocks_Tags]
host = ${KVROCKS_HOST:-${REDIS_CACHE_HOST}}
port = ${KVROCKS_PORT:-${REDIS_CACHE_PORT}}
db = 12
password = ${KVROCKS_PASSWORD:-${REDIS_CACHE_PASSWORD}}
ssl = ${KVROCKS_SSL:-true}

[Kvrocks_Trackers]
host = ${KVROCKS_HOST:-${REDIS_CACHE_HOST}}
port = ${KVROCKS_PORT:-${REDIS_CACHE_PORT}}
db = 13
password = ${KVROCKS_PASSWORD:-${REDIS_CACHE_PASSWORD}}
ssl = ${KVROCKS_SSL:-true}

[Pystemon]
redis_host = ${REDIS_CACHE_HOST}
redis_port = ${REDIS_CACHE_PORT}
redis_db = 10

[Logs]
logDirectory = /opt/ail/logs/
logLevel = INFO
logEnabled = True
logFile = "logs.log"

[Notifications]
ail_domain = https://ail-app.delightfulbay-9e24f820.westeurope.azurecontainerapps.io
sender_host = 127.0.0.1
sender_port = 1337
sender_pw = None

[Flask]
host = 0.0.0.0
port = 7000
baseurl = /
host_static_content = False
static_content_host_ip = 127.0.0.1
static_content_host_port = 5555
max_preview_char = 1000
max_preview_modal = 9000
DiffMaxLineLength = 10000
screenshot = True
screenshot_worker = False
max_dashboard_logs = 15

[Users]
default_admin = True
hash_password_min_size = 8
force_2fa = False
2fa_name = AIL

[AIL_2_AIL]
log = True

[BankAccount]
max_execution_time = 30

[Categ]
max_execution_time = 60

[Credential]
max_execution_time = 30
redis_timeout_prefix = 100
redis_timeout_save_name = 300
redis_timeout_save_domain = 300
redis_timeout_save_iban = 300

[Decoder]
max_execution_time = 60
path = /opt/ail/var/

[Onion]
max_execution_time = 30
full_crawl_timeout = 3600

[PgpDump]
max_execution_time = 60

[Modules_Duplicates]
maximum_month_range = 3
threshold_duplicate_ssdeep = 50
threshold_duplicate_tlsh = 52
min_paste_size = 0.3

[Module_ModuleInformation]
max_execution_time = 60

[Module_DomainClassifier]
cc = EN
cc_tld = True

[Module_Categ]
max_execution_time = 60

[Module_Credential]
max_execution_time = 300

[Module_Keys]
max_execution_time = 300

[Module_Decoder]
max_execution_time = 300

[Module_Onion]
max_execution_time = 300

[Module_Global]
max_execution_time = 300

[Module_Phone]
max_execution_time = 30

[Module_Cve]
max_execution_time = 30

[Module_Cryptocurrency]
max_execution_time = 30

[Module_Zerobins]
max_execution_time = 30

[Module_Duplicates]
max_execution_time = 3600

[Module_Telegram]
max_execution_time = 30

[Module_Discord]
max_execution_time = 30

[Module_LibInjection]
max_execution_time = 30

[Module_FilesNames]
max_execution_time = 30

[Module_Iban]
max_execution_time = 30

[Module_Urls]
max_execution_time = 30

[Module_ApiKey]
max_execution_time = 30

[Module_Mail]
max_execution_time = 30

[Module_CreditCards]
max_execution_time = 30

[Module_SentimentAnalysis]
max_execution_time = 30

[Module_Languages]
max_execution_time = 30
min_len = 600

[Module_HASHS]
max_execution_time = 30

[Module_Pastes]
max_execution_time = 30

[Module_Mixer]
ttl_duplicate = 86400
default_crawler_closespider_timeout = 1800
default_crawler_download_delay = 1
bind = tcp://127.0.0.1:5556

[Tracker_Term]
max_execution_time = 90

[Tracker_Regex]
max_execution_time = 60

[Crawler]
activate_crawler = True
default_depth_limit = 1
default_har = True
default_screenshot = True
splash_manager_url = ${LACUS_URL:-http://lacus}

[Url]
cc_critical = DE

[DomClassifier]
cc =
cc_tld =
dns = 8.8.8.8

[Mail]
dns = 8.8.8.8

[Indexer]
type = whoosh
path = indexdir
register = indexdir/all_index.txt
index_max_size = 2000

[ailleakObject]
maxDuplicateToPushToMISP=10

[ZMQ_Global]
address = tcp://127.0.0.1:5556
channel = 102
bind = tcp://127.0.0.1:5556

[RedisPubSub]
host = ${REDIS_WORK_HOST:-${REDIS_CACHE_HOST}}
port = ${REDIS_WORK_PORT:-${REDIS_CACHE_PORT}}
db = 0
password = ${REDIS_WORK_PASSWORD:-${REDIS_CACHE_PASSWORD}}
ssl = ${REDIS_WORK_SSL:-true}

[Translation]
libretranslate = 

[IP]
networks =

[SubmitPaste]
TEXT_MAX_SIZE = 1000000
FILE_MAX_SIZE = 1000000000
FILE_ALLOWED_EXTENSIONS = txt,sh,pdf,html,json
EOF

echo "[SUCCESS] Azure configuration created at /opt/ail/configs/azure.cfg"

# Copy Azure config to main config location
cp /opt/ail/configs/azure.cfg /opt/ail/configs/core.cfg

# Create symbolic link for config in root directory if it doesn't exist
if [ ! -f /opt/ail/core.cfg ]; then
    ln -sf /opt/ail/configs/core.cfg /opt/ail/core.cfg
fi

# Initialize AIL database and configuration if needed
echo "[CONFIG] Initializing AIL Framework..."
cd /opt/ail

# Test Redis connectivity before starting
echo "🔍 Testing Redis connectivity..."
python3 -c "
import redis
import os
import ssl

try:
    host = os.environ['REDIS_CACHE_HOST']
    port = int(os.environ['REDIS_CACHE_PORT'])
    password = os.environ['REDIS_CACHE_PASSWORD']
    ssl_enabled = os.environ.get('REDIS_CACHE_SSL', 'true').lower() == 'true'
    
    if ssl_enabled:
        r = redis.Redis(host=host, port=port, password=password, ssl=True, ssl_cert_reqs=None)
    else:
        r = redis.Redis(host=host, port=port, password=password)
    
    r.ping()
    print('[SUCCESS] Redis connection successful')
except Exception as e:
    print(f'❌ Redis connection failed: {e}')
    exit(1)
"

# Create symbolic links for modules that may be referenced from wrong locations
echo "[CONFIG] Creating module compatibility symlinks..."
mkdir -p /opt/ail/bin/modules
if [ ! -f "/opt/ail/bin/modules/Crawler.py" ] && [ -f "/opt/ail/bin/crawlers/Crawler.py" ]; then
    ln -sf /opt/ail/bin/crawlers/Crawler.py /opt/ail/bin/modules/Crawler.py
    echo "[SUCCESS] Created symlink for Crawler.py"
fi

# Note: Crawler_Manager.py doesn't exist in this version of AIL, so we'll create a dummy
if [ ! -f "/opt/ail/bin/modules/Crawler_Manager.py" ]; then
    cat > /opt/ail/bin/modules/Crawler_Manager.py << 'EOF'
#!/usr/bin/env python3
# Compatibility shim for deprecated Crawler_Manager module
# This module has been replaced by the main Crawler.py
import sys
import time
print("Crawler_Manager.py is deprecated. Use Crawler.py instead.")
print("This is a compatibility shim that will exit gracefully.")
sys.exit(0)
EOF
    chmod +x /opt/ail/bin/modules/Crawler_Manager.py
    echo "[SUCCESS] Created compatibility shim for Crawler_Manager.py"
fi

# Run any necessary initialization
if [ ! -f "/opt/ail/.initialized" ]; then
    echo "[CONFIG] Running first-time initialization..."
    python3 /opt/ail/bin/AIL_Init.py
    touch /opt/ail/.initialized
    echo "[SUCCESS] Initialization complete"
fi

# Inject LACUS_URL into Redis/Kvrocks database
if [ -n "${LACUS_URL:-}" ]; then
    echo "[CONFIG] Injecting LACUS_URL environment variable into Redis database..."
    python3 /opt/ail/inject_lacus_url.py
    if [ $? -eq 0 ]; then
        echo "[SUCCESS] LACUS_URL injection successful"
    else
        echo "[ERROR] LACUS_URL injection failed"
        exit 1
    fi
else
    echo "[WARNING] LACUS_URL environment variable not set"
fi

# Create default user for Azure deployment (only if it doesn't exist)
echo "[USER] Creating default user for Azure deployment..."
if ! python3 -c "import sys; sys.path.append('/opt/ail/bin'); from lib import User; u = User.User(); exit(0 if u.exist_user('ail@ail.test') else 1)" 2>/dev/null; then
    echo "[USER] Creating default user: ail@ail.test"
    cd /opt/ail/var/www
    python3 create_default_user.py
    echo "[SUCCESS] Default user created successfully!"
    echo "[INFO] Login credentials: ail@ail.test / ail"
else
    echo "[INFO] Default user already exists, skipping creation."
fi

echo "🚀 Starting AIL Framework services..."

# Launch the AIL processing modules in the background
echo "Starting AIL processing modules..."
cd ${AIL_BIN}

# Initialize AIL
python3 ./AIL_Init.py

# Start core modules in the background using nohup since screen may not work well in containers
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

# Start the critical Crawler module (note: it's in crawlers/, not modules/)
echo "Starting Crawler module..."
nohup python3 ./crawlers/Crawler.py > /opt/ail/logs/crawler.log 2>&1 &
CRAWLER_PID=$!

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

# Start Flask web interface in the foreground (this keeps the container running)
echo "🌐 Starting AIL Flask web interface..."
cd ${AIL_FLASK}
exec python3 Flask_server.py
