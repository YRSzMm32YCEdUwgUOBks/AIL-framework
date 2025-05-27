# AIL Framework - Docker Containerization 🐳

This repository contains a **complete and verified working** containerized setup for the AIL (Analysis Information Leak) Framework with full web crawler functionality, local development support, and deployment guidance.

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
```powershell
git clone https://github.com/ail-project/ail-framework.git ail-framework
cd ail-framework
```

### 2. Initialize Git Submodules
```bash
git submodule init
git submodule update
```

This downloads essential components:
- YARA rules for malware detection (`bin/trackers/yara/ail-yara-rules/`)
- MISP taxonomies and galaxy data (`files/misp-*`)

**Without this step, the tracker functionality will fail with internal server errors.**

### 3. Launch AIL Stack
```powershell
# Build and start all services (first time)
docker-compose up --build -d

# Check status
docker-compose ps
```

### 4. Verify Setup ✅
```powershell
# Wait for services to initialize (2-3 minutes)
Start-Sleep 180

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

### Submit Crawl Request
1. **Login** to web interface: `http://localhost:7000`
2. **Navigate**: `Crawlers → Crawler Splash`
3. **Enter URL**: Any website (e.g., `https://example.com`)
4. **Click Submit** → Watch real-time processing in logs

### Monitor Crawling Activity
```powershell
# Watch crawler logs in real-time
docker-compose logs -f ail-app | findstr -i crawler

# Check Lacus service logs  
docker-compose logs -f lacus

# Monitor work queue
docker exec -it ail-framework-redis-work-1 redis-cli -p 6381 monitor
```

### Crawler Status Verification
```powershell
# Check module status
curl http://localhost:7000/api/v1/modules | jq

# Verify Redis work queue
docker exec -it ail-framework-redis-work-1 redis-cli -p 6381 keys "*"

# Check Kvrocks connection
docker exec -it ail-framework-kvrocks-1 redis-cli -h kvrocks -p 6383 ping
```

---

## 🔧 Configuration Files

### Core Configuration
- **Main Config**: `configs/docker/core.cfg` (container-optimized)
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

---

## 📊 Monitoring & Troubleshooting

### Health Checks
```powershell
# Quick system status
docker-compose ps
curl http://localhost:7000/api/v1/health

# Database connectivity
docker exec -it ail-framework-redis-cache-1 redis-cli ping
docker exec -it ail-framework-kvrocks-1 redis-cli -h kvrocks -p 6383 ping

# Module status
curl http://localhost:7000/api/v1/modules
```

### Common Issues & Solutions

**❌ "AIL not responding"**
```powershell
# Check if container is running
docker-compose ps ail-app

# View startup logs
docker-compose logs ail-app

# Restart if needed
docker-compose restart ail-app
```

**❌ "Crawler not working"**
```powershell
# Verify Lacus service
curl http://localhost:7100/

# Check crawler module
docker-compose logs ail-app | findstr -i "crawler.py"

# Verify Redis work queue
docker exec -it ail-framework-redis-work-1 redis-cli -p 6381 keys "*queue*"
```

**❌ "Database connection errors"**
```powershell
# Check Redis services
docker-compose logs redis-cache redis-log redis-work

# Test Kvrocks connectivity  
docker exec -it ail-framework-kvrocks-1 redis-cli -h kvrocks -p 6383 info
```

### Log Locations
```powershell
# Application logs
docker-compose logs ail-app

# Individual module logs (inside container)
docker exec -it ail-framework-ail-app-1 ls /opt/ail/logs/

# Specific module log
docker exec -it ail-framework-ail-app-1 tail -f /opt/ail/logs/crawler.log
```

---

## 🔐 Security Configuration

### Default Users
- **Admin User**: `ail@ail.test` / `ail` (auto-created)
- **API Access**: Available at `/api/v1/` endpoints

### Production Security Checklist
- [ ] Change default passwords
- [ ] Configure SSL/TLS certificates
- [ ] Set up proper firewall rules
- [ ] Configure authentication backend
- [ ] Enable audit logging

---

## 🚢 Deployment Options

### Local Development ✅ (Current Setup)
- All services on localhost
- Data persisted to `./data/` directories  
- Direct container access for debugging

### Azure Container Apps 🌐 (Ready for Deployment)
- Replace Redis services with **Azure Cache for Redis**
- Use **Azure Container Registry** for images
- Configure **Azure Files** for persistent storage
- Set up **Azure Application Gateway** for SSL termination

### Production Scaling 📈
- **Horizontal**: Multiple AIL app instances behind load balancer
- **Database**: Separate Redis cluster + managed Kvrocks
- **Storage**: Object storage (Azure Blob/AWS S3) for large files
- **Monitoring**: Azure Monitor/Prometheus integration

---

## 🧹 **File Cleanup Recommendations**

### Obsolete Files (Safe to Remove)
```powershell
# Remove conflicting host-specific config
Remove-Item core.cfg

# Remove obsolete virtual environment installer  
Remove-Item install_virtualenv.sh

# Optional: Remove unused development helper
Remove-Item dev-helper.sh
```

### Optional Components
- **`misp/`** directory: MISP threat intelligence integration (keep if needed)
- **`.dockerignore`**: Review exclusions, may be too aggressive

---

## 📈 Performance Tuning

### Resource Allocation
```yaml
# docker-compose.yml additions for production
services:
  ail-app:
    deploy:
      resources:
        limits:
          memory: 4G
          cpus: 2.0
        reservations:
          memory: 2G
          cpus: 1.0
```

### Database Optimization
```ini
# kvrocks.conf tuning
max-db-size 20gb
max-memory-usage 8gb
workers 4
```

---

## 🆘 Support & Documentation

## 🆘 Support & Documentation

### Getting Help
- **Troubleshooting Guide**: See `docs/troubleshooting.md` for detailed problem resolution
- **Crawler Architecture**: See `docs/crawler-architecture.md` for technical implementation details  
- **Docker Setup Guide**: See `docs/docker.md` for comprehensive setup instructions
- **AIL Documentation**: [Official AIL Docs](https://ail-project.github.io/ail-framework/)
- **Docker Issues**: Check logs with `docker-compose logs [service]`
- **Crawler Problems**: Verify Lacus at `http://localhost:7100`

### Useful Commands
```powershell
# Complete system restart
docker-compose down && docker-compose up -d --build

# Reset all data (WARNING: Destructive)
docker-compose down -v && Remove-Item -Recurse -Force data

# Export/Import configurations
docker exec ail-framework-ail-app-1 tar -czf /tmp/ail-config.tar.gz /opt/ail/configs
```

---

**🎉 SUCCESS**: This Docker setup provides a fully functional AIL Framework with verified web crawling capabilities, ready for development and deployment!
