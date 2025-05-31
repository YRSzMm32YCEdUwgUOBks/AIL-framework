# AIL Framework with Lacus - PowerShell Startup Script

param(
    [Parameter(Position=0)]
    [string]$Command = "up",
    
    [Parameter(Position=1)]
    [string]$Service = "",
    
    [Parameter()]
    [ValidateSet("dev-local", "test-cloud", "prod-cloud")]
    [string]$Environment = "dev-local"
)

$LacusCompose = "configs/docker/docker-compose.lacus.yml"
$MainCompose = "configs/docker/docker-compose.ail.yml"

# Environment-specific overrides
$EnvOverrides = @{
    "dev-local"   = @("configs/docker/docker-compose.dev-local.yml")
    "test-cloud"  = @("configs/docker/docker-compose.test-cloud.yml")
    "prod-cloud"  = @()  # Production uses Azure deployment, not local Docker
}

# Environment descriptions
$EnvDescriptions = @{
    "dev-local"   = "Local development with Docker services"
    "test-cloud"  = "Cloud testing/staging environment with external services"
    "prod-cloud"  = "Production cloud environment (Azure/AWS/GCP deployment)"
}

function Show-Usage {
    Write-Host "=== AIL Framework Multi-Environment Startup Script ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Usage: .\start-all.ps1 {command} [service] [-Environment {environment}]" -ForegroundColor White
    Write-Host ""
    Write-Host "Commands:" -ForegroundColor Yellow
    Write-Host "  up           - Start all services (Lacus first, then AIL)"
    Write-Host "  down         - Stop all services"
    Write-Host "  restart      - Restart all services"
    Write-Host "  logs [svc]   - Show logs for a specific service or list available services"
    Write-Host "  status       - Show status of all services"
    Write-Host "  lacus-only   - Manage only Lacus services"
    Write-Host "  ail-only     - Manage only AIL services"
    Write-Host "  config       - Show current environment configuration"
    Write-Host "  validate     - Validate environment configuration"
    Write-Host ""
    Write-Host "Environments:" -ForegroundColor Yellow
    foreach ($env in $EnvDescriptions.Keys | Sort-Object) {
        $desc = $EnvDescriptions[$env]
        Write-Host "  $env" -ForegroundColor Green -NoNewline
        Write-Host (" " * (12 - $env.Length)) -NoNewline
        Write-Host "- $desc" -ForegroundColor Gray
    }
    Write-Host ""    Write-Host "Examples:" -ForegroundColor Yellow
    Write-Host "  .\start-all.ps1 up                           # Start in dev-local mode"
    Write-Host "  .\start-all.ps1 up -Environment test-cloud   # Start in cloud testing mode"
    Write-Host "  .\start-all.ps1 logs ail-app                # Show AIL application logs"
    Write-Host "  .\start-all.ps1 lacus-only up               # Start only Lacus services"
    Write-Host "  .\start-all.ps1 config -Environment test-cloud # Show test environment config"
    Write-Host "  .\start-all.ps1 validate -Environment dev-local # Validate dev environment"
    Write-Host ""
}

# Helper function to build compose arguments with environment overrides
function Get-ComposeArgs {
    param([string]$ComposeFile, [string]$Env)
    
    $composeArgs = @("-f", $ComposeFile)
    
    # Add environment-specific override file if it exists
    if ($EnvOverrides.ContainsKey($Env) -and $EnvOverrides[$Env].Count -gt 0) {
        foreach ($override in $EnvOverrides[$Env]) {
            if (Test-Path $override) {
                $composeArgs += @("-f", $override)
                Write-Host "📁 Using environment override: $override" -ForegroundColor Blue
            }
        }
    }
    
    return $composeArgs
}

