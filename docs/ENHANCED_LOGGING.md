# Enhanced Logging for UDP Log Relay

## 개요
UDP Log Relay 서비스의 로깅 시스템을 대폭 개선하여 더 상세하고 유용한 정보를 제공합니다.

## 주요 개선사항

### 1. 상세한 로그 포맷
- 파일명과 라인 번호 포함
- 타임스탬프, 로그 레벨, 메시지 구조화
- 예: `2025-01-01 12:00:00,123 - UDPLogRelay - INFO - [udp_log_relay.py:123] - Message`

### 2. 통계 및 성능 메트릭
- 처리된 라인 수, 전송 성공/실패 수
- 전송된 바이트 수
- 로그 파일 회전 횟수
- 업타임 및 처리 속도 (라인/초, 바이트/초)

### 3. 파일 모니터링 개선
- 파일 크기 및 수정 시간 로깅
- 파일 위치 추적
- 회전 감지 시 상세 정보

### 4. UDP 전송 상세 로깅
- 전송 성공/실패 상세 정보
- 메시지 길이 및 잘림 정보
- 소켓 타임아웃 처리
- 바이트 단위 전송 통계

### 5. 주기적 상태 로깅
- 설정 가능한 간격으로 통계 로깅 (기본 60초)
- 성능 메트릭 모니터링
- 루프 실행 시간 추적

### 6. 설정 가능한 로그 레벨
- 환경변수 `LOG_LEVEL`로 제어 (DEBUG, INFO, WARNING, ERROR)
- 파일과 콘솔에 다른 레벨 적용 가능

## 환경변수 설정

```bash
# 로그 레벨 설정 (DEBUG, INFO, WARNING, ERROR)
export LOG_LEVEL=DEBUG

# 통계 로깅 간격 (초)
export STATS_LOG_INTERVAL=60

# 기존 설정들
export UDP_HOST=127.0.0.1
export UDP_PORT=514
export LOG_FILE_PATH=./logs/app.log
```

## 로그 레벨별 정보

### DEBUG 레벨
- 상세한 파일 읽기 정보
- UDP 전송 세부사항
- 파일 크기 변화 추적
- 루프 실행 시간
- 설정 정보

### INFO 레벨
- 서비스 시작/종료
- 파일 회전 처리
- 주기적 통계
- 주요 이벤트

### WARNING 레벨
- UDP 전송 실패
- 파일 접근 문제
- 성능 이슈

### ERROR 레벨
- 치명적 오류
- 설정 검증 실패
- 예상치 못한 예외

## 테스트 방법

```bash
# 테스트 스크립트 실행
python3 test_enhanced_logging.py

# 수동으로 DEBUG 레벨로 실행
LOG_LEVEL=DEBUG python3 udp_log_relay.py

# 통계 로깅 간격을 10초로 설정
STATS_LOG_INTERVAL=10 LOG_LEVEL=DEBUG python3 udp_log_relay.py
```

## 로그 파일 위치
- 메인 로그: `logs/udp_log_relay.log`
- 로그 회전: `logs/udp_log_relay.log.1`, `logs/udp_log_relay.log.2`, etc.

## 모니터링 권장사항

1. **운영 환경**: `LOG_LEVEL=INFO` 사용
2. **디버깅**: `LOG_LEVEL=DEBUG` 사용
3. **통계 모니터링**: `STATS_LOG_INTERVAL=300` (5분) 권장
4. **로그 파일 크기**: 기본 10MB, 필요시 `LOG_MAX_BYTES` 조정
