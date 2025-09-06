#!/bin/bash

# Native deployment script for UDP Log Relay service (without Docker)

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
PID_FILE="$(pwd)/run/udp_log_relay.pid"

echo -e "${BLUE}Deploying UDP Log Relay Service (Native)${NC}"
echo ""

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
check_prerequisites() {
    echo -e "${GREEN}Checking prerequisites...${NC}"
    
    if ! command_exists python3; then
        echo -e "${RED}Error: Python 3 is not installed${NC}"
        exit 1
    fi
    
    if ! command_exists pip3; then
        echo -e "${RED}Error: pip3 is not installed${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}Prerequisites check passed${NC}"
}

# Create service user
create_service_user() {
    echo -e "${GREEN}Creating service user...${NC}"
    
    if ! id "$SERVICE_USER" &>/dev/null; then
        sudo useradd -r -s /bin/false -d "$SERVICE_DIR" "$SERVICE_USER"
        echo -e "${GREEN}Service user created: $SERVICE_USER${NC}"
    else
        echo -e "${YELLOW}Service user already exists: $SERVICE_USER${NC}"
    fi
}

# Create directories
create_directories() {
    echo -e "${GREEN}Creating directories...${NC}"
    
    # Create service directory
    sudo mkdir -p "$SERVICE_DIR"
    
    # Create log directory
    sudo mkdir -p "$LOG_DIR"
    
    # Create run directory
    sudo mkdir -p "$RUN_DIR"
    
    # Note: The service monitors the log file specified in LOG_FILE_PATH environment variable
    # Default is /home/iss/var/logs/platform/receiver/rawdata/nmea_rawdata.log
    
    echo -e "${GREEN}Directories created successfully${NC}"
}

# Install Python dependencies
install_dependencies() {
    echo -e "${GREEN}Installing Python dependencies...${NC}"
    
    # Install system dependencies
    sudo apt-get update
    sudo apt-get install -y python3-pip python3-venv
    
    # Create virtual environment
    sudo python3 -m venv "$SERVICE_DIR/venv"
    
    # Install Python packages
    sudo "$SERVICE_DIR/venv/bin/pip" install --upgrade pip
    sudo "$SERVICE_DIR/venv/bin/pip" install watchdog
    
    echo -e "${GREEN}Dependencies installed successfully${NC}"
}

# Copy application files
copy_application_files() {
    echo -e "${GREEN}Copying application files...${NC}"
    
    # Copy Python files
    sudo cp udp_log_relay.py "$SERVICE_DIR/"
    sudo cp config.py "$SERVICE_DIR/"
    sudo cp requirements.txt "$SERVICE_DIR/"
    
    # Set ownership
    sudo chown -R "$SERVICE_USER:$SERVICE_USER" "$SERVICE_DIR"
    sudo chown -R "$SERVICE_USER:$SERVICE_USER" "$LOG_DIR"
    sudo chown -R "$SERVICE_USER:$SERVICE_USER" "$RUN_DIR"
    
    # Set permissions
    sudo chmod +x "$SERVICE_DIR/udp_log_relay.py"
    sudo chmod 644 "$SERVICE_DIR/config.py"
    sudo chmod 644 "$SERVICE_DIR/requirements.txt"
    
    echo -e "${GREEN}Application files copied successfully${NC}"
}

# Create systemd service
create_systemd_service() {
    echo -e "${GREEN}Creating systemd service...${NC}"
    
    sudo tee /etc/systemd/system/udp-log-relay.service > /dev/null <<EOF
[Unit]
Description=UDP Log Relay Service
After=network.target

[Service]
Type=forking
User=$SERVICE_USER
Group=$SERVICE_USER
WorkingDirectory=$SERVICE_DIR
ExecStart=$SERVICE_DIR/venv/bin/python $SERVICE_DIR/udp_log_relay.py --daemon
PIDFile=$PID_FILE
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=udp-log-relay

# Environment variables
Environment=LOG_FILE_PATH=/home/iss/var/logs/platform/receiver/rawdata/nmea_rawdata.log
Environment=UDP_HOST=127.0.0.1
Environment=UDP_PORT=514
Environment=POLL_INTERVAL=0.1
Environment=MAX_LINE_LENGTH=8192
Environment=DAEMON_LOG_FILE=$LOG_DIR/udp_log_relay.log
Environment=DAEMON_PID_FILE=$PID_FILE
Environment=DAEMON_WORKING_DIR=$SERVICE_DIR
Environment=LOG_MAX_BYTES=10485760
Environment=LOG_BACKUP_COUNT=5

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd
    sudo systemctl daemon-reload
    
    echo -e "${GREEN}Systemd service created successfully${NC}"
}

# Start service
start_service() {
    echo -e "${GREEN}Starting service...${NC}"
    
    # Enable service
    sudo systemctl enable udp-log-relay
    
    # Start service
    sudo systemctl start udp-log-relay
    
    # Wait a moment
    sleep 3
    
    # Check status
    if sudo systemctl is-active --quiet udp-log-relay; then
        echo -e "${GREEN}Service started successfully${NC}"
    else
        echo -e "${RED}Service failed to start${NC}"
        sudo systemctl status udp-log-relay
        exit 1
    fi
}

# Verify deployment
verify_deployment() {
    echo -e "${GREEN}Verifying deployment...${NC}"
    
    # Check service status
    echo -e "${GREEN}Service status:${NC}"
    sudo systemctl status udp-log-relay --no-pager
    
    # Check logs
    echo -e "${GREEN}Recent logs:${NC}"
    sudo journalctl -u udp-log-relay --no-pager -n 10
    
    # Test log entry (using the configured log file path)
    echo -e "${GREEN}Creating test log entry...${NC}"
    echo "$(date): Test message from deployment" | sudo tee -a /home/iss/var/logs/platform/receiver/rawdata/nmea_rawdata.log
    
    sleep 2
    
    # Check if service is processing
    echo -e "${GREEN}Service logs after test:${NC}"
    sudo journalctl -u udp-log-relay --no-pager -n 5
}

# Show deployment information
show_deployment_info() {
    echo ""
    echo -e "${GREEN}Deployment completed successfully!${NC}"
    echo ""
    echo -e "${GREEN}Service Information:${NC}"
    echo -e "  Service Name: udp-log-relay"
    echo -e "  Service User: $SERVICE_USER"
    echo -e "  Service Directory: $SERVICE_DIR"
    echo -e "  Log Directory: $LOG_DIR"
    echo -e "  PID File: $PID_FILE"
    echo ""
    echo -e "${GREEN}Useful Commands:${NC}"
    echo -e "  View status: sudo systemctl status udp-log-relay"
    echo -e "  View logs: sudo journalctl -u udp-log-relay -f"
    echo -e "  Stop service: sudo systemctl stop udp-log-relay"
    echo -e "  Restart service: sudo systemctl restart udp-log-relay"
    echo -e "  Disable service: sudo systemctl disable udp-log-relay"
    echo ""
    echo -e "${GREEN}Test the service:${NC}"
    echo -e "  echo \"\$(date): Test message\" | sudo tee -a /home/iss/var/logs/platform/receiver/rawdata/nmea_rawdata.log"
    echo ""
}

# Main deployment function
main() {
    echo -e "${BLUE}Starting native deployment process...${NC}"
    
    check_prerequisites
    create_service_user
    create_directories
    install_dependencies
    copy_application_files
    create_systemd_service
    start_service
    verify_deployment
    show_deployment_info
}

# Run main function
main