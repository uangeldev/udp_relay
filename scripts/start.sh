#!/bin/bash

# UDP Log Relay Service Start Script
# This script starts the UDP Log Relay service

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

# Function to check if service is already running
check_if_running() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            print_status "WARNING" "Service is already running (PID: $pid)"
            echo "  Use './scripts/restart.sh' to restart the service"
            return 1
        else
            print_status "WARNING" "Stale PID file found, removing..."
            rm -f "$PID_FILE"
        fi
    fi
    return 0
}

# Function to create necessary directories
create_directories() {
    print_status "INFO" "Creating necessary directories..."
    
    local dirs=("logs" "run")
    for dir in "${dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
            print_status "SUCCESS" "Created directory: $dir"
        else
            print_status "INFO" "Directory exists: $dir"
        fi
    done
}

# Function to check prerequisites
check_prerequisites() {
    print_status "INFO" "Checking prerequisites..."
    
    # Check if Python 3 is available
    if ! command -v python3 &> /dev/null; then
        print_status "ERROR" "Python 3 is not installed"
        exit 1
    fi
    
    # Check if required Python modules are available
    if ! python3 -c "import socket, logging, signal, time, os, sys" 2>/dev/null; then
        print_status "ERROR" "Required Python modules are not available"
        exit 1
    fi
    
    # No external dependencies required
    
    # Check if main script exists
    if [ ! -f "udp_log_relay.py" ]; then
        print_status "ERROR" "Main script not found: udp_log_relay.py"
        exit 1
    fi
    
    # Check if config file exists
    if [ ! -f "config.py" ]; then
        print_status "ERROR" "Configuration file not found: config.py"
        exit 1
    fi
    
    print_status "SUCCESS" "All prerequisites met"
}

# Function to start service in background mode
start_background() {
    print_status "INFO" "Starting UDP Log Relay service in background mode..."
    
    # Start the service in background
    nohup python3 udp_log_relay.py > /dev/null 2>&1 &
    local service_pid=$!
    
    # Wait a moment for the service to start
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

# Function to start service in foreground mode
start_foreground() {
    print_status "INFO" "Starting UDP Log Relay service in foreground mode..."
    echo "  Press Ctrl+C to stop the service"
    echo
    
    # Start the service in foreground
    python3 udp_log_relay.py
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
    echo "  View logs:     tail -f $LOG_FILE"
    echo "  Restart:       ./scripts/restart.sh"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  --daemon, -d     Start service in daemon mode (default)"
    echo "  --foreground, -f Start service in foreground mode"
    echo "  --help, -h       Show this help message"
    echo
    echo "Examples:"
    echo "  $0                # Start in daemon mode"
    echo "  $0 --daemon       # Start in daemon mode"
    echo "  $0 --foreground   # Start in foreground mode"
}

# Main function
main() {
    local daemon_mode=true
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --daemon|-d)
                daemon_mode=true
                shift
                ;;
            --foreground|-f)
                daemon_mode=false
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
    
    echo "=== UDP Log Relay Service Start ==="
    echo
    
    # Check if service is already running
    if ! check_if_running; then
        exit 1
    fi
    
    # Create necessary directories
    create_directories
    
    # Check prerequisites
    check_prerequisites
    
    # Start the service
    if [ "$daemon_mode" = true ]; then
        if start_background; then
            show_service_info
        else
            print_status "ERROR" "Failed to start service"
            exit 1
        fi
    else
        start_foreground
    fi
}

# Run main function
main "$@"
