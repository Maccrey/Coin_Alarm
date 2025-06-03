import 'package:flutter/material.dart';
import '../services/settings_service.dart';

// 설정 관련 ViewModel 클래스
class SettingsViewModel extends ChangeNotifier {
  final SettingsService _settingsService;

  // 상태 관리
  bool _isLoading = false;
  ThemeMode _themeMode = ThemeMode.system;
  int _refreshInterval = 30;
  bool _pushNotificationsEnabled = true;
  bool _useBiometricAuth = false;
  String _language = '한국어';
  bool _saveLoginInfo = false;

  // API 키 상태
  String? _upbitAccessKey;
  String? _upbitSecretKey;
  String? _binanceApiKey;
  String? _binanceSecretKey;

  // 생성자
  SettingsViewModel(this._settingsService) {
    // 설정값 로드
    _loadSettings();
  }

  // Getters
  bool get isLoading => _isLoading;
  ThemeMode get themeMode => _themeMode;
  int get refreshInterval => _refreshInterval;
  bool get pushNotificationsEnabled => _pushNotificationsEnabled;
  bool get useBiometricAuth => _useBiometricAuth;
  String get language => _language;
  bool get saveLoginInfo => _saveLoginInfo;

  // API 키 Getters
  String? get upbitAccessKey => _upbitAccessKey;
  String? get upbitSecretKey => _upbitSecretKey;
  String? get binanceApiKey => _binanceApiKey;
  String? get binanceSecretKey => _binanceSecretKey;

  // API 키 설정 여부 확인
  bool get hasUpbitApiKeys =>
      _upbitAccessKey != null && _upbitSecretKey != null;
  bool get hasBinanceApiKeys =>
      _binanceApiKey != null && _binanceSecretKey != null;

