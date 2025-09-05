#!/usr/bin/env python3
"""
UDP Log Receiver

A simple UDP receiver that listens for log messages and displays them on screen.
Useful for testing the UDP Log Relay service.
"""

import socket
import sys
import signal
import time
import logging
from datetime import datetime
from typing import Optional
from pathlib import Path

from receiver_config import ReceiverConfig


class UDPReceiver:
    """Simple UDP receiver for log messages"""
    
    def __init__(self, config: Optional[ReceiverConfig] = None):
        self.config = config or ReceiverConfig()
        self.socket: Optional[socket.socket] = None
        self.running = False
        self.message_count = 0
        self.bytes_received = 0
        self.start_time = None
        
        # Setup logging
        self.setup_logging()
        
    def setup_logging(self):
        """Setup logging configuration"""
        # Create logger
        self.logger = logging.getLogger('UDPReceiver')
        
        # Set log level from configuration
        log_level = getattr(logging, self.config.LOG_LEVEL.upper(), logging.INFO)
        self.logger.setLevel(log_level)
        
        # Clear any existing handlers
        self.logger.handlers.clear()
        
        # Create formatter
        formatter = logging.Formatter(
            '%(asctime)s - %(name)s - %(levelname)s - [%(filename)s:%(lineno)d] - %(message)s'
        )
        
        # Console handler
        console_handler = logging.StreamHandler(sys.stdout)
        console_handler.setFormatter(formatter)
        console_handler.setLevel(log_level)
        self.logger.addHandler(console_handler)
        
        # File handler (if enabled)
        if self.config.LOG_TO_FILE:
            # Create log directory if it doesn't exist
            log_file_path = Path(self.config.LOG_FILE)
            log_file_path.parent.mkdir(parents=True, exist_ok=True)
            
            file_handler = logging.FileHandler(log_file_path, encoding='utf-8')
            file_handler.setFormatter(formatter)
            file_handler.setLevel(log_level)
            self.logger.addHandler(file_handler)
        
        self.logger.info("Logging system initialized")
        
    def setup_socket(self) -> bool:
        """Setup UDP socket for receiving messages"""
        try:
            self.socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            self.socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            self.socket.bind((self.config.HOST, self.config.PORT))
            self.logger.info(f"UDP receiver listening on {self.config.HOST}:{self.config.PORT}")
            self.logger.debug(f"Buffer size: {self.config.BUFFER_SIZE}, Timeout: {self.config.SOCKET_TIMEOUT}s")
            return True
        except Exception as e:
            self.logger.error(f"Failed to setup UDP socket: {e}")
            return False
            
    def close_socket(self):
        """Close UDP socket"""
        if self.socket:
            self.socket.close()
            self.socket = None
            self.logger.info("UDP socket closed")
            
    def signal_handler(self, signum, frame):
        """Handle system signals"""
        self.logger.info(f"Received signal {signum}, shutting down...")
        self.running = False
        
    def format_message(self, data: bytes, addr: tuple) -> str:
        """Format received message for display"""
        parts = []
        
        if self.config.SHOW_TIMESTAMP:
            timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")[:-3]
            parts.append(f"[{timestamp}]")
            
        if self.config.SHOW_SOURCE_ADDRESS:
            parts.append(f"{addr[0]}:{addr[1]}")
            
        message = data.decode('utf-8', errors='replace')
        
        # Truncate message if too long
        if len(message) > self.config.MAX_MESSAGE_LENGTH:
            message = message[:self.config.MAX_MESSAGE_LENGTH] + "... [truncated]"
            
        parts.append(message)
        return " -> ".join(parts)
        
    def log_statistics(self):
        """Log current statistics"""
        if not self.start_time:
            return
            
        uptime = time.time() - self.start_time
        print(f"--- Received {self.message_count} messages ({self.bytes_received} bytes) in {uptime:.1f}s ---")
        
        # Calculate rates
        if uptime > 0:
            messages_per_sec = self.message_count / uptime
            bytes_per_sec = self.bytes_received / uptime
            self.logger.info(f"Statistics - Messages: {self.message_count}, "
                           f"Bytes: {self.bytes_received}, "
                           f"Rate: {messages_per_sec:.2f} msg/s, "
                           f"{bytes_per_sec:.2f} bytes/s")
        
    def run(self):
        """Main receiver loop"""
        self.logger.info("UDP Log Receiver started")
        print("Press Ctrl+C to stop")
        print("-" * 80)
        
        # Initialize start time for statistics
        self.start_time = time.time()
        
        # Validate configuration
        if not self.config.validate():
            self.logger.error("Configuration validation failed")
            return False
            
        # Print configuration
        self.config.print_config()
        
        # Setup signal handlers
        signal.signal(signal.SIGTERM, self.signal_handler)
        signal.signal(signal.SIGINT, self.signal_handler)
        self.logger.debug("Signal handlers registered for SIGTERM and SIGINT")
        
        # Setup socket
        if not self.setup_socket():
            return False
            
        self.running = True
        self.logger.info("Service started successfully")
        
        try:
            while self.running:
                try:
                    # Set socket timeout for responsive shutdown
                    self.socket.settimeout(self.config.SOCKET_TIMEOUT)
                    
                    # Receive data
                    data, addr = self.socket.recvfrom(self.config.BUFFER_SIZE)
                    
                    # Update statistics
                    self.message_count += 1
                    self.bytes_received += len(data)
                    
                    # Format and display message
                    formatted_message = self.format_message(data, addr)
                    print(formatted_message)
                    
                    # Log received message
                    self.logger.debug(f"Received {len(data)} bytes from {addr[0]}:{addr[1]}")
                    
                    # Show statistics at configured interval
                    if self.message_count % self.config.SHOW_STATS_INTERVAL == 0:
                        self.log_statistics()
                        
                except socket.timeout:
                    # Timeout is expected, continue loop
                    continue
                except Exception as e:
                    self.logger.error(f"Error receiving data: {e}")
                    time.sleep(0.1)
                    
        except KeyboardInterrupt:
            self.logger.info("Interrupted by user")
        except Exception as e:
            self.logger.error(f"Unexpected error: {e}")
        finally:
            self.cleanup()
            
        return True
        
    def cleanup(self):
        """Cleanup resources"""
        # Log final statistics
        if self.start_time:
            self.log_statistics()
        
        print(f"\nTotal messages received: {self.message_count}")
        print(f"Total bytes received: {self.bytes_received}")
        self.close_socket()
        self.logger.info("UDP receiver stopped")


