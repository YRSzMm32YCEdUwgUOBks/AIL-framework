#!/usr/bin/env python3
"""
Azure post-deployment script to inject LACUS_URL environment variable
into Redis/Kvrocks database for AIL Framework crawler functionality.

This script follows the same pattern as docker-entrypoint.sh but ensures
the correct database (3) is used for Kvrocks_DB as per Azure configuration.
"""

import os
import sys
import redis
from urllib.parse import urlparse

def inject_lacus_url():
    """Inject LACUS_URL environment variable into Redis/Kvrocks database"""
    
    # Get LACUS_URL from environment
    lacus_url = os.environ.get('LACUS_URL')
    
    if not lacus_url:
        print("❌ ERROR: LACUS_URL environment variable not found")
        return False
    
    # Validate URL format
    try:
        parsed = urlparse(lacus_url)
        if not parsed.scheme or not parsed.netloc:
            print(f"❌ ERROR: Invalid LACUS_URL format: {lacus_url}")
            return False
    except Exception:
        print(f"❌ ERROR: Invalid LACUS_URL format: {lacus_url}")
        return False
    
    print(f"🔗 Injecting LACUS_URL: {lacus_url}")
    
    try:
        # Get Redis connection parameters from environment
        host = os.environ.get('REDIS_CACHE_HOST')
        port = int(os.environ.get('REDIS_CACHE_PORT', 6379))
        password = os.environ.get('REDIS_CACHE_PASSWORD')
        ssl_enabled = os.environ.get('REDIS_CACHE_SSL', 'true').lower() == 'true'
        
        if not host or not password:
            print("❌ ERROR: Missing Redis connection parameters")
            print("Required: REDIS_CACHE_HOST, REDIS_CACHE_PASSWORD")
            return False
        
        # Connect to the correct database (3) for Kvrocks_DB functionality
        # This is where crawler data is stored according to azure.cfg
        if ssl_enabled:
            r = redis.Redis(
                host=host, 
                port=port, 
                password=password, 
                db=3,  # Kvrocks_DB database
                ssl=True, 
                ssl_cert_reqs=None,
                decode_responses=True
            )
        else:
            r = redis.Redis(
                host=host, 
                port=port, 
                password=password, 
                db=3,  # Kvrocks_DB database
                decode_responses=True
            )
        
        # Test connection
        r.ping()
        print("✅ Connected to Redis/Kvrocks database (db=3)")
        
        # Inject LACUS URL using the same method as save_lacus_url_api()
        r.hset('crawler:lacus', 'url', lacus_url)
        print("✅ LACUS URL injected into crawler:lacus hash")
        
        # Verify the injection worked
        stored_url = r.hget('crawler:lacus', 'url')
        if stored_url == lacus_url:
            print(f"✅ LACUS URL injection verified: {stored_url}")
            return True
        else:
            print(f"❌ LACUS URL verification failed. Expected: {lacus_url}, Got: {stored_url}")
            return False
            
    except redis.ConnectionError as e:
        print(f"❌ Redis connection error: {e}")
        return False
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        return False

if __name__ == "__main__":
    print("🚀 Starting LACUS URL injection...")
    
    if inject_lacus_url():
        print("✅ LACUS URL injection completed successfully")
        sys.exit(0)
    else:
        print("❌ LACUS URL injection failed")
        sys.exit(1)
