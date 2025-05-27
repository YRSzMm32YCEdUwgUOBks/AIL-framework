# AIL Framework - Docker Troubleshooting Guide

This guide covers common issues, solutions, and diagnostic procedures for the AIL Framework Docker deployment.

## Common Issues & Solutions

### ❌ "AIL not responding"
```bash
# Check if container is running
docker-compose ps ail-app

# View startup logs
docker-compose logs ail-app

# Restart if needed
docker-compose restart ail-app
```

### ❌ "Crawler not working"
```bash
# Verify Lacus service
curl http://localhost:7100/

# Check crawler module
docker-compose logs ail-app | grep -i "crawler.py"

# Verify Redis work queue
docker exec -it $(docker-compose ps -q redis-work) redis-cli -p 6381 keys "*queue*"
```

### ❌ "Database connection errors"
```bash
# Check Redis services
docker-compose logs redis-cache redis-log redis-work

# Test Kvrocks connectivity
docker exec -it $(docker-compose ps -q kvrocks) redis-cli -h kvrocks -p 6383 ping

# Test Valkey connectivity
docker exec -it $(docker-compose ps -q valkey) redis-cli -h valkey -p 6385 ping
```

### ❌ "Lacus Container Exiting Immediately"

**Symptoms**: Lacus container starts then immediately exits

**Root Cause**: Usually missing dependencies or configuration issues

**Solution**:
```bash
# Check dependencies are running
docker-compose ps valkey tor_proxy

# View Lacus startup logs
docker-compose logs lacus

# Restart dependencies first, then Lacus
docker-compose restart valkey tor_proxy
docker-compose restart lacus
```

### ❌ "Error: Can't connect to AIL Lacus"

**Root Cause**: AIL's `get_lacus_url()` function reads from Kvrocks database but the URL isn't stored there

**Solution**:
```bash
# Check if Lacus URL is configured in Kvrocks
docker exec -it $(docker-compose ps -q kvrocks) redis-cli -p 6383 HGET crawler:lacus url

# If empty, the init-lacus-url service should set it automatically
# Check if init service ran successfully
docker-compose logs init-lacus-url

# Manually set if needed
docker exec -it $(docker-compose ps -q kvrocks) redis-cli -p 6383 HSET crawler:lacus url http://lacus:7100
```

### ❌ "Error resolving tor_proxy"

**Symptoms**: "Error resolving tor_proxy" in Lacus logs

**Solution**:
```bash
# Ensure Tor proxy service is running
docker-compose ps tor_proxy

# Check Tor proxy logs
docker-compose logs tor_proxy

# Test network connectivity
docker-compose exec lacus ping tor_proxy

# Restart Tor proxy if needed
docker-compose restart tor_proxy
```

### ❌ "Tasks stuck in crawler queue"

**Symptoms**: URLs submitted but never processed

**Diagnostics**:
```bash
# Check crawler queue
docker exec -it $(docker-compose ps -q kvrocks) redis-cli -p 6383 ZRANGE crawler:queue 0 -1 WITHSCORES

# Check if crawler daemon is running
docker-compose logs ail-app | grep -i "crawler.py"

# Check concurrent capture limits
curl http://localhost:7100/
```

### ❌ "Permission denied" errors

**Solution**:
```bash
# Fix data directory permissions
sudo chown -R $(id -u):$(id -g) data/

# Or on Windows
# Right-click data folder → Properties → Security → Give full control to Users
```

## Diagnostic Commands

### Container Status
```bash
# Check all container status
docker-compose ps

# Check resource usage
docker stats

# View container details
docker inspect $(docker-compose ps -q ail-app)
```

### Database Diagnostics
```bash
# Test all database connections
echo "Testing Redis Cache..."
docker exec -it $(docker-compose ps -q redis-cache) redis-cli ping

echo "Testing Redis Log..."
docker exec -it $(docker-compose ps -q redis-log) redis-cli -p 6380 ping

echo "Testing Redis Work..."
docker exec -it $(docker-compose ps -q redis-work) redis-cli -p 6381 ping

echo "Testing Kvrocks..."
docker exec -it $(docker-compose ps -q kvrocks) redis-cli -p 6383 ping

echo "Testing Valkey..."
docker exec -it $(docker-compose ps -q valkey) redis-cli -p 6385 ping
```

### Network Connectivity
```bash
# Test inter-service connectivity
docker-compose exec ail-app ping lacus
docker-compose exec ail-app ping kvrocks
docker-compose exec lacus ping tor_proxy
docker-compose exec lacus ping valkey
```