# Helper function specifically for AIL compose arguments (applies overrides)
function Get-AILComposeArgs {
    param([string]$ComposeFile, [string]$Env)
    
    $composeArgs = @("-f", $ComposeFile)
    
    # Add environment-specific override file if it exists
    if ($EnvOverrides.ContainsKey($Env) -and $EnvOverrides[$Env].Count -gt 0) {
        foreach ($override in $EnvOverrides[$Env]) {
            if (Test-Path $override) {
                $composeArgs += @("-f", $override)
                Write-Host "📁 Using AIL environment override: $override" -ForegroundColor Blue
            }
        }
    }
    
    return $composeArgs
}

# Helper function specifically for Lacus compose arguments (no overrides for now)
function Get-LacusComposeArgs {
    param([string]$ComposeFile, [string]$Env)
    
    $composeArgs = @("-f", $ComposeFile)
    # Note: Not applying dev-local overrides to Lacus since they contain AIL-specific services
    
    return $composeArgs
}

# Function to validate environment configuration
function Test-EnvironmentConfig {
    param([string]$Env)
    
    $configManager = "bin/lib/environment_config.py"
    if (Test-Path $configManager) {
        Write-Host "🔍 Validating environment configuration..." -ForegroundColor Yellow
        $result = python $configManager --environment $Env --validate 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Environment configuration validated successfully" -ForegroundColor Green
            return $true
        } else {
            Write-Host "❌ Environment configuration validation failed:" -ForegroundColor Red
            Write-Host $result -ForegroundColor Red
            return $false
        }
    } else {
        Write-Host "⚠️ Configuration manager not found, skipping validation" -ForegroundColor Yellow
        return $true
    }
}

# Function to show environment configuration
function Show-EnvironmentConfig {
    param([string]$Env)
    
    $configManager = "bin/lib/environment_config.py"
    if (Test-Path $configManager) {
        Write-Host "📋 Environment Configuration for: $Env" -ForegroundColor Cyan
        Write-Host "Description: $($EnvDescriptions[$Env])" -ForegroundColor Gray
        Write-Host ""
        python $configManager --environment $Env --info
    } else {
        Write-Host "❌ Configuration manager not found: $configManager" -ForegroundColor Red
    }
}

