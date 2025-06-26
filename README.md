# Coin Alarm

암호화폐 가격 알림 및 모니터링 앱

## 소개

Coin Alarm은 암호화폐 가격을 실시간으로 모니터링하고 사용자가 설정한 가격에 도달하면 알림을 보내는 모바일 앱입니다. Flutter로 개발되었으며, Supabase와 Firebase를 백엔드로 사용합니다.

## 주요 기능

- 실시간 암호화폐 가격 모니터링
- 사용자 지정 가격 알림 설정
- 코인별 차트 및 가격 이력 조회
- 차트 데이터 1분마다 자동 새로고침
- 암호화폐 관련 뉴스 제공 (MSA 아키텍처 기반 크롤링)
- 다크 모드 지원
- 오프라인 모드 지원 (캐시된 데이터 사용)
- 차트 페이지 캐시/로딩 UX 개선
- 이메일/소셜 로그인 (Supabase 연동)
- 코인 시세/차트/뉴스/알림 실시간 제공
- **설정: 생체 인증(지문/Face ID) 사용 가능**
- 로컬 저장소(Hive) 기반 자동 로그인/알림/차트 캐시
- **Firebase Realtime Database 연동 실시간 데이터 동기화**
- **강력한 알림 기능 (Awesome Notifications 기반)**

## 기술 스택

- **프론트엔드**: Flutter
- **백엔드**:
  - Supabase (PostgreSQL, Auth, Storage, Functions, Realtime)
  - Firebase (Authentication, Realtime Database)
- **상태 관리**: Provider, Riverpod
- **API**: Upbit, Binance
- **로컬 저장소**: Hive, SharedPreferences
- **차트**: 커스텀 차트 위젯
- **뉴스 크롤링**: Python, BeautifulSoup, Docker, MSA 아키텍처
- **알림 시스템**: Awesome Notifications

## Supabase 연동

### 1. 인증 시스템

- 이메일/비밀번호 로그인
- 소셜 로그인 (준비 중)
- 사용자 프로필 관리

### 2. 데이터베이스 구조

Supabase PostgreSQL 데이터베이스에 다음과 같은 테이블이 구성되어 있습니다:

- `user_profiles`: 사용자 프로필 정보
- `coins`: 코인 기본 정보
- `price_history`: 코인 가격 이력 데이터
- `price_alerts`: 사용자 가격 알림 설정
- `news`: 뉴스 정보 (image_url, related_coins 포함)
- `news_coins`: 뉴스와 코인의 관계 정보
- `user_settings`: 사용자별 앱 설정 정보
- `chart_data`: 차트 데이터 캐시
- `alert_history`: 알림 발생 이력

자세한 테이블 구조는 [lib/database/supabase_tables.md](lib/database/supabase_tables.md) 파일을 참조하세요.

### 3. Row Level Security (RLS)

Supabase의 RLS(Row Level Security) 기능을 사용하여 다음과 같은 보안 정책을 적용했습니다:

- 사용자는 자신의 프로필, 알림 설정, 앱 설정만 읽고 수정할 수 있습니다.
- 코인 정보, 가격 이력, 뉴스는 모든 사용자가 읽기 가능합니다.

## Firebase 연동

### 1. Firebase Realtime Database

Firebase Realtime Database를 사용하여 다음과 같은 기능을 구현했습니다:

- 실시간 데이터 동기화: 사용자 설정 및 알림 정보를 여러 기기 간에 실시간으로 동기화
- 오프라인 지원: 네트워크 연결이 끊겨도 로컬에서 데이터 조작 가능, 연결 복구 시 자동 동기화
- 실시간 알림 처리: 가격 알림 조건 충족 시 즉시 알림 트리거

### 2. Firebase 데이터 구조

Firebase Realtime Database에는 다음과 같은 데이터 구조가 구성되어 있습니다:

- `/users/{userId}/settings`: 사용자별 설정 정보
- `/users/{userId}/alerts`: 사용자별 알림 설정
- `/coins/{coinId}/price`: 코인별 최신 가격 정보
- `/coins/{coinId}/alerts`: 코인별 알림 조건 및 트리거 상태

