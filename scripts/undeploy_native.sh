#!/bin/bash

# Native undeploy script for UDP Log Relay service

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SERVICE_NAME="udp-log-relay"
SERVICE_USER="udprelay"
SERVICE_DIR="$(pwd)"
LOG_DIR="$(pwd)/logs"
RUN_DIR="$(pwd)/run"

echo -e "${BLUE}Undeploying UDP Log Relay Service (Native)${NC}"
echo ""

# Stop and disable service
stop_service() {
    echo -e "${GREEN}Stopping service...${NC}"
    
    # Stop service
    sudo systemctl stop udp-log-relay || true
    
    # Disable service
    sudo systemctl disable udp-log-relay || true
    
    echo -e "${GREEN}Service stopped and disabled${NC}"
}

# Remove systemd service
remove_systemd_service() {
    echo -e "${GREEN}Removing systemd service...${NC}"
    
    # Remove service file
    sudo rm -f /etc/systemd/system/udp-log-relay.service
    
    # Reload systemd
    sudo systemctl daemon-reload
    
    echo -e "${GREEN}Systemd service removed${NC}"
}

# Remove service user
remove_service_user() {
    echo -e "${GREEN}Removing service user...${NC}"
    
    if id "$SERVICE_USER" &>/dev/null; then
        sudo userdel "$SERVICE_USER" || true
        echo -e "${GREEN}Service user removed: $SERVICE_USER${NC}"
    else
        echo -e "${YELLOW}Service user does not exist: $SERVICE_USER${NC}"
    fi
}

# Remove directories and files
remove_directories() {
    echo -e "${GREEN}Removing directories and files...${NC}"
    
    # Remove service directory
    sudo rm -rf "$SERVICE_DIR" || true
    
    # Remove log directory
    sudo rm -rf "$LOG_DIR" || true
    
    # Remove run directory
    sudo rm -rf "$RUN_DIR" || true
    
    echo -e "${GREEN}Directories and files removed${NC}"
}

# Show undeployment information
show_undeployment_info() {
    echo ""
    echo -e "${GREEN}Undeployment completed successfully!${NC}"
    echo ""
    echo -e "${GREEN}Removed components:${NC}"
    echo -e "  Systemd service: /etc/systemd/system/udp-log-relay.service"
    echo -e "  Service user: $SERVICE_USER"
    echo -e "  Service directory: $SERVICE_DIR"
    echo -e "  Log directory: $LOG_DIR"
    echo -e "  Run directory: $RUN_DIR"
    echo ""
}

# Main undeployment function
main() {
    echo -e "${BLUE}Starting native undeployment process...${NC}"
    
    stop_service
    remove_systemd_service
    remove_service_user
    remove_directories
    show_undeployment_info
}

# Run main function
main