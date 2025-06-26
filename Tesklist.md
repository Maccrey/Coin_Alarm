# 암호화폐 뉴스 파이프라인 MSA 재구현 테스크 (2025.06)

- [x] **0. 프로젝트 환경 개선 및 빌드 최적화**

  - **빌드 프로세스 분석**: Docker 빌드 프로세스를 조사하여 긴 빌드 시간의 원인을 분석했습니다. 원인은 Docker 빌드 컨텍스트에 불필요한 파일들이 대거 포함되어 빌드 속도를 저하시키는 것이었습니다.
  - **`.dockerignore` 파일 생성**: `webcrawler` 루트 디렉토리에 `.dockerignore` 파일을 추가하여 `logs`, `shared` 디렉토리, 임시 파일 등이 빌드 컨텍스트에 포함되지 않도록 설정하여 빌드 속도를 향상시켰습니다.
  - **오래된 모놀리식 파일 제거**: 현재 `docker-compose.yml` 기반의 마이크로서비스 아키텍처에서는 더 이상 사용되지 않는 과거의 모놀리식 관련 파일들을 삭제하여 프로젝트 구조를 정리했습니다.
    - 삭제된 파일: `Dockerfile`, `supervisord.conf`, `entrypoint.sh`, `install_chromedriver.sh`, `writer_container.py`, `container_cleaner.py`, `temp_cleaner.py`, `docker-compose.synology.yml`, `SYNOLOGY_INSTALL_GUIDE.md`

- [ ] **1. 크롤러**: 주요 사이트(예: blockmedia, coinreaders, digitaltoday)에서 Playwright로 뉴스 수집, `crawled_news_*.json` 파일로 저장 (한글 주석, 명확한 변수명, 예외 처리, 중복/빈 데이터 방지)
- [ ] **2. 클리너**: `crawled_news_*.json`을 읽어 정제(필터링, 중복/광고/짧은 기사 제거), `cleaned_news_*.json` 파일로 저장
- [x] **3. writer**: `cleaned_news_*.json`을 읽어 Supabase에 저장, 성공 시 파일 삭제, 실패 시 로그 남기고 파일 유지
- [ ] **4. 각 단계별 robust한 예외/에러/빈 데이터/중복/포맷 문제 처리**, 한글 상세 로그 남기기
- [ ] **5. logger**: 각 단계별 로그/상태를 실시간 대시보드로 시각화 (최신 30건, KPI, 에러 강조, 다크테마 등)
- [x] **6. 불필요 파일/임시/중복/테스트 파일(.DS_Store, temp_cleaner.py 등) 정리 및 삭제** (0번 항목에서 완료)
- [x] **7. `README.md` 문서 업데이트**: 프로젝트 정리 및 구조 변경 사항을 `README.md`에 반영하여 최신 상태를 유지했습니다.
- [x] **8. Firebase Realtime Database 설치 및 테스트**: Firebase Realtime Database 의존성을 추가하고 서비스 클래스를 구현하여 데이터 저장, 조회, 업데이트, 삭제 기능을 테스트했습니다. Android 빌드를 위해 minSdkVersion을 23으로 업데이트했습니다.
- [x] **9. 알림 시스템 업그레이드**: flutter_local_notifications에서 awesome_notifications로 알림 시스템을 업그레이드하여 더 강력한 알림 기능을 구현했습니다.

---

_이전 작업 내역_

- [x] Supabase 저장 신뢰성 강화 (저장 후 DB 반영 여부 즉시 검증, 실패 시 재시도, 필수 필드 체크, 상세 로그 및 예외 처리)

## 1. Webcrawler Docker 재구성 및 아키텍처 변경 (완료)

- **상태:** 완료
- **변경 사항:**
  - 기존의 MSA(Microservices Architecture) 구조에서 각 서비스(`news-crawler`, `news-cleaner`, `news-writer`)를 별도의 컨테이너로 실행하던 방식을 변경했습니다.
  - `scheduler` 서비스가 전체 파이프라인을 순차적으로 실행하는 단일 컨테이너(Monolithic) 방식으로 아키텍처를 재구성했습니다.
  - `scheduler` 컨테이너 내에서 `subprocess`를 사용하여 각 스크립트를 실행합니다.
- **수정된 파일:**
  - `webcrawler/docker-compose.yml`: `news-crawler`, `news-cleaner`, `news-writer` 서비스를 제거하고, `scheduler` 서비스의 빌드 컨텍스트와 환경 변수를 수정했습니다.
  - `webcrawler/scheduler/Dockerfile`: `scheduler` 이미지 빌드 시 모든 관련 스크립트와 의존성을 포함하도록 수정했습니다.
- **결과:**
  - Docker 빌드 오류가 해결되었습니다.
  - 아키텍처가 단순화되어 유지보수성이 향상되었습니다.
  - `scheduler`가 모든 작업을 제어하므로 파이프라인의 동작이 더 명확해졌습니다.

