# From Monolith to Cloud-Native  
## Porting AIL Framework (+ Lacus) to Azure Container Apps

*Author: Blue-Team Fx*        *Date: 2025-05-31*


---

## 1  Why we touched the code at all  🗒️

| Pain in upstream repo | Impact | Cloud consequence |
|-----------------------|--------|-------------------|
| **All-in-one VM design** – `docker-compose.ail.yml` spawns 6+ containers but is meant to run on a single IaaS box. | • Ops sprawl  • No autoscale | ACA / K8s needs 1 image = 1 concern. |
| **Engine-named key prefixes** (`kvrocks__paste:*`, `valkey__sess:*`). | Ties code to a host-local port; breaks when we move to Azure Cache. | Use engine-agnostic prefixes (`ail__store__`). |
| **Five Redis processes + KVrocks** | Extra memory; unclear separation. | One managed Redis + logical DBs is enough (<250 MB). |
| **Multiple dev lineages** – original ARDB/KVrocks team vs Lacus team → duplicated choices. | Onboarding confusion. | Consolidate config in a single YAML map. |
| **Hard-wired DB numbers in code** | “Magic numbers” (e.g. 6381, DB 15) | Central map + env-expansion removes guesswork. |
| **No TLS when exposed** | Must run Nginx manually | ACA ingress gives free TLS certs. |

Outcome: **modernise the runtime** without breaking local “purist” Docker
testing, and deliver a one-click ACA deployment.

---

## 2  What we actually changed  🔨

### 2.1 New file `configs/redis-map.yaml`

```yaml
# Logical Redis mappings for AIL + Lacus
cache:   { db: 0,  prefix: "ail__cache__",  notes: "was redis-cache:6379" }
log:     { db: 1,  prefix: "ail__log__",    notes: "was redis-log:6380" }
queue:   { db: 2,  prefix: "ail__queue__",  notes: "was redis-work:6381" }
store:   { db: 10, prefix: "ail__store__",  notes: "was kvrocks:6383" }
crawler: { db: 4,  prefix: "lacus__",       notes: "was valkey:6385" }
```

*Comment-rich, one truth – change DB once, rebuild, done.*

### 2.2 Generated env file `configs/redis.env`

Created by `scripts/build-redis-env.py` at image-build time.

```
CACHE_DB=0
CACHE_PREFIX=ail__cache__
...
STORE_DB=10
STORE_PREFIX=ail__store__
```

### 2.3 Patched `configs/docker/core.cfg`

```ini
[Redis_Cache]  db = ${CACHE_DB}  key_prefix = ${CACHE_PREFIX}  ssl = true
[Redis_Log]    db = ${LOG_DB}    key_prefix = ${LOG_PREFIX}    ssl = true
[Redis_Work]   db = ${QUEUE_DB}  key_prefix = ${QUEUE_PREFIX}  ssl = true
[KVrocks]      db = ${STORE_DB}  key_prefix = ${STORE_PREFIX}  ssl = true
```

### 2.4 Docker → ACA alignment

* `LACUS_URL` injected as env-var in both local compose and ACA.
* Redis connection goes to **Azure Cache port 6380 (TLS)** for every block.
* Mount Azure File share at `/opt/ail/PASTES` & `/opt/ail/CRAWLED_SCREENSHOT`.

### 2.5 Security hardening

* No plain-text secrets; ACA secrets store `REDIS_PASSWORD`.
* Only **ail-app** exposes public ingress (`https://*.azurecontainerapps.io`).
* Lacus, Tor proxy run **internal ingress** only.
* Redis & SMB links already encrypted; inside-env HTTP accepted by threat-model.

---

## 3  Step-by-step deploy (West Europe)

_This is the short recap; full CLI with explanations lives in
`docs/azure-deploy.md`._

