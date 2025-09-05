import os
from typing import Optional

class Config:
    """Configuration settings for UDP Log Relay service"""
    
    # Log file settings
    LOG_FILE_PATH: str = os.getenv('LOG_FILE_PATH', '/home/iss/var/logs/platform/receiver/rawdata/nmea_rawdata.log')
    LOG_FILE_ENCODING: str = os.getenv('LOG_FILE_ENCODING', 'utf-8')
    
    # UDP settings
    UDP_HOST: str = os.getenv('UDP_HOST', '127.0.0.1')
    UDP_PORT: int = int(os.getenv('UDP_PORT', '514'))
    UDP_BUFFER_SIZE: int = int(os.getenv('UDP_BUFFER_SIZE', '1024'))
    
    # Service settings
    DAEMON_PID_FILE: str = os.getenv('DAEMON_PID_FILE', './run/udp_log_relay.pid')
    DAEMON_LOG_FILE: str = os.getenv('DAEMON_LOG_FILE', './logs/udp_log_relay.log')
    DAEMON_WORKING_DIR: str = os.getenv('DAEMON_WORKING_DIR', '.')
    
    # File monitoring settings
    POLL_INTERVAL: float = float(os.getenv('POLL_INTERVAL', '0.1'))  # seconds
    MAX_LINE_LENGTH: int = int(os.getenv('MAX_LINE_LENGTH', '8192'))
    
    # File rotation detection settings
    ROTATION_CHECK_INTERVAL: float = float(os.getenv('ROTATION_CHECK_INTERVAL', '1.0'))  # seconds
    ROTATION_RETRY_ATTEMPTS: int = int(os.getenv('ROTATION_RETRY_ATTEMPTS', '5'))
    ROTATION_RETRY_DELAY: float = float(os.getenv('ROTATION_RETRY_DELAY', '1.0'))  # seconds
    
    # Log rotation settings
    LOG_MAX_BYTES: int = int(os.getenv('LOG_MAX_BYTES', '10485760'))  # 10MB
    LOG_BACKUP_COUNT: int = int(os.getenv('LOG_BACKUP_COUNT', '5'))
    
    # Logging settings
    LOG_LEVEL: str = os.getenv('LOG_LEVEL', 'INFO')  # DEBUG, INFO, WARNING, ERROR
    STATS_LOG_INTERVAL: int = int(os.getenv('STATS_LOG_INTERVAL', '60'))  # seconds
    
    @classmethod
    def validate(cls) -> bool:
        """Validate configuration settings"""
        try:
            # Check if log file path is accessible
            if not os.path.exists(os.path.dirname(cls.LOG_FILE_PATH)):
                print(f"Warning: Log file directory does not exist: {os.path.dirname(cls.LOG_FILE_PATH)}")
            
            # Validate UDP port range
            if not (1 <= cls.UDP_PORT <= 65535):
                raise ValueError(f"Invalid UDP port: {cls.UDP_PORT}")
                
            return True
        except Exception as e:
            print(f"Configuration validation error: {e}")
            return False