# AIL Framework - Environment Configuration Guide 🌍

> **Note:** The Docker build and Compose structure are used for both local and cloud deployments. Only the environment variables, secrets, and some config files change. See the [Docker Setup Guide](usage-docker.md) and [Azure Migration Guide](migrate-local-to-azure.md) for details.

This comprehensive guide explains the AIL Framework's environment-based configuration system, supporting different deployment scenarios from local development to production cloud deployments.

## 📋 Overview

The AIL Framework uses an **environment-based configuration system** that automatically detects and loads the appropriate configuration based on your deployment target. This ensures consistent behavior across development, testing, and production environments.

### 🎯 **Supported Environments**

| Environment | Use Case | Deployment Target | Configuration Base |
|-------------|----------|-------------------|-------------------|
| **`dev-local`** | Local development with Docker | Docker Compose | Based on `core.cfg` |
| **`test-cloud`** | Cloud testing and staging | Azure/AWS/GCP | Based on `azure.cfg` |
| **`prod-cloud`** | Production cloud deployment | Azure/AWS/GCP | Based on `test-cloud.cfg` |

---

## 🏗️ Architecture

### Environment Detection Flow
```
1. Check DEPLOYMENT_ENV environment variable
2. Check AIL_ENV environment variable  
3. Fall back to 'dev-local' default
4. Validate environment exists
5. Load base config + environment overrides
6. Substitute environment variables
7. Route to appropriate deployment method
```

### Configuration Structure
```
configs/
├── core.cfg                    # Base local configuration
├── azure.cfg                   # Base cloud configuration
└── environments/
    ├── dev-local.cfg           # Local Docker development
    ├── test-cloud.cfg          # Cloud testing/staging
    └── prod-cloud.cfg          # Production cloud deployment
```

---

## 🚀 Getting Started

### 1. **Local Development** (`dev-local`)

For local development using Docker Compose with all services containerized:

```bash
# Set environment (optional - this is the default)
export DEPLOYMENT_ENV=dev-local

# Start with Docker Compose
cd ail-framework
docker-compose -f configs/docker/docker-compose.ail.yml \
               -f configs/docker/docker-compose.dev-local.yml up
```

**Features:**
- ✅ All services in Docker containers
- ✅ Debug mode enabled
- ✅ Hot reload for development
- ✅ Local Redis instances
- ✅ Verbose logging
- ✅ Development ports exposed

### 2. **Cloud Testing** (`test-cloud`)

For testing in cloud environments with external services:

```bash
# Set environment
export DEPLOYMENT_ENV=test-cloud

# Set required cloud variables
export AZURE_REDIS_HOST="your-redis.redis.cache.windows.net"
export AZURE_REDIS_PASSWORD="your-redis-password"
export LACUS_URL="https://your-lacus-instance.com"
export FLASK_SECRET_KEY="your-secret-key"

# Deploy (method depends on cloud provider)
# For Docker testing:
docker-compose -f configs/docker/docker-compose.ail.yml \
               -f configs/docker/docker-compose.test-cloud.yml up
```

**Features:**
- ✅ Cloud Redis/database services
- ✅ External crawler (Lacus)
- ✅ Production-like settings
- ✅ Health checks enabled
- ✅ Integration testing ready

### 3. **Production Cloud** (`prod-cloud`)

For production deployments with enterprise features:

```bash
# Set environment
export DEPLOYMENT_ENV=prod-cloud

# Set production variables (use Azure Key Vault, AWS Secrets, etc.)
export AZURE_REDIS_HOST="prod-redis.redis.cache.windows.net"
export AZURE_REDIS_PASSWORD="$(az keyvault secret show --name redis-password --vault-name prod-vault --query value -o tsv)"
# ... other production secrets

# Deploy using your cloud deployment method
# (Azure Container Apps, AWS ECS, GCP Cloud Run, etc.)
```

**Features:**
- ✅ Enterprise security settings
- ✅ Performance optimizations  
- ✅ Monitoring and alerting
- ✅ High availability configuration
- ✅ Production logging levels

---

## ⚙️ Configuration Management

### Using the Configuration Manager

The AIL Framework includes a powerful configuration manager at `bin/lib/environment_config.py`:

```bash
# Validate environment configuration
python bin/lib/environment_config.py --validate --environment dev-local

# Get specific configuration values
python bin/lib/environment_config.py --get Redis host --environment test-cloud

# Export environment variables
python bin/lib/environment_config.py --export-env --environment prod-cloud

# Show environment information
python bin/lib/environment_config.py --info --environment dev-local
```

### Environment Variables

The system supports environment variable substitution in configuration files:

```ini
# In test-cloud.cfg
[Redis]
host = ${AZURE_REDIS_HOST}
password = ${AZURE_REDIS_PASSWORD}

# In dev-local.cfg  
[Redis]
host = redis-cache
password = 
```