switch ($Command.ToLower()) {
    "up" {
        Write-Host "🚀 Starting AIL Framework with Lacus in $Environment environment..." -ForegroundColor Green
        Write-Host "Environment: $($EnvDescriptions[$Environment])" -ForegroundColor Gray
        
        # Validate environment configuration
        if (-not (Test-EnvironmentConfig -Env $Environment)) {
            Write-Host "❌ Environment validation failed. Please check your configuration." -ForegroundColor Red
            exit 1
        }
        
        Write-Host "Creating external network 'ail-net' if it doesn't exist..."
        try {
            docker network create ail-net --driver bridge 2>$null
        } catch {
            # Network likely already exists
        }
          Write-Host "🔧 Starting Lacus services..."
        $lacusArgs = Get-LacusComposeArgs -ComposeFile $LacusCompose -Env $Environment
        & docker-compose @lacusArgs up -d --remove-orphans
        
        Write-Host "⏳ Waiting for Lacus to be ready..."
        Start-Sleep -Seconds 10
        
        Write-Host "🎯 Starting AIL services..."
        $ailArgs = Get-AILComposeArgs -ComposeFile $MainCompose -Env $Environment
        & docker-compose @ailArgs up -d --remove-orphans
        
        Write-Host "✅ All services started successfully!" -ForegroundColor Green
        Write-Host "🌐 AIL Web Interface: http://localhost:7000" -ForegroundColor Cyan
        Write-Host "🔗 Lacus API: http://localhost:7100" -ForegroundColor Cyan
        Write-Host "📊 Environment: $Environment" -ForegroundColor Cyan
    }    "down" {
        Write-Host "🛑 Stopping AIL Framework and Lacus..." -ForegroundColor Yellow
        $ailArgs = Get-AILComposeArgs -ComposeFile $MainCompose -Env $Environment
        $lacusArgs = Get-LacusComposeArgs -ComposeFile $LacusCompose -Env $Environment
        & docker-compose @ailArgs down --remove-orphans
        & docker-compose @lacusArgs down --remove-orphans
        Write-Host "✅ All services stopped." -ForegroundColor Green
    }
    "config" {
        Show-EnvironmentConfig -Env $Environment
    }
    "validate" {
        $isValid = Test-EnvironmentConfig -Env $Environment
        if ($isValid) {
            Write-Host "✅ Environment '$Environment' configuration is valid" -ForegroundColor Green
        } else {
            Write-Host "❌ Environment '$Environment' configuration has errors" -ForegroundColor Red
            exit 1
        }
    }
      "restart" {
        Write-Host "🔄 Restarting AIL Framework and Lacus in $Environment environment..." -ForegroundColor Yellow
        & $MyInvocation.MyCommand.Path down -Environment $Environment
        Start-Sleep -Seconds 5
        & $MyInvocation.MyCommand.Path up -Environment $Environment
    }
    
    "logs" {
        if ($Service) {
            $ailArgs = Get-ComposeArgs -ComposeFile $MainCompose -Env $Environment
            $lacusArgs = Get-ComposeArgs -ComposeFile $LacusCompose -Env $Environment
            
            $mainServices = & docker-compose @ailArgs ps --services
            $lacusServices = & docker-compose @lacusArgs ps --services
            
            if ($mainServices -contains $Service) {
                Write-Host "📋 Showing logs for AIL service: $Service" -ForegroundColor Cyan
                & docker-compose @ailArgs logs -f $Service
            } elseif ($lacusServices -contains $Service) {
                Write-Host "📋 Showing logs for Lacus service: $Service" -ForegroundColor Cyan
                & docker-compose @lacusArgs logs -f $Service
            } else {
                Write-Host "❌ Service '$Service' not found." -ForegroundColor Red
                Write-Host "Available services:" -ForegroundColor Yellow
                Write-Host "AIL services: $($mainServices -join ', ')" -ForegroundColor Gray
                Write-Host "Lacus services: $($lacusServices -join ', ')" -ForegroundColor Gray
                exit 1
            }
        } else {
            Write-Host "📋 Available services:" -ForegroundColor Cyan
            $ailArgs = Get-ComposeArgs -ComposeFile $MainCompose -Env $Environment
            $lacusArgs = Get-ComposeArgs -ComposeFile $LacusCompose -Env $Environment
            Write-Host "AIL services:" -ForegroundColor Yellow
            & docker-compose @ailArgs ps --services
            Write-Host "Lacus services:" -ForegroundColor Yellow
            & docker-compose @lacusArgs ps --services
        }
    }
    "status" {
        Write-Host "📊 AIL Services Status ($Environment environment):" -ForegroundColor Cyan
        $ailArgs = Get-ComposeArgs -ComposeFile $MainCompose -Env $Environment
        & docker-compose @ailArgs ps
        Write-Host ""
        Write-Host "📊 Lacus Services Status:" -ForegroundColor Cyan
        $lacusArgs = Get-ComposeArgs -ComposeFile $LacusCompose -Env $Environment
        & docker-compose @lacusArgs ps
    }
    "lacus-only" {
        $Action = if ($Service) { $Service } else { "up" }
        Write-Host "🔧 Managing Lacus services only: $Action ($Environment environment)" -ForegroundColor Yellow
        $lacusArgs = Get-ComposeArgs -ComposeFile $LacusCompose -Env $Environment
        if ($Action -eq "up" -or $Action -eq "down") {
            & docker-compose @lacusArgs $Action --remove-orphans
        } else {
            & docker-compose @lacusArgs $Action
        }
    }
    
    "ail-only" {
        $Action = if ($Service) { $Service } else { "up" }
        Write-Host "🎯 Managing AIL services only: $Action ($Environment environment)" -ForegroundColor Yellow
        $ailArgs = Get-ComposeArgs -ComposeFile $MainCompose -Env $Environment
        if ($Action -eq "up" -or $Action -eq "down") {
            & docker-compose @ailArgs $Action --remove-orphans
        } else {
            & docker-compose @ailArgs $Action
        }
    }
    
    default {
        Show-Usage
        exit 1
    }
}
