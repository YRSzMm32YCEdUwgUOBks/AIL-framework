# AIL Framework - Documentation Index 📚

Welcome to the comprehensive documentation for the AIL (Analysis Information Leak) Framework. This index helps you navigate to the right documentation based on your needs.

---

## 🚀 Quick Start & Index
- [Project Overview & Basic Setup](../README.md)
- [Docker Setup Guide (Local & Cloud)](usage-docker.md) *(Docker Compose is the foundation for all environments—see the new section on local-to-cloud deployment!)*
- [Azure Migration Guide](migrate-local-to-azure.md) *(How to deploy the same Docker images to Azure Container Apps)*
- [Azure Fork-Lift Guide](migrate-azure-forklift.md) *(Step-by-step cloud deployment)*

---

## 📖 Documentation by Use Case

### 🖥️ Developers & Contributors
| Document | Purpose | Key Topics |
|----------|---------|------------|
| [HOWTO.md](../HOWTO.md) | Development guide | Module creation, feeding data, environment setup |
| [README-workflow-testing.md](../README-workflow-testing.md) | Testing workflows | Test procedures, validation |
| [API Documentation](../doc/api.md) | API reference | REST endpoints, authentication |

### 🐳 DevOps & Infrastructure
| Document | Purpose | Key Topics |
|----------|---------|------------|
| [Docker Setup Guide](usage-docker.md) | Container orchestration | Docker Compose, environments, local-to-cloud |
| [Deployment Scenarios](usage-deployment-scenarios.md) | Infrastructure patterns | Local, cloud, hybrid deployments |
| [Environment Configuration](usage-environment.md) | Configuration management | dev-local, test-cloud, prod-cloud |
| [Troubleshooting Guide](troubleshooting-docker.md) | Issue resolution | Common problems, diagnostics |

### ☁️ Cloud Engineers
| Document | Purpose | Key Topics |
|----------|---------|------------|
| [Azure Migration Guide](migrate-local-to-azure.md) | Cloud migration | Step-by-step Azure deployment |
| [Azure Planning Guide](migrate-azure-forklift.md) | Migration planning | Architecture, costs, timeline |
| [Deployment Scenarios](usage-deployment-scenarios.md) | Cloud patterns | Azure, AWS, GCP examples |

### 🖼️ System Administrators
| Document | Purpose | Key Topics |
|----------|---------|------------|
| [Docker Guide](usage-docker.md) | Container management | Service orchestration, volumes, local-to-cloud |
| [Log Monitoring & Debugging](troubleshooting-logs.md) | Monitoring & debugging | Flask debug mode, log tailing, troubleshooting |
| [Troubleshooting](troubleshooting-docker.md) | System diagnostics | Logs, connectivity, performance |
| [PowerShell Scripts](automation-powershell.md) | Windows administration | Automation, environment management |

---

## 🌍 Environment-Specific Documentation

### Local Development (`dev-local`)
```bash
export DEPLOYMENT_ENV=dev-local
```
- [Docker Setup Guide](usage-docker.md#local-development)
- [HOWTO.md](../HOWTO.md#environment-configuration)
- [Troubleshooting](troubleshooting-docker.md#dev-local-environment)

### Cloud Testing (`test-cloud`)
```bash
export DEPLOYMENT_ENV=test-cloud
```
- [Docker Setup Guide](usage-docker.md#cloud-deployment)
- [Environment Configuration](usage-environment.md#cloud-testing)
- [Deployment Scenarios](usage-deployment-scenarios.md#scenario-2-cloud-testing)
- [Azure Migration Guide](migrate-local-to-azure.md)

### Production Cloud (`prod-cloud`)
```bash
export DEPLOYMENT_ENV=prod-cloud
```
- [Docker Setup Guide](usage-docker.md#cloud-deployment)
- [Deployment Scenarios](usage-deployment-scenarios.md#scenario-3-production-cloud)
- [Environment Configuration](usage-environment.md#production-cloud)
- [Troubleshooting](troubleshooting-docker.md#prod-cloud-environment)

---

## 🗑️ Obsolete/Redundant Docs (To Review)
- [arch-crawler.md](arch-crawler.md) *(Consider merging into Docker or Crawler guides)*
- [arch-crawler-troubleshooting.md](arch-crawler-troubleshooting.md) *(May be redundant with troubleshooting-docker.md)*
- [arch-redis.md](arch-redis.md) *(If not referenced elsewhere, merge or prune)*

---

**Note:** The Docker build and Compose structure are used for both local and cloud deployments. Only the environment variables, secrets, and some config files change. See the Docker guide and Azure migration guides for details.
