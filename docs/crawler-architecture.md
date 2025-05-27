# AIL Framework - Crawler Architecture & Flow Analysis

This document provides a complete technical analysis of the crawler implementation, including code execution flow, database interactions, and integration points.

## Overview

The AIL Framework crawler provides web crawling capabilities through integration with [Lacus](https://github.com/ail-project/lacus), a specialized web crawler designed for cybersecurity analysis. The crawler supports both surface web and dark web (.onion) crawling with comprehensive data capture.

## Architecture Components

### Core Components
- **AIL Framework**: Main application with web interface and processing modules
- **Lacus Crawler**: Specialized web crawler with Playwright browser automation
- **Tor Proxy**: Anonymous browsing for .onion sites
- **Database Layer**: Multi-database architecture for different data types

### Database Architecture
```
┌─────────────────┬─────────────────┬─────────────────┐
│ Redis Cluster   │ Kvrocks         │ Valkey          │
│ (Ephemeral)     │ (Persistent)    │ (Lacus)         │
├─────────────────┼─────────────────┼─────────────────┤
│ • Work queues   │ • Task metadata │ • Capture data  │
│ • Caching       │ • Correlations  │ • Screenshots   │
│ • Session data  │ • URL mappings  │ • HAR files     │
└─────────────────┴─────────────────┴─────────────────┘
```

## Complete Execution Flow

### 1. Frontend Form Submission
**File**: `var/www/templates/crawler/crawler_splash/crawler_manual.html`

```html
<form action="{{ url_for('crawler_splash.send_to_spider') }}" method='post'>
    <input name="url" type="url" required>
    <input name="depth" type="number" min="0" max="3">
    <input name="screenshot" type="checkbox" checked>
    <input name="har" type="checkbox" checked>
    <!-- Additional options: tags, proxy, cookiejar -->
</form>
```

**User Actions**:
- Fill out crawler form with URL and options
- Select crawling depth (0-3 levels)
- Choose capture options (screenshot, HAR)
- Configure proxy settings (auto-detects .onion)
- Submit form to Flask endpoint

### 2. Flask Route Handler
**File**: `var/www/blueprints/crawler_splash.py` (lines 116-219)
**Function**: `send_to_spider()`

```python
@crawler_splash.route("/crawlers/send_to_spider", methods=['POST'])
@login_required
@login_user_no_api
def send_to_spider():
    # Extract and validate form data
    url = request.form.get('url', '').strip()
    depth = int(request.form.get('depth', 1))
    screenshot = 'screenshot' in request.form
    har = 'har' in request.form
    
    # Auto-configure Tor proxy for .onion URLs
    if url.endswith('.onion'):
        proxy = 'force_tor'
    
    # Delegate to crawler API
    res = crawlers.api_add_crawler_task(data, user_org, user_id=user_id)
    return jsonify(res)
```

**Key Processing**:
- Validates form parameters and URL format
- Automatically sets `proxy = 'force_tor'` for .onion URLs
- Handles tags, cookiejars, and scheduling frequency
- Delegates to `crawlers.api_add_crawler_task()`

### 3. Task Creation API
**File**: `bin/lib/crawlers.py` (lines 1936-2009)
**Function**: `api_add_crawler_task()`

```python
def api_add_crawler_task(data, user_org, user_id=None):
    # Parse and validate task parameters
    task_dict = api_parse_task_dict_basic(data)
    
    # Handle cookiejar permissions
    if 'cookiejar' in task_dict:
        # Validate cookiejar access permissions
        
    # Process recurring tasks
    if frequency:
        # Create scheduled crawler task
    
    # Create one-time task with high priority (90)
    task_uuid = create_task(url, depth=depth, priority=90, **options)
    return {'task_uuid': task_uuid}
```

**Validation Steps**:
- URL format and accessibility validation
- Domain blacklist checking
- User permission verification
- Resource availability checking

### 4. Task Object Creation
**File**: `bin/lib/crawlers.py` (lines 1871-1883)
**Function**: `create_task()`

```python
def create_task(url, depth=1, har=True, screenshot=True, 
                header=None, cookiejar=None, proxy=None, 
                user_agent=None, tags=[], priority=90):
    
    # Generate unique task identifier
    task_uuid = str(uuid.uuid4())
    
    # Create task instance
    task = CrawlerTask(task_uuid)
    
    # Store task in database
    task.create(url, depth, har, screenshot, header, 
                cookiejar, proxy, user_agent, tags, priority)
    
    return task_uuid
```

### 5. Task Database Storage
**File**: `bin/lib/crawlers.py` (lines 1754-1819)
**Function**: `CrawlerTask.create()`

```python
def create(self, url, depth=1, har=True, screenshot=True, ...):
    # URL parsing and domain extraction
    parsed_url = urlparse(url)
    domain = parsed_url.netloc
    
    # Security validations
    if self._is_domain_blacklisted(domain):
        raise Exception("Domain blacklisted")
    
    # Deduplication via content hashing
    task_hash = self._generate_task_hash(url, depth, options)
    existing_task = r_db.hget('crawler:queue:hash', task_hash)
    if existing_task:
        return existing_task  # Return existing task UUID
    
    # Store task metadata in Kvrocks
    task_data = {
        'uuid': self.uuid,
        'url': url,
        'depth': depth,
        'screenshot': screenshot,
        'har': har,
        'proxy': proxy,
        'created_at': datetime.utcnow().isoformat(),
        'status': 'queued'
    }
    r_db.hset(f'crawler:task:{self.uuid}', mapping=task_data)
    
    # Add to priority queue
    self.add_to_db_crawler_queue(priority)
```

**Storage Locations**:
```
Kvrocks Database:
├── crawler:task:{uuid}         # Task metadata
├── crawler:queue               # Priority queue (sorted set)  
├── crawler:queue:hash          # Deduplication mapping
└── crawler:lacus:url           # Lacus service endpoint
```

### 6. Queue Management
**File**: `bin/lib/crawlers.py` (line 1821)
**Function**: `add_to_db_crawler_queue()`

```python
def add_to_db_crawler_queue(self, priority):
    # Add to Redis sorted set (priority queue)
    # Higher numbers = higher priority
    r_crawler.zadd('crawler:queue', {self.uuid: priority})
    
    # Manual tasks get priority 90
    # Automatic/scheduled tasks get lower priority
```

**Priority System**:
- **Priority 90**: Manual user submissions
- **Priority 50**: Scheduled recurring tasks  
- **Priority 10**: Automatic/background crawling

### 7. Background Task Processing
**File**: `bin/crawlers/Crawler.py` (lines 150-180)
**Background Daemon Process**

```python
def main():
    while True:
        try:
            # Check capture capacity
            current_captures = crawlers.get_nb_crawler_captures()
            max_captures = crawlers.get_crawler_max_captures()
            
            if current_captures < max_captures:
                # Get highest priority task
                task_row = crawlers.add_task_to_lacus_queue()
                
                if task_row:
                    task_uuid, priority = task_row
                    
                    # Filter unsafe domains for .onion
                    if not crawlers.is_crawler_capture_unsafe_onion(task_uuid):
                        # Launch capture
                        crawlers.enqueue_capture(task_uuid, priority)
                    
                    # Remove from queue
                    crawlers.delete_task_from_db_crawler_queue(task_uuid)
            
            time.sleep(5)  # Check every 5 seconds
            
        except Exception as e:
            logger.error(f"Crawler daemon error: {e}")
            time.sleep(30)
```

**Processing Logic**:
- Continuous monitoring of task queue
- Respects concurrent capture limits
- Implements safety filters for .onion domains
- Automatic retry logic for failed tasks

### 8. Lacus Integration
**File**: `bin/crawlers/Crawler.py` (lines 236-290)
**Function**: `enqueue_capture()`

```python
def enqueue_capture(self, task_uuid, priority):
    # Load task details
    task = crawlers.CrawlerTask(task_uuid)
    
    # Get Lacus service URL from database
    lacus_url = crawlers.get_lacus_url()  # Returns: http://lacus:7100
    
    # Initialize PyLacus client
    lacus_client = PyLacus(root_url=lacus_url)
    
    # Prepare capture request
    capture_params = {
        'url': task.get_url(),
        'depth': task.get_depth(),
        'screenshot': task.is_screenshot(),
        'har': task.is_har()
    }
    
    # Handle proxy configuration
    if task.get_proxy() == 'force_tor':
        capture_params['proxy'] = 'tor'
    
    # Submit to Lacus
    try:
        capture_uuid = lacus_client.enqueue(
            url=capture_params['url'],
            **capture_params
        )
        
        print(f"Task {task_uuid} -> Capture {capture_uuid} launched")
        
        # Store capture mapping
        r_db.hset(f'crawler:capture:{capture_uuid}', 
                  'task_uuid', task_uuid)
        
    except Exception as e:
        logger.error(f"Lacus enqueue failed: {e}")
        # Retry logic handled by daemon
```

**Critical Integration Point**: This is where AIL connects to Lacus!

### 9. Lacus Execution (External Container)
**Container**: `lacus:7100`
**Technology**: Python + Playwright + FastAPI

```python
# Lacus receives HTTP POST to /capture endpoint
@app.post("/capture")
def create_capture(request: CaptureRequest):
    # Validate request parameters
    # Initialize Playwright browser
    # Configure proxy settings (Tor for .onion)
    # Execute capture workflow
    # Store results in Valkey database
    # Return capture UUID
```

**Lacus Processing Steps**:
1. **Browser Initialization**: Playwright creates browser instance
2. **Proxy Configuration**: For .onion URLs, routes through `tor_proxy:9050`
3. **Page Navigation**: Loads target URL with configured options
4. **Content Capture**: Screenshots, HAR files, page source
5. **Data Storage**: Results stored in Valkey database
6. **Status Updates**: Progress updates via API endpoints

### 10. Result Processing
**File**: `bin/crawlers/Crawler.py` (monitoring loop)

```python
def monitor_captures():
    # Poll Lacus for capture status
    for capture_uuid in active_captures:
        status = lacus_client.get_capture_status(capture_uuid)
        
        if status == 'done':
            # Download results
            screenshot = lacus_client.get_screenshot(capture_uuid)
            har_data = lacus_client.get_har(capture_uuid)
            
            # Store in AIL filesystem
            save_screenshot(screenshot, task_uuid)
            save_har_data(har_data, task_uuid)
            
            # Update task status
            task.set_status('completed')
            
            # Trigger analysis modules
            submit_for_analysis(task_uuid)
```

## Database Schema Details

### Kvrocks Storage (AIL Framework)
```
# Task metadata
crawler:task:{uuid} -> {
    "uuid": "task-uuid",
    "url": "https://example.com",
    "depth": 1,
    "screenshot": true,
    "har": true,
    "proxy": "force_tor",
    "created_at": "2025-01-01T12:00:00Z",
    "status": "queued|running|completed|failed",
    "domain": "example.com",
    "user_id": "user-uuid"
}

# Priority queue (sorted set)
crawler:queue -> {
    "task-uuid-1": 90,  # Higher priority
    "task-uuid-2": 50,
    "task-uuid-3": 10   # Lower priority
}

# Deduplication mapping
crawler:queue:hash -> {
    "hash-of-url+options": "existing-task-uuid"
}

# Lacus service configuration
crawler:lacus -> {
    "url": "http://lacus:7100"
}
```

### Valkey Storage (Lacus Container)
```
# Capture data (internal to Lacus)
capture:{uuid} -> {
    "status": "queued|running|done|failed",
    "url": "target-url",
    "screenshot_data": "binary-data",
    "har_data": "json-string",
    "created_at": "timestamp",
    "completed_at": "timestamp"
}
```

## Configuration Files

### AIL Configuration
**File**: `configs/docker/core.cfg`
```ini
[Kvrocks_DB]
host = kvrocks
port = 6383
db = 0

[Redis_Cache]  
host = redis-cache
port = 6379

[Flask]
host = 0.0.0.0
port = 7000
```

### Lacus Configuration
**File**: `configs/lacus/docker.generic.json`
```json
{
    "website_listen_ip": "0.0.0.0",
    "website_listen_port": 7100,
    "concurrent_captures": 2,
    "max_capture_time": 3600,
    "tor_proxy": {
        "server": "socks5://tor_proxy:9050"
    },
    "only_global_lookups": true
}
```

## Network Communication

### Service Communication Flow
```
User Browser
    ↓ HTTPS (7000)
AIL Flask App
    ↓ Redis Protocol (6383)
Kvrocks Database
    ↓ Background Daemon
Crawler.py Module
    ↓ HTTP API (7100)
Lacus Service
    ↓ SOCKS5 (9050)
Tor Proxy (for .onion)
    ↓ HTTPS/HTTP
Target Website
```

### Internal Docker Networking
```
Docker Network: ail-net
├── ail-app:7000          # Flask web interface
├── lacus:7100           # Crawler API
├── redis-cache:6379     # Cache database  
├── redis-log:6380       # Logging database
├── redis-work:6381      # Work queue database
├── kvrocks:6383         # Persistent database
├── valkey:6385          # Lacus database
└── tor_proxy:9050       # Tor SOCKS proxy
```

## Error Handling & Recovery

### Common Failure Points

1. **Database Connection Failures**
   - **Symptom**: Tasks not queued or processed
   - **Recovery**: Automatic retry with exponential backoff

2. **Lacus Service Unavailable**
   - **Symptom**: "Can't connect to AIL Lacus" errors
   - **Recovery**: Task remains in queue for retry

3. **Tor Proxy Failures**
   - **Symptom**: .onion crawling fails
   - **Recovery**: Automatic fallback to direct connection (if configured)

4. **Browser Automation Failures**
   - **Symptom**: Captures timeout or fail
   - **Recovery**: Lacus retries with different browser settings

### Monitoring Points

```python
# Key metrics to monitor
def get_crawler_metrics():
    return {
        'queue_size': r_db.zcard('crawler:queue'),
        'active_captures': len(get_active_captures()),
        'completed_today': get_completed_count(today),
        'failed_count': get_failed_count(),
        'lacus_status': check_lacus_health(),
        'tor_status': check_tor_proxy_health()
    }
```

## Performance Considerations

### Scalability Factors
- **Concurrent Captures**: Limited by Lacus configuration
- **Memory Usage**: ~2GB per concurrent capture
- **Database Performance**: Kvrocks handles persistent storage
- **Network Bandwidth**: Depends on target site sizes

### Optimization Strategies
1. **Queue Management**: Priority-based processing
2. **Resource Limits**: Configurable capture timeouts
3. **Caching**: Deduplication prevents duplicate crawls
4. **Database Separation**: Different databases for different workloads

## Security Implications

### Privacy Features
- **Tor Integration**: Anonymous .onion crawling
- **Network Isolation**: All services in isolated Docker network
- **Data Encryption**: HTTPS for web interface

### Security Considerations
- **Domain Blacklisting**: Prevents crawling restricted domains
- **User Permissions**: Role-based access control
- **Resource Limits**: Prevents resource exhaustion attacks
- **Input Validation**: URL and parameter sanitization

This architecture provides a robust, scalable web crawling solution with strong privacy features and comprehensive data capture capabilities.
