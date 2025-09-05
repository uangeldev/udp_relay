#!/bin/bash

# UDP Log Relay Service Status Check Script
# This script checks the status of the UDP Log Relay service

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
        "RUNNING")
            echo -e "${GREEN}✓${NC} $message"
            ;;
        "STOPPED")
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
check_service_status() {
    echo "=== UDP Log Relay Service Status ==="
    echo
    
    # Check if PID file exists
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        
        # Check if process is actually running
        if ps -p "$pid" > /dev/null 2>&1; then
            print_status "RUNNING" "Service is running (PID: $pid)"
            
            # Get process info (macOS compatible)
            local process_info=$(ps -p "$pid" -o pid,ppid,command | tail -1)
            echo "  Process info: $process_info"
            
            # Check memory usage (macOS compatible)
            local memory_usage=$(ps -p "$pid" -o rss | tail -1 | awk '{print $1/1024 " MB"}')
            echo "  Memory usage: $memory_usage"
            
            # Check uptime (macOS compatible)
            local start_time=$(ps -p "$pid" -o lstart | tail -1)
            echo "  Started at: $start_time"
            
            return 0
        else
            print_status "STOPPED" "Service is not running (stale PID file: $pid)"
            return 1
        fi
    else
        print_status "STOPPED" "Service is not running (no PID file)"
        return 1
    fi
}

# Function to check systemd service status
check_systemd_status() {
    echo
    echo "=== Systemd Service Status ==="
    
    if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
        print_status "RUNNING" "Systemd service is active"
        
        # Get systemd status
        echo "  Status: $(systemctl is-active "$SERVICE_NAME")"
        echo "  Enabled: $(systemctl is-enabled "$SERVICE_NAME" 2>/dev/null || echo 'disabled')"
        
        # Get service info
        local service_info=$(systemctl show "$SERVICE_NAME" --property=MainPID,ActiveState,SubState,LoadState 2>/dev/null || echo "Service not found")
        echo "  Details: $service_info"
        
        return 0
    else
        print_status "STOPPED" "Systemd service is not active"
        return 1
    fi
}

# Function to check log file
check_log_file() {
    echo
    echo "=== Log File Status ==="
    
    if [ -f "$LOG_FILE" ]; then
        print_status "INFO" "Log file exists: $LOG_FILE"
        
        # Get log file size
        local log_size=$(ls -lh "$LOG_FILE" | awk '{print $5}')
        echo "  Size: $log_size"
        
        # Get last modified time
        local last_modified=$(ls -l "$LOG_FILE" | awk '{print $6, $7, $8}')
        echo "  Last modified: $last_modified"
        
        # Show last few lines
        echo "  Last 5 lines:"
        tail -5 "$LOG_FILE" | sed 's/^/    /'
        
        # Check for rotated logs
        local rotated_logs=$(ls -1 "$LOG_FILE".* 2>/dev/null | wc -l)
        if [ "$rotated_logs" -gt 0 ]; then
            echo "  Rotated logs: $rotated_logs files"
        fi
        
    else
        print_status "WARNING" "Log file not found: $LOG_FILE"
    fi
}

# Function to check configuration
check_configuration() {
    echo
    echo "=== Configuration Check ==="
    
    # Check if config file exists
    if [ -f "config.py" ]; then
        print_status "INFO" "Configuration file exists"
        
        # Check Python syntax
        if python3 -m py_compile config.py 2>/dev/null; then
            print_status "INFO" "Configuration syntax is valid"
        else
            print_status "WARNING" "Configuration syntax error"
        fi
    else
        print_status "WARNING" "Configuration file not found"
    fi
    
    # Check required directories
    local required_dirs=("logs" "run")
    for dir in "${required_dirs[@]}"; do
        if [ -d "$dir" ]; then
            print_status "INFO" "Directory exists: $dir"
        else
            print_status "WARNING" "Directory missing: $dir"
        fi
    done
}

# Function to check network connectivity
check_network() {
    echo
    echo "=== Network Check ==="
    
    # Check if UDP port is in use
    local udp_port=$(python3 -c "from config import Config; print(Config.UDP_PORT)" 2>/dev/null || echo "514")
    
    if netstat -uln 2>/dev/null | grep -q ":$udp_port "; then
        print_status "INFO" "UDP port $udp_port is in use"
    else
        print_status "WARNING" "UDP port $udp_port is not in use"
    fi
}

# Function to show overall status
show_overall_status() {
    echo
    echo "=== Overall Status ==="
    
    local service_running=false
    local systemd_running=false
    
    # Check service status
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            service_running=true
        fi
    fi
    
    # Check systemd status
    if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
        systemd_running=true
    fi
    
    if [ "$service_running" = true ] && [ "$systemd_running" = true ]; then
        print_status "RUNNING" "Service is fully operational"
        echo "  ✓ Process running"
        echo "  ✓ Systemd service active"
    elif [ "$service_running" = true ]; then
        print_status "WARNING" "Service running but systemd not active"
        echo "  ✓ Process running"
        echo "  ✗ Systemd service inactive"
    elif [ "$systemd_running" = true ]; then
        print_status "WARNING" "Systemd active but process not running"
        echo "  ✗ Process not running"
        echo "  ✓ Systemd service active"
    else
        print_status "STOPPED" "Service is not running"
        echo "  ✗ Process not running"
        echo "  ✗ Systemd service inactive"
    fi
}

# Main function
main() {
    # Check if we're in the right directory
    if [ ! -f "udp_log_relay.py" ]; then
        echo "Error: Please run this script from the project root directory"
        exit 1
    fi
    
    # Run all checks
    check_service_status
    check_systemd_status
    check_log_file
    check_configuration
    check_network
    show_overall_status
    
    echo
    echo "=== Quick Commands ==="
    echo "  Start service:   ./scripts/start.sh"
    echo "  Stop service:    ./scripts/stop.sh"
    echo "  Restart service: ./scripts/restart.sh"
    echo "  View logs:       tail -f $LOG_FILE"
}

# Run main function
main "$@"