### 3. Firebase 보안 규칙

Firebase Realtime Database의 보안 규칙을 통해 다음과 같은 보안 정책을 적용했습니다:

- 사용자는 자신의 데이터(`/users/{userId}/`)만 읽고 쓸 수 있습니다.
- 코인 가격 정보는 모든 인증된 사용자가 읽을 수 있지만, 쓰기는 관리자만 가능합니다.
- 인증되지 않은 사용자는 데이터에 접근할 수 없습니다.

## 알림 시스템

### 1. Awesome Notifications

최신 버전의 Awesome Notifications 패키지를 사용하여 강력한 알림 기능을 구현했습니다:

- 고급 알림 기능: 사용자 지정 소리, 진동 패턴, LED 색상 등 설정 가능
- 예약 알림: 특정 시간에 알림을 예약하여 표시 가능
- 알림 채널 및 그룹: 알림을 유형별로 구분하여 관리
- 알림 권한 관리: 사용자 친화적인 권한 요청 UI 제공
- 플랫폼별 최적화: Android, iOS 플랫폼별 최적화된 알림 설정

### 2. 알림 권한 관리

- 앱 최초 실행 시 알림 권한을 요청합니다.
- 권한이 거부된 경우, 사용자에게 필요한 권한과 그 이유를 설명하는 다이얼로그를 표시합니다.
- 사용자는 설정 화면에서 언제든지 알림 권한을 관리할 수 있습니다.

### 3. 알림 유형

- **코인 가격 알림**: 사용자가 설정한 가격에 도달하면 알림을 표시합니다.
- **예약 알림**: 특정 시간에 알림을 예약하여 표시합니다.
- **뉴스 알림**: 주요 암호화폐 뉴스가 발생하면 알림을 표시합니다.
- **시스템 알림**: 앱 업데이트, 서비스 점검 등 시스템 관련 알림을 표시합니다.

## 뉴스 크롤링 서버 (MSA 아키텍처)

암호화폐 관련 뉴스를 자동으로 수집하는 MSA(Microservice Architecture) 기반 크롤링 서버입니다.

### 1. 서비스 구조

- **news-crawler-service**: 다양한 암호화폐 뉴스 사이트에서 뉴스 수집

  - Blockmedia, CoinReaders, Bloomingbit 크롤러
  - 각 사이트별 독립적인 크롤링 모듈
  - 관련 코인 자동 태깅
  - 뉴스 이미지 URL 추출 및 저장

- **news-cleaner-service**: 수집된 뉴스 데이터 정제

  - 중복 뉴스 제거
  - 제목/본문 정제
  - 광고성 컨텐츠 필터링
  - 이미지 URL 및 관련 코인 정보 유지

- **news-writer-service**: 정제된 뉴스 데이터 저장

  - Supabase DB 연동
  - 뉴스 저장 및 업데이트
  - 이미지 URL(imageUrl → image_url) 및 관련 코인 배열 저장
  - SQLite DB 기반 처리 이력 추적으로 중복 저장 방지
  - 처리 완료된 파일 자동 정리

- **scheduler-service**: 정기적인 크롤링 작업 스케줄링

  - 2시간 주기 실행
  - 오류 복구 및 재시도 로직

- **logger-service**: 로깅 및 오류 추적
  - 중앙 집중식 로깅
  - 오류 발생 시 알림

### 2. 기술 스택

- **언어**: Python
- **크롤링 라이브러리**: BeautifulSoup, Requests
- **컨테이너화**: Docker, docker-compose
- **스케줄링**: cron
- **데이터베이스**: Supabase (PostgreSQL), SQLite (로컬 처리 추적)
- **배포 환경**: Synology NAS

### 3. 주요 특징

