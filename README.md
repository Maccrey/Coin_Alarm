# 🪙 Coin Alarm - 암호화폐 가격 알림 앱

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=flat&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=flat&logo=dart&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=flat&logo=firebase&logoColor=black)
![Android](https://img.shields.io/badge/Android-3DDC84?style=flat&logo=android&logoColor=white)
![iOS](https://img.shields.io/badge/iOS-000000?style=flat&logo=ios&logoColor=white)
![Web](https://img.shields.io/badge/Web-FF6B6B?style=flat&logo=html5&logoColor=white)

## 📋 프로젝트 개요

**Coin Alarm**은 Flutter로 개발된 크로스플랫폼 암호화폐 가격 모니터링 및 알림 앱입니다. 실시간 암호화폐 가격 추적, 가격 알림 설정, 차트 분석, 뉴스 제공 등의 기능을 제공합니다.

### 🎯 주요 기능

#### 🔐 인증 및 보안

- **Firebase 인증**: 이메일/비밀번호 기반 회원가입 및 로그인
- **생체 인증**: 지문/Face ID를 통한 빠른 로그인
- **자동 로그인**: 로그인 정보 저장 및 자동 로그인 기능
- **보안 설정**: 생체 인증 활성화/비활성화 옵션

#### 📊 실시간 가격 모니터링

- **멀티 거래소 지원**: Upbit, Binance API 연동
- **실시간 데이터**: 자동 새로고침 (1초~5분 간격 설정 가능)
- **가격 변동 표시**: 실시간 상승/하락 표시 및 애니메이션
- **즐겨찾기**: 관심 코인 선택 및 대시보드 표시

#### 🔔 가격 알림 시스템

- **조건부 알림**: 지정 가격 이상/이하 도달 시 알림
- **백그라운드 알림**: 앱이 백그라운드에서도 15분마다 자동 체크
- **개인화**: 코인별 개별 알림 설정 및 메모 추가
- **알림 히스토리**: 트리거된 알림 내역 관리

#### 📈 차트 분석

- **다양한 시간대**: 1분, 5분, 1시간, 1일, 1주일, 1개월 차트
- **캔들스틱 차트**: 전문적인 차트 분석 도구 제공
- **캐시 시스템**: 차트 데이터 캐싱으로 빠른 로딩
- **실시간 업데이트**: 선택된 시간대별 자동 갱신

#### 📰 뉴스 서비스

- **실시간 뉴스**: Firebase를 통한 암호화폐 관련 뉴스 제공
- **인기 뉴스**: 조회수 기반 인기 뉴스 선별
- **뉴스 검색**: 키워드 기반 뉴스 검색 기능
- **상세 보기**: 전문 뉴스 상세 페이지

#### ⚙️ 개인화 설정

- **테마 설정**: 라이트/다크/시스템 설정 테마 지원
- **햅틱 피드백**: 네이티브 수준의 진동 피드백 시스템
- **새로고침 간격**: 1초~5분 자유 설정
- **API 키 관리**: Upbit, Binance API 키 개별 설정
- **알림 설정**: 푸시 알림 및 진동 설정

## 🏗️ 프로젝트 구조

### 📁 디렉토리 구조

```
lib/
├── core/                    # 핵심 설정 및 상수
│   ├── constants.dart       # 앱 전역 상수
│   └── theme.dart          # 테마 설정
├── model/                   # 데이터 모델
│   ├── coin_model.dart      # 코인 데이터 모델
│   ├── user_model.dart      # 사용자 모델
│   ├── news_model.dart      # 뉴스 모델
│   ├── price_alert_model.dart # 가격 알림 모델
│   └── chart_data_model.dart  # 차트 데이터 모델
├── services/                # 비즈니스 로직 서비스
│   ├── auth_service.dart    # 인증 서비스
│   ├── firebase_service.dart # Firebase 연동
│   ├── crypto_api_service.dart # 암호화폐 API 서비스
│   ├── chart_api_service.dart  # 차트 API 서비스
│   ├── chart_cache_service.dart # 차트 캐시 서비스
│   ├── notification_service.dart # 알림 서비스
│   ├── price_alert_service.dart  # 가격 알림 서비스
│   ├── haptic_service.dart      # 햅틱 피드백 서비스
│   └── settings_service.dart    # 설정 서비스
├── viewmodel/               # MVVM 뷰모델
│   ├── auth_viewmodel.dart  # 인증 뷰모델
│   ├── crypto_viewmodel.dart # 암호화폐 뷰모델
│   ├── chart_viewmodel.dart # 차트 뷰모델
│   ├── news_viewmodel.dart  # 뉴스 뷰모델
│   ├── price_alert_viewmodel.dart # 가격 알림 뷰모델
│   ├── settings_viewmodel.dart    # 설정 뷰모델
│   ├── theme_viewmodel.dart       # 테마 뷰모델
│   └── coin_viewmodel.dart        # 코인 뷰모델
└── view/                    # UI 컴포넌트
    └── screens/             # 화면 위젯
        ├── splash_screen.dart       # 스플래시 화면
        ├── login_screen.dart        # 로그인 화면
        ├── register_screen.dart     # 회원가입 화면
        ├── biometric_login_screen.dart # 생체 인증 로그인
        ├── forgot_password_screen.dart # 비밀번호 찾기
        ├── home_screen.dart         # 메인 홈 화면
        ├── dashboard_screen.dart    # 대시보드 화면
        ├── chart_screen.dart        # 차트 화면
        ├── alerts_screen.dart       # 알림 화면
        ├── news_screen.dart         # 뉴스 화면
        ├── news_detail_screen.dart  # 뉴스 상세 화면
        ├── settings_screen.dart     # 설정 화면
        ├── terms_of_service_screen.dart    # 서비스 약관
        └── privacy_policy_screen.dart      # 개인정보 처리방침
```

### 🔧 기술 스택

#### 📱 프론트엔드

- **Framework**: Flutter 3.8.1
- **언어**: Dart
- **상태 관리**: Provider 패턴
- **아키텍처**: MVVM (Model-View-ViewModel)

#### 🗄️ 백엔드 & 데이터베이스

- **인증**: Firebase Authentication
- **데이터베이스**: Firebase Firestore
- **스토리지**: Firebase Storage
- **로컬 DB**: Hive (Key-Value 저장소)
- **캐싱**: Shared Preferences

#### 🌐 외부 API

- **Upbit API**: 국내 암호화폐 거래소 데이터
- **Binance API**: 글로벌 암호화폐 거래소 데이터
- **Chart API**: 실시간 차트 데이터

#### 📦 주요 패키지

```yaml
dependencies:
  # 상태 관리
  provider: ^6.0.5

  # 네트워크
  http: ^0.13.5
  dio: ^5.4.0

  # 로컬 저장소
  hive: ^2.2.3
  hive_flutter: ^1.1.0
  shared_preferences: ^2.2.0

  # UI/UX
  fl_chart: ^0.66.0
  cached_network_image: ^3.3.1
  shimmer: ^3.0.0
  lottie: ^2.7.0

  # 인증 & 보안
  local_auth: ^2.1.7
  crypto: ^3.0.6

  # 백그라운드 작업
  workmanager: ^0.6.0

  # 알림
  awesome_notifications: ^0.10.1

  # Firebase
  firebase_core: ^2.24.2
  firebase_auth: ^4.15.3
  cloud_firestore: ^4.13.6
  firebase_storage: ^11.5.6
  firebase_messaging: ^14.7.10
```

## 🚀 설치 및 실행

### 📋 필수 요구사항

- Flutter SDK 3.8.1 이상
- Dart SDK
- Android Studio / Xcode (모바일 개발 시)
- Firebase 프로젝트 설정

### 🛠️ 설치 과정

1. **저장소 클론**

   ```bash
   git clone https://github.com/your-username/coin_alarm.git
   cd coin_alarm
   ```

2. **의존성 설치**

   ```bash
   flutter pub get
   ```

3. **환경 변수 설정**

   ```bash
   # .env 파일 생성 (루트 디렉토리)
   SUPABASE_URL=your_supabase_url
   SUPABASE_ANON_KEY=your_supabase_anon_key
   ```

4. **Firebase 설정**

   - Firebase 콘솔에서 프로젝트 생성
   - `firebase_options.dart` 파일 구성
   - Android/iOS 앱 등록 및 설정 파일 다운로드

5. **코드 생성**

   ```bash
   flutter packages pub run build_runner build
   ```

6. **앱 실행**

   ```bash
   # 개발 모드
   flutter run

   # 웹에서 실행
   flutter run -d web-server --web-port=8080

   # 릴리즈 모드
   flutter run --release
   ```

## 📱 지원 플랫폼

- ✅ **Android** (API 23+)
- ✅ **iOS** (iOS 11.0+)
- ✅ **Web** (Chrome, Safari, Firefox)
- 🔄 **macOS** (개발 예정)
- 🔄 **Windows** (개발 예정)

## 🔒 보안 기능

### 🛡️ 데이터 보안

- API 키 안전한 로컬 저장
- 생체 인증을 통한 앱 보안
- Firebase 보안 규칙 적용
- HTTPS 통신 강제

### 🔐 인증 보안

- Firebase Authentication 사용
- 이메일 인증 필수
- 비밀번호 복잡도 검증
- 자동 로그아웃 기능

## 📊 성능 최적화

### ⚡ 성능 특징

- **로컬 캐싱**: 차트 및 코인 데이터 캐싱으로 빠른 로딩
- **백그라운드 처리**: WorkManager를 통한 효율적인 백그라운드 작업
- **메모리 관리**: Provider 패턴을 통한 효율적인 상태 관리
- **네트워크 최적화**: HTTP 요청 최적화 및 재시도 로직

### 📈 모니터링

- 실시간 가격 업데이트 (최소 1초 간격)
- 백그라운드 알림 체크 (15분 간격)
- 자동 오류 복구 시스템

## 🤝 기여 가이드

### 🐛 버그 리포트

- GitHub Issues를 통한 버그 리포트
- 재현 가능한 단계 제공
- 디바이스 및 OS 정보 포함

### 💡 기능 제안

- Feature Request 템플릿 사용
- 구체적인 사용 사례 설명
- UI/UX 목업 제공 (선택사항)

### 🔧 개발 참여

1. Fork 후 feature 브랜치 생성
2. 코딩 컨벤션 준수
3. 테스트 코드 작성
4. Pull Request 제출

## 📝 라이선스

이 프로젝트는 MIT 라이선스 하에 배포됩니다. 자세한 내용은 [LICENSE](LICENSE) 파일을 참조하세요.

## 📞 문의 및 지원

- **이메일**: support@coinalarm.com
- **GitHub Issues**: [버그 리포트 및 기능 요청](https://github.com/your-username/coin_alarm/issues)
- **Discord**: [개발자 커뮤니티](https://discord.gg/coinalarm)

## 🎉 감사 인사

- Flutter 팀의 훌륭한 프레임워크
- Firebase의 강력한 백엔드 서비스
- Upbit과 Binance의 오픈 API
- 오픈소스 커뮤니티의 모든 기여자들

---

**Made with ❤️ using Flutter**
