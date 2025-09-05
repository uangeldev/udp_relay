import os
from typing import Optional

class ReceiverConfig:
    """Configuration settings for UDP Log Receiver"""
    
    # Network settings
    HOST: str = os.getenv('RECEIVER_HOST', '0.0.0.0')
    PORT: int = int(os.getenv('RECEIVER_PORT', '514'))
    BUFFER_SIZE: int = int(os.getenv('RECEIVER_BUFFER_SIZE', '1024'))
    
    # Display settings
    SHOW_STATS_INTERVAL: int = int(os.getenv('RECEIVER_STATS_INTERVAL', '10'))  # Show stats every N messages
    SOCKET_TIMEOUT: float = float(os.getenv('RECEIVER_SOCKET_TIMEOUT', '1.0'))  # seconds
    
    # Logging settings
    LOG_LEVEL: str = os.getenv('RECEIVER_LOG_LEVEL', 'INFO')  # DEBUG, INFO, WARNING, ERROR
    LOG_TO_FILE: bool = os.getenv('RECEIVER_LOG_TO_FILE', 'false').lower() == 'true'
    LOG_FILE: str = os.getenv('RECEIVER_LOG_FILE', './logs/udp_receiver.log')
    
    # Message formatting
    SHOW_TIMESTAMP: bool = os.getenv('RECEIVER_SHOW_TIMESTAMP', 'true').lower() == 'true'
    SHOW_SOURCE_ADDRESS: bool = os.getenv('RECEIVER_SHOW_SOURCE', 'true').lower() == 'true'
    MAX_MESSAGE_LENGTH: int = int(os.getenv('RECEIVER_MAX_MESSAGE_LENGTH', '1000'))
    
    @classmethod
    def validate(cls) -> bool:
        """Validate configuration settings"""
        try:
            # Validate port range
            if not (1 <= cls.PORT <= 65535):
                raise ValueError(f"Invalid receiver port: {cls.PORT}")
                
            # Validate buffer size
            if cls.BUFFER_SIZE < 1:
                raise ValueError(f"Invalid buffer size: {cls.BUFFER_SIZE}")
                
            # Validate timeout
            if cls.SOCKET_TIMEOUT < 0:
                raise ValueError(f"Invalid socket timeout: {cls.SOCKET_TIMEOUT}")
                
            return True
        except Exception as e:
            print(f"Receiver configuration validation error: {e}")
            return False
    
    @classmethod
    def print_config(cls):
        """Print current configuration"""
        print("UDP Receiver Configuration:")
        print(f"  Host: {cls.HOST}")
        print(f"  Port: {cls.PORT}")
        print(f"  Buffer Size: {cls.BUFFER_SIZE}")
        print(f"  Socket Timeout: {cls.SOCKET_TIMEOUT}s")
        print(f"  Stats Interval: {cls.SHOW_STATS_INTERVAL} messages")
        print(f"  Log Level: {cls.LOG_LEVEL}")
        print(f"  Log to File: {cls.LOG_TO_FILE}")
        if cls.LOG_TO_FILE:
            print(f"  Log File: {cls.LOG_FILE}")
        print(f"  Show Timestamp: {cls.SHOW_TIMESTAMP}")
        print(f"  Show Source Address: {cls.SHOW_SOURCE_ADDRESS}")
        print(f"  Max Message Length: {cls.MAX_MESSAGE_LENGTH}")
