#!/bin/bash

# AIL Framework with Lacus - Startup Script

set -e

COMMAND=${1:-up}
LACUS_COMPOSE="configs/docker/docker-compose.lacus.yml"
MAIN_COMPOSE="configs/docker/docker-compose.ail.yml"

case "$COMMAND" in
    up)
        echo "Starting AIL Framework with Lacus..."
        echo "Creating external network 'ail-net' if it doesn't exist..."
        docker network create ail-net --driver bridge || true
        
        echo "Starting Lacus services..."
        docker-compose -f $LACUS_COMPOSE up -d
        
        echo "Waiting for Lacus to be ready..."
        sleep 10
        
        echo "Starting AIL services..."
        docker-compose -f $MAIN_COMPOSE up -d
        
        echo "All services started successfully!"
        echo "AIL Web Interface: http://localhost:7000"
        echo "Lacus API: http://localhost:7100"
        ;;
    
    down)
        echo "Stopping AIL Framework and Lacus..."
        docker-compose -f $MAIN_COMPOSE down
        docker-compose -f $LACUS_COMPOSE down
        echo "All services stopped."
        ;;
    
    restart)
        echo "Restarting AIL Framework and Lacus..."
        $0 down
        sleep 5
        $0 up
        ;;
    
    logs)
        SERVICE=${2:-}
        if [ -n "$SERVICE" ]; then
            if docker-compose -f $MAIN_COMPOSE ps | grep -q "$SERVICE"; then
                docker-compose -f $MAIN_COMPOSE logs -f "$SERVICE"
            elif docker-compose -f $LACUS_COMPOSE ps | grep -q "$SERVICE"; then
                docker-compose -f $LACUS_COMPOSE logs -f "$SERVICE"
            else
                echo "Service '$SERVICE' not found."
                exit 1
            fi
        else
            echo "Available services:"
            echo "Main services:"
            docker-compose -f $MAIN_COMPOSE ps --services
            echo "Lacus services:"
            docker-compose -f $LACUS_COMPOSE ps --services
        fi
        ;;
    
    status)
        echo "AIL Services Status:"
        docker-compose -f $MAIN_COMPOSE ps
        echo ""
        echo "Lacus Services Status:"
        docker-compose -f $LACUS_COMPOSE ps
        ;;
    
    lacus-only)
        ACTION=${2:-up}
        echo "Managing Lacus services only: $ACTION"
        docker-compose -f $LACUS_COMPOSE $ACTION
        ;;
    
    ail-only)
        ACTION=${2:-up}
        echo "Managing AIL services only: $ACTION"
        docker-compose -f $MAIN_COMPOSE $ACTION
        ;;
    
    *)
        echo "Usage: $0 {up|down|restart|logs [service]|status|lacus-only [action]|ail-only [action]}"
        echo ""
        echo "Commands:"
        echo "  up           - Start all services (Lacus first, then AIL)"
        echo "  down         - Stop all services"
        echo "  restart      - Restart all services"
        echo "  logs [svc]   - Show logs for a specific service or list available services"
        echo "  status       - Show status of all services"
        echo "  lacus-only   - Manage only Lacus services"
        echo "  ail-only     - Manage only AIL services"
        echo ""
        echo "Examples:"
        echo "  $0 up                    # Start everything"
        echo "  $0 logs lacus           # Show Lacus logs"
        echo "  $0 lacus-only down      # Stop only Lacus"
        echo "  $0 ail-only restart     # Restart only AIL"
        exit 1
        ;;
esac
