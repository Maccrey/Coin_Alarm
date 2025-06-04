# Coin Alarm

암호화폐 가격 알림 및 모니터링 앱

## 소개

Coin Alarm은 암호화폐 가격을 실시간으로 모니터링하고 사용자가 설정한 가격에 도달하면 알림을 보내는 모바일 앱입니다. Flutter로 개발되었으며, Supabase를 백엔드로 사용합니다.

## 주요 기능

- 실시간 암호화폐 가격 모니터링
- 사용자 지정 가격 알림 설정
- 코인별 차트 및 가격 이력 조회
- 차트 데이터 1분마다 자동 새로고침
- 암호화폐 관련 뉴스 제공
- 다크 모드 지원
- 오프라인 모드 지원 (캐시된 데이터 사용)

## 기술 스택

- **프론트엔드**: Flutter
- **백엔드**: Supabase (PostgreSQL, Auth, Storage, Functions, Realtime)
- **상태 관리**: Provider
- **API**: Upbit, Binance
- **로컬 저장소**: Hive, SharedPreferences
- **차트**: 커스텀 차트 위젯

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
- `news`: 뉴스 정보
- `news_coins`: 뉴스와 코인의 관계 정보
- `user_settings`: 사용자별 앱 설정 정보
- `chart_data`: 차트 데이터 캐시
- `alert_history`: 알림 발생 이력

자세한 테이블 구조는 [lib/database/supabase_tables.md](lib/database/supabase_tables.md) 파일을 참조하세요.

### 3. Row Level Security (RLS)

Supabase의 RLS(Row Level Security) 기능을 사용하여 다음과 같은 보안 정책을 적용했습니다:

- 사용자는 자신의 프로필, 알림 설정, 앱 설정만 읽고 수정할 수 있습니다.
- 코인 정보, 가격 이력, 뉴스는 모든 사용자가 읽기 가능합니다.

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

## 프로젝트 구조

```
lib/
├── core/           # 상수, 테마, 유틸리티 함수
├── database/       # Supabase 데이터베이스 스키마 및 문서
├── data/           # 더미 데이터 및 로컬 데이터 소스
├── model/          # 데이터 모델 클래스
├── services/       # 서비스 클래스 (API, 저장소, 인증 등)
├── view/           # UI 화면 및 위젯
│   ├── screens/    # 앱 화면
│   └── widgets/    # 재사용 가능한 위젯
├── viewmodel/      # 뷰모델 클래스 (MVVM 패턴)
└── main.dart       # 앱 진입점
```

## 라이선스

이 프로젝트는 MIT 라이선스 하에 배포됩니다. 자세한 내용은 [LICENSE](LICENSE) 파일을 참조하세요.

## 기여

버그 신고, 기능 요청 또는 풀 리퀘스트는 언제든지 환영합니다.

## 연락처

프로젝트 관리자: [이름](mailto:email@example.com)
