#!/usr/bin/env python3
# -*-coding:UTF-8 -*

'''
    Flask global variables shared across modules
'''
##################################
# Import External packages
##################################
import os
import re
import sys

##################################
# Import Project packages
##################################
sys.path.append(os.environ['AIL_BIN'])
from lib import ConfigLoader

# FLASK #
app = None

# CONFIG #
config_loader = ConfigLoader.ConfigLoader()

# REDIS #
# Initialize connection variables as None - connections will be established lazily
r_serv = None
r_cache = None
r_serv_log = None
r_serv_log_submit = None
r_serv_db = None
r_serv_tags = None

def get_redis_connection(conn_type):
    """Lazy loading of Redis connections to avoid blocking Flask startup"""
    global r_serv, r_cache, r_serv_log, r_serv_log_submit, r_serv_db, r_serv_tags
    
    try:
        if conn_type == "Redis_Queues" and r_serv is None:
            r_serv = config_loader.get_redis_conn("Redis_Queues")
            print("Connected to Redis_Queues")
        elif conn_type == "Redis_Cache" and r_cache is None:
            r_cache = config_loader.get_redis_conn("Redis_Cache")
            print("Connected to Redis_Cache")
        elif conn_type == "Redis_Log" and r_serv_log is None:
            r_serv_log = config_loader.get_redis_conn("Redis_Log")
            print("Connected to Redis_Log")
        elif conn_type == "Redis_Log_submit" and r_serv_log_submit is None:
            r_serv_log_submit = config_loader.get_redis_conn("Redis_Log_submit")
            print("Connected to Redis_Log_submit")
        elif conn_type == "Kvrocks_DB" and r_serv_db is None:
            r_serv_db = config_loader.get_db_conn("Kvrocks_DB")
            print("Connected to Kvrocks_DB")
        elif conn_type == "Kvrocks_Tags" and r_serv_tags is None:
            r_serv_tags = config_loader.get_db_conn("Kvrocks_Tags")
            print("Connected to Kvrocks_Tags")
        return True
    except Exception as e:
        print(f"Warning: Failed to connect to {conn_type}: {e}")
        return False

# Try to establish connections at startup, but don't fail if they're not available
print("Attempting to establish database connections...")
for conn_name in ["Redis_Queues", "Redis_Cache", "Redis_Log", "Redis_Log_submit", "Kvrocks_DB", "Kvrocks_Tags"]:
    get_redis_connection(conn_name)

sys.path.append('../../configs/keys')

#### VARIABLES ####
baseUrl = config_loader.get_config_str("Flask", "baseurl")
baseUrl = baseUrl.replace('/', '')
if baseUrl != '':
    baseUrl = '/' + baseUrl

max_preview_char = int(
    config_loader.get_config_str("Flask", "max_preview_char"))  # Maximum number of character to display in the tooltip
max_preview_modal = int(
    config_loader.get_config_str("Flask", "max_preview_modal"))  # Maximum number of character to display in the modal

max_tags_result = 50

DiffMaxLineLength = int(config_loader.get_config_str("Flask",
                                                     "DiffMaxLineLength"))  # Use to display the estimated percentage instead of a raw value

bootstrap_label = ['primary', 'success', 'danger', 'warning', 'info']

dict_update_description = {'v1.5': {'nb_background_update': 5,
                                    'update_warning_message': 'An Update is running on the background. Some informations like Tags, screenshot can be',
                                    'update_warning_message_notice_me': 'missing from the UI.'},
                           'v2.4': {'nb_background_update': 1,
                                    'update_warning_message': 'An Update is running on the background. Some informations like Domain Tags/Correlation can be',
                                    'update_warning_message_notice_me': 'missing from the UI.'},
                           'v2.6': {'nb_background_update': 1,
                                    'update_warning_message': 'An Update is running on the background. Some informations like Domain Tags/Correlation can be',
                                    'update_warning_message_notice_me': 'missing from the UI.'},
                           'v2.7': {'nb_background_update': 1,
                                    'update_warning_message': 'An Update is running on the background. Some informations like Domain Tags can be',
                                    'update_warning_message_notice_me': 'missing from the UI.'},
                           'v3.4': {'nb_background_update': 1,
                                    'update_warning_message': 'An Update is running on the background. Some informations like Domain Languages can be',
                                    'update_warning_message_notice_me': 'missing from the UI.'},
                           'v3.7': {'nb_background_update': 1,
                                    'update_warning_message': 'An Update is running on the background. Some informations like Tracker first_seen/last_seen can be',
                                    'update_warning_message_notice_me': 'missing from the UI.'}
                           }

UPLOAD_FOLDER = os.path.join(os.environ['AIL_FLASK'], 'submitted')

PASTES_FOLDER = os.path.join(os.environ['AIL_HOME'], config_loader.get_config_str("Directories", "pastes")) + '/'
SCREENSHOT_FOLDER = config_loader.get_files_directory('screenshot')

REPO_ORIGIN = 'https://github.com/ail-project/ail-framework.git'

max_dashboard_logs = int(config_loader.get_config_str("Flask", "max_dashboard_logs"))

crawler_enabled = config_loader.get_config_boolean("Crawler", "activate_crawler")

email_regex = r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,6}'
email_regex = re.compile(email_regex)

# SubmitPaste vars
SUBMIT_PASTE_TEXT_MAX_SIZE = int(config_loader.get_config_str("SubmitPaste", "TEXT_MAX_SIZE"))
SUBMIT_PASTE_FILE_MAX_SIZE = int(config_loader.get_config_str("SubmitPaste", "FILE_MAX_SIZE"))
SUBMIT_PASTE_FILE_ALLOWED_EXTENSIONS = [item.strip() for item in config_loader.get_config_str("SubmitPaste", "FILE_ALLOWED_EXTENSIONS").split(',')]

# VT
try:
    from virusTotalKEYS import vt_key

    if vt_key != '':
        vt_auth = vt_key
        vt_enabled = True
        print('VT submission is enabled')
    else:
        vt_enabled = False
        print('VT submission is disabled')
except:
    vt_auth = {'apikey': config_loader.get_config_str("Flask", "max_preview_char")}
    vt_enabled = False
    print('VT submission is disabled')
