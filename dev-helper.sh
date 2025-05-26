#!/usr/bin/env bash
# Development helper script for AIL Framework

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check prerequisites
check_prerequisites() {
    info "Checking prerequisites..."
    
    if ! command -v docker &> /dev/null; then
        error "Docker is not installed or not in PATH"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        error "Docker Compose is not installed or not in PATH"
        exit 1
    fi
    
    success "Prerequisites check passed"
}

# Build AIL container
build_ail() {
    info "Building AIL Framework container..."
    docker-compose build ail-app
    success "AIL container built successfully"
}

# Start services
start_services() {
    info "Starting AIL Framework services..."
    docker-compose up -d
    success "Services started"
    
    info "Waiting for services to be ready..."
    sleep 10
    
    # Check if AIL is responding
    if curl -f http://localhost:7000/api/v1/health > /dev/null 2>&1; then
        success "AIL Framework is ready at http://localhost:7000"
    else
        warning "AIL Framework may still be starting up. Check logs with: docker-compose logs ail-app"
    fi
}

# Stop services
stop_services() {
    info "Stopping AIL Framework services..."
    docker-compose down
    success "Services stopped"
}

# Show logs
show_logs() {
    local service=${1:-}
    if [ -n "$service" ]; then
        docker-compose logs -f "$service"
    else
        docker-compose logs -f
    fi
}

# Clean up everything
cleanup() {
    warning "This will remove all containers, volumes, and data. Are you sure? (y/N)"
    read -r response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        info "Cleaning up..."
        docker-compose down -v --rmi all
        success "Cleanup complete"
    else
        info "Cleanup cancelled"
    fi
}

# Check system status
status() {
    info "Checking system status..."
    docker-compose ps
    
    echo ""
    info "Container resource usage:"
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"
    
    echo ""
    info "Testing connectivity:"
    
    # Test Redis
    if docker-compose exec -T redis-cache redis-cli ping | grep -q PONG; then
        success "Redis Cache: Connected"
    else
        error "Redis Cache: Connection failed"
    fi
    
    # Test KVrocks
    if docker-compose exec -T kvrocks redis-cli -h kvrocks -p 6383 ping | grep -q PONG; then
        success "KVrocks: Connected"  
    else
        error "KVrocks: Connection failed"
    fi
    
    # Test AIL API
    if curl -f http://localhost:7000/api/v1/health > /dev/null 2>&1; then
        success "AIL API: Responding"
    else
        error "AIL API: Not responding"
    fi
}

# Show help
show_help() {
    echo "AIL Framework Development Helper"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  build         Build AIL container"
    echo "  start         Start all services"
    echo "  stop          Stop all services"
    echo "  restart       Restart all services"
    echo "  logs [SERVICE] Show logs (optional service name)"
    echo "  status        Show system status"
    echo "  cleanup       Remove all containers and data"
    echo "  check         Check prerequisites"
    echo "  help          Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 start                # Start all services"
    echo "  $0 logs ail-app        # Show AIL application logs"
    echo "  $0 status              # Check system status"
}

# Main script logic
case "${1:-help}" in
    build)
        check_prerequisites
        build_ail
        ;;
    start)
        check_prerequisites
        start_services
        ;;
    stop)
        stop_services
        ;;
    restart)
        stop_services
        start_services
        ;;
    logs)
        show_logs "${2:-}"
        ;;
    status)
        status
        ;;
    cleanup)
        cleanup
        ;;
    check)
        check_prerequisites
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac
