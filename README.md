# UDP Log Relay Service

실시간으로 누적되는 로그 파일을 읽어서 UDP unicast로 전송하는 Python 데몬 서비스입니다. 로그 파일의 롤링을 자동으로 감지하고 처리합니다.

## 주요 기능

- 📁 **실시간 로그 모니터링**: 지정된 로그 파일을 실시간으로 모니터링
- 🔄 **로그 롤링 감지**: 로그 파일이 롤링되어도 자동으로 감지하고 새 파일을 추적
- 📡 **UDP 전송**: 새로운 로그 엔트리를 UDP unicast로 전송
- 🚀 **네이티브 배포**: systemd 서비스로 간편하게 배포
- 🔧 **설정 가능**: 환경 변수를 통한 유연한 설정

## 프로젝트 구조

```
udp_relay/
├── udp_log_relay.py      # 메인 서비스 코드
├── udp_receiver.py       # UDP 수신 테스트 클라이언트
├── config.py             # 설정 관리
├── receiver_config.py    # 수신기 설정 관리
├── requirements.txt      # Python 표준 라이브러리 정보
├── scripts/              # 실행 스크립트
│   ├── start.sh          # 서비스 시작
│   ├── stop.sh           # 서비스 중지
│   ├── restart.sh        # 서비스 재시작
│   ├── status.sh         # 서비스 상태 확인
│   ├── test_integration.sh # 통합 테스트
│   ├── test_rotation.sh  # 롤링 테스트
│   ├── test_real_rotation.sh # 실제 롤링 테스트
│   ├── debug_start.sh    # 디버그 시작
│   ├── run_local.sh      # 로컬 실행 스크립트
│   ├── deploy_native.sh  # 네이티브 배포 스크립트
│   └── undeploy_native.sh # 네이티브 배포 제거 스크립트
├── docs/                 # 문서
│   ├── ROTATION_IMPROVEMENTS.md # 롤링 개선사항
│   ├── ENHANCED_LOGGING.md      # 로깅 개선사항
│   └── OPTIMIZATION_SUMMARY.md  # 최적화 요약
└── README.md             # 이 파일
```

## 빠른 시작

### 1. 저장소 클론 및 이동
```bash
cd /Users/syjung/workspace/iss/udp_relay
```

### 2. 네이티브 배포
```bash
./scripts/deploy_native.sh
```

### 3. 서비스 중지
```bash
./scripts/undeploy_native.sh
```

### 4. 테스트 실행
```bash
# 통합 테스트 (권장)
./scripts/test_integration.sh

# 롤링 테스트
./scripts/test_rotation.sh
```

## 설정

환경 변수를 통해 서비스를 설정할 수 있습니다:

### 로그 파일 설정
- `LOG_FILE_PATH`: 모니터링할 로그 파일 경로 (기본값: `/home/iss/var/logs/platform/receiver/rawdata/nmea_rawdata.log`)
- `LOG_FILE_ENCODING`: 로그 파일 인코딩 (기본값: `utf-8`)

### UDP 설정
- `UDP_HOST`: UDP 전송 대상 호스트 (기본값: `127.0.0.1`)
- `UDP_PORT`: UDP 전송 대상 포트 (기본값: `514`)
- `UDP_BUFFER_SIZE`: UDP 버퍼 크기 (기본값: `1024`)

### 서비스 설정
- `DAEMON_PID_FILE`: 데몬 PID 파일 경로 (기본값: `./run/udp_log_relay.pid`)
- `DAEMON_LOG_FILE`: 데몬 로그 파일 경로 (기본값: `./logs/udp_log_relay.log`)
- `DAEMON_WORKING_DIR`: 데몬 작업 디렉토리 (기본값: `.`)

### 모니터링 설정
- `POLL_INTERVAL`: 파일 폴링 간격 (초) (기본값: `0.1`)
- `MAX_LINE_LENGTH`: 최대 라인 길이 (기본값: `8192`)

### 로그 로테이션 설정
- `LOG_MAX_BYTES`: 로그 파일 최대 크기 (바이트) (기본값: `10485760` = 10MB)
- `LOG_BACKUP_COUNT`: 보관할 백업 파일 개수 (기본값: `5`)

## 네이티브 배포

### 자동 배포 (권장)
```bash
# 네이티브 배포 실행
./scripts/deploy_native.sh
```

이 스크립트는 다음 작업을 자동으로 수행합니다:
- Python 3 및 pip3 설치 확인
- 서비스 사용자 생성 (`udprelay`)
- 필요한 디렉토리 생성
- Python 가상환경 생성 및 의존성 설치
- 애플리케이션 파일 복사
- systemd 서비스 생성
- 서비스 시작 및 검증

### 배포 제거
```bash
# 네이티브 배포 제거
./scripts/undeploy_native.sh
```

### 로컬 개발/테스트
```bash
# 로컬에서 실행 (포그라운드)
./scripts/run_local.sh

# 로컬에서 데몬으로 실행
./scripts/run_local.sh --daemon
```

### 수동 배포
```bash
# 외부 의존성 없음 (Python 표준 라이브러리만 사용)

# 포그라운드에서 실행
python3 udp_log_relay.py

# 백그라운드에서 실행
./scripts/start.sh
```

## 로그 파일 롤링 지원

서비스는 다음과 같은 로그 파일 롤링 시나리오를 자동으로 처리합니다:

