#!/usr/bin/env python3
"""
UDP Log Relay Service

A Python daemon service that monitors a log file in real-time and forwards
new log entries via UDP unicast. Handles log file rotation automatically.
"""

import os
import sys
import time
import socket
import signal
import logging
from logging.handlers import RotatingFileHandler
from typing import Optional, TextIO
from pathlib import Path

from config import Config


class UDPLogRelay:
    """Main service class for UDP log relay"""
    
    def __init__(self):
        self.config = Config()
        self.socket: Optional[socket.socket] = None
        self.log_file: Optional[TextIO] = None
        self.log_file_path = Path(self.config.LOG_FILE_PATH)
        self.file_position = 0
        self.file_inode = None
        self.file_mtime = None
        self.running = False
        
        # Statistics tracking
        self.stats = {
            'lines_processed': 0,
            'lines_sent': 0,
            'lines_failed': 0,
            'bytes_sent': 0,
            'rotation_count': 0,
            'start_time': None,
            'last_activity': None
        }
        
        # Setup logging
        self.setup_logging()
        
    def setup_logging(self):
        """Setup logging configuration with rotation"""
        # Create logger
        self.logger = logging.getLogger('UDPLogRelay')
        
        # Set log level from configuration
        log_level = getattr(logging, self.config.LOG_LEVEL.upper(), logging.INFO)
        self.logger.setLevel(log_level)
        
        # Clear any existing handlers
        self.logger.handlers.clear()
        
        # Create detailed formatter with more information
        formatter = logging.Formatter(
            '%(asctime)s - %(name)s - %(levelname)s - [%(filename)s:%(lineno)d] - %(message)s'
        )
        
        # Create rotating file handler with configurable settings
        file_handler = RotatingFileHandler(
            self.config.DAEMON_LOG_FILE,
            maxBytes=self.config.LOG_MAX_BYTES,
            backupCount=self.config.LOG_BACKUP_COUNT,
            encoding='utf-8'
        )
        file_handler.setFormatter(formatter)
        file_handler.setLevel(log_level)  # Use configured log level
        
        # Create console handler
        console_handler = logging.StreamHandler(sys.stdout)
        console_handler.setFormatter(formatter)
        console_handler.setLevel(logging.INFO)  # Keep console at INFO level
        
        # Add handlers to logger
        self.logger.addHandler(file_handler)
        self.logger.addHandler(console_handler)
        
        # Log configuration details
        self.logger.info("Logging system initialized")
        self.logger.debug(f"Configuration: UDP={self.config.UDP_HOST}:{self.config.UDP_PORT}, "
                         f"LogFile={self.config.LOG_FILE_PATH}, PollInterval={self.config.POLL_INTERVAL}s, "
                         f"LogLevel={self.config.LOG_LEVEL}")
        
    def setup_udp_socket(self) -> bool:
        """Setup UDP socket for sending log entries"""
        try:
            self.socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            self.socket.settimeout(1.0)  # Set socket timeout for better error handling
            self.logger.info(f"UDP socket created for {self.config.UDP_HOST}:{self.config.UDP_PORT}")
            self.logger.debug(f"Socket timeout set to 1.0 seconds, buffer size: {self.config.UDP_BUFFER_SIZE}")
            return True
        except Exception as e:
            self.logger.error(f"Failed to create UDP socket: {e}")
            return False
            
    def close_udp_socket(self):
        """Close UDP socket"""
        if self.socket:
            self.socket.close()
            self.socket = None
            self.logger.info("UDP socket closed")
            
    def open_log_file(self) -> bool:
        """Open log file for reading"""
        try:
            if not self.log_file_path.exists():
                self.logger.warning(f"Log file does not exist: {self.log_file_path}")
                return False
                
            # Get file stats before opening
            file_stats = self.log_file_path.stat()
            self.logger.debug(f"Log file stats: size={file_stats.st_size} bytes, "
                            f"modified={time.ctime(file_stats.st_mtime)}, "
                            f"inode={file_stats.st_ino}")
                
            self.log_file = open(self.log_file_path, 'r', encoding=self.config.LOG_FILE_ENCODING)
            
            # Set position to end of file to start monitoring new entries
            self.log_file.seek(0, 2)  # Seek to end of file
            self.file_position = self.log_file.tell()
            
            # Store file metadata for rotation detection
            self.file_inode = file_stats.st_ino
            self.file_mtime = file_stats.st_mtime
            
            self.logger.info(f"Opened log file: {self.log_file_path} (size: {file_stats.st_size} bytes, inode: {self.file_inode})")
            self.logger.debug(f"Starting position: {self.file_position}")
            return True
            
        except Exception as e:
            self.logger.error(f"Failed to open log file: {e}")
            return False
            
    def close_log_file(self):
        """Close log file"""
        if self.log_file:
            self.log_file.close()
            self.log_file = None
            self.logger.info("Log file closed")
            
    def check_file_rotation(self) -> bool:
        """Check if log file has been rotated using multiple detection methods"""
        try:
            if not self.log_file_path.exists():
                self.logger.info("Log file no longer exists, rotation detected")
                return True
                
            # Get current file stats
            current_stats = self.log_file_path.stat()
            current_inode = current_stats.st_ino
            current_mtime = current_stats.st_mtime
            current_size = current_stats.st_size
            
            # Method 1: Check if inode has changed (most reliable for rotation detection)
            if self.file_inode is not None and current_inode != self.file_inode:
                self.logger.info(f"File inode changed from {self.file_inode} to {current_inode}, rotation detected")
                return True
                
            # Method 2: Check if file size is smaller than our last position
            if current_size < self.file_position:
                self.logger.info(f"Log file size decreased from {self.file_position} to {current_size}, rotation detected")
                return True
                
            # Method 3: Check if modification time is significantly older (file was recreated)
            if self.file_mtime is not None and current_mtime < self.file_mtime:
                self.logger.info(f"File modification time went backwards from {time.ctime(self.file_mtime)} to {time.ctime(current_mtime)}, rotation detected")
                return True
                
            # Method 4: Check if we can't read from current position (file was truncated)
            if self.log_file and self.file_position > 0 and current_size < self.file_position:
                try:
                    self.log_file.seek(self.file_position)
                    test_read = self.log_file.read(1)
                    if not test_read:
                        self.logger.info(f"Cannot read from position {self.file_position}, file may have been rotated")
                        return True
                    self.log_file.seek(0, 2)
                except (OSError, IOError) as e:
                    self.logger.info(f"Error reading from position {self.file_position}: {e}, rotation likely occurred")
                    return True
                
            return False
            
        except Exception as e:
            self.logger.error(f"Error checking file rotation: {e}")
            return True
            
    def handle_file_rotation(self):
        """Handle log file rotation by reopening the file with retry logic"""
        self.stats['rotation_count'] += 1
        self.logger.info(f"Handling log file rotation (count: {self.stats['rotation_count']})")
        
        # Close current file handle
        self.close_log_file()
        
        # Reset file tracking variables
        self.file_position = 0
        self.file_inode = None
        self.file_mtime = None
        
        # Retry logic for file reopening
        max_retries = self.config.ROTATION_RETRY_ATTEMPTS
        retry_delay = self.config.ROTATION_RETRY_DELAY
        
        for attempt in range(max_retries):
            try:
                # Wait for the new file to be created
                time.sleep(retry_delay)
                
                if self.open_log_file():
                    self.logger.info(f"Successfully reopened log file after rotation (attempt {attempt + 1})")
                    self.logger.debug(f"Rotation completed, new file position: {self.file_position}, inode: {self.file_inode}")
                    return
                else:
                    self.logger.warning(f"Failed to reopen log file after rotation (attempt {attempt + 1}/{max_retries})")
                    
            except Exception as e:
                self.logger.warning(f"Error during rotation recovery (attempt {attempt + 1}/{max_retries}): {e}")
                
            # Increase delay for next attempt
            retry_delay = min(retry_delay * 1.5, 5.0)
            
        self.logger.error("Failed to reopen log file after rotation after all retry attempts")
            
    def read_new_lines(self) -> list:
        """Read new lines from the log file with improved error handling"""
        if not self.log_file:
            return []
            
        try:
            # Get current file size
            file_size = self.log_file_path.stat().st_size
            
            # If file size hasn't changed, no new content
            if file_size <= self.file_position:
                return []
                
            # Seek to our last known position
            self.log_file.seek(self.file_position)
            
            new_lines = []
            bytes_read = 0
            
            while True:
                try:
                    line = self.log_file.readline()
                    if not line:
                        break
                        
                    bytes_read += len(line)
                    
                    # Remove trailing newline and process non-empty lines
                    line = line.rstrip('\n\r')
                    if line:
                        new_lines.append(line)
                        
                except (OSError, IOError) as e:
                    self.logger.warning(f"Error reading line at position {self.log_file.tell()}: {e}")
                    break
                    
            # Update position to current file position
            self.file_position = self.log_file.tell()
            
            # Log reading activity
            if new_lines:
                self.stats['last_activity'] = time.time()
                self.logger.debug(f"Read {len(new_lines)} new lines ({bytes_read} bytes)")
            
        except Exception as e:
            self.logger.error(f"Error reading log file: {e}")
            self.file_position = 0
            
        return new_lines
        
    def send_udp_message(self, message: str) -> bool:
        """Send message via UDP"""
        if not self.socket:
            return False
            
        try:
            # Truncate message if too long
            if len(message) > self.config.MAX_LINE_LENGTH:
                message = message[:self.config.MAX_LINE_LENGTH] + "... [truncated]"
                
            # Encode and send message
            encoded_message = message.encode('utf-8')
            bytes_sent = self.socket.sendto(encoded_message, (self.config.UDP_HOST, self.config.UDP_PORT))
            
            # Update statistics
            self.stats['lines_sent'] += 1
            self.stats['bytes_sent'] += bytes_sent
            
            return True
            
        except socket.timeout:
            self.stats['lines_failed'] += 1
            return False
        except Exception as e:
            self.logger.error(f"Failed to send UDP message: {e}")
            self.stats['lines_failed'] += 1
            return False
            
    def log_statistics(self):
        """Log current statistics"""
        if not self.stats['start_time']:
            return
            
        uptime = time.time() - self.stats['start_time']
        self.logger.info(f"Statistics - Uptime: {uptime:.1f}s, "
                       f"Lines processed: {self.stats['lines_processed']}, "
                       f"Lines sent: {self.stats['lines_sent']}, "
                       f"Lines failed: {self.stats['lines_failed']}, "
                       f"Bytes sent: {self.stats['bytes_sent']}, "
                       f"Rotations: {self.stats['rotation_count']}")
        
        # Calculate rates
        if uptime > 0:
            lines_per_sec = self.stats['lines_sent'] / uptime
            bytes_per_sec = self.stats['bytes_sent'] / uptime
            self.logger.debug(f"Rates - Lines/sec: {lines_per_sec:.2f}, Bytes/sec: {bytes_per_sec:.2f}")
    
    def signal_handler(self, signum, frame):
        """Handle system signals"""
        self.logger.info(f"Received signal {signum}, shutting down...")
        self.running = False
        
    def run(self):
        """Main service loop"""
        self.logger.info("Starting UDP Log Relay service")
        
        # Initialize start time for statistics
        self.stats['start_time'] = time.time()
        
        # Validate configuration
        if not self.config.validate():
            self.logger.error("Configuration validation failed")
            return False
            
        # Log detailed configuration
        self.logger.info(f"Configuration validated - UDP target: {self.config.UDP_HOST}:{self.config.UDP_PORT}")
        self.logger.info(f"Monitoring log file: {self.config.LOG_FILE_PATH}")
        self.logger.info(f"Poll interval: {self.config.POLL_INTERVAL}s, Max line length: {self.config.MAX_LINE_LENGTH}")
            
        # Setup signal handlers
        signal.signal(signal.SIGTERM, self.signal_handler)
        signal.signal(signal.SIGINT, self.signal_handler)
        self.logger.debug("Signal handlers registered for SIGTERM and SIGINT")
        
        # Setup UDP socket
        if not self.setup_udp_socket():
            return False
            
        # Open log file
        if not self.open_log_file():
            self.close_udp_socket()
            return False
            
        self.running = True
        self.logger.info("Service started successfully")
        
        # Variables for periodic logging and rotation checking
        last_stats_log = time.time()
        last_rotation_check = time.time()
        stats_interval = float(self.config.STATS_LOG_INTERVAL)  # Log statistics at configured interval
        rotation_check_interval = float(self.config.ROTATION_CHECK_INTERVAL)  # Check for rotation at configured interval
        
        try:
            while self.running:
                loop_start = time.time()
                current_time = time.time()
                
                # Check for file rotation periodically (less frequent than line reading)
                if current_time - last_rotation_check >= rotation_check_interval:
                    if self.check_file_rotation():
                        self.handle_file_rotation()
                    last_rotation_check = current_time
                
                # Read new lines from log file
                new_lines = self.read_new_lines()
                self.stats['lines_processed'] += len(new_lines)
                
                # Send each new line via UDP
                for line in new_lines:
                    if not self.send_udp_message(line):
                        self.logger.warning(f"Failed to send line: {line[:100]}...")
                
                # Periodic statistics logging
                if current_time - last_stats_log >= stats_interval:
                    self.log_statistics()
                    last_stats_log = current_time
                
                # Log performance metrics
                loop_duration = time.time() - loop_start
                if loop_duration > self.config.POLL_INTERVAL * 2:
                    self.logger.warning(f"Main loop took {loop_duration:.3f}s (expected ~{self.config.POLL_INTERVAL}s)")
                        
                # Sleep before next poll
                time.sleep(self.config.POLL_INTERVAL)
                
        except Exception as e:
            self.logger.error(f"Unexpected error in main loop: {e}")
            
        finally:
            self.cleanup()
            
        return True
        
    def cleanup(self):
        """Cleanup resources"""
        self.logger.info("Cleaning up resources")
        
        # Log final statistics
        if self.stats['start_time']:
            self.log_statistics()
        
        self.close_log_file()
        self.close_udp_socket()
        self.logger.info("Service stopped")


