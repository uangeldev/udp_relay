#!/bin/bash

# UDP Log Relay Service Debug Start Script
# This script provides detailed debugging information for service startup issues

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

# Function to check Python environment
check_python_environment() {
    echo "=== Python Environment Check ==="
    
    # Check Python version
    if command -v python3 &> /dev/null; then
        local python_version=$(python3 --version)
        print_status "SUCCESS" "Python found: $python_version"
    else
        print_status "ERROR" "Python 3 not found"
        return 1
    fi
    
    # Check Python path
    local python_path=$(which python3)
    print_status "INFO" "Python path: $python_path"
    
    # Check required standard library modules
    local modules=("socket" "logging" "signal" "time" "os" "sys" "pathlib")
    for module in "${modules[@]}"; do
        if python3 -c "import $module" 2>/dev/null; then
            print_status "SUCCESS" "Standard library module '$module' available"
        else
            print_status "ERROR" "Standard library module '$module' not available"
        fi
    done
    
    # No external dependencies required
    print_status "INFO" "No external dependencies required"
    
    # Check logging handlers
    if python3 -c "from logging.handlers import RotatingFileHandler" 2>/dev/null; then
        print_status "SUCCESS" "RotatingFileHandler available"
    else
        print_status "ERROR" "RotatingFileHandler not available"
    fi
}

# Function to check file system
check_file_system() {
    echo
    echo "=== File System Check ==="
    
    # Check current directory
    local current_dir=$(pwd)
    print_status "INFO" "Current directory: $current_dir"
    
    # Check if we're in the right directory
    if [ -f "udp_log_relay.py" ]; then
        print_status "SUCCESS" "Main script found: udp_log_relay.py"
    else
        print_status "ERROR" "Main script not found: udp_log_relay.py"
        return 1
    fi
    
    # Check config file
    if [ -f "config.py" ]; then
        print_status "SUCCESS" "Config file found: config.py"
    else
        print_status "ERROR" "Config file not found: config.py"
        return 1
    fi
    
    # Check and create directories
    local dirs=("logs" "run")
    for dir in "${dirs[@]}"; do
        if [ -d "$dir" ]; then
            print_status "SUCCESS" "Directory exists: $dir"
        else
            print_status "WARNING" "Directory missing: $dir - creating..."
            mkdir -p "$dir"
            if [ -d "$dir" ]; then
                print_status "SUCCESS" "Directory created: $dir"
            else
                print_status "ERROR" "Failed to create directory: $dir"
                return 1
            fi
        fi
        
        # Check directory permissions
        if [ -w "$dir" ]; then
            print_status "SUCCESS" "Directory writable: $dir"
        else
            print_status "ERROR" "Directory not writable: $dir"
        fi
    done
}

# Function to check configuration
check_configuration() {
    echo
    echo "=== Configuration Check ==="
    
    # Test config import
    if python3 -c "from config import Config; print('Config import successful')" 2>/dev/null; then
        print_status "SUCCESS" "Config import successful"
    else
        print_status "ERROR" "Config import failed"
        python3 -c "from config import Config" 2>&1
        return 1
    fi
    
    # Test config validation
    if python3 -c "from config import Config; print('Config validation:', Config.validate())" 2>/dev/null; then
        print_status "SUCCESS" "Config validation passed"
    else
        print_status "ERROR" "Config validation failed"
        python3 -c "from config import Config; Config.validate()" 2>&1
    fi
    
    # Show config values
    echo "  Configuration values:"
    python3 -c "
from config import Config
print(f'  LOG_FILE_PATH: {Config.LOG_FILE_PATH}')
print(f'  UDP_HOST: {Config.UDP_HOST}')
print(f'  UDP_PORT: {Config.UDP_PORT}')
print(f'  DAEMON_LOG_FILE: {Config.DAEMON_LOG_FILE}')
print(f'  DAEMON_PID_FILE: {Config.DAEMON_PID_FILE}')
print(f'  LOG_MAX_BYTES: {Config.LOG_MAX_BYTES}')
print(f'  LOG_BACKUP_COUNT: {Config.LOG_BACKUP_COUNT}')
" 2>/dev/null || print_status "ERROR" "Failed to read config values"
}

