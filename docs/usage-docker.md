# AIL Framework - Docker Setup Guide 🐳

<!--
Canonical, detailed guide for deploying and operating the AIL Framework with Docker in all environments (local, cloud, production). This is the main reference for Docker users: includes architecture, quick start, environment matrix, configuration, troubleshooting, and advanced usage. For high-level entry, see README-Docker.md. For all details, always refer to this file.
-->

This guide provides comprehensive instructions for deploying the AIL (Analysis Information Leak) Framework with Docker using the new **environment-based configuration system**.

---

## 📑 Table of Contents
- [Local and Cloud: One Build, Many Deployments](#local-and-cloud-one-build-many-deployments)
- [Status](#status-fully-operational)
- [Environment-Based Deployment](#environment-based-deployment)
- [Architecture Overview](#architecture-overview)
- [Database Architecture Explained](#database-architecture-explained)
- [Quick Start Guide (Local)](#quick-start-guide)
- [Cloud Deployment (Azure Container Apps)](#cloud-deployment-azure-container-apps)
- [Docker Compose Architecture](#docker-compose-architecture)
- [Web Crawler Usage](#web-crawler-usage-verified-working)
- [Configuration Files](#configuration-files)
- [Data Persistence](#data-persistence)
- [Monitoring & Health Checks](#monitoring-health-checks)
- [Security Considerations](#security-considerations)
- [Common Operations](#common-operations)
- [Additional Resources](#additional-resources)
- [Need Help?](#need-help)

---

## 🏗️ Local and Cloud: One Build, Many Deployments

> **The same Docker images and Compose structure power both local development and cloud (Azure Container Apps, ACR) deployments.**

- **Local development** uses Docker Compose and local environment files.
- **Cloud deployment** (e.g., Azure Container Apps) uses the same images, pushed to Azure Container Registry (ACR), and runs them in ACA with cloud-specific environment variables and secrets.
- **No code or Dockerfile changes are needed**—just different environment configs and secrets.

**Workflow Overview:**

```
Dockerfile/Compose
   │
   ├──► Local Dev: docker-compose up (local .env, configs)
   │
   └──► Build & Push: docker build/tag/push to ACR
         │
         └──► Cloud Deploy: az containerapp create/update (cloud env/secrets)
```

- All configuration (Redis, storage, URLs, etc.) is injected via environment variables and config files, not hardcoded.
- See [Azure Migration Guide](migrate-local-to-azure.md) and [Azure Fork-Lift Guide](migrate-azure-forklift.md) for step-by-step cloud deployment.
- For hybrid or advanced scenarios, see [usage-deployment-scenarios.md](usage-deployment-scenarios.md) and [usage-environment.md](usage-environment.md).

---

## ✅ **STATUS: FULLY OPERATIONAL** 
- **Container Infrastructure**: All 7 services running ✅
- **Environment Configuration**: Multi-environment support ✅
- **Web Crawler**: End-to-end submission and processing verified ✅
- **Database Connectivity**: Redis, Kvrocks, Valkey all connected ✅
- **Web Interface**: Login, dashboard, and crawler UI working ✅
- **Module Processing**: 650+ AIL modules running ✅

---

## 🌍 **Environment-Based Deployment**

AIL Framework now supports **automatic environment detection and configuration**:

| Environment | Use Case | Configuration | Docker Compose Files |
|-------------|----------|---------------|---------------------|
| **`dev-local`** | Local development | Docker containers | `ail.yml` + `dev-local.yml` |
| **`test-cloud`** | Cloud testing | External services | `ail.yml` + `test-cloud.yml` |
| **`prod-cloud`** | Production | Enterprise cloud | Custom deployment |

### **Quick Environment Setup**

```bash
# Development (default)
export DEPLOYMENT_ENV=dev-local
docker-compose -f configs/docker/docker-compose.ail.yml \
               -f configs/docker/docker-compose.dev-local.yml up

# Testing with cloud services  
export DEPLOYMENT_ENV=test-cloud
export AZURE_REDIS_HOST="your-redis.cache.windows.net"
export AZURE_REDIS_PASSWORD="your-password"
docker-compose -f configs/docker/docker-compose.ail.yml \
               -f configs/docker/docker-compose.test-cloud.yml up
```

---

## 🚀 Cloud Deployment (Azure Container Apps)

> **The same Docker images and Compose structure are used for both local and Azure deployments. Only environment variables, secrets, and storage change.**

### Quick Start (Summary)
1. **Build and tag images locally:**
   ```powershell
   $REG="acrthreatlab.azurecr.io"
   docker build -t $REG/ail-framework:0.1 -f Dockerfile.ail .
   docker push $REG/ail-framework:0.1
   docker pull ghcr.io/ail-project/lacus:latest
   docker tag ghcr.io/ail-project/lacus:latest $REG/lacus:latest
   docker push $REG/lacus:latest
   ```
2. **Provision Azure resources:**
   - Azure Container Registry (ACR)
   - Azure Cache for Redis
   - Azure File Share
   - Azure Container Apps environment
3. **Deploy containers:**
   - Use `az containerapp create` for `ail-app` (public) and `lacus` (internal)
   - Inject environment variables and secrets (see below)
   - Mount Azure File Share for persistent data

### Environment Variables & Configuration
- All config is injected via environment variables and/or env files (see `configs/redis.env`).
- Example variables:
  - `LACUS_URL`, `REDIS_HOST`, `REDIS_PORT`, `REDIS_PASSWORD`, `REDIS_SSL`, etc.
- See [migrate-local-to-azure.md](migrate-local-to-azure.md) and [migrate-azure-forklift.md](migrate-azure-forklift.md) for full variable lists and deployment scripts.

### Example Azure CLI Deployment
```powershell
az containerapp create \
  -n ail-app \
  -g <resource-group> \
  --environment <aca-env> \
  --image $REG/ail-framework:0.1 \
  --target-port 7000 --ingress external \
  --env-vars-file configs/redis.env \
  --env-vars LACUS_URL=http://lacus:7100 \
  --registry-server $REG \
  --registry-username <acr-username> \
  --registry-password <acr-password> \
  --storage-mounts "mountName=aildata,path=/opt/ail/PASTES,storageName=stthreatlab,shareName=aildata,accessMode=readwrite"
```

### Troubleshooting Cloud Deployments
- Use `az containerapp logs show -n ail-app -g <resource-group> --follow` to view logs.
- Confirm all required environment variables and secrets are set.
- See [migrate-local-to-azure.md](migrate-local-to-azure.md) and [migrate-azure-forklift.md](migrate-azure-forklift.md) for troubleshooting tips and cost breakdowns.
- For hybrid or advanced scenarios, see [usage-deployment-scenarios.md](usage-deployment-scenarios.md).

---

## 🏗️ Architecture Overview

```
AIL Docker Stack
├── ail-app (Port 7000)          # Main AIL application with Flask UI
├── lacus (Port 7100)            # Web crawler service  
├── redis-cache (6379)           # Core caching and operations
├── redis-log (6380)             # Logging and debugging
├── redis-work (6381)            # Work queues and job processing
├── kvrocks (6383)               # Persistent key-value storage
├── valkey (6385)                # Lacus crawler backend
└── tor_proxy                    # Tor proxy for .onion crawling
```

### 🔄 **Data Flow Architecture**
```
Web UI → Flask → Redis Work Queue → Crawler.py Module → Lacus → Target Website
   ↓           ↓                         ↓                ↓
Screenshots  Logs                   Database           Crawled Data
```

---

## ⚡ **Database Architecture Explained**

The AIL framework uses **three different Redis-compatible databases** for optimal performance:

| Database | Purpose | Port | Use Case |
|----------|---------|------|----------|
| **Redis** | Core operations, caching, work queues | 6379-6381 | Fast ephemeral data, job queues |
| **Kvrocks** | Persistent storage, correlations | 6383 | Long-term data, relationships |
| **Valkey** | Lacus crawler backend | 6385 | Robust crawling operations |

**Why three separate databases?**
- **Performance optimization**: Each optimized for specific workloads
- **Data isolation**: Prevents interference between components  
- **Scalability**: Can be scaled independently
- **Reliability**: Failure in one doesn't affect others

---

## 🚀 Quick Start Guide

### Prerequisites
- **Docker Desktop** for Windows/Mac/Linux
- **Docker Compose** (included with Docker Desktop)
- **8GB+ RAM** available for containers
- **20GB+ free disk space**

### 1. Clone Repository
```bash
git clone https://github.com/ail-project/ail-framework.git ail-framework
cd ail-framework
```

### 2. Initialize Git Submodules
```bash
git submodule init
git submodule update
```
This downloads YARA rules and MISP data required for tracker functionality.

### 3. Choose Your Environment

#### **🏠 Development Environment** (Recommended for beginners)
All services run locally in Docker containers:

```bash
# Set environment (optional - this is the default)
export DEPLOYMENT_ENV=dev-local

# Launch AIL stack
docker-compose -f configs/docker/docker-compose.ail.yml \
               -f configs/docker/docker-compose.dev-local.yml up --build -d

# Check status
docker-compose ps
```

#### **☁️ Cloud Testing Environment**
For integration with cloud services:

```bash
# Set environment and cloud credentials
export DEPLOYMENT_ENV=test-cloud
export AZURE_REDIS_HOST="your-redis.cache.windows.net" 
export AZURE_REDIS_PASSWORD="your-password"
export LACUS_URL="https://your-lacus-instance.com"
export FLASK_SECRET_KEY="your-secret-key"

# Launch with cloud configuration
docker-compose -f configs/docker/docker-compose.ail.yml \
               -f configs/docker/docker-compose.test-cloud.yml up --build -d
```

### 4. Verify Setup ✅
```bash
# Wait for services to initialize (2-3 minutes)
sleep 180

# Check if AIL is responding
curl http://localhost:7000/api/v1/health

# Check container logs
docker-compose logs ail-app --tail=50

# Validate environment configuration
python bin/lib/environment_config.py --validate --environment dev-local
```

### 5. Access Web Interface 🌐
- **URL**: `http://localhost:7000`
- **Default Login**: `ail@ail.test` / `ail`
- **Dashboard**: Overview of system status and modules
- **Crawler**: `Navigation → Crawlers → Crawler Splash` for web crawling

---

## 🐳 **Docker Compose Architecture**

### **File Structure**
The AIL Framework uses a **base + override** pattern for Docker Compose:

```
configs/docker/
├── docker-compose.ail.yml        # Base services (Redis, KVRocks, AIL app)
├── docker-compose.dev-local.yml  # Development environment overrides
├── docker-compose.test-cloud.yml # Cloud testing environment overrides
└── docker-compose.lacus.yml      # Optional Lacus web crawler service
```

### **Usage Patterns**

```bash
# Basic development setup
docker-compose -f configs/docker/docker-compose.ail.yml \
               -f configs/docker/docker-compose.dev-local.yml up

# Development with web crawler
docker-compose -f configs/docker/docker-compose.ail.yml \
               -f configs/docker/docker-compose.dev-local.yml \
               -f configs/docker/docker-compose.lacus.yml up

# Cloud testing environment
docker-compose -f configs/docker/docker-compose.ail.yml \
               -f configs/docker/docker-compose.test-cloud.yml up

# Custom combinations as needed
docker-compose -f configs/docker/docker-compose.ail.yml \
               -f configs/docker/docker-compose.dev-local.yml \
               -f configs/docker/docker-compose.lacus.yml up -d
```

### **Environment Configuration**

Each Docker environment automatically:
1. **Detects environment** from `DEPLOYMENT_ENV` variable
2. **Validates configuration** using environment config manager
3. **Loads appropriate settings** from `configs/environments/`
4. **Substitutes variables** for cloud deployments
5. **Routes to correct entrypoint** via `smart-entrypoint.sh`

```bash
# Configuration validation
python bin/lib/environment_config.py --validate --environment dev-local
# Output: ✓ Environment configuration validated successfully

# View environment details
python bin/lib/environment_config.py --info --environment dev-local

# Get specific configuration values
python bin/lib/environment_config.py --get Redis host --environment test-cloud
```

---

## 🕷️ **Web Crawler Usage** (VERIFIED WORKING)

### Lacus Crawler Integration

The AIL framework includes [Lacus](https://github.com/ail-project/lacus), a specialized web crawler that provides:

- **Web Crawling**: Advanced crawling with JavaScript rendering
- **Tor Support**: Anonymous crawling through Tor network
- **Screenshot Capture**: Visual capture of crawled content
- **Playwright Integration**: Modern browser automation for dynamic content

### Submit Crawl Request
1. **Login** to web interface: `http://localhost:7000`
2. **Navigate**: `Crawlers → Crawler Splash`
3. **Enter URL**: Any website (e.g., `https://example.com`)
4. **Configure Options**:
   - **Depth**: How many levels to crawl
   - **Screenshot**: Capture page screenshots
   - **HAR**: Save HTTP Archive files
   - **Proxy**: Force Tor for .onion sites (automatic)
5. **Click Submit** → Watch real-time processing in logs

### Monitor Crawling Activity
```bash
# Watch crawler logs in real-time
docker-compose logs -f ail-app | grep -i crawler

# Check Lacus service logs  
docker-compose logs -f lacus

# Monitor work queue
docker exec -it $(docker-compose ps -q redis-work) redis-cli -p 6381 monitor
```

### Crawler Status Verification
```bash
# Check module status
curl http://localhost:7000/api/v1/modules | jq

# Verify Redis work queue
docker exec -it $(docker-compose ps -q redis-work) redis-cli -p 6381 keys "*"

# Check Kvrocks connection
docker exec -it $(docker-compose ps -q kvrocks) redis-cli -h kvrocks -p 6383 ping
```

---

## 🔧 Configuration Files

### Core Configuration
- **Main Config**: `configs/docker/core.cfg` (container-optimized)
- **Lacus Config**: `configs/lacus/docker.generic.json` (crawler settings)
- **Kvrocks Config**: `kvrocks.conf` (database settings)
- **Docker Compose**: `docker-compose.ail.yml` (service orchestration)
- **Container Startup**: `docker-entrypoint.sh` (initialization script)

### Key Configuration Changes for Docker
```ini
# Flask server accessible from host
[Flask]
host = 0.0.0.0
port = 7000

# Redis services point to containers
[Redis_Cache]
host = redis-cache
port = 6379

# Kvrocks persistent storage
[Kvrocks_DB] 
host = kvrocks
port = 6383
```

---

## 💾 Data Persistence

All important data is persisted outside containers:

| Data Type | Host Path | Container Path | Purpose |
|-----------|-----------|----------------|---------|
| Pastes | `./data/pastes` | `/opt/ail/PASTES` | Analyzed content |
| Screenshots | `./data/screenshots` | `/opt/ail/CRAWLED_SCREENSHOT` | Web captures |
| Images | `./data/images` | `/opt/ail/IMAGES` | Extracted images |
| Logs | `./data/logs` | `/opt/ail/logs` | Application logs |
| Kvrocks DB | `./data/kvrocks` | `/opt/kvrocks/data` | Persistent database |
| Lacus Data | `./data/lacus` | `/opt/lacus/data` | Crawler data |

---

## 📊 Monitoring & Health Checks

### Health Checks
```bash
# Quick system status
docker-compose ps
curl http://localhost:7000/api/v1/health

# Database connectivity
docker exec -it $(docker-compose ps -q redis-cache) redis-cli ping
docker exec -it $(docker-compose ps -q kvrocks) redis-cli -h kvrocks -p 6383 ping

# Module status
curl http://localhost:7000/api/v1/modules
```

### Networking

All services communicate through the `ail-net` Docker bridge network, providing:
- Internal service discovery by container name
- Isolation from other Docker networks
- Secure inter-service communication

---

## 🔒 Security Considerations

### Current Security Features
- **SSL Certificates**: AIL generates self-signed certificates for HTTPS
- **Tor Integration**: Lacus includes Tor for anonymous crawling
- **Network Isolation**: Services communicate through isolated Docker network
- **Default Credentials**: Change default AIL credentials after first login

### Security Best Practices
1. **Regular Updates**: Keep base images updated
2. **Resource Limits**: Set appropriate CPU/memory limits on containers
3. **Log Monitoring**: Monitor logs for suspicious activity
4. **Access Control**: Restrict access to AIL web interface

---

## 🛠️ Common Operations

### Starting/Stopping Services
```bash
# Start all services
docker-compose up -d

# Stop all services
docker-compose down

# Restart specific service
docker-compose restart lacus

# View logs
docker-compose logs -f ail-app
```

### Updating Images
```bash
# Pull latest base images
docker-compose pull

# Rebuild with latest code
docker-compose up --build -d
```

### Backup Data
```bash
# Backup persistent data
tar -czf ail-backup-$(date +%Y%m%d).tar.gz data/
```

---

## 📚 Additional Resources

- **Troubleshooting Guide**: See `docs/troubleshooting-docker.md`
- **Crawler Flow Analysis**: See `docs/crawler-architecture.md`
- **Main Project README**: See `README.md`

---

## 🆘 Need Help?

For troubleshooting common issues, see the [Troubleshooting Guide](troubleshooting-docker.md).

For technical details about crawler implementation, see the [Crawler Architecture Guide](crawler-architecture.md).
