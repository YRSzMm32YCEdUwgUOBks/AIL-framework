# AIL Framework - Docker Containerization

This repository contains a complete containerized setup for the AIL (Analysis Information Leak) Framework with local development support and a clear path to Azure Container Apps deployment.

## 🏗️ Architecture Overview

```
AIL-Framework/
├── ail-framework/           # AIL application container
│   ├── Dockerfile          # Custom AIL container image
│   ├── docker-entrypoint.sh # Container startup script
│   ├── core.cfg            # AIL configuration for containers
│   └── kvrocks.conf        # KVrocks database configuration
├── misp/                   # MISP threat intelligence platform
│   ├── docker-compose.yml # MISP services
│   └── env/               # Environment configurations
├── data/                  # Persistent data volumes
└── docker-compose.yml    # Main orchestration file
```

## 🚀 Quick Start

### Prerequisites

- Docker Desktop for Windows
- Docker Compose
- At least 8GB RAM available for containers
- 20GB free disk space

### 1. Clone and Setup

```powershell
# Clone the AIL framework (if not already done)
git clone https://github.com/ail-project/ail-framework.git ail-framework

# Navigate to the project directory
cd ail-framework
```

### 2. Build and Launch AIL

```powershell
# Build and start all services
docker-compose up --build

# Or run in background
docker-compose up -d --build
```

### 3. Verify Installation

**Check AIL Web Interface:**
- Open browser to `http://localhost:7000`
- Default login: Check AIL documentation for default credentials

**Test AIL API:**
```powershell
# Check API status
curl http://localhost:7000/api/v1/modules

# Check system health
curl http://localhost:7000/api/v1/health
```

### 4. View Logs

```powershell
# View all logs
docker-compose logs

# View specific service logs
docker-compose logs ail-app
docker-compose logs redis-cache
docker-compose logs kvrocks
```

## 🔧 Configuration

### AIL Configuration

The `core.cfg` file has been pre-configured for container deployment:

- **Flask Server**: Binds to `0.0.0.0:7000` for external access
- **Redis Services**: Points to containerized Redis instances
- **KVrocks**: Configured for container networking
- **Data Paths**: Set for volume mounting

### Environment Variables

You can customize the deployment using environment variables:

```yaml
environment:
  FLASK_HOST: 0.0.0.0
  FLASK_PORT: 7000
  AIL_HOME: /opt/ail
  AIL_BIN: /opt/ail/bin
  AIL_FLASK: /opt/ail/var/www
```

### Data Persistence

Data is persisted using Docker volumes and bind mounts:

- **Pastes**: `./data/pastes` → `/opt/ail/PASTES`
- **Screenshots**: `./data/screenshots` → `/opt/ail/CRAWLED_SCREENSHOT`
- **Images**: `./data/images` → `/opt/ail/IMAGES`
- **Redis Data**: Docker named volumes
- **KVrocks Data**: `./data/kvrocks`

## 🔍 MISP Integration

### Setup MISP (Optional)

```powershell
# Navigate to MISP directory
cd misp

# Start MISP services
docker-compose up -d

# Wait for initialization (may take 5-10 minutes)
docker-compose logs -f misp
```

### Access MISP

- URL: `http://localhost:8080`
- Default credentials: `admin@admin.test` / `admin`
- **Important**: Change default passwords in production!

### Configure AIL → MISP Integration

1. Get MISP API key from MISP interface
2. Configure AIL's MISP exporter module
3. Test connectivity between services

## 🐛 Troubleshooting

### Common Issues

**Port Conflicts:**
```powershell
# Check if ports are in use
netstat -an | findstr ":7000"
netstat -an | findstr ":8080"
```

**Container Startup Issues:**
```powershell
# Check container status
docker-compose ps

# Inspect specific container
docker-compose logs ail-app

# Restart services
docker-compose restart
```

**Database Connection Issues:**
```powershell
# Test Redis connectivity
docker exec -it $(docker-compose ps -q redis-cache) redis-cli ping

# Test KVrocks connectivity
docker exec -it $(docker-compose ps -q kvrocks) redis-cli -h kvrocks -p 6383 ping
```

**Memory Issues:**
```powershell
# Check container resource usage
docker stats

# Increase Docker Desktop memory allocation if needed
```

### Reset Environment

```powershell
# Stop all services
docker-compose down

# Remove volumes (WARNING: This deletes all data!)
docker-compose down -v

# Remove images
docker-compose down --rmi all

# Clean rebuild
docker-compose up --build --force-recreate
```

## ☁️ Azure Container Apps Deployment

### Preparation Steps

1. **Push to Azure Container Registry (ACR)**
```bash
# Build and tag image
docker build -t myacr.azurecr.io/ail-framework:latest ./ail-framework

# Push to ACR
docker push myacr.azurecr.io/ail-framework:latest
```

2. **Replace Local Services with Azure PaaS**
   - **Redis**: Azure Cache for Redis
   - **KVrocks**: Azure Cache for Redis (separate instance)
   - **Storage**: Azure File Share for persistent data
   - **Database**: Azure Database for MariaDB (for MISP)

3. **Configuration Changes for ACA**
```yaml
# Update core.cfg for Azure services
[Redis_Cache]
host = your-redis-cache.redis.cache.windows.net
port = 6380
password = your-redis-key

[Kvrocks_DB]
host = your-kvrocks-redis.redis.cache.windows.net
port = 6380
password = your-kvrocks-key
```

4. **Deploy Container App**
```bash
# Create Container App
az containerapp create \
  --name ail-framework \
  --resource-group myResourceGroup \
  --environment myContainerEnv \
  --image myacr.azurecr.io/ail-framework:latest \
  --target-port 7000 \
  --ingress external
```

### Environment Variables for ACA

```yaml
env:
- name: FLASK_HOST
  value: "0.0.0.0"
- name: FLASK_PORT
  value: "7000"
- name: REDIS_CACHE_HOST
  secretRef: redis-cache-host
- name: REDIS_CACHE_PASSWORD
  secretRef: redis-cache-password
```

## 📊 Monitoring

### Health Checks

AIL provides several endpoints for monitoring:

- `http://localhost:7000/api/v1/health` - Overall health
- `http://localhost:7000/api/v1/modules` - Module status
- `http://localhost:7000/api/v1/stats` - System statistics

### Metrics

Monitor key metrics:
- Container CPU/Memory usage
- Redis connection pools
- Queue depths
- Processing rates

## 🔒 Security Considerations

### Local Development

- Change default passwords in `misp/env/` files
- Use strong passwords for production deployment
- Limit network exposure (use `127.0.0.1` instead of `0.0.0.0` for local-only access)

### Production Deployment

- Use Azure Key Vault for secrets
- Enable HTTPS/TLS termination
- Configure firewall rules
- Regular security updates
- Monitor access logs

## 📚 Additional Resources

- [AIL Framework Documentation](https://github.com/ail-project/ail-framework)
- [MISP Documentation](https://www.misp-project.org/)
- [Azure Container Apps Documentation](https://docs.microsoft.com/en-us/azure/container-apps/)
- [Docker Compose Reference](https://docs.docker.com/compose/)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test locally using Docker Compose
5. Submit a pull request

## 📄 License

This project maintains the same license as the original AIL Framework. See `LICENSE` file for details.

---

**Note**: This containerization setup prioritizes simplicity and portability. For production deployments, consider additional security hardening, monitoring, and backup strategies.
