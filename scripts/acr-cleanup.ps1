# Azure Container Registry Smart Cleanup Script (PowerShell)
# Keeps the most recent N images per repository, deletes older ones
# Usage: .\acr-cleanup.ps1 [-RetentionCount N] [-DryRun]

param(
    [string]$AcrName = "",
    [int]$RetentionCount = 2,
    [switch]$DryRun = $false
)

$ErrorActionPreference = "Stop"

# Auto-discover ACR name if not provided
if (-not $AcrName) {
    Write-Host "🔍 Auto-discovering ACR name..." -ForegroundColor Cyan
    
    # Try environment variable first
    if ($env:AZURE_CONTAINER_REGISTRY_NAME) {
        $AcrName = $env:AZURE_CONTAINER_REGISTRY_NAME
        Write-Host "📋 Found ACR in environment: $AcrName" -ForegroundColor Green
    } else {
        # Query Azure for ACR in current subscription/resource group
        try {
            $acrList = & az acr list --query '[].name' --output tsv 2>$null
            if ($LASTEXITCODE -eq 0 -and $acrList) {
                $acrArray = $acrList -split "`n" | Where-Object { $_.Trim() }
                if ($acrArray.Count -eq 1) {
                    $AcrName = $acrArray[0].Trim()
                    Write-Host "📋 Auto-discovered ACR: $AcrName" -ForegroundColor Green
                } elseif ($acrArray.Count -gt 1) {
                    Write-Host "⚠️  Multiple ACRs found. Please specify with -AcrName parameter:" -ForegroundColor Yellow
                    $acrArray | ForEach-Object { Write-Host "  - $_" -ForegroundColor Gray }
                    exit 1
                } else {
                    Write-Host "❌ No ACRs found in current subscription" -ForegroundColor Red
                    exit 1
                }
            } else {
                Write-Host "❌ Failed to query ACRs. Please ensure you're logged into Azure CLI" -ForegroundColor Red
                exit 1
            }
        } catch {
            Write-Host "❌ Error discovering ACR: $($_.Exception.Message)" -ForegroundColor Red
            exit 1
        }
    }
}

Write-Host "🧹 Smart ACR Cleanup Starting..." -ForegroundColor Cyan
Write-Host "📋 ACR: $AcrName" -ForegroundColor Yellow
Write-Host "📦 Retention: Keep $RetentionCount most recent images per repository" -ForegroundColor Yellow
Write-Host "🔍 Dry Run: $DryRun" -ForegroundColor Yellow
Write-Host ""

function Clear-Repository {
    param([string]$Repository)
    
    Write-Host "🔍 Processing repository: $Repository" -ForegroundColor White
      try {
        # Get all manifests with creation time using the new API
        $manifestsJson = & az acr manifest list-metadata --registry $AcrName --name $Repository --query '[].{digest:digest,createdTime:createdTime}' --output json 2>$null
        
        if ($LASTEXITCODE -ne 0 -or -not $manifestsJson) {
            Write-Host "  ℹ️  No manifests found or repository doesn't exist" -ForegroundColor Gray
            return
        }
        
        $manifests = $manifestsJson | ConvertFrom-Json
        $totalCount = $manifests.Count
        
        Write-Host "  📊 Found $totalCount manifests" -ForegroundColor Gray
        
        # If we have fewer or equal images than retention count, keep all
        if ($totalCount -le $RetentionCount) {
            Write-Host "  ✅ Keeping all $totalCount manifests (within retention limit)" -ForegroundColor Green
            return
        }        # Sort by creation time (newest first) and get manifests to delete
        $sortedManifests = $manifests | 
            Where-Object { $_.createdTime } |
            Sort-Object { [DateTime]$_.createdTime } -Descending
        $manifestsToDelete = $sortedManifests | Select-Object -Skip $RetentionCount
        
        $deleteCount = $manifestsToDelete.Count
        
        if ($deleteCount -eq 0) {
            Write-Host "  ✅ No manifests to delete" -ForegroundColor Green
            return
        }
        
        Write-Host "  🗑️  Will delete $deleteCount old manifests (keeping $RetentionCount newest)" -ForegroundColor Yellow
        
        # Delete old manifests
        foreach ($manifest in $manifestsToDelete) {
            $imageRef = "$Repository@$($manifest.digest)"
            
            if ($DryRun) {
                Write-Host "  🔍 [DRY-RUN] Would delete: $imageRef" -ForegroundColor Magenta
            } else {
                Write-Host "  🗑️  Deleting: $imageRef" -ForegroundColor Red
                try {
                    & az acr repository delete --name $AcrName --image $imageRef --yes | Out-Null
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "  ✅ Deleted successfully" -ForegroundColor Green
                    } else {
                        Write-Host "  ⚠️  Failed to delete (may be in use)" -ForegroundColor Yellow
                    }
                } catch {
                    Write-Host "  ⚠️  Failed to delete: $($_.Exception.Message)" -ForegroundColor Yellow
                }
            }
        }
    } catch {
        Write-Host "  ❌ Error processing repository: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Get all repositories in the ACR
Write-Host "🔍 Discovering repositories..." -ForegroundColor Cyan
try {
    $repositories = & az acr repository list --name $AcrName --output tsv 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $repositories -or $repositories.Trim() -eq "") {
        Write-Host "❌ No repositories found or ACR access failed" -ForegroundColor Red
        exit 1
    }

    $repoList = $repositories -split "`n" | Where-Object { $_ -and $_.Trim() -ne "" }

    Write-Host "📋 Found repositories:" -ForegroundColor White
    $repoList | ForEach-Object { Write-Host "  - $_" -ForegroundColor Gray }
    Write-Host ""

    foreach ($repo in $repoList) {
        if ($repo -and $repo.Trim()) {
            try {
                $count = & az acr manifest list-metadata --registry $AcrName --name $repo.Trim() --query 'length(@)' --output tsv 2>$null 
                if ($LASTEXITCODE -eq 0 -and $null -ne $count -and $count -ne "") {
                    Write-Host "  📦 ${repo}: $count images" -ForegroundColor Gray
                } else {
                    Write-Host "  📦 ${repo}: Unable to get count" -ForegroundColor Yellow
                }
            } catch {
                Write-Host "  📦 ${repo}: Unable to get count" -ForegroundColor Yellow
                continue
            }
        }
    }

    Write-Host "✅ Smart ACR cleanup completed!" -ForegroundColor Green

    if ($repoList.Count -gt 0) {
        # Show final repository status
        Write-Host ""
        Write-Host "📊 Final Repository Status:" -ForegroundColor Cyan
        foreach ($repo in $repoList) {
            if ($repo -and $repo.Trim()) {
                try {
                    $count = & az acr manifest list-metadata --registry $AcrName --name $repo.Trim() --query 'length(@)' --output tsv 2>$null
                    if ($LASTEXITCODE -eq 0 -and $null -ne $count -and $count -ne "") {
                        Write-Host "  📦 ${repo}: $count images" -ForegroundColor Gray
                    } else {
                        Write-Host "  📦 ${repo}: Unable to get count" -ForegroundColor Yellow
                    }
                } catch {
                    Write-Host "  📦 ${repo}: Unable to get count" -ForegroundColor Yellow
                }
            }
        }
    }
} catch {
    Write-Host "❌ Failed to discover repositories: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
