# AIL Framework - Docker Setup Guide 🐳

This guide provides comprehensive instructions for deploying the AIL (Analysis Information Leak) Framework with Docker, including the integrated Lacus web crawler.

## ✅ **STATUS: FULLY OPERATIONAL** 
- **Container Infrastructure**: All 7 services running ✅
- **Web Crawler**: End-to-end submission and processing verified ✅
- **Database Connectivity**: Redis, Kvrocks, Valkey all connected ✅
- **Web Interface**: Login, dashboard, and crawler UI working ✅
- **Module Processing**: 650+ AIL modules running ✅

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

### 3. Launch AIL Stack
```bash
# Build and start all services (first time)
docker-compose up --build -d

# Check status
docker-compose ps
```

### 4. Verify Setup ✅
```bash
# Wait for services to initialize (2-3 minutes)
sleep 180

# Check if AIL is responding
curl http://localhost:7000/api/v1/health

# Check container status
docker-compose logs ail-app --tail=50
```

### 5. Access Web Interface 🌐
- **URL**: `http://localhost:7000`
- **Default Login**: `ail@ail.test` / `ail`
- **Dashboard**: Overview of system status and modules
- **Crawler**: `Navigation → Crawlers → Crawler Splash` for web crawling

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
- **Docker Compose**: `docker-compose.yml` (service orchestration)
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

- **Troubleshooting Guide**: See `docs/troubleshooting.md`
- **Crawler Flow Analysis**: See `docs/crawler-architecture.md`
- **Main Project README**: See `README.md`

---

## 🆘 Need Help?

For troubleshooting common issues, see the [Troubleshooting Guide](troubleshooting.md).

For technical details about crawler implementation, see the [Crawler Architecture Guide](crawler-architecture.md).
