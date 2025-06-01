# AIL Framework - Crawler/Lacus Troubleshooting

> **Note:** This document may be partially obsolete or redundant. For up-to-date troubleshooting, see the main [Troubleshooting Guide](troubleshooting-docker.md) and [Docker Setup Guide](usage-docker.md). Consider merging or pruning this file in the future.

# LACUS URL Undefined Error - Fix Documentation

## Problem Summary

The AIL Framework running on Azure Container Apps was showing "Lacus URL undefined" error on the `/crawlers/dashboard` portal despite:
- LACUS service being accessible at `https://lacus.internal.delightfulbay-9e24f820.westeurope.azurecontainerapps.io`
- LACUS_URL environment variable being correctly set in the container
- LACUS service returning proper Swagger UI responses

## Root Cause Analysis

The issue was found in `bin/lib/crawlers.py` line 2173:
```python
def ping_lacus():
    lacus_url = get_lacus()  # This returns None
    if not lacus_url:
        req_error = {'error': 'Lacus URL undefined', 'status_code': 400}
        # Error gets stored and displayed to user
```

The `get_lacus_url()` function (line 2117) retrieves the URL from Redis:
```python
def get_lacus_url():
    return r_db.hget('crawler:lacus', 'url')  # Returns None - key doesn't exist
```

**Configuration Gap Identified**: The `LACUS_URL` environment variable was not being injected into the Redis/Kvrocks database where the application expects to find it.

## Solution Implementation

### 1. Created LACUS URL Injection Script

**File**: `inject_lacus_url_fixed.py`

This script:
- Reads `LACUS_URL` environment variable
- Connects to Redis/Kvrocks database 3 (where crawler data is stored)
- Injects the URL using: `r.hset('crawler:lacus', 'url', lacus_url)`
- Verifies the injection was successful

### 2. Updated Azure Entry Point Scripts

**Files Modified**:
- `azure-entrypoint.sh`
- `azure-entrypoint-fixed.sh`

**Added post-initialization step**:
```bash
# Inject LACUS_URL into Redis/Kvrocks database
if [ -n "${LACUS_URL:-}" ]; then
    echo "🔗 Injecting LACUS_URL environment variable into Redis database..."
    python3 /opt/ail/inject_lacus_url_fixed.py
    if [ $? -eq 0 ]; then
        echo "✅ LACUS_URL injection successful"
    else
        echo "❌ LACUS_URL injection failed"
        exit 1
    fi
else
    echo "⚠️  WARNING: LACUS_URL environment variable not set"
fi
```

### 3. Created Diagnostic Tools

**File**: `diagnose_lacus.py`
- Comprehensive diagnostic script to check environment variables, Redis state, config files, and LACUS connectivity
- Can automatically fix the configuration if the environment variable exists but Redis key is missing

**File**: `test_lacus_logic.py`
- Simple test to validate the injection logic locally

## Key Technical Details

### Database Configuration
- **Environment Variable**: `LACUS_URL`
- **Redis Database**: 3 (Kvrocks_DB)
- **Redis Key**: `crawler:lacus` (hash)
- **Redis Field**: `url`
- **Command**: `HSET crawler:lacus url <LACUS_URL>`

### AIL Framework Data Flow
1. Web interface calls `ping_lacus()` in `bin/lib/crawlers.py`
2. `ping_lacus()` calls `get_lacus()` which calls `get_lacus_url()`
3. `get_lacus_url()` queries Redis: `r_db.hget('crawler:lacus', 'url')`
4. If Redis returns None, error is set and displayed to user

## Deployment Steps

### For New Deployments
1. Ensure the updated Azure entry point scripts are included in the container image
2. Ensure `inject_lacus_url_fixed.py` is included in the container image at `/opt/ail/`
3. The injection will happen automatically during container startup

### For Existing Deployments
1. Deploy the updated container image with the fixes
2. Or manually run the injection script in the running container:
   ```bash
   docker exec -it <container_name> python3 /opt/ail/inject_lacus_url_fixed.py
   ```

### Manual Verification
Check if the fix worked:
```bash
# Connect to Redis and verify the key exists
docker exec -it <container_name> python3 -c "
import redis, os
r = redis.Redis(
    host=os.environ['REDIS_CACHE_HOST'], 
    port=int(os.environ['REDIS_CACHE_PORT']), 
    password=os.environ['REDIS_CACHE_PASSWORD'], 
    db=3, ssl=True, ssl_cert_reqs=None, decode_responses=True
)
print('LACUS URL in Redis:', r.hget('crawler:lacus', 'url'))
"
```

## Files Modified/Created

### Modified Files
- `azure-entrypoint.sh` - Added LACUS URL injection step
- `azure-entrypoint-fixed.sh` - Added LACUS URL injection step

### New Files
- `inject_lacus_url_fixed.py` - Main injection script
- `diagnose_lacus.py` - Comprehensive diagnostic tool
- `test_lacus_logic.py` - Logic validation test
- `README-LACUS-FIX.md` - This documentation

## Verification Commands

### Check Environment Variable
```bash
echo $LACUS_URL
```

### Check Redis Database
```bash
python3 diagnose_lacus.py
```

### Test LACUS Connectivity
```bash
curl -k https://lacus.internal.delightfulbay-9e24f820.westeurope.azurecontainerapps.io
```

### Check Web Interface
- Navigate to `/crawlers/dashboard`
- Should no longer show "Lacus URL undefined" error
- LACUS status should show as connected

## Future Considerations

1. **Automated Testing**: Add health checks to verify LACUS URL injection during deployment
2. **Configuration Management**: Consider using Azure App Configuration for centralized settings
3. **Monitoring**: Add monitoring to detect when crawler:lacus URL becomes undefined
4. **Documentation**: Update deployment documentation to include this critical step

## Reference Links

- **Issue Location**: `bin/lib/crawlers.py:2173`
- **Function**: `ping_lacus()` 
- **Database**: Kvrocks_DB (Redis database 3)
- **Hash Key**: `crawler:lacus`
- **Environment Variable**: `LACUS_URL`
