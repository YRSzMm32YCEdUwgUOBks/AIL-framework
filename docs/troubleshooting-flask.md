# Flask Startup Troubleshooting - AIL Framework

## Problem
Flask server never finishes starting in the AIL container, causing the application to hang during initialization.

## Root Causes Identified

### 1. SSL Certificate Loading Issue
- **Problem**: Flask was trying to load SSL certificates (`server.crt`, `server.key`) that may not exist or be accessible in container environments
- **Impact**: This would cause Flask to fail silently or hang during SSL context initialization
- **Solution**: Made SSL optional and configurable

### 2. Database Connection Blocking
- **Problem**: Database connections (Redis, KVRocks) were being established synchronously at import time
- **Impact**: If databases aren't ready, Flask would hang waiting for connections
- **Solution**: Added try-catch blocks with graceful fallback

### 3. Taxonomy and Cache Initialization
- **Problem**: Default taxonomy loading and git cache clearing could block startup
- **Impact**: These operations might hang if dependencies aren't available
- **Solution**: Added error handling and debug output

## Changes Made

### 1. Flask Server (var/www/Flask_server.py)
```python
# SSL Configuration - Now Optional
ssl_context = None
ssl_enabled = config_loader.get_config_str("Flask", "ssl_enabled", fallback="false").lower() == "true"
cert_file = os.path.join(Flask_dir, 'server.crt')
key_file = os.path.join(Flask_dir, 'server.key')

if ssl_enabled and os.path.exists(cert_file) and os.path.exists(key_file):
    # Load SSL certificates
else:
    # Continue without SSL
```

### 2. Database Connections (Flask_config.py)
```python
# All database connections now have try-catch blocks
try:
    r_serv = config_loader.get_redis_conn("Redis_Queues")
    print("Connected to Redis_Queues")
except Exception as e:
    print(f"Warning: Failed to connect to Redis_Queues: {e}")
    r_serv = None
```

### 3. Configuration Files
Added `ssl_enabled = false` to:
- `configs/environments/test-cloud.cfg`
- `configs/environments/prod-cloud.cfg` 
- `configs/environments/dev-local.cfg`

### 4. Debug Output
Added comprehensive logging throughout Flask startup to identify where hangs occur:
- Environment variable validation
- Configuration loading progress
- Database connection status
- SSL initialization status
- Taxonomy loading progress

## Testing the Fix

### 1. Container Startup
```bash
# Build and run the container
docker build -t ail-framework -f Dockerfile.ail .
docker run -p 7000:7000 ail-framework

# Monitor startup logs
docker logs -f <container_id>
```

### 2. Expected Output
You should now see detailed startup logs:
```
AIL Flask Server - Starting initialization...
Environment variables - AIL_HOME: /opt/ail
Loading configuration...
SSL disabled - running in HTTP mode
Connected to Redis_Queues
Connected to Kvrocks_DB
...
Starting Flask server on 0.0.0.0:7000
SSL enabled: False
Flask server starting...
* Running on all addresses (0.0.0.0)
* Running on http://127.0.0.1:7000
* Running on http://172.17.0.2:7000
```

## Configuration Options

### Environment Variables
- `AIL_HOME`: Base directory for AIL
- `AIL_BIN`: Binary/script directory
- `AIL_FLASK`: Flask application directory

### Flask Configuration
```ini
[Flask]
host = 0.0.0.0
port = 7000
ssl_enabled = false  # Set to true only if SSL certificates are available
secret_key = ${FLASK_SECRET_KEY}
```

## Container Environment Considerations

### 1. Azure Container Apps
- SSL termination happens at the load balancer level
- Internal communication should use HTTP
- `ssl_enabled = false` is correct for this environment

### 2. Development Environment
- SSL certificates typically not needed for local development
- Use HTTP for simplicity and debugging
- `ssl_enabled = false` recommended

### 3. Production Considerations
- SSL should be handled by reverse proxy (nginx, Azure Application Gateway)
- Container should run in HTTP mode
- Secure communication handled at infrastructure level

## Troubleshooting Steps

### 1. If Flask Still Doesn't Start
```bash
# Check if container has required environment variables
docker exec -it <container_id> env | grep AIL

# Check if configuration file is being used
docker exec -it <container_id> cat /opt/ail/configs/core.cfg

# Check database connectivity manually
docker exec -it <container_id> python3 -c "
import redis
r = redis.Redis(host='localhost', port=6379)
print(r.ping())
"
```

### 2. Enable Debug Mode
Set `debug_mode = True` in the configuration file for more verbose output.

### 3. Check Resource Limits
Ensure container has sufficient:
- Memory (minimum 2GB recommended)
- CPU (minimum 1 core)
- Disk space for logs and data

## Next Steps

1. **Test the changes** in your container environment
2. **Monitor startup logs** to confirm Flask starts successfully
3. **Verify web interface** is accessible on port 7000
4. **Check application functionality** after startup completes

If issues persist, the debug output will now provide specific information about where the startup process is failing
