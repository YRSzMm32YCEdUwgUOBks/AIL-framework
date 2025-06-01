#!/usr/bin/env python3
"""
Environment Configuration Manager for AIL Framework

This module provides dynamic environment-based configuration loading
supporting dev, local, test, and prod environments.

Usage:
    from bin.lib.environment_config import EnvironmentConfig
    
    # Load configuration for current environment
    config = EnvironmentConfig()
    
    # Or load specific environment
    config = EnvironmentConfig(environment='dev')
    
    # Get configuration values
    redis_host = config.get('Redis', 'host')
    log_level = config.get('Logs', 'logLevel')
"""

import os
import sys
import configparser
import logging
from pathlib import Path
from typing import Optional, Dict, Any


class EnvironmentConfig:
    """
    Environment-aware configuration manager for AIL Framework.
    
    Supports multiple deployment environments:
    - dev-local: Local development with Docker containers
    - test-cloud: Cloud-based testing and staging 
    - prod-cloud: Production cloud deployment
    """
    
    SUPPORTED_ENVIRONMENTS = ['dev-local', 'test-cloud', 'prod-cloud']
    DEFAULT_ENVIRONMENT = 'dev-local'
    
    def __init__(self, environment: Optional[str] = None, config_root: Optional[str] = None):
        """
        Initialize configuration manager.
        
        Args:
            environment: Target environment (dev/local/test/prod)
            config_root: Root path for configuration files
        """
        self.environment = self._determine_environment(environment)
        self.config_root = Path(config_root) if config_root else self._find_config_root()
        self.config = configparser.ConfigParser()
        self.logger = self._setup_logging()
        
        # Load configuration
        self._load_configuration()
        self._substitute_environment_variables()
        
        self.logger.info(f"Loaded configuration for environment: {self.environment}")
    
    def _determine_environment(self, environment: Optional[str]) -> str:
        """Determine the target environment from various sources."""
        # Priority order for environment detection:
        # 1. Explicit parameter
        # 2. DEPLOYMENT_ENV environment variable
        # 3. AIL_ENV environment variable
        # 4. Default environment
        
        if environment:
            env = environment.lower()
            if env in self.SUPPORTED_ENVIRONMENTS:
                return env
            else:
                raise ValueError(f"Unsupported environment: {environment}. "
                               f"Supported: {', '.join(self.SUPPORTED_ENVIRONMENTS)}")
        
        # Check environment variables
        for env_var in ['DEPLOYMENT_ENV', 'AIL_ENV']:
            env_value = os.getenv(env_var, '').lower()
            if env_value in self.SUPPORTED_ENVIRONMENTS:
                return env_value
            elif env_value in ['development', 'docker']:
                return 'local'
            elif env_value in ['staging', 'testing']:
                return 'test'
            elif env_value in ['production', 'azure', 'cloud']:
                return 'prod'
        
        return self.DEFAULT_ENVIRONMENT
    
    def _find_config_root(self) -> Path:
        """Find the configuration root directory."""
        # Start from current directory and walk up to find configs
        current_path = Path.cwd()
        
        for path in [current_path] + list(current_path.parents):
            configs_path = path / 'configs'
            if configs_path.is_dir() and (configs_path / 'environments').is_dir():
                return configs_path
        
        # Fallback: relative to this script
        script_path = Path(__file__).parent.parent.parent
        configs_path = script_path / 'configs'
        
        if not configs_path.is_dir():
            raise FileNotFoundError(f"Configuration directory not found. "
                                  f"Expected at: {configs_path}")
        
        return configs_path
    
    def _setup_logging(self) -> logging.Logger:
        """Setup basic logging for the configuration manager."""
        logger = logging.getLogger(f'ail.config.{self.environment}')
        if not logger.handlers:
            handler = logging.StreamHandler()
            formatter = logging.Formatter(
                '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
            )
            handler.setFormatter(formatter)
            logger.addHandler(handler)
            logger.setLevel(logging.INFO)
        return logger
    
    def _load_configuration(self) -> None:
        """Load configuration files in order of precedence."""
        config_files = []
        
        # 1. Load base configuration if it exists
        base_config = self.config_root / 'core.cfg'
        if base_config.exists():
            config_files.append(base_config)
        
        # 2. Load environment-specific configuration
        env_config = self.config_root / 'environments' / f'{self.environment}.cfg'
        if not env_config.exists():
            raise FileNotFoundError(f"Environment configuration not found: {env_config}")
        config_files.append(env_config)
        
        # 3. Load local overrides if they exist
        local_override = self.config_root / f'{self.environment}.local.cfg'
        if local_override.exists():
            config_files.append(local_override)
            self.logger.info(f"Found local override: {local_override}")
        
        # Read all configuration files
        for config_file in config_files:
            self.logger.debug(f"Loading configuration: {config_file}")
            try:
                self.config.read(config_file)
            except Exception as e:
                self.logger.error(f"Failed to load {config_file}: {e}")
                raise
    
    def _substitute_environment_variables(self) -> None:
        """Substitute environment variables in configuration values."""
        for section_name in self.config.sections():
            section = self.config[section_name]
            for key, value in section.items():
                if isinstance(value, str) and '${' in value:
                    # Simple environment variable substitution
                    import re
                    env_vars = re.findall(r'\$\{([^}]+)\}', value)
                    for env_var in env_vars:
                        env_value = os.getenv(env_var, '')
                        if env_value:
                            value = value.replace(f'${{{env_var}}}', env_value)
                        else:
                            self.logger.warning(f"Environment variable not found: {env_var}")
                    section[key] = value
    
    def get(self, section: str, option: str, fallback: Any = None) -> Any:
        """
        Get configuration value with environment-aware fallback.
        
        Args:
            section: Configuration section name
            option: Configuration option name
            fallback: Default value if option not found
            
        Returns:
            Configuration value or fallback
        """
        try:
            return self.config.get(section, option)
        except (configparser.NoSectionError, configparser.NoOptionError):
            if fallback is not None:
                return fallback
            raise
    
    def getint(self, section: str, option: str, fallback: Optional[int] = None) -> int:
        """Get integer configuration value."""
        try:
            return self.config.getint(section, option)
        except (configparser.NoSectionError, configparser.NoOptionError):
            if fallback is not None:
                return fallback
            raise
    
    def getboolean(self, section: str, option: str, fallback: Optional[bool] = None) -> bool:
        """Get boolean configuration value."""
        try:
            return self.config.getboolean(section, option)
        except (configparser.NoSectionError, configparser.NoOptionError):
            if fallback is not None:
                return fallback
            raise
    
    def getfloat(self, section: str, option: str, fallback: Optional[float] = None) -> float:
        """Get float configuration value."""
        try:
            return self.config.getfloat(section, option)
        except (configparser.NoSectionError, configparser.NoOptionError):
            if fallback is not None:
                return fallback
            raise
    
    def get_section(self, section: str) -> Dict[str, str]:
        """Get entire configuration section as dictionary."""
        try:
            return dict(self.config[section])
        except KeyError:
            return {}
    
    def get_environment_info(self) -> Dict[str, str]:
        """Get environment information."""
        env_section = self.get_section('Environment')
        return {
            'name': env_section.get('name', self.environment),
            'type': env_section.get('type', 'unknown'),
            'deployment_target': env_section.get('deployment_target', 'unknown'),
            'log_level': env_section.get('log_level', 'INFO'),
            'debug_mode': env_section.get('debug_mode', 'False')
        }
    
    def is_development(self) -> bool:
        """Check if running in development environment."""
        return self.environment in ['dev', 'local']
    
    def is_production(self) -> bool:
        """Check if running in production environment."""
        return self.environment == 'prod'
    
    def is_testing(self) -> bool:
        """Check if running in testing environment."""
        return self.environment == 'test'
    
    def export_env_file(self, output_path: Optional[str] = None) -> str:
        """
        Export configuration as environment file for Docker/containers.
        
        Args:
            output_path: Output file path (optional)
            
        Returns:
            Path to exported environment file
        """
        if not output_path:
            output_path = self.config_root / f'.env.{self.environment}'
        
        env_lines = [
            f"# Environment configuration for {self.environment}",
            f"# Generated automatically - do not edit manually",
            f"DEPLOYMENT_ENV={self.environment}",
            f"AIL_ENV={self.environment}",
            ""
        ]
        
        # Export key configuration values as environment variables
        key_configs = [
            ('Redis', 'host', 'REDIS_HOST'),
            ('Redis', 'port', 'REDIS_PORT'),
            ('Redis', 'password', 'REDIS_PASSWORD'),
            ('Flask', 'secret_key', 'FLASK_SECRET_KEY'),
            ('Logs', 'logLevel', 'LOG_LEVEL'),
            ('Notifications', 'ail_domain', 'AIL_DOMAIN'),
        ]
        
        for section, option, env_name in key_configs:
            try:
                value = self.get(section, option)
                if value:
                    env_lines.append(f"{env_name}={value}")
            except:
                pass
        
        with open(output_path, 'w') as f:
            f.write('\n'.join(env_lines))
        
        self.logger.info(f"Exported environment configuration to: {output_path}")
        return str(output_path)
    
    def validate_configuration(self) -> bool:
        """
        Validate that required configuration options are present.
        
        Returns:
            True if configuration is valid
        """
        required_sections = ['Environment', 'Redis', 'Flask', 'Logs']
        errors = []
        
        for section in required_sections:
            if not self.config.has_section(section):
                errors.append(f"Missing required section: {section}")
        
        if errors:
            for error in errors:
                self.logger.error(error)
            return False
        
        self.logger.info("Configuration validation passed")
        return True


