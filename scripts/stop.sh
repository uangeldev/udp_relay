#!/bin/bash

# UDP Log Relay Service Stop Script
# This script stops the UDP Log Relay service

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
            print_status "WARNING" "Stale PID file found (PID: $pid)"
            return 1  # Service is not running
        fi
    else
        return 1  # No PID file, service not running
    fi
}

# Function to stop service gracefully
stop_service_gracefully() {
    local pid=$1
    local timeout=30  # 30 seconds timeout
    
    print_status "INFO" "Sending SIGTERM to process $pid..."
    
    # Send SIGTERM signal
    if kill -TERM "$pid" 2>/dev/null; then
        print_status "SUCCESS" "SIGTERM signal sent"
        
        # Wait for process to stop
        local count=0
        while [ $count -lt $timeout ]; do
            if ! ps -p "$pid" > /dev/null 2>&1; then
                print_status "SUCCESS" "Service stopped gracefully"
                return 0
            fi
            sleep 1
            count=$((count + 1))
            echo -n "."
        done
        echo
        
        print_status "WARNING" "Service did not stop within $timeout seconds"
        return 1
    else
        print_status "ERROR" "Failed to send SIGTERM signal"
        return 1
    fi
}

# Function to force stop service
force_stop_service() {
    local pid=$1
    
    print_status "WARNING" "Force stopping service (PID: $pid)..."
    
    # Send SIGKILL signal
    if kill -KILL "$pid" 2>/dev/null; then
        print_status "SUCCESS" "Service force stopped"
        return 0
    else
        print_status "ERROR" "Failed to force stop service"
        return 1
    fi
}

# Function to stop systemd service
stop_systemd_service() {
    print_status "INFO" "Stopping systemd service..."
    
    if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
        if systemctl stop "$SERVICE_NAME" 2>/dev/null; then
            print_status "SUCCESS" "Systemd service stopped"
        else
            print_status "WARNING" "Failed to stop systemd service"
        fi
    else
        print_status "INFO" "Systemd service is not active"
    fi
}

# Function to clean up PID file
cleanup_pid_file() {
    if [ -f "$PID_FILE" ]; then
        rm -f "$PID_FILE"
        print_status "SUCCESS" "PID file removed"
    fi
}

# Function to show service status after stop
show_final_status() {
    echo
    echo "=== Final Status ==="
    
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            print_status "ERROR" "Service is still running (PID: $pid)"
            echo "  You may need to force stop the service"
        else
            print_status "SUCCESS" "Service is stopped"
        fi
    else
        print_status "SUCCESS" "Service is stopped"
    fi
    
    # Check systemd status
    if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
        print_status "WARNING" "Systemd service is still active"
    else
        print_status "SUCCESS" "Systemd service is stopped"
    fi
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  --force, -f      Force stop the service (SIGKILL)"
    echo "  --systemd, -s    Stop systemd service only"
    echo "  --help, -h       Show this help message"
    echo
    echo "Examples:"
    echo "  $0                # Stop service gracefully"
    echo "  $0 --force        # Force stop service"
    echo "  $0 --systemd      # Stop systemd service only"
}

# Main function
main() {
    local force_stop=false
    local systemd_only=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --force|-f)
                force_stop=true
                shift
                ;;
            --systemd|-s)
                systemd_only=true
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
    
    echo "=== UDP Log Relay Service Stop ==="
    echo
    
    # Handle systemd-only stop
    if [ "$systemd_only" = true ]; then
        stop_systemd_service
        exit 0
    fi
    
    # Check if service is running
    if ! check_if_running; then
        print_status "INFO" "Service is not running"
        cleanup_pid_file
        exit 0
    fi
    
    local pid=$(cat "$PID_FILE")
    print_status "INFO" "Stopping service (PID: $pid)..."
    
    # Stop the service
    if [ "$force_stop" = true ]; then
        if force_stop_service "$pid"; then
            cleanup_pid_file
        else
            print_status "ERROR" "Failed to force stop service"
            exit 1
        fi
    else
        if stop_service_gracefully "$pid"; then
            cleanup_pid_file
        else
            print_status "WARNING" "Graceful stop failed, trying force stop..."
            if force_stop_service "$pid"; then
                cleanup_pid_file
            else
                print_status "ERROR" "Failed to stop service"
                exit 1
            fi
        fi
    fi
    
    # Stop systemd service if it's running
    stop_systemd_service
    
    # Show final status
    show_final_status
    
    echo
    echo "=== Quick Commands ==="
    echo "  Check status:  ./scripts/status.sh"
    echo "  Start service: ./scripts/start.sh"
    echo "  View logs:     tail -f $LOG_FILE"
}

# Run main function
main "$@"