def write_pid_file(pid_file_path: str):
    """Write PID file"""
    try:
        pid_dir = os.path.dirname(pid_file_path)
        os.makedirs(pid_dir, exist_ok=True)
        with open(pid_file_path, 'w') as f:
            f.write(str(os.getpid()))
    except Exception as e:
        print(f"Warning: Could not write PID file: {e}")

def remove_pid_file(pid_file_path: str):
    """Remove PID file"""
    try:
        if os.path.exists(pid_file_path):
            os.remove(pid_file_path)
    except Exception as e:
        print(f"Warning: Could not remove PID file: {e}")

def main():
    """Main entry point"""
    relay = UDPLogRelay()
    
    # Check if running as daemon
    if len(sys.argv) > 1 and sys.argv[1] == '--daemon':
        # Create PID file directory if it doesn't exist
        pid_dir = os.path.dirname(relay.config.DAEMON_PID_FILE)
        os.makedirs(pid_dir, exist_ok=True)
        
        # Create log directory if it doesn't exist
        log_dir = os.path.dirname(relay.config.DAEMON_LOG_FILE)
        os.makedirs(log_dir, exist_ok=True)
        
        # Write PID file
        write_pid_file(relay.config.DAEMON_PID_FILE)
        
        # Fork to background
        try:
            pid = os.fork()
            if pid > 0:
                # Parent process exits
                sys.exit(0)
        except OSError as e:
            print(f"Fork failed: {e}")
            sys.exit(1)
        
        # Child process continues
        os.setsid()
        os.chdir(relay.config.DAEMON_WORKING_DIR)
        os.umask(0)
        
        # Close file descriptors
        try:
            os.close(0)  # stdin
            os.close(1)  # stdout
            os.close(2)  # stderr
        except OSError:
            pass
        
        # Redirect to /dev/null
        try:
            os.open('/dev/null', os.O_RDWR)  # stdin
            os.dup2(0, 1)  # stdout
            os.dup2(0, 2)  # stderr
        except OSError:
            pass
        
        # Run the service
        try:
            relay.run()
        finally:
            remove_pid_file(relay.config.DAEMON_PID_FILE)
    else:
        # Run in foreground
        relay.run()


if __name__ == '__main__':
    main()