### Log Analysis
```bash
# View recent logs for all services
docker-compose logs --tail=50

# Follow logs in real-time
docker-compose logs -f

# Service-specific logs
docker-compose logs -f ail-app
docker-compose logs -f lacus
docker-compose logs -f tor_proxy
```

## Configuration Verification

### Lacus URL Configuration
The most common issue is incorrect Lacus URL configuration. AIL reads the Lacus URL from:
```
Database: Kvrocks (port 6383)
Key: crawler:lacus
Field: url
Expected Value: http://lacus:7100
```

**Verification**:
```bash
# Check current configuration
docker exec -it $(docker-compose ps -q kvrocks) redis-cli -p 6383 HGET crawler:lacus url

# Should return: http://lacus:7100
```

### Database Configuration Locations
```bash
# Check AIL's database configuration
docker-compose exec ail-app cat /opt/ail/configs/core.cfg | grep -A 10 "\[Redis\|Kvrocks\]"

# Check Lacus configuration
docker-compose exec lacus cat /opt/lacus/config/generic.json
```

## Performance Monitoring

### Resource Usage
```bash
# Monitor container resource usage
docker stats --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"

# Check disk usage
docker system df
```

### Queue Monitoring
```bash
# Monitor crawler queue size
watch "docker exec -it $(docker-compose ps -q kvrocks) redis-cli -p 6383 ZCARD crawler:queue"

# Monitor active captures
curl -s http://localhost:7100/ | grep -o '"nb_captures":[0-9]*'
```

## Recovery Procedures

### Complete Stack Restart
```bash
# Stop all services
docker-compose down

# Clean up (optional - removes data)
# docker-compose down -v

# Start fresh
docker-compose up --build -d

# Wait for initialization
sleep 180

# Verify status
docker-compose ps
```

### Selective Service Restart
```bash
# Restart only problematic services
docker-compose restart lacus valkey tor_proxy

# Restart AIL components
docker-compose restart ail-app redis-cache redis-work kvrocks
```

### Database Reset (DESTRUCTIVE)
```bash
# WARNING: This removes all data
docker-compose down -v
rm -rf data/
docker-compose up --build -d
```

## Debug Mode

### Enable Verbose Logging
```bash
# Add to docker-compose.yml environment section:
# LOGLEVEL: DEBUG
# AIL_DEBUG: 1

# Restart services
docker-compose up -d
```

### Access Container Shells
```bash
# AIL container
docker-compose exec ail-app /bin/bash

# Lacus container
docker-compose exec lacus /bin/bash

# Redis containers
docker-compose exec redis-cache redis-cli
docker-compose exec kvrocks redis-cli -p 6383
```

## Known Issues & Workarounds

### Issue: Lacus workers not starting
**Workaround**: Increase memory allocation in Docker Desktop settings

### Issue: Tor proxy connection timeouts
**Workaround**: Restart tor_proxy service periodically

### Issue: Screenshots not saving
**Workaround**: Check data/screenshots directory permissions

## Getting Help

If these troubleshooting steps don't resolve your issue:

1. **Check Logs**: Always start with `docker-compose logs -f`
2. **Search Issues**: Check the GitHub repository issues
3. **Gather Information**: Run diagnostic commands and collect output
4. **Report Issues**: Include logs, configuration, and system information

## Tracker Internal Server Error

**Symptoms:** 500 error when accessing `/tracker/add`, logs show `StopIteration` in `Tracker.py`

**Cause:** Missing YARA rules - git submodules not initialized

**Solution:**
```bash
git submodule init
git submodule update
docker-compose restart ail-app
```

The YARA rules directory (`bin/trackers/yara/ail-yara-rules/rules/`) must exist and contain rule files.

## Missing MISP Data

**Symptoms:** Issues with taxonomies or galaxy data

**Solution:** Same as above - initialize git submodules to download MISP taxonomies and galaxy data.

## Useful Commands Reference

```bash
# Quick health check
docker-compose ps && curl -s http://localhost:7000/api/v1/health

# View all logs
docker-compose logs --tail=100

# Monitor resource usage
docker stats --no-stream

# Test database connections
for port in 6379 6380 6381 6383 6385; do
    echo "Testing port $port..."
    docker exec -it $(docker-compose ps -q redis-cache) redis-cli -h host.docker.internal -p $port ping || echo "Failed"
done

# Clean up stopped containers
docker system prune -f
```
