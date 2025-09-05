# 로그 파일 롤링 처리 개선사항

## 문제점 분석

기존 코드의 로그 파일 롤링 처리에서 발견된 문제점들:

1. **파일 핸들 관리 문제**: 파일이 새로 생성되어도 기존 파일 핸들이 여전히 유효할 수 있음
2. **파일 위치 추적 문제**: 파일이 완전히 새로 생성되면 inode가 바뀌어 기존 핸들로는 새 파일을 읽을 수 없음
3. **롤링 감지 로직의 한계**: 파일 크기 감소만 감지하지만, 실제 롤링 시나리오는 다양함

## 개선사항

### 1. 다중 롤링 감지 방법 구현

#### 기존 방법
- 파일 크기 감소만 감지

#### 개선된 방법
- **Method 1**: inode 변경 감지 (가장 신뢰성 높음)
- **Method 2**: 파일 크기 감소 감지
- **Method 3**: 수정 시간 역행 감지 (파일이 재생성됨)
- **Method 4**: 파일 위치에서 읽기 불가능 감지 (파일이 잘림)

### 2. 파일 메타데이터 추적

```python
# 새로 추가된 추적 변수들
self.file_inode = None      # 파일의 inode 번호
self.file_mtime = None      # 파일의 수정 시간
```

### 3. 향상된 롤링 처리 로직

#### 재시도 메커니즘
- 최대 5회 재시도 (설정 가능)
- 지수적 백오프 지연 (1초 → 1.5초 → 2.25초 → ...)
- 각 재시도마다 파일 재생성 대기

#### 안전한 파일 재오픈
- 기존 파일 핸들 완전 종료
- 파일 추적 변수 초기화
- 새 파일 메타데이터 저장

### 4. 설정 가능한 롤링 옵션

```python
# config.py에 추가된 설정들
ROTATION_CHECK_INTERVAL: float = 1.0    # 롤링 체크 간격 (초)
ROTATION_RETRY_ATTEMPTS: int = 5        # 재시도 횟수
ROTATION_RETRY_DELAY: float = 1.0       # 초기 재시도 지연 (초)
```

### 5. 개선된 파일 읽기 로직

- 더 안정적인 오류 처리
- 파일 위치 추적 개선
- 롤링 감지와 읽기 로직 분리

## 테스트 시나리오

새로 추가된 `scripts/test_rotation.sh` 스크립트는 다음 시나리오들을 테스트합니다:

1. **정상 로그 처리**: 기본적인 로그 엔트리 처리
2. **파일 이동 및 재생성**: `mv` 명령으로 파일 이동 후 새 파일 생성
3. **파일 잘림**: 파일을 새로 덮어쓰기
4. **파일 삭제 및 재생성**: 파일 삭제 후 새로 생성
5. **연속 동작 확인**: 롤링 후에도 정상적으로 계속 동작하는지 확인

## 사용법

### 기본 사용
```bash
# 기존과 동일하게 사용
python3 udp_log_relay.py
```

### 롤링 테스트
```bash
# 롤링 처리 테스트 실행
./scripts/test_rotation.sh
```

### 환경 변수로 설정 조정
```bash
# 롤링 체크 간격을 0.5초로 설정
ROTATION_CHECK_INTERVAL=0.5 python3 udp_log_relay.py

# 재시도 횟수를 3회로 설정
ROTATION_RETRY_ATTEMPTS=3 python3 udp_log_relay.py
```

## 로그 메시지

개선된 코드는 더 자세한 로그 메시지를 제공합니다:

- `File inode changed from X to Y, rotation detected`
- `File modification time went backwards, rotation detected`
- `Successfully reopened log file after rotation (attempt N)`
- `Failed to reopen log file after rotation after all retry attempts`

## 호환성

- 기존 설정 파일과 완전 호환
- 기존 명령행 옵션과 완전 호환
- 새로운 설정들은 기본값으로 동작

## 성능 영향

- 롤링 체크는 별도 간격으로 실행되어 성능 영향 최소화
- 기본적으로 1초마다 체크 (설정 가능)
- 정상 동작 시에는 추가 오버헤드 없음

