#!/bin/bash

# Smart Entrypoint for AIL Framework
# Routes to appropriate entrypoint based on environment
# Supports: dev-local, test-cloud, prod-cloud environments

set -e

# Default values
DEPLOYMENT_ENV=${DEPLOYMENT_ENV:-"dev-local"}
DEFAULT_ENTRYPOINT="/opt/ail/docker-entrypoint.sh"
AZURE_ENTRYPOINT="/opt/ail/azure-entrypoint.sh"
CONFIG_MANAGER="/opt/ail/bin/lib/environment_config.py"

echo "=== AIL Framework Smart Entrypoint ==="
echo "Deployment Environment: $DEPLOYMENT_ENV"
echo "Container ID: $(hostname)"
echo "Current User: $(whoami)"
echo "Working Directory: $(pwd)"
echo "Timestamp: $(date)"

# Validate environment using configuration manager if available
if [ -f "$CONFIG_MANAGER" ] && command -v python3 >/dev/null 2>&1; then
    echo "Validating environment configuration..."
    if python3 "$CONFIG_MANAGER" --environment "$DEPLOYMENT_ENV" --validate; then
        echo "✓ Environment configuration validated successfully"
        
        # Note: We no longer export environment variables or modify core.cfg
        # The docker-entrypoint.sh now directly uses environment-specific config files
        echo "✓ Using direct environment-specific configuration files"
        
        # Show environment info
        python3 "$CONFIG_MANAGER" --environment "$DEPLOYMENT_ENV" --info
    else
        echo "⚠ Warning: Environment configuration validation failed"
        echo "Continuing with environment: $DEPLOYMENT_ENV"
    fi
else
    echo "⚠ Warning: Configuration manager not available, skipping validation"
fi

# Set AIL_ENV for consistency
export AIL_ENV="$DEPLOYMENT_ENV"

# Route to appropriate entrypoint based on environment
case "$DEPLOYMENT_ENV" in
    "dev-local")
        echo "Routing to: Development-Local Environment"
        echo "Using Docker entrypoint: $DEFAULT_ENTRYPOINT"
        echo "Features: Local Docker services, debug mode, development tools"
        exec "$DEFAULT_ENTRYPOINT" "$@"
        ;;
    "test-cloud")
        echo "Routing to: Test-Cloud Environment"
        echo "Using Azure entrypoint: $AZURE_ENTRYPOINT"
        echo "Features: Azure services, cloud testing, staging, integration tests"
        exec "$AZURE_ENTRYPOINT" "$@"
        ;;
    "prod-cloud")
        echo "Routing to: Production-Cloud Environment"
        echo "Using Azure entrypoint: $AZURE_ENTRYPOINT"
        echo "Features: Azure services, SSL, high availability, production"
        exec "$AZURE_ENTRYPOINT" "$@"
        ;;
    *)
        echo "❌ ERROR: Unsupported deployment environment '$DEPLOYMENT_ENV'"
        echo "Supported environments: dev-local, test-cloud, prod-cloud"
        echo ""
        echo "Falling back to dev-local environment with Docker entrypoint"
        export DEPLOYMENT_ENV="dev-local"
        export AIL_ENV="dev-local"
        exec "$DEFAULT_ENTRYPOINT" "$@"
        ;;
esac