- 확장 가능한 MSA 아키텍처로 각 서비스가 독립적으로 동작
- 도커 기반 컨테이너화로 쉬운 배포 및 관리
- TDD(Test-Driven Development) 방식 개발로 높은 안정성
- 2시간마다 자동 업데이트되는 최신 뉴스 제공
- 코인 관련 키워드 기반 자동 태깅 시스템
- SQLite 기반 처리 이력 추적으로 서버 부하 감소 및 중복 저장 방지
- 뉴스 이미지 URL 및 관련 코인 정보 Supabase DB에 저장
- 처리 완료된 파일 자동 정리로 디스크 공간 최적화

## 설치 및 실행

### 요구 사항

- Flutter 3.10.0 이상
- Dart 3.0.0 이상
- Android Studio 또는 VS Code
- Android SDK 또는 iOS 개발 환경

### 설치 단계

1. 저장소 클론:

   ```bash
   git clone https://github.com/yourusername/coin_alarm.git
   cd coin_alarm
   ```

2. 의존성 설치:

   ```bash
   flutter pub get
   ```

3. `.env` 파일 생성:

   ```
   SUPABASE_URL=your_supabase_url
   SUPABASE_ANON_KEY=your_supabase_anon_key
   UPBIT_API_KEY=your_upbit_api_key (선택사항)
   UPBIT_SECRET_KEY=your_upbit_secret_key (선택사항)
   ```

4. 앱 실행:
   ```bash
   flutter run
   ```

### 뉴스 크롤링 서버 실행 (개발자용)

1. webcrawler 디렉토리로 이동:

   ```bash
   cd webcrawler
   ```

2. Docker 컨테이너 빌드 및 실행:

   ```bash
   docker-compose up -d
   ```

3. 로그 확인:

   ```bash
   docker-compose logs -f
   ```

## 프로젝트 구조

```
lib/
├── core/           # 상수, 테마, 유틸리티 함수
├── database/       # 데이터베이스 관련 코드
│   ├── firebase/   # Firebase Realtime Database 관련 코드
│   └── supabase/   # Supabase 데이터베이스 스키마 및 문서
├── data/           # 더미 데이터 및 로컬 데이터 소스
├── model/          # 데이터 모델 클래스
├── services/       # 서비스 클래스 (API, 저장소, 인증 등)
├── view/           # UI 화면 및 위젯
│   ├── screens/    # 앱 화면
│   └── widgets/    # 재사용 가능한 위젯
├── viewmodel/      # 뷰모델 클래스 (MVVM 패턴)
└── main.dart       # 앱 진입점

webcrawler/         # 뉴스 크롤링 서버 (MSA 아키텍처)
├── docker-compose.yml  # 도커 구성 파일
├── news-crawler/   # 뉴스 크롤링 서비스
├── news-cleaner/   # 뉴스 정제 서비스
├── news-writer/    # Supabase DB 저장 서비스
├── scheduler/      # 스케줄러 서비스
├── logger/         # 로깅 서비스
└── shared/         # 공유 디렉토리 (처리 파일 및 SQLite DB)
```

## 라이선스

이 프로젝트는 MIT 라이선스 하에 배포됩니다. 자세한 내용은 [LICENSE](LICENSE) 파일을 참조하세요.

## 기여

버그 신고, 기능 요청 또는 풀 리퀘스트는 언제든지 환영합니다.

## 연락처

프로젝트 관리자: [이름](mailto:email@example.com)

## 문제 해결 내역

### 차트 페이지 캐시/로딩 UX 개선

- 캐시 데이터가 있으면 즉시 차트에 표시, 네트워크는 백그라운드에서 최신 데이터 요청
- 로딩 중에도 캐시 데이터가 있으면 차트 먼저 보여주고, 하단에 '최신 데이터 수신 중...' 안내 메시지 표시
- 네트워크가 느릴 때도 UX가 쾌적하게 개선됨

### Hive Box 초기화 순서 오류 (LateInitializationError)

- **증상:** SettingsService 등에서 Hive Box 사용 시 LateInitializationError 발생
- **원인:** main.dart에서 Hive.initFlutter()와 어댑터 등록이 SettingsService.initialize()보다 늦게 실행되어, Box가 열리기 전에 접근이 발생함
- **해결:** Hive 초기화 및 어댑터 등록을 SettingsService.initialize()보다 먼저 실행하도록 main.dart 코드 순서 수정

