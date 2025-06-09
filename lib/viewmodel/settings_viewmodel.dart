import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/settings_service.dart';
import '../core/theme.dart';
import 'crypto_viewmodel.dart';
import 'package:local_auth/local_auth.dart';

// 설정 관련 ViewModel 클래스
class SettingsViewModel extends ChangeNotifier {
  final SettingsService _settingsService;

  // 상태 관리
  bool _isLoading = false;
  ThemeMode _themeMode = ThemeMode.system;
  int _refreshInterval = 30;
  bool _pushNotificationsEnabled = true;
  bool _useBiometrics = false;
  String _language = '한국어';
  bool _saveLoginInfo = false;

  // API 키 상태
  String? _upbitAccessKey;
  String? _upbitSecretKey;
  String? _binanceApiKey;
  String? _binanceSecretKey;

  final LocalAuthentication _localAuth = LocalAuthentication();

  String? _biometricErrorMessage;
  String? get biometricErrorMessage => _biometricErrorMessage;

  // 생성자
  SettingsViewModel(this._settingsService) {
    _loadBiometrics();
    // 설정값 로드
    _loadSettings();
  }

  // Getters
  bool get isLoading => _isLoading;
  ThemeMode get themeMode => _themeMode;
  int get refreshInterval => _refreshInterval;
  bool get pushNotificationsEnabled => _pushNotificationsEnabled;
  bool get useBiometrics => _useBiometrics;
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
      _pushNotificationsEnabled = _settingsService
          .getPushNotificationsEnabled();
      _useBiometrics = await _settingsService.getUseBiometrics();
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

  /// 생체 인증 사용 여부 불러오기 (초기화 시)
  Future<void> _loadBiometrics() async {
    _useBiometrics = await _settingsService.getUseBiometrics();
    notifyListeners();
  }

  /// 생체 인증 사용 토글 및 실제 인증 시도
  Future<void> toggleBiometrics(bool value) async {
    _biometricErrorMessage = null;
    if (value) {
      // 실제 생체 인증 시도
      final canCheck = await _localAuth.canCheckBiometrics;
      if (!canCheck) {
        _biometricErrorMessage = '이 기기에서는 생체 인증을 지원하지 않습니다.';
        notifyListeners();
        return;
      }
      final available = await _localAuth.getAvailableBiometrics();
      if (available.isEmpty) {
        _biometricErrorMessage = '생체 인증(지문/Face ID)이 등록되어 있지 않습니다.';
        notifyListeners();
        return;
      }
      final didAuth = await _localAuth.authenticate(
        localizedReason: '생체 인증을 사용하여 인증하세요',
        options: const AuthenticationOptions(biometricOnly: true),
      );
      if (!didAuth) {
        _biometricErrorMessage = '생체 인증에 실패했습니다.';
        notifyListeners();
        return;
      }
    }
    _useBiometrics = value;
    await _settingsService.setUseBiometrics(value);
    notifyListeners();
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

      debugPrint('SettingsViewModel: 새로고침 간격 변경됨 - $seconds초');

      // 다른 뷰모델에서 이 변경사항을 알 수 있도록 서비스에 알림
      // CryptoViewModel은 자체 SettingsService를 통해 이 변경을 감지할 수 있습니다
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

  // 로그인 정보 관련 public 메서드 (Hive 연동)
  String? getSavedEmail() => _settingsService.getSavedEmail();
  String? getSavedPassword() => _settingsService.getSavedPassword();
  Future<void> setSavedEmail(String email) =>
      _settingsService.setSavedEmail(email);
  Future<void> setSavedPassword(String password) =>
      _settingsService.setSavedPassword(password);
  Future<void> clearLoginInfo() => _settingsService.clearLoginInfo();
}