## 2. 로깅 및 모니터링 시스템 개선 (진행 예정)

- **Tesk:** `logger` 서비스와 `scheduler`의 로그를 통합하고, 파이프라인 상태를 명확하게 추적할 수 있는 시스템을 구축합니다.
- **TDD 테스트 케이스:**
  - [ ] `scheduler`의 각 파이프라인 단계(crawling, cleaning, writing)의 시작과 끝, 성공/실패 여부가 `logs/scheduler.log` 파일에 정상적으로 기록되는지 테스트합니다.
  - [ ] `shared/pipeline_status.json` 파일에 현재 파이프라인의 상태(`running`, `waiting`, `error`), 현재 단계, 다음 실행 시간이 정확히 기록되는지 테스트합니다.
  - [ ] 로깅 레벨(INFO, ERROR, WARNING)에 따라 로그 메시지가 올바르게 저장되는지 확인하는 테스트를 작성합니다.
- **구현:**
  - [ ] `scheduler/main.py`의 로깅 로직을 검토하고, 각 단계별 로그를 더 상세하게 기록하도록 개선합니다.
  - [ ] `logger` 서비스가 `scheduler.log` 파일을 읽어 API를 통해 로그를 조회할 수 있는 기능을 구현합니다. (선택 사항)
  - [ ] 파이프라인 실패 시, 어떤 단계에서 어떤 오류로 실패했는지 명확히 알 수 있도록 예외 처리 및 로깅을 강화합니다.

## 3. README.md 업데이트 (진행 예정)

- **Tesk:** 변경된 아키텍처와 실행 방법을 `README.md` 파일에 반영합니다.
- **구현:**
  - [ ] `README.md`에 현재 프로젝트가 단일 `scheduler` 컨테이너 기반으로 동작함을 명시합니다.
  - [ ] `docker-compose up` 명령어로 간단히 실행할 수 있음을 안내합니다.
  - [ ] 각 디렉토리와 파일의 역할을 최신 상태로 업데이트합니다.

---

## [신규 개선 Task - 2025.06.22]

### 8. 뉴스 파이프라인 신뢰성/안정성 개선 (MSA & TDD)

- [x] **1. 에러 발생 시 재시도/복구 로직 강화** (전체 서비스 적용 완료)

  - news-crawler, news-cleaner, news-writer, scheduler, logger의 모든 주요 파일 저장/삭제/이동/상태 기록/로그 기록에 대해 3회까지 robust 재시도(2초 대기) 및 3회 실패 시 .fail 확장자 파일로 이동(중복/유실 방지) 로직을 적용함.
  - 모든 네트워크/DB/파일/프로세스 단계에서 3회 robust 재시도 및 한글 상세 로그를 남기도록 개선.
  - 모든 에러/실패 로그를 한글로 상세하게 기록.
  - 코드 적용 및 테스트 완료 (2024-06-22)

- [x] **2. 파일 처리 후 삭제/이동 로직 개선**

  - 파일 이동/삭제 시 robust 예외 처리, 3회 재시도, 실패 시 .fail 확장자 처리로 중복/유실 방지.
  - 파일 처리 중 오류 발생 시 한글 상세 로그 남기고, 다음 실행 시 중복 처리 방지 로직 추가.
  - 코드 적용 및 테스트 완료 (2024-06-22)

- [x] **3. SHARED_DIR 경로 환경변수화 및 일관성 확보**

  - 모든 서비스에서 SHARED_DIR 경로를 환경변수로 통일하고, 경로가 없거나 잘못된 경우 robust 예외 처리 및 한글 에러 로그를 남기도록 개선.
  - 코드 적용 및 테스트 완료 (2024-06-22)

- [x] **4. 로깅 포맷/레벨/한글화 일관성 확보**

  - logger 사용 방식 통일, 모든 로그 메시지를 한글로 작성, 로그 레벨별 구분 및 robust 예외 처리 적용.
  - 코드 적용 및 테스트 완료 (2024-06-22)

- [x] **5. 불필요 파일/임시 파일 자동 정리**

  - .DS_Store 등 불필요 파일이 남지 않도록 각 서비스 시작 시 자동 정리 로직 추가 및 robust 예외 처리 적용.
  - 코드 적용 및 테스트 완료 (2024-06-22)

- [x] **6. 테스트 코드/자동화 강화**

  - 각 서비스별 주요 기능(크롤링, 정제, 저장, 파일 처리 등)에 대한 단위 테스트/통합 테스트 코드 작성 및 robust 예외 상황 시뮬레이션 테스트 추가.
  - 코드 적용 및 테스트 완료 (2024-06-22)

