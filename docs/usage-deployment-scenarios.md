# AIL Framework - Deployment Scenarios Guide 🚀

> **Note:** The Docker build and Compose structure are used for both local and cloud deployments. Only the environment variables, secrets, and some config files change. See the [Docker Setup Guide](usage-docker.md) and [Azure Migration Guide](migrate-local-to-azure.md) for details.

This guide provides comprehensive deployment scenarios for the AIL Framework across different environments, infrastructures, and use cases.

## 📋 **Deployment Overview**

The AIL Framework supports multiple deployment patterns designed for different organizational needs and infrastructure capabilities.

### **Deployment Matrix**

| Scenario | Environment | Infrastructure | Services | Complexity |
|----------|-------------|----------------|----------|------------|
| **Local Development** | `dev-local` | Docker Desktop | All containerized | ⭐ Simple |
| **Cloud Testing** | `test-cloud` | Cloud VMs + Managed Services | Hybrid | ⭐⭐ Moderate |
| **Production Cloud** | `prod-cloud` | Enterprise Cloud | Fully managed | ⭐⭐⭐ Advanced |
| **On-Premises** | `dev-local` | Physical/VM | Self-hosted | ⭐⭐ Moderate |
| **Hybrid Cloud** | Mixed | Multi-cloud | Distributed | ⭐⭐⭐⭐ Expert |

---

## 🖥️ **Scenario 1: Local Development**

**Best for**: Individual developers, proof-of-concept, testing

### **Architecture**
```
Developer Machine
├── Docker Desktop
├── AIL Container (Port 7000)
├── Lacus Container (Port 7100)  
├── Redis Containers (6379-6383)
└── Tor Proxy Container
```

### **Quick Setup**
```bash
# Clone and configure
git clone https://github.com/ail-project/ail-framework.git
cd ail-framework

# Set environment (optional - this is default)
export DEPLOYMENT_ENV=dev-local

# Start everything
docker-compose -f configs/docker/docker-compose.ail.yml \
               -f configs/docker/docker-compose.dev-local.yml up -d

# Access AIL
open http://localhost:7000
```

### **Advantages**
- ✅ Zero external dependencies
- ✅ Complete offline capability
- ✅ Fast iteration and debugging
- ✅ Full control over all services

### **Limitations**
- ❌ Limited to single machine resources
- ❌ No high availability
- ❌ Not production-ready

---

## ☁️ **Scenario 2: Cloud Testing**

**Best for**: CI/CD pipelines, staging environments, integration testing

### **Architecture**
```
Cloud Environment
├── Container Service (Azure Container Apps, AWS ECS, GCP Cloud Run)
├── Managed Redis (Azure Cache, AWS ElastiCache, GCP Memorystore)
├── Managed Storage (Blob/S3/Cloud Storage)
└── Load Balancer
```

### **Azure Example Setup**
```bash
# Set environment
export DEPLOYMENT_ENV=test-cloud

# Configure Azure services
export AZURE_REDIS_HOST="ail-test.redis.cache.windows.net"
export AZURE_REDIS_PASSWORD="your-redis-access-key"
export AZURE_STORAGE_ACCOUNT="ailstorage"
export AZURE_STORAGE_KEY="your-storage-key"
export LACUS_URL="https://lacus-test.azurewebsites.net"

# Deploy using Azure Container Apps
az containerapp up --name ail-framework \
                   --resource-group ail-rg \
                   --location eastus \
                   --environment test-env \
                   --image ghcr.io/ail-project/ail-framework:latest
```

### **AWS Example Setup**
```bash
# Set environment  
export DEPLOYMENT_ENV=test-cloud

# Configure AWS services
export AWS_REDIS_ENDPOINT="ail-test.abc123.cache.amazonaws.com"
export AWS_S3_BUCKET="ail-data-bucket"
export LACUS_URL="https://lacus.example.com"

# Deploy using ECS
aws ecs create-service --cluster ail-cluster \
                      --service-name ail-framework \
                      --task-definition ail-task:1 \
                      --desired-count 2
```

### **Advantages**
- ✅ Managed database services
- ✅ Automatic scaling
- ✅ High availability options
- ✅ Integration with cloud monitoring

### **Considerations**
- ⚠️ Requires cloud service configuration
- ⚠️ Network latency to managed services
- ⚠️ Cloud service costs

---

## 🏢 **Scenario 3: Production Cloud**

**Best for**: Enterprise deployments, high-scale operations

### **Architecture**
```
Production Cloud (Multi-Region)
├── Container Orchestration (Kubernetes/OpenShift)
├── Enterprise Redis Cluster
├── High-Performance Storage
├── Load Balancer + CDN
├── Monitoring & Alerting
├── Backup & Disaster Recovery
└── Security & Compliance
```

### **Enterprise Setup**
```bash
# Set production environment
export DEPLOYMENT_ENV=prod-cloud

# Configure enterprise services
export REDIS_CLUSTER_ENDPOINT="prod-redis-cluster.internal"
export ENTERPRISE_STORAGE="enterprise-blob-storage"
export SECURITY_VAULT_URL="https://vault.company.com"
export MONITORING_ENDPOINT="https://monitoring.company.com"

# Deploy using Helm (Kubernetes)
helm install ail-framework ./charts/ail-framework \
             --namespace production \
             --values values-production.yaml
```

### **Features**
- ✅ High availability (99.9%+ uptime)
- ✅ Auto-scaling based on load
- ✅ Enterprise security integration
- ✅ Comprehensive monitoring
- ✅ Automated backups
- ✅ Disaster recovery