def main():
    """Main entry point"""
    import argparse
    
    parser = argparse.ArgumentParser(description='UDP Log Receiver for testing UDP Log Relay')
    parser.add_argument('--host', help=f'Host to bind to (default: {ReceiverConfig.HOST})')
    parser.add_argument('--port', type=int, help=f'Port to listen on (default: {ReceiverConfig.PORT})')
    parser.add_argument('--buffer-size', type=int, help=f'Buffer size (default: {ReceiverConfig.BUFFER_SIZE})')
    parser.add_argument('--log-level', choices=['DEBUG', 'INFO', 'WARNING', 'ERROR'], 
                       help=f'Log level (default: {ReceiverConfig.LOG_LEVEL})')
    parser.add_argument('--log-to-file', action='store_true', 
                       help='Enable logging to file')
    parser.add_argument('--stats-interval', type=int, 
                       help=f'Statistics display interval (default: {ReceiverConfig.SHOW_STATS_INTERVAL})')
    parser.add_argument('--show-config', action='store_true', 
                       help='Show configuration and exit')
    
    args = parser.parse_args()
    
    # Create configuration
    config = ReceiverConfig()
    
    # Override with command line arguments if provided
    if args.host:
        config.HOST = args.host
    if args.port:
        config.PORT = args.port
    if args.buffer_size:
        config.BUFFER_SIZE = args.buffer_size
    if args.log_level:
        config.LOG_LEVEL = args.log_level
    if args.log_to_file:
        config.LOG_TO_FILE = True
    if args.stats_interval:
        config.SHOW_STATS_INTERVAL = args.stats_interval
    
    # Show configuration and exit if requested
    if args.show_config:
        config.print_config()
        return
    
    # Create and run receiver
    receiver = UDPReceiver(config=config)
    receiver.run()


if __name__ == '__main__':
    main()
