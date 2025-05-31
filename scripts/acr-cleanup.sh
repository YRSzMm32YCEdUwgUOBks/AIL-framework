#!/bin/bash
# Azure Container Registry Smart Cleanup Script
# Keeps the most recent N images per repository, deletes older ones
# Usage: ./acr-cleanup.sh [-a ACR_NAME] [-r RETENTION_COUNT] [-d]

set -euo pipefail

# Default configuration
ACR_NAME=""
RETENTION_COUNT="2"
DRY_RUN="false"

# Parse command line arguments
while getopts "a:r:dh" opt; do
    case $opt in
        a) ACR_NAME="$OPTARG" ;;
        r) RETENTION_COUNT="$OPTARG" ;;
        d) DRY_RUN="true" ;;
        h) echo "Usage: $0 [-a ACR_NAME] [-r RETENTION_COUNT] [-d]"
           echo "  -a: ACR name (auto-discovered if not provided)"
           echo "  -r: Retention count (default: 2)"
           echo "  -d: Dry run mode"
           exit 0 ;;
        *) echo "Invalid option. Use -h for help." >&2; exit 1 ;;
    esac
done

# Auto-discover ACR name if not provided
if [[ -z "$ACR_NAME" ]]; then
    echo "🔍 Auto-discovering ACR name..."
    
    # Try environment variable first
    if [[ -n "${AZURE_CONTAINER_REGISTRY_NAME:-}" ]]; then
        ACR_NAME="$AZURE_CONTAINER_REGISTRY_NAME"
        echo "📋 Found ACR in environment: $ACR_NAME"
    else
        # Query Azure for ACR in current subscription
        local acr_list
        acr_list=$(az acr list --query '[].name' --output tsv 2>/dev/null || echo "")
        
        if [[ -n "$acr_list" ]]; then
            local acr_count
            acr_count=$(echo "$acr_list" | wc -l)
            
            if [[ $acr_count -eq 1 ]]; then
                ACR_NAME=$(echo "$acr_list" | tr -d '\n\r')
                echo "📋 Auto-discovered ACR: $ACR_NAME"
            elif [[ $acr_count -gt 1 ]]; then
                echo "⚠️  Multiple ACRs found. Please specify with -a parameter:"
                echo "$acr_list" | sed 's/^/  - /'
                exit 1
            else
                echo "❌ No ACRs found in current subscription"
                exit 1
            fi
        else
            echo "❌ Failed to query ACRs. Please ensure you're logged into Azure CLI"
            exit 1
        fi
    fi
fi

echo "🧹 Smart ACR Cleanup Starting..."
echo "📋 ACR: $ACR_NAME"
echo "📦 Retention: Keep $RETENTION_COUNT most recent images per repository"
echo "🔍 Dry Run: $DRY_RUN"
echo ""

# Function to cleanup a repository
cleanup_repository() {
    local repo="$1"
    echo "🔍 Processing repository: $repo"
    
    # Get all manifests with creation time, sorted by creation date (newest first)
    local manifests
    manifests=$(az acr manifest list-metadata \
        --registry "$ACR_NAME" \
        --name "$repo" \
        --query '[].{digest:digest,createdTime:createdTime}' \
        --output json 2>/dev/null || echo "[]")
    
    # Count total manifests
    local total_count
    total_count=$(echo "$manifests" | jq '. | length')
    
    if [ "$total_count" -eq 0 ]; then
        echo "  ℹ️  No manifests found"
        return 0
    fi
    
    echo "  📊 Found $total_count manifests"
    
    # If we have fewer or equal images than retention count, keep all
    if [ "$total_count" -le "$RETENTION_COUNT" ]; then
        echo "  ✅ Keeping all $total_count manifests (within retention limit)"
        return 0
    fi
    
    # Get manifests to delete (skip the first N newest ones)
    local manifests_to_delete
    manifests_to_delete=$(echo "$manifests" | jq -r \
        --argjson skip "$RETENTION_COUNT" \
        'sort_by(.createdTime) | reverse | .[$skip:] | .[].digest')
    
    local delete_count
    delete_count=$(echo "$manifests_to_delete" | wc -l)
    
    if [ -z "$manifests_to_delete" ] || [ "$delete_count" -eq 0 ]; then
        echo "  ✅ No manifests to delete"
        return 0
    fi
    
    echo "  🗑️  Will delete $delete_count old manifests (keeping $RETENTION_COUNT newest)"
    
    # Delete old manifests
    while IFS= read -r digest; do
        if [ -n "$digest" ]; then
            if [ "$DRY_RUN" = "true" ]; then
                echo "  🔍 [DRY-RUN] Would delete: $repo@$digest"
            else
                echo "  🗑️  Deleting: $repo@$digest"
                if az acr repository delete \
                    --name "$ACR_NAME" \
                    --image "$repo@$digest" \
                    --yes &>/dev/null; then
                    echo "  ✅ Deleted successfully"
                else
                    echo "  ⚠️  Failed to delete (may be in use)"
                fi
            fi
        fi
    done <<< "$manifests_to_delete"
}

# Get all repositories in the ACR
echo "🔍 Discovering repositories..."
repositories=$(az acr repository list --name "$ACR_NAME" --output tsv 2>/dev/null || true)

if [ -z "$repositories" ]; then
    echo "❌ No repositories found or ACR access failed"
    exit 1
fi

echo "📋 Found repositories:"
echo "$repositories" | sed 's/^/  - /'
echo ""

# Process each repository
while IFS= read -r repo; do
    if [ -n "$repo" ]; then
        cleanup_repository "$repo"
        echo ""
    fi
done <<< "$repositories"

echo "✅ Smart ACR cleanup completed!"

# Show final repository status only if there are repositories
if [ -n "$repositories" ]; then
    echo ""
    echo "📊 Final Repository Status:"
    while IFS= read -r repo; do
        if [ -n "$repo" ] && [ "$repo" != "" ]; then
            count=$(az acr manifest list-metadata --registry "$ACR_NAME" --name "$repo" --query 'length(@)' --output tsv 2>/dev/null)
            if [ $? -eq 0 ] && [ -n "$count" ] && [ "$count" != "" ]; then
                echo "  📦 $repo: $count images"
            else
                echo "  📦 $repo: Unable to get count"
            fi
        fi
    done <<< "$repositories"
fi
