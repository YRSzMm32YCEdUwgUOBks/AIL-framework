# AIL Framework with Lacus - PowerShell Startup Script

param(
    [Parameter(Position=0)]
    [string]$Command = "up",
    
    [Parameter(Position=1)]
    [string]$Service = ""
)

$LacusCompose = "docker-compose.lacus.yml"
$MainCompose = "docker-compose.yml"

function Show-Usage {
    Write-Host "Usage: .\start-all.ps1 {up|down|restart|logs [service]|status|lacus-only [action]|ail-only [action]}"
    Write-Host ""
    Write-Host "Commands:"
    Write-Host "  up           - Start all services (Lacus first, then AIL)"
    Write-Host "  down         - Stop all services"
    Write-Host "  restart      - Restart all services"
    Write-Host "  logs [svc]   - Show logs for a specific service or list available services"
    Write-Host "  status       - Show status of all services"
    Write-Host "  lacus-only   - Manage only Lacus services"
    Write-Host "  ail-only     - Manage only AIL services"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\start-all.ps1 up                    # Start everything"
    Write-Host "  .\start-all.ps1 logs lacus           # Show Lacus logs"
    Write-Host "  .\start-all.ps1 lacus-only down      # Stop only Lacus"
    Write-Host "  .\start-all.ps1 ail-only restart     # Restart only AIL"
}

switch ($Command.ToLower()) {
    "up" {
        Write-Host "Starting AIL Framework with Lacus..." -ForegroundColor Green
        Write-Host "Creating external network 'ail-net' if it doesn't exist..."
        try {
            docker network create ail-net --driver bridge 2>$null
        } catch {
            # Network likely already exists
        }
        Write-Host "Starting Lacus services..."
        docker-compose -f $LacusCompose up -d --remove-orphans
        
        Write-Host "Waiting for Lacus to be ready..."
        Start-Sleep -Seconds 10
        
        Write-Host "Starting AIL services..."
        docker-compose -f $MainCompose up -d --remove-orphans
        
        Write-Host "All services started successfully!" -ForegroundColor Green
        Write-Host "AIL Web Interface: http://localhost:7000" -ForegroundColor Cyan
        Write-Host "Lacus API: http://localhost:7100" -ForegroundColor Cyan
    }
    "down" {
        Write-Host "Stopping AIL Framework and Lacus..." -ForegroundColor Yellow
        docker-compose -f $MainCompose down --remove-orphans
        docker-compose -f $LacusCompose down --remove-orphans
        Write-Host "All services stopped." -ForegroundColor Green
    }
    
    "restart" {
        Write-Host "Restarting AIL Framework and Lacus..." -ForegroundColor Yellow
        & $MyInvocation.MyCommand.Path down
        Start-Sleep -Seconds 5
        & $MyInvocation.MyCommand.Path up
    }
    
    "logs" {
        if ($Service) {
            $mainServices = docker-compose -f $MainCompose ps --services
            $lacusServices = docker-compose -f $LacusCompose ps --services
            
            if ($mainServices -contains $Service) {
                docker-compose -f $MainCompose logs -f $Service
            } elseif ($lacusServices -contains $Service) {
                docker-compose -f $LacusCompose logs -f $Service
            } else {
                Write-Host "Service '$Service' not found." -ForegroundColor Red
                exit 1
            }
        } else {
            Write-Host "Available services:" -ForegroundColor Cyan
            Write-Host "Main services:" -ForegroundColor Yellow
            docker-compose -f $MainCompose ps --services
            Write-Host "Lacus services:" -ForegroundColor Yellow
            docker-compose -f $LacusCompose ps --services
        }
    }
    
    "status" {
        Write-Host "AIL Services Status:" -ForegroundColor Cyan
        docker-compose -f $MainCompose ps
        Write-Host ""
        Write-Host "Lacus Services Status:" -ForegroundColor Cyan
        docker-compose -f $LacusCompose ps
    }
    "lacus-only" {
        $Action = if ($Service) { $Service } else { "up" }
        Write-Host "Managing Lacus services only: $Action" -ForegroundColor Yellow
        if ($Action -eq "up" -or $Action -eq "down") {
            docker-compose -f $LacusCompose $Action --remove-orphans
        } else {
            docker-compose -f $LacusCompose $Action
        }
    }
    
    "ail-only" {
        $Action = if ($Service) { $Service } else { "up" }
        Write-Host "Managing AIL services only: $Action" -ForegroundColor Yellow
        if ($Action -eq "up" -or $Action -eq "down") {
            docker-compose -f $MainCompose $Action --remove-orphans
        } else {
            docker-compose -f $MainCompose $Action
        }
    }
    
    default {
        Show-Usage
        exit 1
    }
}