```bash
# 1  Push images
docker build -t acr.../ail-framework:0.1 .
docker push acr.../ail-framework:0.1
docker tag ghcr.io/ail-project/lacus:latest acr.../lacus:latest
docker push acr.../lacus:latest

# 2  Managed services
az redis create -n redisThreatlab ...
az storage share-rm create --storage-account stthreatlab --name aildata

# 3  ACA env
az containerapp env create -n cae-threatlab ...

# 4a  ail-app
az containerapp create -n ail-app \
   --image acr.../ail-framework:0.1 \
   --env-vars-file configs/redis.env \
   --env-vars LACUS_URL=http://lacus:7100 \
   ...

# 4b  lacus
az containerapp create -n lacus \
   --image acr.../lacus:latest \
   --env-vars-file configs/redis.env \
   --ingress internal ...
```

Result: **TLS edge in ACA, single Redis, autoscaling ready.**

---

## 4  Cost snapshot (West Europe, May 2025)

| Resource (24×7) | SKU | €/mo |
|-----------------|-----|------|
| ACA compute 1½ vCPU / 3 GiB | Pay-go | 113 |
| Azure Cache for Redis Basic C1 | 250 MB | 41 |
| Azure Files 100 GB | Hot | 8 |
| ACR Basic | 10 GB | 4 |
| Bandwidth (100 GB) | egress | 7 |
| **Total** | | **≈ 173** |

*Set Lacus min-replicas = 0 → compute drops to 75 € → total ≈ 128 €.*

A single **B4ms VM** (monolithic compose) is ≈ 155 €/mo but
lacks autoscale, managed TLS, patching.

---

## 5  Open questions / future PR hooks  ❓

| Topic | Discussion |
|-------|------------|
| **KVrocks data size** | If >25 GB of `store` keys emerge, self-host KVrocks as a stateful Container App with Azure Disk and flip `STORE_HOST`. |
| **mTLS between apps** | ACA mTLS preview could replace internal HTTP; evaluate after GA. |
| **MISP integration** | Planned next: container-app `misp-core` with Azure Database for MySQL, API key secret `MISP_KEY` injected into ail-app. |
| **Key prefix migration script** | `scripts/redis-migrate-prefix.py` copies old `kvrocks__*` to new `ail__store__*`; delete DB 15 afterwards. |
| **CI/CD** | GitHub Actions workflow: build → push → `az containerapp update`; tag images by short SHA. |

---

## 6  Tasks for coding-assistant  🧑‍💻

1. **Implement** `configs/redis-map.yaml` + env generator script.
2. **Refactor** `core.cfg` to use `${…}` variables; remove hard-wired DB numbers.
3. **Search-and-replace** key prefixes in AIL Python modules:
   * `kvrocks__` → `ail__store__`
   * `valkey__`  → `lacus__`
4. **Update** Dockerfile to run the env-generator during build.
5. **Patch** `docker-compose.ail.yml` and `docker-compose.lacus.yml`
   to load `env_file: configs/redis.env`.
6. **Add** `docs/azure-deploy.md` (already drafted) and `docs/security.md`.
7. **CI smoke test** – run local `make start-all`, assert all modules fire and
   crawler returns screenshot.

---

## 7  Why this makes AIL stronger  🔒✨

* **Attack surface shrinks** – fewer daemons, no self-managed TLS stack.
* **Patching is automatic** – ACA images can be rebuilt nightly; Redis is PaaS.
* **Config as data** – one YAML governs every environment (laptop, ACA, AKS).
* **Cost control** – pay-by-second compute; Redis tier downgrade path; autoscale.
* **Ego-proof** – code reads *what* keys do (`ail__log__`) not *where* they used to live (`kvrocks__`).

> _“Monolith to modules without breaking the CLI.”_

We believe this PR makes AIL easier to run, audit, and
extend—whether on a single laptop or across multiple cloud tenants.

---

- See [Docker Setup Guide](usage-docker.md) for local-to-cloud workflow.
- See [Environment Configuration Guide](usage-environment.md) for environment variables and config structure.

