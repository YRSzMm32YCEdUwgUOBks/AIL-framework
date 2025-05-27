
# AIL Framework - Unified Docker Orchestration 🐳

This repository provides a **complete, scalable, and modular containerized setup** for the AIL (Analysis Information Leak) Framework, including the Lacus web crawler as a separate, independently managed service. This README is your high-level starting point—see [`docs/docker.md`](docs/docker.md) for full details and advanced usage.


## ✅ **STATUS: FULLY OPERATIONAL**
- **Container Infrastructure**: All core and crawler services running ✅
- **Web Crawler**: End-to-end submission and processing verified ✅
- **Database Connectivity**: Redis, Kvrocks, Valkey all connected ✅
- **Web Interface**: Login, dashboard, and crawler UI working ✅
- **Module Processing**: 650+ AIL modules running ✅

---


## 🏗️ Architecture Overview

```
AIL Docker Stack
├── ail-app (Port 7000)          # Main AIL application with Flask UI
├── lacus (Port 7100)            # Web crawler service (runs as a separate, modular stack)
├── redis-cache (6379)           # Core caching and operations
├── redis-log (6380)             # Logging and debugging
├── redis-work (6381)            # Work queues and job processing
├── kvrocks (6383)               # Persistent key-value storage
├── valkey (6385)                # Lacus crawler backend
└── tor_proxy                    # Tor proxy for .onion crawling
```

> **Note:** The Lacus crawler and its dependencies are orchestrated via a separate Docker Compose file for modularity and scalability. You can start/stop Lacus independently, scale it separately, or even run it on different infrastructure if needed. See below for orchestration commands.

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
git clone https://github.com/YRSzMm32YCEdUwgUOBks/AIL-framework.git ail-framework
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

### 3. Orchestration: Start All Services

#### **Recommended: Use the Makefile (cross-platform)**

```powershell
# Start all AIL and Lacus services (auto-detects your OS)
make start-all

# Stop all services
make stop-all

# Restart all services
make restart-all

# Check status
make status
```

#### **Or: Use the orchestration scripts directly**

- **Windows/PowerShell:**
  ```powershell
  scripts/start-all.ps1 up
  scripts/start-all.ps1 down
  scripts/start-all.ps1 status
  ```
- **Linux/macOS/Bash:**
  ```bash
  ./scripts/start-all.sh up
  ./scripts/start-all.sh down
  ./scripts/start-all.sh status
  ```

#### **Manual Docker Compose (Advanced/Optional)**

```bash
# Create the shared network (if not already present)
docker network create ail-net --driver bridge

# Start Lacus services (separate stack)
docker-compose -f docker-compose.lacus.yml up -d

# Start AIL services
docker-compose -f docker-compose.yml up -d

# Stop services (reverse order)
docker-compose -f docker-compose.yml down
docker-compose -f docker-compose.lacus.yml down
```

### 4. Access Web Interface 🌐
- **AIL Web UI**: [http://localhost:7000](http://localhost:7000)
- **Lacus API**: [http://localhost:7100](http://localhost:7100)
- **Default Login**: `ail@ail.test` / `ail`

---


## 🕷️ **Web Crawler (Lacus) Usage**

The Lacus crawler is now a **separate, modular service**. You can:
- Start/stop Lacus independently for development or scaling
- Run multiple Lacus instances for higher throughput
- Develop or debug Lacus in isolation

**Typical workflow:**
1. **Login** to the AIL web interface: [http://localhost:7000](http://localhost:7000)
2. **Navigate**: `Crawlers → Crawler Splash`
3. **Enter URL** and submit
4. **Monitor logs** using Makefile/scripts or Docker Compose as above

---

host = 0.0.0.0
host = redis-cache
host = kvrocks

## 🔧 Configuration Overview

- **AIL Main Config:** `configs/docker/core.cfg` (container-optimized)
- **Lacus Config:** `configs/lacus/docker.generic.json`
- **Kvrocks Config:** `kvrocks.conf` (database settings)
- **Docker Compose:** `docker-compose.yml` (AIL), `docker-compose.lacus.yml` (Lacus)
- **Container Startup:** `docker-entrypoint.sh` (initialization script)

---


## 💾 Data Persistence

All important data is persisted outside containers:

| Data Type   | Host Path           | Container Path           | Purpose            |
|-------------|---------------------|--------------------------|--------------------|
| Pastes      | `./data/pastes`     | `/opt/ail/PASTES`        | Analyzed content   |
| Screenshots | `./data/screenshots`| `/opt/ail/CRAWLED_SCREENSHOT` | Web captures |
| Images      | `./data/images`     | `/opt/ail/IMAGES`        | Extracted images   |
| Logs        | `./data/logs`       | `/opt/ail/logs`          | Application logs   |
| Kvrocks DB  | `./data/kvrocks`    | `/opt/kvrocks/data`      | Persistent database|
| Lacus Data  | `./data/lacus`      | `/opt/lacus/data`        | Crawler data       |

---


## 📊 Monitoring & Troubleshooting

See [`docs/docker.md`](docs/docker.md) for detailed troubleshooting, health checks, and advanced monitoring tips.

---


## 🔐 Security Configuration

- **Admin User**: `ail@ail.test` / `ail` (auto-created)
- **API Access**: Available at `/api/v1/` endpoints

See [`docs/docker.md`](docs/docker.md) for production security checklist and best practices.

---


## 🚢 Deployment & Scaling

- **Local Development:** All services run on localhost, with data persisted to `./data/` directories.
- **Lacus Separation:** The Lacus crawler stack is fully modular—start/stop/scale it independently for development, testing, or production scaling.
- **Production Scaling:**
  - Run multiple AIL or Lacus instances behind a load balancer
  - Use managed Redis/Kvrocks/Valkey for high availability
  - Store large files in object storage (Azure Blob, AWS S3, etc.)
  - Integrate with monitoring tools (Prometheus, Azure Monitor, etc.)

See [`docs/docker.md`](docs/docker.md) for cloud deployment, advanced scaling, and infrastructure options.

---


## 🧹 File Cleanup & Optional Components

See [`docs/docker.md`](docs/docker.md) for file cleanup recommendations and optional component details.

---


## 📈 Performance Tuning

See [`docs/docker.md`](docs/docker.md) for resource allocation, database optimization, and performance tuning tips.

---


## 🆘 Support & Documentation

- **Full Docker Setup Guide:** [`docs/docker.md`](docs/docker.md)
- **Troubleshooting:** [`docs/troubleshooting.md`](docs/troubleshooting.md)
- **Crawler Architecture:** [`docs/crawler-architecture.md`](docs/crawler-architecture.md)
- **Official AIL Documentation:** [https://ail-project.github.io/ail-framework/](https://ail-project.github.io/ail-framework/)

For Docker issues, check logs with `make logs` or the orchestration scripts. For crawler problems, verify Lacus at [http://localhost:7100](http://localhost:7100).

---

**🎉 SUCCESS:** This unified Docker setup provides a fully functional, modular, and scalable AIL Framework with verified web crawling capabilities. Start here, and see [`docs/docker.md`](docs/docker.md) for everything else!
