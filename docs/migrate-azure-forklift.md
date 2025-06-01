# 🚢 AIL Framework → Azure Container Apps (ACA) Fork-Lift Guide

This guide moves the **local “Fully Operational” Docker stack** (AIL core + Lacus crawler)
into Azure Container Apps, replaces on-host Redis/KVrocks with Azure Cache for Redis, and
mounts an Azure File Share for persistent data.  
All containers remain **HTTP-only**; TLS is terminated by ACA ingress or Front Door.

---

## 0  Prerequisites

| Requirement | Command / Link |
|-------------|----------------|
| Azure CLI ≥ 2.55 | `az version` |
| Resource Group  | `az group create -g rg-threatlab -l westeurope` |
| Azure Container Registry (ACR) | `az acr create -g rg-threatlab -n acrthreatlab --sku Basic --admin-enabled true` |
| Docker images built locally | `ail-framework`, `lacus` |

---

## 1  Build & push images

```bash
REG=acrthreatlab.azurecr.io

# AIL core
docker build -t $REG/ail-framework:0.1 -f Dockerfile.ail .
docker push $REG/ail-framework:0.1

# Lacus crawler
docker pull ghcr.io/ail-project/lacus:latest
docker tag ghcr.io/ail-project/lacus:latest $REG/lacus:latest
docker push $REG/lacus:latest
```

---

## 2  Provision managed services

```bash
RG=rg-threatlab
LOC=westeurope

# 2-A  Redis (single instance, DB0-2 for cache/log/work, DB15 for Kvrocks replacement)
az redis create -g $RG -n redisThreatlab --sku Basic --vm-size C1

# 2-B  File share
az storage account create -g $RG -n stthreatlab --kind StorageV2 --sku Standard_LRS
az storage share-rm create --storage-account stthreatlab --name aildata
```

> **Keys**  
> Retrieve Redis key:  
> `REDIS_KEY=$(az redis list-keys -n redisThreatlab -g $RG --query primaryKey -o tsv)`

---

## 3  Create ACA environment

```bash
az containerapp env create \
  -n cae-threatlab \
  -g $RG \
  -l $LOC
```

---

## 4  Deploy container apps

### 4-A  AIL core

```bash
az containerapp create \
  -n ail-app \
  -g $RG \
  --environment cae-threatlab \
  --image $REG/ail-framework:0.1 \
  --target-port 7000 --ingress external \
  --cpu 1 --memory 2Gi \
  --registry-server $REG \
  --registry-username $(az acr credential show -n acrthreatlab --query username -o tsv) \
  --registry-password $(az acr credential show -n acrthreatlab --query passwords[0].value -o tsv) \
  --env-vars \
      LACUS_URL=http://lacus:7100 \
      REDIS_HOST=redisThreatlab.redis.cache.windows.net \
      REDIS_PORT=6380 \
      REDIS_SSL=true \
      REDIS_PASSWORD=$REDIS_KEY \
      KV_HOST=redisThreatlab.redis.cache.windows.net \
      KV_PORT=6380 \
      KV_SSL=true \
      KV_PASSWORD=$REDIS_KEY \
  --storage-mounts \
      "mountName=aildata,path=/opt/ail/PASTES,storageName=stthreatlab,shareName=aildata,accessMode=readwrite"
```

### 4-B  Lacus crawler

```bash
az containerapp create \
  -n lacus \
  -g $RG \
  --environment cae-threatlab \
  --image $REG/lacus:latest \
  --target-port 7100 --ingress internal \
  --cpu 1 --memory 1Gi \
  --env-vars \
      REDIS_HOST=redisThreatlab.redis.cache.windows.net \
      REDIS_PORT=6380 \
      REDIS_SSL=true \
      REDIS_PASSWORD=$REDIS_KEY
```

*(Skip Tor proxy for first deployment; add later if needed.)*

---

## 5  Network wiring

```
Internet ──TLS──▶ ACA Ingress ──HTTP──▶ ail-app :7000
                                    │
                                    │ internal HTTP
                                    └──▶ lacus :7100
Redis traffic: ail-app & lacus ──rediss://6380──▶ Azure Cache
Screenshots: ail-app ↔ Azure File Share ↔ lacus
```

* `LACUS_URL=http://lacus:7100` is injected as env-var, matching local compose.  
* Containers run **HTTP only**; ACA terminates TLS.

---

## 6  Smoke tests

```bash
AILURL=$(az containerapp show -n ail-app -g $RG --query properties.configuration.ingress.fqdn -o tsv)

# API ping
curl -k https://$AILURL/api/v1/ping   # → {"message":"pong"}

# UI open browser: https://$AILURL
# Submit crawl job in GUI, verify screenshot written to Azure File share "aildata"
```

Troubleshoot:

```bash
az containerapp logs show -n ail-app -g $RG --follow
```

---

## 7  Security posture

| Hop | Protocol | Encryption | Notes |
|-----|----------|------------|-------|
| User → ACA | HTTPS 1.2+ | ✅ managed cert | Custom domain via FrontDoor optional |
| ACA → Containers | HTTP | 🔶 inside env | Isolated VNet, no public route |
| Containers → Redis | rediss://6380 | ✅ TLS | Password in ACA secret |
| Containers → File share | SMB 3 | ✅ | Transport-encrypted |

Risks & mitigations:

* Same-env snooping → keep AIL/Lacus in dedicated ACA environment  
* Secrets in logs → store via `az containerapp secret set`, not inline env  
* Public exposure → Lacus ingress is **internal**; only ail-app is public  
* Compliance for E2E TLS → add Nginx sidecar or enable ACA mTLS preview if required

---

## 8  Next steps

* **Autoscale:**  
  ```bash
  az containerapp update -n ail-app -g $RG --scale-rule-name cpu --scale-rule-type cpu --scale-rule-metadata cpu=70
  ```
* **Tor proxy:** push `torproxy` image, create internal Container App `tor-proxy`, set `HTTP_PROXY` env in Lacus.  
* **MISP integration:** build `misp-core`, create Azure MySQL, reuse Redis, deploy Container App, set `MISP_KEY` secret in ail-app.  
* **KVrocks:** if Redis memory cost grows, build `kvrocks` image, deploy as stateful Container App with Azure Disk, change `KV_HOST`.

---

### TL;DR

1. **Push images to ACR**  
2. **Provision Redis + File share**  
3. **Create ACA env**  
4. **Deploy `ail-app` (public) and `lacus` (internal)**  
5. **Confirm `/api/v1/ping` and crawler workflow**  

Once green, you have a fully cloud-hosted AIL stack with Azure-level TLS, secrets, logs, and autoscaling.

---

- See [Docker Setup Guide](usage-docker.md) for building and pushing images.
- See [Environment Configuration Guide](usage-environment.md) for environment variables and config structure.