# Convenience function for quick configuration loading
def load_config(environment: Optional[str] = None) -> EnvironmentConfig:
    """
    Quick configuration loader.
    
    Args:
        environment: Target environment (optional)
        
    Returns:
        Configured EnvironmentConfig instance
    """
    return EnvironmentConfig(environment=environment)


# CLI interface for testing and debugging
def main():
    """CLI interface for configuration management."""
    import argparse
    
    parser = argparse.ArgumentParser(description='AIL Environment Configuration Manager')
    parser.add_argument('--environment', '-e', 
                       choices=EnvironmentConfig.SUPPORTED_ENVIRONMENTS,
                       help='Target environment')
    parser.add_argument('--validate', '-v', action='store_true',
                       help='Validate configuration')
    parser.add_argument('--export-env', '-x', action='store_true',
                       help='Export environment file')
    parser.add_argument('--info', '-i', action='store_true',
                       help='Show environment information')
    parser.add_argument('--get', '-g', nargs=2, metavar=('SECTION', 'OPTION'),
                       help='Get specific configuration value')
    
    args = parser.parse_args()
    
    try:
        config = EnvironmentConfig(environment=args.environment)
        
        if args.validate:
            is_valid = config.validate_configuration()
            print(f"Configuration valid: {is_valid}")
            sys.exit(0 if is_valid else 1)
        
        if args.export_env:
            env_file = config.export_env_file()
            print(f"Environment file exported: {env_file}")
        
        if args.info:
            env_info = config.get_environment_info()
            print("Environment Information:")
            for key, value in env_info.items():
                print(f"  {key}: {value}")
        
        if args.get:
            section, option = args.get
            try:
                value = config.get(section, option)
                print(f"{section}.{option} = {value}")
            except Exception as e:
                print(f"Error getting {section}.{option}: {e}")
                sys.exit(1)
        
        if not any([args.validate, args.export_env, args.info, args.get]):
            print(f"Configuration loaded successfully for environment: {config.environment}")
            print(f"Configuration root: {config.config_root}")
    
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)


if __name__ == '__main__':
    main()
