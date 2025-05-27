.PHONY: help start-all stop-all restart-all status-all logs-all lacus-up lacus-down ail-up ail-down

help:
    @echo "Available targets:"
    @echo "  start-all         - Start all AIL and Lacus containers (cross-platform)"
    @echo "  stop-all          - Stop all AIL and Lacus containers"
    @echo "  restart-all       - Restart all AIL and Lacus containers"
    @echo "  status-all        - Show status of all AIL and Lacus containers"
    @echo "  logs-all [svc]    - Show logs for a specific service or list available services"
    @echo "  lacus-up          - Start only Lacus containers"
    @echo "  lacus-down        - Stop only Lacus containers"
    @echo "  ail-up            - Start only AIL containers"
    @echo "  ail-down          - Stop only AIL containers"

# Cross-platform orchestration (uses PowerShell or Bash depending on OS)
start-all:
    @if [ "$(OS)" = "Windows_NT" ]; then \
        pwsh -ExecutionPolicy Bypass -File scripts/start-all.ps1 up ; \
    else \
        bash scripts/start-all.sh up ; \
    fi

stop-all:
    @if [ "$(OS)" = "Windows_NT" ]; then \
        pwsh -ExecutionPolicy Bypass -File scripts/start-all.ps1 down ; \
    else \
        bash scripts/start-all.sh down ; \
    fi

restart-all:
    @if [ "$(OS)" = "Windows_NT" ]; then \
        pwsh -ExecutionPolicy Bypass -File scripts/start-all.ps1 restart ; \
    else \
        bash scripts/start-all.sh restart ; \
    fi

status-all:
    @if [ "$(OS)" = "Windows_NT" ]; then \
        pwsh -ExecutionPolicy Bypass -File scripts/start-all.ps1 status ; \
    else \
        bash scripts/start-all.sh status ; \
    fi

logs-all:
    @if [ "$(OS)" = "Windows_NT" ]; then \
        pwsh -ExecutionPolicy Bypass -File scripts/start-all.ps1 logs $(svc) ; \
    else \
        bash scripts/start-all.sh logs $(svc) ; \
    fi

lacus-up:
    @if [ "$(OS)" = "Windows_NT" ]; then \
        pwsh -ExecutionPolicy Bypass -File scripts/start-all.ps1 lacus-only up ; \
    else \
        bash scripts/start-all.sh lacus-only up ; \
    fi

lacus-down:
    @if [ "$(OS)" = "Windows_NT" ]; then \
        pwsh -ExecutionPolicy Bypass -File scripts/start-all.ps1 lacus-only down ; \
    else \
        bash scripts/start-all.sh lacus-only down ; \
    fi

ail-up:
    @if [ "$(OS)" = "Windows_NT" ]; then \
        pwsh -ExecutionPolicy Bypass -File scripts/start-all.ps1 ail-only up ; \
    else \
        bash scripts/start-all.sh ail-only up ; \
    fi

ail-down:
    @if [ "$(OS)" = "Windows_NT" ]; then \
        pwsh -ExecutionPolicy Bypass -File scripts/start-all.ps1 ail-only down ; \
    else \
        bash scripts/start-all.sh ail-only down ; \
    fi