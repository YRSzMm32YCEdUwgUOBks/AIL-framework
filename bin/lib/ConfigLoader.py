#!/usr/bin/python3

"""
The ``Domain``
===================


"""

import os
import sys
import redis
import configparser
import time
import ssl as ssl_module
from redis.exceptions import ConnectionError, TimeoutError

# NOTE: This configuration loader was originally working before the modular refactor.
# The current implementation may not fully support the new environment-based system.
# TODO: Refactor to ensure correct config file selection and environment variable handling
#       for both local and Azure/cloud deployments.

# Get Config file
config_dir = os.path.join(os.environ['AIL_HOME'], 'configs')

# Check if running in Azure environment
if os.environ.get('REDIS_CACHE_HOST') and os.environ.get('REDIS_CACHE_PASSWORD'):
    # Use Azure configuration in Azure environment
    default_config_file = os.path.join(config_dir, 'azure.cfg')
    print("[CONFIG] Using Azure configuration file:", default_config_file)
else:
    # Use standard configuration
    default_config_file = os.path.join(config_dir, 'core.cfg')

if not os.path.exists(default_config_file):
    # Fallback to core.cfg if azure.cfg doesn't exist
    fallback_config = os.path.join(config_dir, 'core.cfg')
    if os.path.exists(fallback_config):
        default_config_file = fallback_config
        print("[WARNING] Falling back to core.cfg")
    else:
        raise Exception('Unable to find the configuration file. \
                        Did you set environment variables? \
                        Or activate the virtualenv.')

 # # TODO: create sphinx doc

 # # TODO: add config_field to reload