- [x] **7. 서비스 간 데이터 포맷/계약 명세 주석 및 문서화**
  - 크롤러→클리너→라이터 각 단계별 입력/출력 JSON 포맷, 필수 필드, 예외 상황 등을 코드 주석과 README에 명확히 문서화.
  - 포맷 불일치/필드 누락 robust 예외 처리 및 한글 로그 추가.
  - 코드 적용 및 테스트 완료 (2024-06-22)

### 9. 대시보드(logs) 연동 및 실시간 상태 모니터링

- [ ] **1. logger API 확장: 각 서비스 로그 파일 REST API 제공**

  - logger 서비스에서 crawler.log, cleaner.log, writer.log, scheduler.log 등 모든 로그 파일을 REST API(`/api/logs/<service>?lines=100&level=ERROR`)로 읽어올 수 있도록 endpoint 구현
  - lines, level, 기간 등 파라미터 지원
  - TDD: API 테스트 코드 작성

- [ ] **2. 대시보드 프론트엔드 연동**

  - http://localhost:5001/ 대시보드에서 각 서비스별 로그를 실시간/최근 로그로 표출하도록 logger API와 연동
  - 서비스별 탭/카드로 최근 로그, 상태, 에러/경고 등 표시
  - 주기적 polling 또는 WebSocket으로 실시간 갱신
  - TDD: 주요 컴포넌트 단위 테스트

- [ ] **3. 서비스 상태 요약/알림 기능**
  - 각 서비스의 최근 로그에서 에러/경고를 파싱하여 상태 요약(정상/에러/경고/최근 실행 시간 등) 표시
  - 에러/경고 발생 시 실시간 알림(Toast 등) 제공
  - TDD: 상태 요약/알림 테스트

### 10. Firebase 통합 및 실시간 데이터베이스 구현

- [x] **1. Firebase Realtime Database 설치 및 의존성 추가**

  - Firebase Realtime Database 의존성(`firebase_database: ^11.3.7`) 추가
  - Android minSdkVersion을 23으로 업데이트하여 Firebase 호환성 확보
  - 의존성 설치 및 iOS/Android 빌드 테스트 완료 (2024-06-24)

- [x] **2. Firebase Realtime Database 서비스 클래스 구현**

  - `FirebaseDatabaseService` 클래스 구현 (데이터 저장, 조회, 업데이트, 삭제, 실시간 리스닝)
  - 모든 메서드에 한글 주석 및 예외 처리 추가
  - 테스트 코드 작성 및 의존성 확인 테스트 완료 (2024-06-24)

- [x] **3. Firebase Realtime Database 예제 구현**
  - 데이터 저장, 조회, 업데이트, 삭제 기능을 포함한 예제 UI 구현
  - 실시간 데이터 리스닝 기능 구현
  - 예제 코드 작성 완료 (2024-06-24)

### 11. 알림 시스템 업그레이드

- [x] **1. 알림 패키지 업그레이드**

  - `flutter_local_notifications` 패키지를 `awesome_notifications` 패키지로 교체
  - 의존성 추가 및 버전 호환성 확인 완료 (2024-06-25)

- [x] **2. 알림 서비스 클래스 리팩토링**

  - `NotificationService` 클래스를 `awesome_notifications` API에 맞게 전면 수정
  - 채널 그룹, 권한 관리, 알림 표시, 예약 알림 등 기능 구현
  - 웹/모바일 플랫폼 분기 처리 및 예외 처리 추가
  - 코드 적용 및 테스트 완료 (2024-06-25)

- [x] **3. 플랫폼별 설정 업데이트**

  - Android: AndroidManifest.xml에 필요한 권한 및 서비스 설정 추가
  - iOS: Podfile에 Awesome Notifications 설정 추가
  - 빌드 및 테스트 완료 (2024-06-25)

- [x] **4. 알림 권한 요청 UI 개선**

  - 사용자 친화적인 권한 요청 다이얼로그 구현
  - 권한 거부 시 안내 메시지 표시 기능 추가
  - 코드 적용 및 테스트 완료 (2024-06-25)

- [x] **5. 알림 리스너 및 핸들러 설정**
  - 알림 탭 이벤트 리스너 설정 및 처리 로직 구현
  - 백그라운드/포그라운드 알림 처리 로직 구현
  - 코드 적용 및 테스트 완료 (2024-06-25)

### 뉴스 페이징 및 캐싱 개선 (MSA/TDD)

- [x] Hive 기반 뉴스 캐싱 구조 설계 및 구현
- [x] Firestore 페이징 쿼리 적용 (limit, startAfter)
- [x] 최초 진입 시 Hive 캐시 우선 표시
- [x] 추가 스크롤 시 Firestore에서 다음 페이지 로드
- [x] 가져온 데이터 Hive에 저장(중복 방지)
- [x] UI에 로딩 인디케이터 및 에러 처리
- [x] Android/iOS 네이티브 설정 확인
- [x] TDD: 캐시/페이징 동작 단위 테스트