  // 설정값 로드
  Future<void> _loadSettings() async {
    debugPrint('SettingsViewModel: 설정 로드 시작');
    _isLoading = true;
    notifyListeners();

    try {
      _themeMode = _settingsService.getThemeMode();
      _refreshInterval = _settingsService.getRefreshInterval();
      _pushNotificationsEnabled =
          _settingsService.getPushNotificationsEnabled();
      _useBiometricAuth = _settingsService.getBiometricAuthEnabled();
      _language = _settingsService.getLanguage();
      _saveLoginInfo = _settingsService.getSaveLoginInfo();

      // API 키 로드
      _upbitAccessKey = _settingsService.getUpbitAccessKey();
      _upbitSecretKey = _settingsService.getUpbitSecretKey();
      _binanceApiKey = _settingsService.getBinanceApiKey();
      _binanceSecretKey = _settingsService.getBinanceSecretKey();

      debugPrint('SettingsViewModel: 설정 로드 완료');
      debugPrint(
        'SettingsViewModel: API 키 로드 상태 - Upbit: ${hasUpbitApiKeys}, Binance: ${hasBinanceApiKeys}',
      );
      debugPrint(
        'SettingsViewModel: 업비트 키 길이 - Access: ${_upbitAccessKey?.length ?? 0}, Secret: ${_upbitSecretKey?.length ?? 0}',
      );
    } catch (e) {
      debugPrint('SettingsViewModel: 설정 로드 실패: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 테마 모드 설정
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;

    _isLoading = true;
    notifyListeners();

    try {
      await _settingsService.setThemeMode(mode);
      _themeMode = mode;
    } catch (e) {
      debugPrint('테마 모드 설정 실패: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 새로고침 간격 설정
  Future<void> setRefreshInterval(int seconds) async {
    if (_refreshInterval == seconds) return;

    _isLoading = true;
    notifyListeners();

    try {
      await _settingsService.setRefreshInterval(seconds);
      _refreshInterval = seconds;

      // CryptoViewModel의 새로고침 간격도 업데이트
      // 이 부분은 Provider.of를 사용하지 않고 대신 CryptoViewModel이 자체적으로
      // SettingsService에서 간격을 읽도록 설계되어 있어 별도 처리가 필요하지 않음
    } catch (e) {
      debugPrint('새로고침 간격 설정 실패: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 푸시 알림 설정
  Future<void> setPushNotificationsEnabled(bool enabled) async {
    if (_pushNotificationsEnabled == enabled) return;

    _isLoading = true;
    notifyListeners();

    try {
      await _settingsService.setPushNotificationsEnabled(enabled);
      _pushNotificationsEnabled = enabled;
    } catch (e) {
      debugPrint('푸시 알림 설정 실패: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 생체 인증 설정
  Future<void> setUseBiometricAuth(bool enabled) async {
    if (_useBiometricAuth == enabled) return;

    _isLoading = true;
    notifyListeners();

    try {
      await _settingsService.setBiometricAuthEnabled(enabled);
      _useBiometricAuth = enabled;
    } catch (e) {
      debugPrint('생체 인증 설정 실패: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 언어 설정
  Future<void> setLanguage(String lang) async {
    if (_language == lang) return;

    _isLoading = true;
    notifyListeners();

    try {
      await _settingsService.setLanguage(lang);
      _language = lang;
    } catch (e) {
      debugPrint('언어 설정 실패: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 로그인 정보 저장 설정
  Future<void> setSaveLoginInfo(bool save) async {
    if (_saveLoginInfo == save) return;

    _isLoading = true;
    notifyListeners();

    try {
      await _settingsService.setSaveLoginInfo(save);
      _saveLoginInfo = save;

      // 로그인 정보 저장 해제 시 저장된 정보 삭제
      if (!save) {
        await _settingsService.clearLoginInfo();
      }
    } catch (e) {
      debugPrint('로그인 정보 저장 설정 실패: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Upbit API 키 설정
  Future<void> setUpbitApiKeys(String accessKey, String secretKey) async {
    if (_upbitAccessKey == accessKey && _upbitSecretKey == secretKey) {
      debugPrint('SettingsViewModel: 업비트 API 키 변경 없음, 무시');
      return;
    }

    debugPrint(
      'SettingsViewModel: 업비트 API 키 설정 시도 - Access 키 길이: ${accessKey.length}, Secret 키 길이: ${secretKey.length}',
    );
    _isLoading = true;
    notifyListeners();

    try {
      await _settingsService.setUpbitApiKeys(accessKey, secretKey);
      _upbitAccessKey = accessKey;
      _upbitSecretKey = secretKey;
      debugPrint('SettingsViewModel: 업비트 API 키 설정 성공');
    } catch (e) {
      debugPrint('SettingsViewModel: 업비트 API 키 설정 실패: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Binance API 키 설정
  Future<void> setBinanceApiKeys(String apiKey, String secretKey) async {
    if (_binanceApiKey == apiKey && _binanceSecretKey == secretKey) {
      debugPrint('SettingsViewModel: 바이낸스 API 키 변경 없음, 무시');
      return;
    }

    debugPrint(
      'SettingsViewModel: 바이낸스 API 키 설정 시도 - API 키 길이: ${apiKey.length}, Secret 키 길이: ${secretKey.length}',
    );
    _isLoading = true;
    notifyListeners();

    try {
      await _settingsService.setBinanceApiKeys(apiKey, secretKey);
      _binanceApiKey = apiKey;
      _binanceSecretKey = secretKey;
      debugPrint('SettingsViewModel: 바이낸스 API 키 설정 성공');
    } catch (e) {
      debugPrint('SettingsViewModel: 바이낸스 API 키 설정 실패: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // API 키 초기화
  Future<void> clearApiKeys() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _settingsService.clearApiKeys();
      _upbitAccessKey = null;
      _upbitSecretKey = null;
      _binanceApiKey = null;
      _binanceSecretKey = null;
    } catch (e) {
      debugPrint('API 키 초기화 실패: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 모든 설정 기본값으로 초기화
  Future<void> resetToDefaults() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _settingsService.resetToDefaults();
      await _loadSettings(); // 기본값 다시 로드
    } catch (e) {
      debugPrint('설정 초기화 실패: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