class ConfigLoader(object):
    """docstring for Config_Loader."""
    
    def __init__(self, config_file=None):
        self.cfg = configparser.ConfigParser()        
        if config_file:
            self.cfg.read(os.path.join(config_dir, config_file))
        else:
            self.cfg.read(default_config_file)
    
    def get_redis_conn(self, redis_name, decode_responses=True, max_retries=3, retry_delay=1):
        host = self.cfg.get(redis_name, "host")
        port = self.cfg.getint(redis_name, "port")
        db = self.cfg.getint(redis_name, "db")
        
        # Check if password is configured (for Azure Redis Cache)
        password = None
        ssl = False
        ssl_cert_reqs = None
        ssl_check_hostname = False
        
        if self.cfg.has_option(redis_name, "password"):
            password = self.cfg.get(redis_name, "password")
            if password == "":  # Empty string means no password
                password = None
          # Check for SSL configuration
        # Only enable SSL if explicitly configured, not based on port number
        if self.cfg.has_option(redis_name, "ssl") and self.cfg.getboolean(redis_name, "ssl"):
            ssl = True
            # Azure Redis Cache SSL configuration - disable cert verification for now
            ssl_cert_reqs = None
            ssl_check_hostname = False
        
        # Retry logic for Azure Redis connections
        for attempt in range(max_retries):
            try:
                conn = redis.StrictRedis(host=host,
                                        port=port,
                                        db=db,
                                        password=password,
                                        ssl=ssl,
                                        ssl_cert_reqs=ssl_cert_reqs,
                                        ssl_check_hostname=ssl_check_hostname,
                                        socket_connect_timeout=30,
                                        socket_timeout=30,
                                        retry_on_timeout=True,
                                        decode_responses=decode_responses)
                
                # Test the connection
                conn.ping()
                return conn
                
            except (ConnectionError, TimeoutError, Exception) as e:
                print(f"Redis connection attempt {attempt + 1}/{max_retries} failed: {str(e)}")
                if attempt < max_retries - 1:
                    time.sleep(retry_delay * (2 ** attempt))  # Exponential backoff
                else:
                    print(f"Failed to connect to Redis after {max_retries} attempts")
                    raise e    
    def get_db_conn(self, db_name, decode_responses=True, max_retries=3, retry_delay=1):
        host = self.cfg.get(db_name, "host")
        port = self.cfg.getint(db_name, "port")
        db = self.cfg.getint(db_name, "db")
        
        # Check if password is configured (for Azure Redis Cache)
        password = None
        ssl = False
        ssl_cert_reqs = None
        ssl_check_hostname = False
        
        if self.cfg.has_option(db_name, "password"):
            password = self.cfg.get(db_name, "password")
            if password == "":  # Empty string means no password
                password = None
          # Check for SSL configuration
        # Only enable SSL if explicitly configured, not based on port number
        if self.cfg.has_option(db_name, "ssl") and self.cfg.getboolean(db_name, "ssl"):
            ssl = True
            # Azure Redis Cache SSL configuration - disable cert verification for now
            ssl_cert_reqs = None
            ssl_check_hostname = False
        
        # Retry logic for Azure Redis connections
        for attempt in range(max_retries):
            try:
                conn = redis.StrictRedis(host=host,
                                        port=port,
                                        db=db,
                                        password=password,
                                        ssl=ssl,
                                        ssl_cert_reqs=ssl_cert_reqs,
                                        ssl_check_hostname=ssl_check_hostname,
                                        socket_connect_timeout=30,
                                        socket_timeout=30,
                                        retry_on_timeout=True,
                                        decode_responses=decode_responses)
                
                # Test the connection
                conn.ping()
                return conn
            except (ConnectionError, TimeoutError, Exception) as e:
                print(f"Redis DB connection attempt {attempt + 1}/{max_retries} failed: {str(e)}")
                if attempt < max_retries - 1:
                    time.sleep(retry_delay * (2 ** attempt))  # Exponential backoff
                else:
                    print(f"Failed to connect to Redis DB after {max_retries} attempts")
                    raise e

    def get_files_directory(self, key_name):
        directory_path = self.cfg.get('Directories', key_name)
        # full path
        if directory_path[0] == '/':
            return directory_path
        else:
            directory_path = os.path.join(os.environ['AIL_HOME'], directory_path)
            return directory_path

    def get_config_sections(self):
        return self.cfg.sections()

    def get_config_str(self, section, key_name):
        return self.cfg.get(section, key_name)

    def get_config_int(self, section, key_name):
        return self.cfg.getint(section, key_name)

    def get_config_boolean(self, section, key_name):
        return self.cfg.getboolean(section, key_name)

    def has_option(self, section, key_name):
        return self.cfg.has_option(section, key_name)

    def has_section(self, section):
        return self.cfg.has_section(section)

    def get_all_keys_values_from_section(self, section):
        if section in self.cfg:
            all_keys_values = []
            for key_name in self.cfg[section]:
                all_keys_values.append((key_name, self.cfg.get(section, key_name)))
            return all_keys_values
        else:
            return []


# # # # Directory Config # # # #

config_loader = ConfigLoader()
ITEMS_FOLDER = config_loader.get_config_str("Directories", "pastes")
if ITEMS_FOLDER == 'PASTES':
    ITEMS_FOLDER = os.path.join(os.environ['AIL_HOME'], ITEMS_FOLDER)
ITEMS_FOLDER = ITEMS_FOLDER + '/'
ITEMS_FOLDER = os.path.join(os.path.realpath(ITEMS_FOLDER), '')

HARS_DIR = config_loader.get_files_directory('har')
if HARS_DIR == 'CRAWLED_SCREENSHOT':
    HARS_DIR = os.path.join(os.environ['AIL_HOME'], HARS_DIR)

SCREENSHOTS_FOLDER = config_loader.get_files_directory('screenshot')
if SCREENSHOTS_FOLDER == 'CRAWLED_SCREENSHOT/screenshot':
    SCREENSHOTS_FOLDER = os.path.join(os.environ['AIL_HOME'], SCREENSHOTS_FOLDER)
config_loader = None

def get_hars_dir():
    return HARS_DIR

def get_items_dir():
    return ITEMS_FOLDER

def get_screenshots_dir():
    return SCREENSHOTS_FOLDER



