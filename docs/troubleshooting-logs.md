# Log Monitoring and Debugging Guide

This guide provides comprehensive information on monitoring AIL Framework logs and understanding Flask debug mode for development and troubleshooting.

## 🔍 Log Monitoring Commands

### Opening Multiple Log Windows

For effective monitoring, open these commands in separate PowerShell windows to track different aspects of the system:

#### Window 1: AIL Application Logs (Primary)
```powershell
cd "C:\CodePlayground\AIL-framework"
docker logs -f ail-ail-app-1
```
**Purpose**: Monitor the main AIL application, Flask server, initialization, and error messages.

#### Window 2: Lacus Service Logs 
```powershell
cd "C:\CodePlayground\AIL-framework"
docker logs -f lacus-lacus-1
```
**Purpose**: Monitor web crawling service, screenshot capture, and Lacus API operations.

#### Window 3: Redis Cache Monitoring
```powershell
cd "C:\CodePlayground\AIL-framework"
docker logs -f ail-redis-cache-1
```
**Purpose**: Monitor caching operations and Redis performance.

#### Window 4: Container Status Dashboard
```powershell
cd "C:\CodePlayground\AIL-framework"
# Refreshes every 2 seconds
while ($true) { 
    Clear-Host
    Write-Host "=== AIL Framework Container Status ===" -ForegroundColor Cyan
    Write-Host "Updated: $(Get-Date)" -ForegroundColor Gray
    Write-Host ""
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    Start-Sleep 2 
}
```
**Purpose**: Real-time overview of all container health and port mappings.

#### Window 5: Using PowerShell Script Logs
```powershell
cd "C:\CodePlayground\AIL-framework"
# Use the custom script for specific service logs
.\scripts\start-all.ps1 logs ail-app
```
**Purpose**: Use the integrated logging system with proper service detection.

### Advanced Log Monitoring

#### Viewing All Redis Services
```powershell
# Monitor all Redis containers simultaneously
docker logs -f ail-redis-cache-1 &
docker logs -f ail-redis-work-1 &
docker logs -f ail-redis-log-1 &
docker logs -f ail-kvrocks-1
```

#### Log Filtering and Search
```powershell
# Filter logs for specific patterns
docker logs ail-ail-app-1 2>&1 | Select-String "ERROR"
docker logs ail-ail-app-1 2>&1 | Select-String "Flask"
docker logs lacus-lacus-1 2>&1 | Select-String "API"
```

#### Historical Log Review
```powershell
# View logs from specific time periods
docker logs ail-ail-app-1 --since 1h        # Last hour
docker logs ail-ail-app-1 --since 2023-01-01T10:00:00    # Since specific time
docker logs ail-ail-app-1 --tail 100        # Last 100 lines only
```

## 🐛 Flask Debug Mode Explained

### What is Flask Debug Mode?

Flask debug mode is a development feature that provides enhanced debugging capabilities for the AIL web interface. When you see this in the logs:

```
* Debugger is active!
* Debugger PIN: 145-260-754
```

The system is running in debug mode, which is **perfect for development and testing**.

### Debug Mode Features

#### 1. 🔄 Auto-Reload Functionality
- **What it does**: Automatically restarts the Flask server when Python files change
- **Benefit**: No need to manually restart containers during development
- **Example**: Edit a Python file → Flask detects change → Server restarts automatically

#### 2. 🐛 Interactive Debugger
- **What it does**: Provides detailed error pages with interactive debugging
- **Access**: Use the Debug PIN (e.g., `145-260-754`) when prompted
- **Features**:
  - Inspect variables at the point of failure
  - Execute Python code in the error context
  - Navigate the full stack trace

#### 3. 📊 Enhanced Error Reporting
- **Instead of**: Generic "500 Internal Server Error"
- **You get**: 
  - Exact line number where error occurred
  - Full stack trace with code context
  - Variable values at each stack level
  - Suggestions for common fixes

### Using the Debug PIN

When you encounter an error page in the browser:

1. **Error Page Appears**: Shows detailed traceback
2. **Click Console Icon**: Small terminal icon next to each stack frame
3. **Enter Debug PIN**: Use the PIN from the logs (e.g., `145-260-754`)
4. **Interactive Console**: Execute Python commands to inspect the error

