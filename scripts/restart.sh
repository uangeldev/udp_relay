#!/bin/bash

# UDP Log Relay Service Restart Script
# This script restarts the UDP Log Relay service

set -e

# Configuration
SERVICE_NAME="udp-log-relay"
PID_FILE="./run/udp_log_relay.pid"
LOG_FILE="./logs/udp_log_relay.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local status=$1
    local message=$2
    
    case $status in
        "SUCCESS")
            echo -e "${GREEN}✓${NC} $message"
            ;;
        "ERROR")
            echo -e "${RED}✗${NC} $message"
            ;;
        "WARNING")
            echo -e "${YELLOW}⚠${NC} $message"
            ;;
        "INFO")
            echo -e "${BLUE}ℹ${NC} $message"
            ;;
    esac
}

# Function to check if service is running
check_if_running() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            return 0  # Service is running
        else
            return 1  # Service is not running
        fi
    else
        return 1  # No PID file, service not running
    fi
}

# Function to stop service
stop_service() {
    print_status "INFO" "Stopping service..."
    
    if check_if_running; then
        local pid=$(cat "$PID_FILE")
        
        # Try graceful stop first
        if kill -TERM "$pid" 2>/dev/null; then
            print_status "SUCCESS" "SIGTERM signal sent"
            
            # Wait for process to stop
            local count=0
            local timeout=30
            while [ $count -lt $timeout ]; do
                if ! ps -p "$pid" > /dev/null 2>&1; then
                    print_status "SUCCESS" "Service stopped gracefully"
                    rm -f "$PID_FILE"
                    return 0
                fi
                sleep 1
                count=$((count + 1))
                echo -n "."
            done
            echo
            
            # Force stop if graceful stop failed
            print_status "WARNING" "Graceful stop failed, force stopping..."
            if kill -KILL "$pid" 2>/dev/null; then
                print_status "SUCCESS" "Service force stopped"
                rm -f "$PID_FILE"
                return 0
            else
                print_status "ERROR" "Failed to stop service"
                return 1
            fi
        else
            print_status "ERROR" "Failed to send SIGTERM signal"
            return 1
        fi
    else
        print_status "INFO" "Service is not running"
        return 0
    fi
}

# Function to start service
start_service() {
    print_status "INFO" "Starting service..."
    
    # Create necessary directories
    local dirs=("logs" "run")
    for dir in "${dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
        fi
    done
    
    # Start the service in background
    nohup python3 udp_log_relay.py > /dev/null 2>&1 &
    local service_pid=$!
    
    # Wait for service to start
    sleep 2
    
    # Check if service started successfully
    if ps -p "$service_pid" > /dev/null 2>&1; then
        # Create PID file manually
        echo "$service_pid" > "$PID_FILE"
        print_status "SUCCESS" "Service started successfully (PID: $service_pid)"
        return 0
    else
        print_status "ERROR" "Service failed to start"
        return 1
    fi
}

# Function to restart systemd service
restart_systemd_service() {
    print_status "INFO" "Restarting systemd service..."
    
    if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
        if systemctl restart "$SERVICE_NAME" 2>/dev/null; then
            print_status "SUCCESS" "Systemd service restarted"
        else
            print_status "WARNING" "Failed to restart systemd service"
        fi
    else
        print_status "INFO" "Systemd service is not active"
    fi
}

# Function to show service information
show_service_info() {
    echo
    echo "=== Service Information ==="
    
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        echo "  PID: $pid"
        echo "  PID File: $PID_FILE"
        echo "  Log File: $LOG_FILE"
        echo "  Working Directory: $(pwd)"
        
        # Show process info (macOS compatible)
        if ps -p "$pid" > /dev/null 2>&1; then
            local process_info=$(ps -p "$pid" -o pid,ppid,command | tail -1)
            echo "  Process: $process_info"
        fi
    fi
    
    echo
    echo "=== Quick Commands ==="
    echo "  Check status:  ./scripts/status.sh"
    echo "  Stop service:  ./scripts/stop.sh"
    echo "  Start service: ./scripts/start.sh"
    echo "  View logs:     tail -f $LOG_FILE"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  --systemd, -s    Restart systemd service only"
    echo "  --force, -f      Force restart (kill and start)"
    echo "  --help, -h       Show this help message"
    echo
    echo "Examples:"
    echo "  $0                # Restart service gracefully"
    echo "  $0 --systemd      # Restart systemd service only"
    echo "  $0 --force        # Force restart service"
}

# Main function
main() {
    local systemd_only=false
    local force_restart=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --systemd|-s)
                systemd_only=true
                shift
                ;;
            --force|-f)
                force_restart=true
                shift
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Check if we're in the right directory
    if [ ! -f "udp_log_relay.py" ]; then
        print_status "ERROR" "Please run this script from the project root directory"
        exit 1
    fi
    
    echo "=== UDP Log Relay Service Restart ==="
    echo
    
    # Handle systemd-only restart
    if [ "$systemd_only" = true ]; then
        restart_systemd_service
        exit 0
    fi
    
    # Handle force restart
    if [ "$force_restart" = true ]; then
        print_status "WARNING" "Force restart mode enabled"
        
        # Force stop
        if [ -f "$PID_FILE" ]; then
            local pid=$(cat "$PID_FILE")
            if ps -p "$pid" > /dev/null 2>&1; then
                kill -KILL "$pid" 2>/dev/null || true
                print_status "SUCCESS" "Service force stopped"
            fi
            rm -f "$PID_FILE"
        fi
        
        # Start service
        if start_service; then
            show_service_info
        else
            print_status "ERROR" "Failed to restart service"
            exit 1
        fi
    else
        # Normal restart
        if stop_service; then
            if start_service; then
                show_service_info
            else
                print_status "ERROR" "Failed to restart service"
                exit 1
            fi
        else
            print_status "ERROR" "Failed to stop service"
            exit 1
        fi
    fi
    
    # Restart systemd service if it's running
    restart_systemd_service
    
    echo
    print_status "SUCCESS" "Service restart completed"
}

# Run main function
main "$@"
