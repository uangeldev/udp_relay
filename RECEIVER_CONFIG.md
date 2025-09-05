# UDP Receiver Configuration Guide

## 개요
UDP Log Receiver의 host와 port를 포함한 모든 설정을 환경변수나 명령행 인수로 편리하게 변경할 수 있습니다.

## 환경변수 설정

### 네트워크 설정
```bash
# 수신할 호스트 주소 (기본값: 0.0.0.0)
export RECEIVER_HOST=127.0.0.1

# 수신할 포트 (기본값: 514)
export RECEIVER_PORT=1514

# 버퍼 크기 (기본값: 1024)
export RECEIVER_BUFFER_SIZE=2048

# 소켓 타임아웃 (기본값: 1.0초)
export RECEIVER_SOCKET_TIMEOUT=2.0
```

### 로깅 설정
```bash
# 로그 레벨 (DEBUG, INFO, WARNING, ERROR)
export RECEIVER_LOG_LEVEL=DEBUG

# 파일 로깅 활성화 (true/false)
export RECEIVER_LOG_TO_FILE=true

# 로그 파일 경로
export RECEIVER_LOG_FILE=./logs/udp_receiver.log
```

### 표시 설정
```bash
# 통계 표시 간격 (메시지 수)
export RECEIVER_STATS_INTERVAL=10

# 타임스탬프 표시 (true/false)
export RECEIVER_SHOW_TIMESTAMP=true

# 소스 주소 표시 (true/false)
export RECEIVER_SHOW_SOURCE=true

# 최대 메시지 길이
export RECEIVER_MAX_MESSAGE_LENGTH=1000
```

## 명령행 인수

### 기본 사용법
```bash
# 기본 설정으로 실행
python3 udp_receiver.py

# 설정 확인
python3 udp_receiver.py --show-config

# 도움말
python3 udp_receiver.py --help
```

### 네트워크 설정
```bash
# 특정 호스트와 포트로 실행
python3 udp_receiver.py --host 127.0.0.1 --port 1514

# 버퍼 크기 변경
python3 udp_receiver.py --buffer-size 2048
```

### 로깅 설정
```bash
# DEBUG 레벨로 실행
python3 udp_receiver.py --log-level DEBUG

# 파일 로깅 활성화
python3 udp_receiver.py --log-to-file

# 통계 표시 간격 변경
python3 udp_receiver.py --stats-interval 5
```

## 사용 예제

### 1. 기본 테스트
```bash
# 기본 설정으로 UDP 수신기 시작
python3 udp_receiver.py
```

### 2. 개발/디버깅용 설정
```bash
# DEBUG 레벨과 파일 로깅으로 실행
RECEIVER_LOG_LEVEL=DEBUG RECEIVER_LOG_TO_FILE=true python3 udp_receiver.py
```

### 3. 특정 포트로 수신
```bash
# 포트 1514로 수신
python3 udp_receiver.py --port 1514
```

### 4. 환경변수로 설정
```bash
# 환경변수 설정
export RECEIVER_HOST=0.0.0.0
export RECEIVER_PORT=1514
export RECEIVER_LOG_LEVEL=INFO
export RECEIVER_STATS_INTERVAL=20

# 실행
python3 udp_receiver.py
```

### 5. UDP Log Relay와 함께 테스트
```bash
# 터미널 1: UDP 수신기 시작
python3 udp_receiver.py --port 1514 --log-level DEBUG

# 터미널 2: UDP Log Relay 시작 (UDP_PORT=1514로 설정)
UDP_PORT=1514 python3 udp_log_relay.py
```

## 설정 우선순위

1. **명령행 인수** (최우선)
2. **환경변수**
3. **기본값**

예시:
```bash
# 환경변수로 포트 설정
export RECEIVER_PORT=1514

# 명령행에서 다른 포트 지정 (명령행이 우선)
python3 udp_receiver.py --port 1515  # 실제로는 1515 포트 사용
```

## 테스트 스크립트

설정 테스트를 위한 스크립트가 제공됩니다:

```bash
# 모든 설정 옵션 테스트
python3 test_receiver_config.py
```

## 로그 파일

파일 로깅이 활성화되면 다음 위치에 로그가 저장됩니다:
- 기본: `./logs/udp_receiver.log`
- 환경변수 `RECEIVER_LOG_FILE`로 변경 가능

## 성능 모니터링

수신기는 다음 통계를 제공합니다:
- 수신된 메시지 수
- 수신된 바이트 수
- 메시지/초, 바이트/초 처리율
- 업타임

통계는 설정된 간격마다 표시되며, 종료 시 최종 통계가 출력됩니다.

## 문제 해결

### 포트가 이미 사용 중인 경우
```bash
# 다른 포트 사용
python3 udp_receiver.py --port 1515
```

### 권한 문제 (1024 이하 포트)
```bash
# sudo 사용 또는 1024 이상 포트 사용
sudo python3 udp_receiver.py --port 514
# 또는
python3 udp_receiver.py --port 1514
```

### 로그 파일 권한 문제
```bash
# 로그 디렉토리 생성
mkdir -p logs
chmod 755 logs
```
