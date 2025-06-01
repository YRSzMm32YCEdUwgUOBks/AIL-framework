# AIL Framework - PowerShell Scripts Reference 🔧

This guide documents the PowerShell scripts available for managing the AIL Framework on Windows systems.

## 📋 Available Scripts

### **🚀 `scripts/start-all.ps1`** - Main Deployment Script

The primary script for starting AIL Framework with environment-aware configuration.

#### **Basic Usage**

```powershell
# Development environment (default)
.\scripts\start-all.ps1

# Specific environment
.\scripts\start-all.ps1 -Environment test-cloud

# With specific Docker Compose files
.\scripts\start-all.ps1 -Environment dev-local -ComposeFiles @("ail", "dev-local", "lacus")

# Clean build
.\scripts\start-all.ps1 -Build
```

#### **Command Reference**

| Parameter | Description | Default | Example |
|-----------|-------------|---------|---------|
| `-Environment` | Target environment | `dev-local` | `dev-local`, `test-cloud`, `prod-cloud` |
| `-ComposeFiles` | Compose file names | Auto-detected | `@("ail", "dev-local")` |
| `-Build` | Force rebuild containers | `$false` | `-Build` |
| `-Detached` | Run in background | `$true` | `-Detached:$false` |

#### **Special Commands**

```powershell
# Validate environment configuration
.\scripts\start-all.ps1 config

# Test all environment configurations
.\scripts\start-all.ps1 validate

# Show help
.\scripts\start-all.ps1 -Help
```

#### **Example Workflows**

```powershell
# 🏠 Local Development Workflow
.\scripts\start-all.ps1                           # Start dev-local
.\scripts\start-all.ps1 config                    # Validate configuration
docker-compose ps                                 # Check status
docker-compose logs ail-app --tail=20            # View logs

# ☁️ Cloud Testing Workflow  
$env:DEPLOYMENT_ENV = "test-cloud"
$env:AZURE_REDIS_HOST = "your-redis.cache.windows.net"
$env:AZURE_REDIS_PASSWORD = "your-password"
.\scripts\start-all.ps1 -Environment test-cloud  # Start with cloud config

# 🕷️ Development with Crawler
.\scripts\start-all.ps1 -ComposeFiles @("ail", "dev-local", "lacus")

# 🔄 Clean Rebuild
docker-compose down -v                           # Stop and remove volumes
.\scripts\start-all.ps1 -Build                   # Rebuild and start
```

---

## 🌍 Environment Integration

### **Automatic Environment Detection**

The scripts automatically detect environment from:
1. `-Environment` parameter
2. `$env:DEPLOYMENT_ENV` environment variable
3. `$env:AIL_ENV` environment variable  
4. Default to `dev-local`

```powershell
# Method 1: Parameter
.\scripts\start-all.ps1 -Environment test-cloud

# Method 2: Environment variable
$env:DEPLOYMENT_ENV = "test-cloud"
.\scripts\start-all.ps1

# Method 3: AIL-specific variable
$env:AIL_ENV = "dev-local"
.\scripts\start-all.ps1
```

### **Environment-Specific Compose Files**

The script automatically selects appropriate Docker Compose files:

| Environment | Base File | Override File | Optional |
|-------------|-----------|---------------|----------|
| `dev-local` | `ail.yml` | `dev-local.yml` | `lacus.yml` |
| `test-cloud` | `ail.yml` | `test-cloud.yml` | `lacus.yml` |
| `prod-cloud` | *Custom deployment* | *Not Docker-based* | *N/A* |

---

## ⚙️ Configuration Management

### **Environment Validation**

```powershell
# Validate current environment
.\scripts\start-all.ps1 config

# Validate specific environment
python bin\lib\environment_config.py --validate --environment test-cloud

# Test all environments
foreach ($env in @("dev-local", "test-cloud", "prod-cloud")) {
    Write-Host "Testing $env..." -ForegroundColor Yellow
    python bin\lib\environment_config.py --validate --environment $env
}
```

### **Configuration Inspection**

```powershell
# View environment information
python bin\lib\environment_config.py --info --environment dev-local

# Get specific configuration value
python bin\lib\environment_config.py --get Redis host --environment dev-local

# Export environment variables
python bin\lib\environment_config.py --export-env --environment test-cloud
```

---

## 🐳 Docker Operations

### **Container Management**

```powershell
# Start services
.\scripts\start-all.ps1

# Stop services  
docker-compose down

# Stop and remove volumes (clean slate)
docker-compose down -v

# View running containers
docker-compose ps

# View logs
docker-compose logs ail-app --tail=50
docker-compose logs -f ail-app  # Follow logs
```

### **Development Commands**

```powershell
# Rebuild specific service
docker-compose build ail-app

# Execute commands in container
docker-compose exec ail-app bash
docker-compose exec redis-cache redis-cli

# View container resource usage
docker stats

# Restart specific service
docker-compose restart ail-app
```

---

## 🔧 Troubleshooting

### **Common Issues**

#### **1. Environment Not Found**
```powershell
# Error: Environment 'my-typo' not supported
# Fix: Check spelling and supported environments
python bin\lib\environment_config.py --help
```

#### **2. Docker Compose File Not Found**
```powershell
# Error: docker-compose.my-env.yml not found
# Fix: Use supported environment or create override file
.\scripts\start-all.ps1 config  # Shows available files
```

#### **3. Port Already in Use**
```powershell
# Error: Port 7000 already in use
# Fix: Stop existing services or change port
docker-compose down
netstat -an | findstr :7000  # Check what's using the port
```

#### **4. Permission Denied (Windows)**
```powershell
# Error: Permission denied accessing Docker
# Fix: Run PowerShell as Administrator or add user to docker-users group
```

### **Debug Mode**

```powershell
# Enable verbose output
$env:LOG_LEVEL = "DEBUG"
.\scripts\start-all.ps1 -Environment dev-local

# View detailed Docker output
.\scripts\start-all.ps1 -Detached:$false  # Run in foreground

# Check configuration loading
python bin\lib\environment_config.py --info --environment dev-local
```

### **Reset Everything**

```powershell
# Complete reset (use with caution)
docker-compose down -v          # Stop and remove volumes
docker system prune -f          # Remove unused containers/images
docker volume prune -f          # Remove unused volumes
.\scripts\start-all.ps1 -Build  # Rebuild from scratch
```

---

## 📚 Related Documentation

- [Docker Setup Guide](usage-docker.md) - Docker deployment instructions
- [Environment Configuration Guide](usage-environment.md) - Complete environment setup
- [Troubleshooting Guide](troubleshooting-docker.md) - Common issues and solutions

---

## 🎯 Quick Reference

### **Most Common Commands**

```powershell
# Start development environment
.\scripts\start-all.ps1

# Start with web crawler
.\scripts\start-all.ps1 -ComposeFiles @("ail", "dev-local", "lacus")

# Validate configuration
.\scripts\start-all.ps1 config

# Stop everything
docker-compose down

# Clean restart
docker-compose down -v && .\scripts\start-all.ps1 -Build
```

### **Environment Variables**

```powershell
# Development
$env:DEPLOYMENT_ENV = "dev-local"

# Cloud testing
$env:DEPLOYMENT_ENV = "test-cloud"
$env:AZURE_REDIS_HOST = "your-redis.cache.windows.net"
$env:AZURE_REDIS_PASSWORD = "your-password"
$env:LACUS_URL = "https://your-lacus.com"
$env:FLASK_SECRET_KEY = "your-secret"
```

Happy scripting! 🚀