### 알림 시스템 업그레이드

- **증상:** 기존 flutter_local_notifications 패키지로 구현된 알림 시스템이 일부 기기에서 작동하지 않는 문제 발생
- **원인:** 패키지 버전 호환성 문제 및 Android 12+ 권한 변경 사항
- **해결:**
  - flutter_local_notifications에서 awesome_notifications 패키지로 교체
  - NotificationService 클래스를 최신 API에 맞게 전면 수정
  - AndroidManifest.xml에 필요한 권한 및 서비스 설정 추가
  - iOS Podfile에 Awesome Notifications 설정 추가
  - 사용자 친화적인 권한 요청 다이얼로그 구현
  - intl 패키지 버전을 ^0.20.2로 업데이트하여 호환성 확보

## 설정 > 생체 인증 사용법

- 설정 화면에서 '생체 인증 사용' 스위치를 켜면, 기기에서 지문/Face ID 인증을 요구합니다.
- 인증에 성공하면 이후 앱 실행/로그인 시 생체 인증을 사용할 수 있습니다.
- 기기에서 생체 인증이 미지원/실패 시 안내 메시지가 표시됩니다.

## Firebase Realtime Database 사용법

### 데이터 저장 및 조회

- `FirebaseDatabaseService` 클래스를 통해 데이터 저장, 조회, 업데이트, 삭제 기능을 사용할 수 있습니다.
- 예시:

  ```dart
  final databaseService = FirebaseDatabaseService();

  // 데이터 저장
  await databaseService.saveData('coins/bitcoin', {
    'name': 'Bitcoin',
    'price': 50000,
    'timestamp': DateTime.now().millisecondsSinceEpoch,
  });

  // 데이터 조회
  final data = await databaseService.getData('coins/bitcoin');

  // 데이터 업데이트
  await databaseService.updateData('coins/bitcoin', {
    'price': 55000,
    'updated_at': DateTime.now().millisecondsSinceEpoch,
  });

  // 데이터 삭제
  await databaseService.deleteData('coins/bitcoin');
  ```

### 실시간 데이터 리스닝

- `listenToData` 메서드를 사용하여 특정 경로의 데이터 변경을 실시간으로 감지할 수 있습니다.
- 예시:

  ```dart
  final databaseService = FirebaseDatabaseService();

  // 실시간 데이터 리스닝
  final Stream<DatabaseEvent> stream = databaseService.listenToData('coins/bitcoin');

  stream.listen((DatabaseEvent event) {
    if (event.snapshot.exists) {
      final data = event.snapshot.value as Map<String, dynamic>;
      print('실시간 데이터 업데이트: $data');
      // 데이터 처리 로직
    }
  });
  ```

### 오프라인 지원

- Firebase Realtime Database는 오프라인 지원 기능을 제공합니다.
- 네트워크 연결이 끊겨도 로컬에서 데이터 조작이 가능하며, 연결이 복구되면 자동으로 동기화됩니다.

## 뉴스 페이징 및 캐싱 구조

- Hive를 활용해 뉴스 데이터를 로컬에 캐싱하여, 앱 실행 시 캐시가 있으면 즉시 표시합니다.
- 캐시가 없거나 최신 데이터가 필요할 경우 Firestore(또는 Realtime DB)에서 일부(20개)만 먼저 가져와 빠르게 화면에 표시합니다.
- 사용자가 스크롤을 내릴 때마다 추가 데이터를 자동으로 불러오며, 불러온 데이터는 Hive에 누적 저장되어 다음 진입 시 빠른 로딩이 가능합니다.
- 추가 데이터 로딩 중에는 하단에 로딩 인디케이터가 표시되어 UX를 개선하였습니다.
- 기존 검색/필터 기능과도 자연스럽게 연동되며, 대용량 데이터 환경에서도 쾌적한 사용성을 제공합니다.