### Validation

All environments are automatically validated on startup:

```bash
# Manual validation
cd ail-framework
python bin/lib/environment_config.py --validate --environment dev-local
# Output: Configuration valid: True

# Validation during container startup
docker logs ail-app
# Output: ✓ Environment configuration validated successfully
```

---

## 🐳 Docker Integration

### Docker Compose Structure

The Docker setup uses a **base + override** pattern:

```
configs/docker/
├── docker-compose.ail.yml        # Base services (Redis, KVRocks, AIL)
├── docker-compose.dev-local.yml  # Development overrides
├── docker-compose.test-cloud.yml # Testing overrides  
└── docker-compose.lacus.yml      # Optional Lacus crawler
```

### Usage Patterns

```bash
# Development
docker-compose -f configs/docker/docker-compose.ail.yml \
               -f configs/docker/docker-compose.dev-local.yml up

# Testing with crawler
docker-compose -f configs/docker/docker-compose.ail.yml \
               -f configs/docker/docker-compose.test-cloud.yml \
               -f configs/docker/docker-compose.lacus.yml up

# Custom combinations
docker-compose -f configs/docker/docker-compose.ail.yml \
               -f configs/docker/docker-compose.dev-local.yml \
               -f configs/docker/docker-compose.lacus.yml up
```

### Smart Entrypoint

The `smart-entrypoint.sh` script automatically:
1. Detects the environment from `DEPLOYMENT_ENV`
2. Validates the configuration
3. Routes to the appropriate startup method
4. Exports environment-specific variables

---

## 🔧 Customization

### Adding New Environments

1. **Create Configuration File**:
```bash
cp configs/environments/dev-local.cfg configs/environments/my-env.cfg
```

2. **Update Environment List**:
```python
# In bin/lib/environment_config.py
SUPPORTED_ENVIRONMENTS = ['dev-local', 'test-cloud', 'prod-cloud', 'my-env']
```

3. **Create Docker Override** (optional):
```yaml
# configs/docker/docker-compose.my-env.yml
services:
  ail-app:
    environment:
      - DEPLOYMENT_ENV=my-env
```

### Configuration Inheritance

Environments can inherit from base configurations:

```ini
# configs/environments/my-custom.cfg
# Based on dev-local.cfg with custom Redis settings

[Environment]
name = my-custom
type = development
deployment_target = docker

# Inherits all other sections from dev-local.cfg
# Override only what you need to change
[Redis]
host = my-custom-redis
port = 6380
```

---

## 🧪 Testing

### Validate All Environments

```bash
# Test all environments
for env in dev-local test-cloud prod-cloud; do
    echo "Testing $env..."
    python bin/lib/environment_config.py --validate --environment $env
done
```

### Integration Testing

```bash
# Test dev-local environment
export DEPLOYMENT_ENV=dev-local
docker-compose -f configs/docker/docker-compose.ail.yml \
               -f configs/docker/docker-compose.dev-local.yml up -d
curl http://localhost:7000/api/v1/health

# Test with different environment
export DEPLOYMENT_ENV=test-cloud
# Set required cloud variables...
docker-compose -f configs/docker/docker-compose.ail.yml \
               -f configs/docker/docker-compose.test-cloud.yml up -d
```

---

## 🐛 Troubleshooting

### Common Issues

1. **Environment Not Found**:
```bash
Error: Unsupported environment: my-typo
# Fix: Check spelling, use --help to see supported environments
```

2. **Missing Environment Variables**:
```bash
WARNING - Environment variable not found: AZURE_REDIS_HOST
# Fix: Set required variables or use different environment
```

3. **Configuration Validation Failed**:
```bash
# Check configuration syntax
python bin/lib/environment_config.py --validate --environment test-cloud
```

### Debug Mode

```bash
# Enable debug logging
export LOG_LEVEL=DEBUG
export DEPLOYMENT_ENV=dev-local

# View detailed configuration loading
python bin/lib/environment_config.py --info --environment dev-local
```

### Logs and Monitoring

```bash
# Container logs
docker-compose logs ail-app

# Configuration manager logs
tail -f logs/ail-*.log

# Environment validation logs
python bin/lib/environment_config.py --validate --environment your-env
```

---

## 📚 Related Documentation

- [Docker Setup Guide](usage-docker.md) - Complete Docker deployment instructions
- [Azure Migration Guide](migrate-local-to-azure.md) - Moving from local to cloud
- [Troubleshooting Guide](troubleshooting-docker.md) - Common issues and solutions
- [Architecture Documentation](arch-redis.md) - System architecture details

---

## 🆘 Support

- **Issues**: GitHub Issues for bug reports
- **Discussions**: GitHub Discussions for questions
- **Chat**: Gitter for real-time help
- **Documentation**: Check all docs/ folder files

Happy configuring! 🚀
