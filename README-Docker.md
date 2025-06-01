# AIL Framework - Unified Docker Orchestration 🐳

> **This README is a high-level entry point for Docker users. For full details, troubleshooting, and advanced usage, see [`docs/docker.md`](docs/docker.md).**

This repository provides a **complete, scalable, and modular containerized setup** for the AIL (Analysis Information Leak) Framework, including the Lacus web crawler as a separate, independently managed service.

---

## ✅ Quick Start (Summary)

1. **Clone Repository & Initialize Submodules**
   ```powershell
   git clone https://github.com/YRSzMm32YCEdUwgUOBks/AIL-framework.git ail-framework
   cd ail-framework
   git submodule init
   git submodule update
   ```
2. **Start All Services** (Recommended: use Makefile or scripts)
   ```powershell
   make start-all
   # or
   scripts/start-all.ps1 up
   # or (Linux/macOS)
   ./scripts/start-all.sh up
   ```
3. **Access Web UI**: [http://localhost:7000](http://localhost:7000)  (Default login: `ail@ail.test` / `ail`)

---

## 🏗️ Architecture Overview

```
AIL Docker Stack
├── ail-app (Port 7000)          # Main AIL application with Flask UI
├── lacus (Port 7100)            # Web crawler service (modular stack)
├── redis-cache (6379)           # Core caching and operations
├── redis-log (6380)             # Logging and debugging
├── redis-work (6381)            # Work queues and job processing
├── kvrocks (6383)               # Persistent key-value storage
├── valkey (6385)                # Lacus crawler backend
└── tor_proxy                    # Tor proxy for .onion crawling
```

---

## 📚 Full Docker Guide & Advanced Usage

- **Complete Docker Setup, Troubleshooting, and Environment Details:**
  - [`docs/docker.md`](docs/docker.md) *(canonical, up-to-date guide)*
- **Environment Configuration:**
  - [`docs/environment-configuration.md`](docs/environment-configuration.md)
- **Deployment Scenarios:**
  - [`docs/deployment-scenarios.md`](docs/deployment-scenarios.md)
- **Troubleshooting:**
  - [`docs/troubleshooting.md`](docs/troubleshooting.md)
- **PowerShell Scripts Reference:**
  - [`docs/powershell-scripts.md`](docs/powershell-scripts.md)

---

## 🌍 Environment-Based Deployment

AIL Framework supports **automatic environment detection and configuration**. See [`docs/docker.md`](docs/docker.md#environment-based-deployment) for the environment matrix, quick start by environment, and all configuration details.

---

## 🆘 Support & Documentation

- **Full Docker Setup Guide:** [`docs/docker.md`](docs/docker.md)
- **Troubleshooting:** [`docs/troubleshooting.md`](docs/troubleshooting.md)
- **Crawler Architecture:** [`docs/crawler-architecture.md`](docs/crawler-architecture.md)
- **Official AIL Documentation:** [https://ail-project.github.io/ail-framework/](https://ail-project.github.io/ail-framework/)

---

**For all advanced usage, troubleshooting, and environment-specific instructions, always refer to [`docs/docker.md`](docs/docker.md).**