1. **파일 삭제**: 로그 파일이 삭제되면 새 파일이 생성될 때까지 대기
2. **파일 크기 감소**: 파일 크기가 이전 위치보다 작아지면 롤링으로 감지
3. **자동 재연결**: 새 파일이 생성되면 자동으로 파일을 다시 열고 모니터링 재개

## 모니터링 및 디버깅

### 서비스 상태 확인
```bash
# 서비스 상태 확인
sudo systemctl status udp-log-relay

# 서비스 로그 확인
sudo journalctl -u udp-log-relay -f

# 실시간 로그 확인
tail -f ./logs/udp_log_relay.log
```

### 테스트

#### 통합 테스트 (권장)
```bash
# 전체 기능 테스트 (UDP 수신기와 함께)
./scripts/test_integration.sh
```

이 스크립트는:
1. UDP 수신 클라이언트를 백그라운드에서 시작
2. UDP Log Relay 서비스를 시작
3. 테스트 로그 엔트리를 생성
4. 로그 파일 롤링 시뮬레이션
5. 수신된 메시지를 실시간으로 화면에 출력

#### 롤링 테스트
```bash
# 로그 파일 롤링 처리 테스트
./scripts/test_rotation.sh

# 실제 운영 환경 롤링 시뮬레이션
./scripts/test_real_rotation.sh
```

#### UDP 수신 테스트
UDP로 전송된 로그를 실시간으로 확인하려면 UDP 수신 클라이언트를 사용하세요:

```bash
# UDP 수신 클라이언트 실행 (기본 포트 514)
python3 udp_receiver.py

# 다른 포트로 수신
python3 udp_receiver.py --port 1514

# 특정 호스트에 바인딩
python3 udp_receiver.py --host 127.0.0.1 --port 514
```

#### 수동 테스트
```bash
# 수동으로 테스트 메시지 생성 (실제 로그 파일 경로 사용)
echo "$(date): Test message" | sudo tee -a /home/iss/var/logs/platform/receiver/rawdata/nmea_rawdata.log
```

## 보안 고려사항

- 서비스는 전용 사용자(`udprelay`)로 실행됩니다
- 로그 파일은 읽기 전용으로 접근됩니다
- systemd를 통한 안전한 서비스 관리
- PID 파일을 통한 프로세스 관리

## 프로덕션 배포 가이드

### 서버 준비사항
1. **Python 3 및 pip3 설치**
   ```bash
   # Ubuntu/Debian
   sudo apt-get update
   sudo apt-get install python3 python3-pip python3-venv
   
   # CentOS/RHEL
   sudo yum install python3 python3-pip
   ```

2. **로그 파일 준비**
   ```bash
   # 모니터링할 로그 파일 디렉토리 생성
   sudo mkdir -p /home/iss/var/logs/platform/receiver/rawdata
   sudo touch /home/iss/var/logs/platform/receiver/rawdata/nmea_rawdata.log
   sudo chmod 644 /home/iss/var/logs/platform/receiver/rawdata/nmea_rawdata.log
   ```

3. **방화벽 설정**
   ```bash
   # UDP 포트 514 열기 (필요한 경우)
   sudo ufw allow 514/udp
   ```

### 배포 단계
1. **코드 배포**
   ```bash
   # 프로젝트 디렉토리로 이동
   cd /path/to/udp_relay
   
   # 네이티브 배포 실행
   ./scripts/deploy_native.sh
   ```

2. **서비스 확인**
   ```bash
   # 서비스 상태 확인
   sudo systemctl status udp-log-relay
   
   # 로그 확인
   sudo journalctl -u udp-log-relay -f
   
   # 테스트 메시지 전송
   echo "$(date): Test message" | sudo tee -a /home/iss/var/logs/platform/receiver/rawdata/nmea_rawdata.log
   ```

3. **모니터링 설정**
   ```bash
   # 서비스 자동 시작 설정 (이미 배포 스크립트에서 설정됨)
   sudo systemctl enable udp-log-relay
   ```

### 업데이트 및 롤백
```bash
# 서비스 중지
sudo systemctl stop udp-log-relay

# 새 코드 배포
./scripts/deploy_native.sh

# 서비스 재시작
sudo systemctl restart udp-log-relay

# 완전 제거
./scripts/undeploy_native.sh
```

## 문제 해결

### 일반적인 문제들

1. **로그 파일을 찾을 수 없음**
   ```bash
   # 로그 파일 경로 확인
   ls -la /home/iss/var/logs/platform/receiver/rawdata/nmea_rawdata.log
   
   # 권한 확인
   ls -la /home/iss/var/logs/platform/receiver/rawdata/
   ```

2. **UDP 전송 실패**
   ```bash
   # 네트워크 연결 확인
   nc -u -v 127.0.0.1 514
   
   # 방화벽 확인
   sudo ufw status
   ```

3. **서비스가 시작되지 않음**
   ```bash
   # 서비스 로그 확인
   sudo journalctl -u udp-log-relay -n 50
   
   # 서비스 상태 확인
   sudo systemctl status udp-log-relay
   
   # 수동 실행 테스트
   sudo -u udprelay $(pwd)/venv/bin/python $(pwd)/udp_log_relay.py
   ```

## 라이선스

이 프로젝트는 MIT 라이선스 하에 배포됩니다.

## 기여

버그 리포트나 기능 요청은 GitHub Issues를 통해 제출해 주세요.
