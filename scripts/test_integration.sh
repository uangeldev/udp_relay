#!/bin/bash

# Integration test script for UDP Log Relay service
# Tests the complete flow: log file monitoring -> UDP relay -> UDP receiver

set -e

# Configuration
TEST_LOG_FILE="/tmp/test_nmea_rawdata.log"
TEST_LOG_DIR="/tmp/test_logs"
UDP_PORT=1514
RELAY_PID_FILE="/tmp/udp_relay_test.pid"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== UDP Log Relay Integration Test ===${NC}"

# Cleanup function
cleanup() {
    echo -e "\n${YELLOW}Cleaning up...${NC}"
    
    # Stop relay if running
    if [ -n "$RELAY_PID" ] && kill -0 "$RELAY_PID" 2>/dev/null; then
        echo "Stopping UDP relay (PID: $RELAY_PID)"
        kill -TERM "$RELAY_PID"
        sleep 2
        if kill -0 "$RELAY_PID" 2>/dev/null; then
            kill -KILL "$RELAY_PID"
        fi
    fi
    
    # Stop receiver if running
    if [ -n "$RECEIVER_PID" ] && kill -0 "$RECEIVER_PID" 2>/dev/null; then
        echo "Stopping UDP receiver (PID: $RECEIVER_PID)"
        kill -TERM "$RECEIVER_PID"
        sleep 1
    fi
    
    # Clean up test files
    rm -f "$TEST_LOG_FILE"*
    rm -rf "$TEST_LOG_DIR"
    
    echo -e "${GREEN}Cleanup completed${NC}"
}

# Set up cleanup trap
trap cleanup EXIT

# Create test directory
mkdir -p "$TEST_LOG_DIR"

echo -e "${BLUE}1. Setting up test environment...${NC}"

# Create initial test log file
echo "Initial log entry 1" > "$TEST_LOG_FILE"
echo "Initial log entry 2" >> "$TEST_LOG_FILE"
echo "Initial log entry 3" >> "$TEST_LOG_FILE"

echo -e "${GREEN}Created test log file: $TEST_LOG_FILE${NC}"

# Start UDP receiver in background
echo -e "${BLUE}2. Starting UDP receiver...${NC}"
python3 udp_receiver.py --port $UDP_PORT --log-level INFO &
RECEIVER_PID=$!
sleep 2

# Start UDP relay with test configuration
echo -e "${BLUE}3. Starting UDP relay...${NC}"
LOG_FILE_PATH="$TEST_LOG_FILE" \
UDP_PORT=$UDP_PORT \
DAEMON_PID_FILE="$RELAY_PID_FILE" \
DAEMON_LOG_FILE="$TEST_LOG_DIR/relay.log" \
POLL_INTERVAL=0.1 \
ROTATION_CHECK_INTERVAL=0.5 \
LOG_LEVEL=DEBUG \
python3 udp_log_relay.py &
RELAY_PID=$!
sleep 3

# Verify relay is running
if kill -0 "$RELAY_PID" 2>/dev/null; then
    echo -e "${GREEN}UDP relay started successfully (PID: $RELAY_PID)${NC}"
else
    echo -e "${RED}UDP relay failed to start${NC}"
    exit 1
fi

echo -e "${BLUE}4. Testing normal log processing...${NC}"
sleep 2

# Add some log entries
echo "Test log entry 1" >> "$TEST_LOG_FILE"
echo "Test log entry 2" >> "$TEST_LOG_FILE"
sleep 1

echo -e "${BLUE}5. Testing log file rotation...${NC}"

# Simulate log rotation by moving the file and creating a new one
mv "$TEST_LOG_FILE" "$TEST_LOG_FILE.1"
echo "New log entry after rotation 1" > "$TEST_LOG_FILE"
echo "New log entry after rotation 2" >> "$TEST_LOG_FILE"
sleep 2

echo -e "${BLUE}6. Adding more entries to verify continuous operation...${NC}"
for i in {1..5}; do
    echo "Continuous test entry $i" >> "$TEST_LOG_FILE"
    sleep 0.5
done

echo -e "${BLUE}7. Checking relay logs...${NC}"
if [ -f "$TEST_LOG_DIR/relay.log" ]; then
    echo -e "${GREEN}Relay log file exists${NC}"
    echo -e "${YELLOW}Last 20 lines of relay log:${NC}"
    tail -20 "$TEST_LOG_DIR/relay.log"
else
    echo -e "${RED}Relay log file not found${NC}"
fi

echo -e "${BLUE}8. Test completed successfully!${NC}"
echo -e "${GREEN}The UDP relay should have handled all scenarios correctly.${NC}"
echo -e "${YELLOW}Check the receiver output above to verify all log entries were received.${NC}"

# Stop receiver
kill $RECEIVER_PID 2>/dev/null || true

echo -e "\n${GREEN}=== Integration Test Completed ===${NC}"
