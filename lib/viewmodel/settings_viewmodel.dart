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

  // 설정값 로드
  Future<void> _loadSettings() async {
    _isLoading = true;
    notifyListeners();

    try {
      _themeMode = _settingsService.getThemeMode();
      _refreshInterval = _settingsService.getRefreshInterval();
      _pushNotificationsEnabled = _settingsService
          .getPushNotificationsEnabled();
      _useBiometricAuth = _settingsService.getBiometricAuthEnabled();
      _language = _settingsService.getLanguage();
    } catch (e) {
      debugPrint('설정 로드 실패: $e');
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
