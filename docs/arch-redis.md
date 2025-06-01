# Redis & KV Store Architecture

> **Note:** This document may be partially obsolete or redundant. For up-to-date Redis/KV architecture, see the main [Docker Setup Guide](usage-docker.md#database-architecture-explained) and [Environment Configuration Guide](usage-environment.md). Consider merging or pruning this file in the future.

```yaml
# configs/redis-map.yaml  (single source of truth)
cache:   { db: 0,  prefix: "ail__cache__",  notes: "was redis-cache:6379" }
log:     { db: 1,  prefix: "ail__log__",    notes: "was redis-log:6380" }
queue:   { db: 2,  prefix: "ail__queue__",  notes: "was redis-work:6381" }
store:   { db: 10, prefix: "ail__store__",  notes: "was kvrocks:6383" }
crawler: { db: 4,  prefix: "lacus__",       notes: "was valkey:6385" }
```

* **Generated env-file** `configs/redis.env` powers both Docker compose and ACA.
* Change a DB number once → rebuild → every environment updated.
* Premium Redis snapshots enabled only in *prod* param file (see Azure doc).

