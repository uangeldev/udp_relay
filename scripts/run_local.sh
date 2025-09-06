#!/bin/bash

# Local run script for UDP Log Relay service

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Running UDP Log Relay Service Locally${NC}"
echo ""

# Create necessary directories
echo -e "${GREEN}Creating directories...${NC}"
mkdir -p logs run

# Note: The service monitors the log file specified in LOG_FILE_PATH environment variable
# Default is /home/iss/var/logs/platform/receiver/rawdata/nmea_rawdata.log

# Install dependencies if needed
if [ ! -d "venv" ]; then
    echo -e "${GREEN}Creating virtual environment...${NC}"
    python3 -m venv venv
    source venv/bin/activate
    pip install -r requirements.txt
else
    echo -e "${GREEN}Activating virtual environment...${NC}"
    source venv/bin/activate
fi

# Check if running as daemon
if [ "$1" = "--daemon" ]; then
    echo -e "${GREEN}Starting as daemon...${NC}"
    python3 udp_log_relay.py --daemon
    echo -e "${GREEN}Daemon started. PID file: ./run/udp_log_relay.pid${NC}"
    echo -e "${GREEN}Log file: ./logs/udp_log_relay.log${NC}"
    echo ""
    echo -e "${GREEN}To stop the daemon:${NC}"
    echo -e "  kill \$(cat ./run/udp_log_relay.pid)"
    echo ""
    echo -e "${GREEN}To view logs:${NC}"
    echo -e "  tail -f ./logs/udp_log_relay.log"
else
    echo -e "${GREEN}Starting in foreground...${NC}"
    echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
    echo ""
    python3 udp_log_relay.py
fi