### **Requirements**
- 🔒 Enterprise security compliance
- 📊 Advanced monitoring setup
- 🔧 DevOps expertise required
- 💰 Higher infrastructure costs

---

## 🏠 **Scenario 4: On-Premises Deployment**

**Best for**: Air-gapped environments, strict data sovereignty requirements

### **Architecture**
```
On-Premises Infrastructure
├── Physical/Virtual Servers
├── Container Runtime (Docker/Podman)
├── Network Storage (NFS/SAN)
├── Internal Load Balancer
└── Local Monitoring
```

### **Setup**
```bash
# Use local environment configuration
export DEPLOYMENT_ENV=dev-local

# Customize for on-premises
export AIL_HOST_IP="192.168.1.100"
export REDIS_HOST="192.168.1.101"
export STORAGE_PATH="/mnt/ail-storage"

# Deploy with custom networking
docker-compose -f configs/docker/docker-compose.ail.yml \
               -f configs/docker/docker-compose.dev-local.yml \
               -f configs/docker/docker-compose.onprem.yml up -d
```

### **Advantages**
- ✅ Complete data control
- ✅ No internet dependency
- ✅ Custom security policies
- ✅ Predictable costs

### **Challenges**
- ❌ Manual infrastructure management
- ❌ Limited scalability
- ❌ Backup/DR complexity

---

## 🌐 **Scenario 5: Hybrid Cloud**

**Best for**: Gradual cloud migration, data residency requirements

### **Architecture**
```
Hybrid Infrastructure
├── On-Premises Core (Sensitive data)
├── Cloud Compute (Processing)
├── Cloud Storage (Archives)
├── Secure VPN/ExpressRoute
└── Data Synchronization
```

### **Phased Migration**
```bash
# Phase 1: Core on-premises
export DEPLOYMENT_ENV=dev-local
export AIL_CORE_HOST="on-prem.company.com"

# Phase 2: Add cloud processing
export CLOUD_PROCESSING_URL="https://ail-processing.azure.com"
export HYBRID_MODE=true

# Phase 3: Full cloud with data sync
export DEPLOYMENT_ENV=prod-cloud
export DATA_SYNC_ENDPOINT="sync.company.com"
```

---

## 🔧 **Deployment Tools & Scripts**

### **PowerShell Scripts (Windows)**
```powershell
# All-in-one deployment
.\scripts\start-all.ps1 -Environment test-cloud -Build

# Environment validation
.\scripts\start-all.ps1 validate

# Custom compose files
.\scripts\start-all.ps1 -ComposeFiles @("ail", "test-cloud", "monitoring")
```

### **Bash Scripts (Linux/macOS)**
```bash
# Quick development setup
./scripts/start-all.sh --environment dev-local

# Production deployment
./scripts/start-all.sh --environment prod-cloud --validate
```

### **Azure DevOps Pipeline**
```yaml
# azure-pipelines.yml
trigger:
  branches:
    include:
    - main
    - develop

pool:
  vmImage: 'ubuntu-latest'

variables:
  DEPLOYMENT_ENV: 'test-cloud'

steps:
- script: |
    export DEPLOYMENT_ENV=$(DEPLOYMENT_ENV)
    docker-compose -f configs/docker/docker-compose.ail.yml \
                   -f configs/docker/docker-compose.test-cloud.yml up -d
  displayName: 'Deploy AIL Framework'
```

---

## 📊 **Monitoring & Observability**

### **Health Checks by Environment**

```bash
# Development
curl http://localhost:7000/health

# Cloud Testing  
curl https://ail-test.company.com/health

# Production
curl https://ail-prod.company.com/health \
     -H "Authorization: Bearer $HEALTH_CHECK_TOKEN"
```

### **Logging Configuration**

| Environment | Log Level | Destination | Retention |
|-------------|-----------|-------------|-----------|
| `dev-local` | DEBUG | Console + File | 7 days |
| `test-cloud` | INFO | Cloud Logging | 30 days |
| `prod-cloud` | WARNING | Enterprise SIEM | 365 days |

---

## 🔐 **Security Considerations**

### **By Deployment Type**

| Deployment | Network Security | Data Encryption | Access Control |
|------------|------------------|-----------------|----------------|
| **Local** | Host firewall | At rest | Local users |
| **Cloud** | Cloud firewall + NSG | In transit + at rest | IAM + RBAC |
| **Enterprise** | WAF + DDoS protection | End-to-end | SSO + MFA |
| **On-Premises** | Physical + network | Custom encryption | Directory services |

---

## 📚 **Reference Documentation**

- 🐳 [Docker Setup Guide](usage-docker.md) - Complete Docker instructions  
- ☁️ [Azure Migration Guide](migrate-local-to-azure.md) - Cloud migration steps
- 🌍 [Environment Configuration Guide](usage-environment.md) - Detailed environment setup
- 🚨 [Troubleshooting Guide](troubleshooting-docker.md) - Common issues and solutions
- 🔧 [PowerShell Scripts Reference](automation-powershell.md) - Windows automation

---

## 🤝 **Support & Community**

- **GitHub Issues**: [Report bugs and feature requests](https://github.com/ail-project/ail-framework/issues)
- **Documentation**: [Full documentation](https://github.com/ail-project/ail-framework/tree/master/docs)
- **Community**: [Join our community discussions](https://gitter.im/ail-project/)

---

**Last Updated**: May 2025 | **Version**: 5.0+ | **Environment System**: v2.0
