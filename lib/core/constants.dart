// 앱 전반에 걸쳐 사용되는 상수값들을 정의하는 파일입니다.

// 앱 정보 관련 상수
class AppConstants {
  static const String appName = 'Coin Alarm';
  static const String appVersion = '1.0.0';
  static const String appDescription = '암호화폐 가격 알림 및 모니터링 앱';
}

// API 엔드포인트 관련 상수
class ApiConstants {
  // Upbit API
  static const String upbitBaseUrl = 'https://api.upbit.com/v1';
  static const String upbitWebSocketUrl = 'wss://api.upbit.com/websocket/v1';

  // Binance API
  static const String binanceBaseUrl = 'https://api.binance.com/api/v3';
  static const String binanceWebSocketUrl = 'wss://stream.binance.com:9443/ws';

  // 가상의 Supabase URL (실제로는 .env 파일에서 로드)
  static const String supabaseUrl = 'https://example.supabase.co';
}

// 네비게이션 관련 상수
class NavigationConstants {
  static const String home = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String dashboard = '/dashboard';
  static const String coinDetail = '/coin-detail';
  static const String settings = '/settings';
  static const String alerts = '/alerts';
  static const String news = '/news';
}

// UI 관련 상수
class UIConstants {
  // 간격
  static const double paddingXS = 4.0;
  static const double paddingS = 8.0;
  static const double paddingM = 16.0;
  static const double paddingL = 24.0;
  static const double paddingXL = 32.0;

  // 반경
  static const double radiusS = 4.0;
  static const double radiusM = 8.0;
  static const double radiusL = 16.0;
  static const double radiusXL = 24.0;

  // 아이콘 크기
  static const double iconSizeS = 16.0;
  static const double iconSizeM = 24.0;
  static const double iconSizeL = 32.0;
  static const double iconSizeXL = 48.0;
}

// 시간 관련 상수
class TimeConstants {
  // 기본 새로고침 간격을 30초에서 10초로 변경
  static const int defaultRefreshIntervalSeconds = 10;
  static const int alertCheckIntervalSeconds = 60;
  static const int newsRefreshIntervalMinutes = 10;
  static const int maxCacheAgeHours = 24;

  // 새로고침 간격 옵션 (세분화)
  static const List<int> refreshIntervalOptions = [
    1,
    2,
    5,
    10,
    15,
    30,
    60,
    120,
    300,
  ];
}

// 기본 설정값 관련 상수
class DefaultSettings {
  static const bool enablePriceAlerts = true;
  static const bool enableNewsAlerts = true;
  static const bool useDarkMode = false;
  static const String defaultCurrency = 'KRW';
  static const List<String> defaultFavoriteCoins = [
    'BTC',
    'ETH',
    'XRP',
    'SOL',
    'DOGE',
  ];
}
