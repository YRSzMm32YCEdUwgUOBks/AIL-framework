# AIL Framework Execution Flow Documentation

## Overview

This document provides a comprehensive analysis of the AIL Framework's execution flow, particularly in Azure Container Apps deployment. It covers the complete startup sequence, service dependencies, and critical components that affect system functionality.

## Table of Contents

1. [Container Startup Sequence](#container-startup-sequence)
2. [Configuration Management](#configuration-management)
3. [Service Dependencies](#service-dependencies)
4. [Background Services](#background-services)
5. [Flask Web Interface](#flask-web-interface)
6. [Redis Database Architecture](#redis-database-architecture)
7. [Troubleshooting Common Issues](#troubleshooting-common-issues)
8. [Container Communication](#container-communication)

## Container Startup Sequence

### Phase 1: Environment Setup
The Azure Container Apps deployment begins with the `azure-entrypoint.sh` script:

```bash
#!/bin/bash
set -euo pipefail

# Azure Container Apps startup script for AIL Framework
echo "Starting AIL Framework Azure configuration..."
```

**Key Actions:**
- Sets critical environment variables (`AIL_HOME`, `AIL_BIN`, `AIL_FLASK`, `PYTHONPATH`)
- Creates necessary directory structure for data persistence
- Validates Redis connection parameters
- Ensures all required Azure environment variables are present

### Phase 2: Configuration Generation
The script generates a comprehensive Azure-specific configuration file (`/opt/ail/configs/azure.cfg`):

```ini
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
```

### Phase 3: One-Time Initialization
```bash
if [ ! -f "/opt/ail/.initialized" ]; then
    echo "[CONFIG] Running first-time initialization..."
    python3 /opt/ail/bin/AIL_Init.py
    touch /opt/ail/.initialized
    echo "[SUCCESS] Initialization complete"
fi
```

**AIL_Init.py performs:**
- Queue digraph structure saving (`ail_queues.save_queue_digraph()`)
- Module queue statistics clearing (`ail_queues.clear_modules_queues_stats()`)
- AIL UUID logging for startup tracking

### Phase 4: Service Integration
```bash
# Inject LACUS_URL into Redis/Kvrocks database
if [ -n "${LACUS_URL:-}" ]; then
    echo "[CONFIG] Injecting LACUS_URL environment variable into Redis database..."
    python3 /opt/ail/inject_lacus_url_fixed.py
fi
```

**LACUS URL Injection:**
- Validates LACUS_URL format and connectivity
- Injects crawler service endpoint into Redis database (db=3)
- Ensures crawler can communicate with Lacus container
- Critical for domain exploration functionality

### Phase 5: User Management
```bash
# Create default user for Azure deployment (only if it doesn't exist)
if ! python3 -c "import sys; sys.path.append('/opt/ail/bin'); from lib import User; u = User.User(); exit(0 if u.exist_user('ail@ail.test') else 1)" 2>/dev/null; then
    cd /opt/ail/var/www
    python3 create_default_user.py
fi
```

**Default Credentials:** `ail@ail.test` / `ail`

## Configuration Management

### Environment Variables Required

**Redis Connection:**
- `REDIS_CACHE_HOST` - Primary Redis server hostname
- `REDIS_CACHE_PORT` - Redis server port (typically 6380 for Azure)
- `REDIS_CACHE_PASSWORD` - Redis authentication password
- `REDIS_CACHE_SSL` - SSL/TLS enablement (default: true)

**Service Communication:**
- `LACUS_URL` - Lacus crawler service endpoint
- `FLASK_HOST` - Flask server bind address (default: 0.0.0.0)
- `FLASK_PORT` - Flask server port (default: 7000)

**AIL Framework Paths:**
- `AIL_HOME` - Base AIL installation directory (/opt/ail)
- `AIL_BIN` - AIL binary/script directory (/opt/ail/bin)
- `AIL_FLASK` - Flask web interface directory (/opt/ail/var/www)

### Configuration Files Generated

1. **azure.cfg** - Main configuration with Redis settings
2. **logging.json** - Logging configuration for all modules
3. **various module configs** - Individual module configurations

## Service Dependencies

### Dependency Graph
```
┌─────────────────┐
│ Azure Container │
│ Infrastructure  │
└─────────┬───────┘
          │
    ┌─────▼──────┐
    │ Redis Cache │ (Azure Cache for Redis)
    └─────┬──────┘
          │
    ┌─────▼──────┐
    │ AIL Main   │
    │ Container  │
    └─────┬──────┘
          │
    ┌─────▼──────┐
    │ Lacus      │
    │ Container  │
    └────────────┘
```

### Inter-Container Communication

**AIL → Redis:**
- Database 0: Primary cache
- Database 1: Logging and sync
- Database 2: Work queues and processing
- Database 3: Kvrocks relationships and crawler data

**AIL → Lacus:**
- HTTP API calls via `LACUS_URL`
- Crawler task submission
- Screenshot and HAR file retrieval

## Background Services

### Core Services (Critical)
```bash
# Core infrastructure services
nohup python3 ./core/ail_2_ail_server.py > /opt/ail/logs/ail_2_ail_server.log 2>&1 &
nohup python3 ./core/Sync_importer.py > /opt/ail/logs/sync_importer.log 2>&1 &
nohup python3 ./core/Sync_manager.py > /opt/ail/logs/sync_manager.log 2>&1 &
nohup python3 ./importer/ZMQImporter.py > /opt/ail/logs/zmq_importer.log 2>&1 &
nohup python3 ./importer/FeederImporter.py > /opt/ail/logs/feeder_importer.log 2>&1 &
```

### Processing Modules
```bash
# Data processing pipeline
nohup python3 ./modules/Mixer.py > /opt/ail/logs/mixer.log 2>&1 &
nohup python3 ./modules/Global.py > /opt/ail/logs/global.log 2>&1 &
nohup python3 ./modules/Categ.py > /opt/ail/logs/categ.log 2>&1 &

# Critical: Crawler module for domain exploration
nohup python3 ./crawlers/Crawler.py > /opt/ail/logs/crawler.log 2>&1 &
```

### Analysis Modules
```bash
# Security analysis modules
nohup python3 ./modules/ApiKey.py > /opt/ail/logs/apikey.log 2>&1 &
nohup python3 ./modules/Credential.py > /opt/ail/logs/credential.log 2>&1 &
nohup python3 ./modules/CreditCards.py > /opt/ail/logs/creditcards.log 2>&1 &
nohup python3 ./modules/Mail.py > /opt/ail/logs/mail.log 2>&1 &
nohup python3 ./modules/Onion.py > /opt/ail/logs/onion.log 2>&1 &
```

### Tracker Modules
```bash
# Threat hunting and tracking
nohup python3 ./trackers/Tracker_Term.py > /opt/ail/logs/tracker_term.log 2>&1 &
nohup python3 ./trackers/Tracker_Regex.py > /opt/ail/logs/tracker_regex.log 2>&1 &
nohup python3 ./trackers/Tracker_Yara.py > /opt/ail/logs/tracker_yara.log 2>&1 &
nohup python3 ./trackers/Retro_Hunt.py > /opt/ail/logs/retro_hunt.log 2>&1 &
```

## Flask Web Interface

### Final Execution
```bash
# Start Flask web interface in the foreground (this keeps the container running)
echo "🌐 Starting AIL Flask web interface..."
cd ${AIL_FLASK}
exec python3 Flask_server.py
```

### Key Components

**Flask_server.py:**
- Main web application entry point
- Handles user authentication and session management
- Imports and registers all blueprint modules
- Serves the web interface on configured port

**Blueprint Structure:**
- `crawler_splash.py` - Domain exploration interface (contains `/domains/explorer/vanity`)
- `correlation.py` - Data correlation analysis
- `objects_*.py` - Various object type handlers
- `investigations.py` - Investigation management

### Critical Routes for Domain Analysis

**Domain Explorer Route:**
```python
@crawler_splash.route("/domains/explorer/vanity")
@login_required
@login_read_only
def domains_explorer_vanity_clusters():
    # Handles domain vanity clustering with Redis operations
    # Fixed: Proper integer parameter handling for Redis
```

## Redis Database Architecture

### Database Allocation

| Database | Purpose | Key Data Types |
|----------|---------|----------------|
| 0 | Primary Cache | Configuration, cached data |
| 1 | Logging & Sync | Log entries, sync status |
| 2 | Work Queues | Processing queues, job status |
| 3 | Kvrocks/Relationships | Crawler data, domain relationships |

### Common Redis Operations

**In Domain Explorer (Fixed Issue):**
```python
# Problem: Redis expecting integer, receiving string
nb_min = request.args.get('min', 4)  # This returns string '4'

# Solution: Proper type conversion with error handling
try:
    nb_min = int(nb_min)
except (ValueError, TypeError):
    nb_min = 4
```

## Troubleshooting Common Issues

### 500 Internal Server Error on `/domains/explorer/vanity`

**Root Cause:** Redis parameter type mismatch
- Flask request parameters are strings by default
- Redis operations expect integers for numerical parameters
- Symptom: `TypeError: unsupported operand type(s)`

**Solution Applied:**
1. Modified `crawler_splash.py` functions:
   - `domains_explorer_vanity_clusters()`
   - `domains_explorer_vanity_explore()`
2. Added proper integer conversion with error handling
3. Ensured backward compatibility with default values

### Lacus Container Syntax Errors

**Root Cause:** Incomplete `else` blocks in `abstractmanager.py`
- Original code had incomplete `else:` statements
- Caused `IndentationError: expected an indented block after 'else' statement`

**Solution Applied:**
1. Fixed incomplete `else` blocks in `lacus-src/lacus/default/abstractmanager.py`
2. Simplified Azure Redis patch script to avoid risky regex operations
3. Ensured proper Python syntax validation

### Redis Connection Issues

**Common Causes:**
- Missing environment variables
- SSL/TLS configuration problems
- Network connectivity between containers
- Database number mismatches

**Diagnostic Commands:**
```bash
# Check Redis connectivity
python3 -c "import redis; r = redis.Redis(host='$REDIS_CACHE_HOST', port=$REDIS_CACHE_PORT, password='$REDIS_CACHE_PASSWORD', ssl=True); print(r.ping())"

# Verify environment variables
env | grep REDIS

# Check container logs
docker logs <container_name>
```

## Container Communication

### Network Architecture
```
┌─────────────────────┐    ┌─────────────────────┐
│                     │    │                     │
│   AIL Container     │    │  Lacus Container    │
│   (Port 7000)       │    │   (Port 7100)       │
│                     │    │                     │
│ ┌─────────────────┐ │    │ ┌─────────────────┐ │
│ │ Flask Server    │ │    │ │ Lacus Server    │ │
│ │ crawler_splash  │◄┼────┼►│ Crawler API     │ │
│ └─────────────────┘ │    │ └─────────────────┘ │
│                     │    │                     │
└─────────┬───────────┘    └─────────────────────┘
          │
          ▼
┌─────────────────────┐
│                     │
│ Azure Cache Redis   │
│ (Port 6380)         │
│                     │
│ ┌─────┬─────┬─────┐ │
│ │ DB0 │ DB1 │ DB2 │ │
│ │Cache│ Log │Queue│ │
│ └─────┴─────┴─────┘ │
│ ┌─────────────────┐ │
│ │      DB3        │ │
│ │   Relationships │ │
│ └─────────────────┘ │
└─────────────────────┘
```

### API Communication Flow

1. **User accesses** `/domains/explorer/vanity`
2. **Flask server** processes request in `crawler_splash.py`
3. **Redis queries** retrieve domain clustering data
4. **Lacus API calls** (if needed) for fresh crawler data
5. **Response rendering** with domain analysis results

## Log File Locations

All service logs are written to `/opt/ail/logs/` with individual files:

- `crawler.log` - Crawler module operations
- `flask.log` - Flask web server logs
- `redis.log` - Redis connection issues
- `*_module.log` - Individual module logs

## Performance Considerations

### Resource Allocation
- **CPU**: Multiple background processes require adequate CPU allocation
- **Memory**: Redis operations and Python modules can be memory-intensive
- **Network**: Regular communication between AIL and Lacus containers

### Scaling Recommendations
- Monitor Redis connection pools
- Consider horizontal scaling for processing modules
- Implement health checks for critical services

## Security Considerations

### Network Security
- All Redis connections use SSL/TLS by default
- Container-to-container communication on internal network
- External access only through configured ports

### Authentication
- Default user creation for Azure deployment
- Session-based authentication for web interface
- Redis password authentication

### Data Protection
- All sensitive data stored in Redis with encryption
- Log files may contain sensitive information
- Proper secret management for environment variables