```python
# Example debug console commands
print(locals())           # See all local variables
print(request.args)       # Inspect request parameters
print(current_user)       # Check user context
help(some_function)       # Get help on functions
```

### Debug Mode Security

#### ✅ Safe for Development
- **Local Development**: Perfect for localhost testing
- **Learning**: Excellent for understanding how the system works
- **Debugging**: Makes troubleshooting much easier

#### ⚠️ Never Use in Production
- **Security Risk**: Exposes internal code and data
- **Performance Impact**: Slower due to monitoring overhead
- **Information Disclosure**: Debug pages reveal system internals

### Typical Debug Scenarios

#### Flask Startup Issues
```
Environment variables - AIL_HOME: /opt/ail
Environment variables - AIL_BIN: /opt/ail/bin
Loading configuration...
ERROR: Configuration file not found
```
**Solution**: Check configuration files and environment variables.

#### Database Connection Problems
```
Successfully connected to Kvrocks_DB
ERROR: Redis connection failed
```
**Solution**: Verify Redis containers are running and accessible.

#### Module Loading Errors
```
Initializing default taxonomies...
ERROR: ImportError in module 'custom_module'
```
**Solution**: Check Python dependencies and module paths.

## 🛠 Quick Testing Commands

### Health Check Commands
```powershell
# Test web interfaces
Invoke-WebRequest -Uri http://localhost:7000 -UseBasicParsing | Select-Object StatusCode
Invoke-WebRequest -Uri http://localhost:7100 -UseBasicParsing | Select-Object StatusCode

# Check container health
docker ps --filter "name=ail-" --format "table {{.Names}}\t{{.Status}}"
docker ps --filter "name=lacus-" --format "table {{.Names}}\t{{.Status}}"
```

### Service Status Verification
```powershell
cd "C:\CodePlayground\AIL-framework"
.\scripts\start-all.ps1 status
```

### Quick Restart for Testing
```powershell
cd "C:\CodePlayground\AIL-framework"
.\scripts\start-all.ps1 restart
```

## 📋 Log Patterns to Monitor

### Normal Operation Indicators
```
✅ "Successfully connected to Kvrocks_DB"
✅ "Flask server starting..."
✅ "Lacus API responding on port 7100"
✅ "All services started successfully"
```

### Warning Signs
```
⚠️ "Configuration file not found"
⚠️ "Redis connection timeout"
⚠️ "Port already in use"
⚠️ "Memory usage high"
```

### Critical Errors
```
❌ "Flask server failed to start"
❌ "Database connection refused"
❌ "Service crashed with exit code"
❌ "Container restart loop detected"
```

## 🔧 Troubleshooting Tips

### Common Issues and Solutions

#### Issue: Flask Won't Start
```bash
# Check logs
docker logs ail-ail-app-1 --tail 50

# Common causes:
# - Port 7000 already in use
# - Configuration file missing
# - Database not accessible
```

#### Issue: Debug PIN Not Working
```bash
# Regenerate containers
.\scripts\start-all.ps1 down
.\scripts\start-all.ps1 up

# New PIN will be generated in logs
```

#### Issue: Logs Too Verbose
```bash
# Filter specific log levels
docker logs ail-ail-app-1 2>&1 | Select-String "ERROR|CRITICAL"
```

### Performance Monitoring
```powershell
# Container resource usage
docker stats --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}"

# Disk usage by containers
docker system df
```

## 📚 Related Documentation

- [Flask Startup Troubleshooting](troubleshooting-flask.md)
- [AIL Crawler Lacus Troubleshooting](arch-crawler-troubleshooting.md)
- [General Troubleshooting](troubleshooting-docker.md)
- [PowerShell Scripts Documentation](automation-powershell.md)

## 🎯 Best Practices

1. **Always monitor logs during testing**: Use multiple windows for comprehensive monitoring
2. **Keep debug mode for development**: It's your friend for learning and troubleshooting
3. **Save the debug PIN**: Write it down when starting containers
4. **Filter logs appropriately**: Use grep/Select-String to focus on relevant information
5. **Monitor resource usage**: Watch for memory leaks or CPU spikes
6. **Test systematically**: Verify each service independently before testing integration

---

*This guide is part of the AIL Framework documentation. For more information, visit the main [README.md](../README.md) file.*