# Function to test script execution
test_script_execution() {
    echo
    echo "=== Script Execution Test ==="
    
    # Test script syntax
    if python3 -m py_compile udp_log_relay.py 2>/dev/null; then
        print_status "SUCCESS" "Script syntax is valid"
    else
        print_status "ERROR" "Script syntax error"
        python3 -m py_compile udp_log_relay.py 2>&1
        return 1
    fi
    
    # Test script import
    if python3 -c "import udp_log_relay; print('Script import successful')" 2>/dev/null; then
        print_status "SUCCESS" "Script import successful"
    else
        print_status "ERROR" "Script import failed"
        python3 -c "import udp_log_relay" 2>&1
        return 1
    fi
}

# Function to test network
test_network() {
    echo
    echo "=== Network Test ==="
    
    # Get UDP port from config
    local udp_port=$(python3 -c "from config import Config; print(Config.UDP_PORT)" 2>/dev/null || echo "514")
    print_status "INFO" "UDP port: $udp_port"
    
    # Check if port is in use
    if netstat -uln 2>/dev/null | grep -q ":$udp_port "; then
        print_status "WARNING" "UDP port $udp_port is already in use"
    else
        print_status "SUCCESS" "UDP port $udp_port is available"
    fi
}

# Function to check log file path
check_log_file_path() {
    echo
    echo "=== Log File Path Check ==="
    
    # Get log file path from config
    local log_file_path=$(python3 -c "from config import Config; print(Config.LOG_FILE_PATH)" 2>/dev/null || echo "Not available")
    print_status "INFO" "Configured log file path: $log_file_path"
    
    # Check if log file directory exists
    local log_dir=$(dirname "$log_file_path")
    if [ -d "$log_dir" ]; then
        print_status "SUCCESS" "Log directory exists: $log_dir"
    else
        print_status "WARNING" "Log directory does not exist: $log_dir"
        print_status "INFO" "The service will create the directory when needed"
    fi
    
    # Check if log file exists
    if [ -f "$log_file_path" ]; then
        print_status "SUCCESS" "Log file exists: $log_file_path"
        print_status "INFO" "Log file size: $(ls -lh "$log_file_path" | awk '{print $5}')"
    else
        print_status "WARNING" "Log file does not exist: $log_file_path"
        print_status "INFO" "The service will monitor this file when it's created"
    fi
}

# Function to run service in foreground for testing
test_service_foreground() {
    echo
    echo "=== Service Foreground Test ==="
    print_status "INFO" "Starting service in foreground mode for 5 seconds..."
    
    # Start service in background with timeout
    python3 udp_log_relay.py &
    local service_pid=$!
    
    # Wait 5 seconds
    sleep 5
    
    # Check if service is still running
    if ps -p "$service_pid" > /dev/null 2>&1; then
        print_status "SUCCESS" "Service is running (PID: $service_pid)"
        
        # Check if log file was created
        if [ -f "$LOG_FILE" ]; then
            print_status "SUCCESS" "Log file created: $LOG_FILE"
            echo "  Log file size: $(ls -lh "$LOG_FILE" | awk '{print $5}')"
            echo "  Last 3 lines:"
            tail -3 "$LOG_FILE" | sed 's/^/    /'
        else
            print_status "ERROR" "Log file not created: $LOG_FILE"
        fi
        
        # Stop the service
        kill $service_pid 2>/dev/null
        print_status "INFO" "Test service stopped"
    else
        print_status "ERROR" "Service stopped unexpectedly"
    fi
}

# Main function
main() {
    echo "=== UDP Log Relay Service Debug ==="
    echo
    
    # Check if we're in the right directory
    if [ ! -f "udp_log_relay.py" ]; then
        print_status "ERROR" "Please run this script from the project root directory"
        exit 1
    fi
    
    # Run all checks
    check_python_environment
    check_file_system
    check_configuration
    test_script_execution
    test_network
    check_log_file_path
    test_service_foreground
    
    echo
    echo "=== Debug Summary ==="
    echo "If all checks passed, try running:"
    echo "  ./scripts/start.sh"
    echo
    echo "If issues persist, check:"
    echo "  - Python version compatibility"
    echo "  - File permissions"
    echo "  - Network configuration"
    echo "  - System resources"
}

# Run main function
main "$@"
