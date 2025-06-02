import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';

// 설정 관리를 위한 서비스 클래스
class SettingsService {
  // SharedPreferences 인스턴스
  late SharedPreferences _prefs;

  // 싱글톤 인스턴스
  static final SettingsService _instance = SettingsService._internal();

  // 팩토리 생성자
  factory SettingsService() {
    return _instance;
  }

  // 내부 생성자
  SettingsService._internal();

  // SharedPreferences 키 상수
  static const String _keyThemeMode = 'theme_mode';
  static const String _keyRefreshInterval = 'refresh_interval';
  static const String _keyPushNotifications = 'push_notifications';
  static const String _keyBiometricAuth = 'biometric_auth';
  static const String _keyLanguage = 'language';

  // 초기화
  Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      debugPrint('SettingsService: 초기화 완료');
    } catch (e) {
      debugPrint('SettingsService: 초기화 실패 - $e');
      rethrow;
    }
  }

  // 테마 모드 저장
  Future<bool> setThemeMode(ThemeMode themeMode) async {
    return await _prefs.setString(_keyThemeMode, themeMode.toString());
  }

  // 테마 모드 불러오기
  ThemeMode getThemeMode() {
    final themeModeStr = _prefs.getString(_keyThemeMode);

    if (themeModeStr == 'ThemeMode.light') {
      return ThemeMode.light;
    } else if (themeModeStr == 'ThemeMode.dark') {
      return ThemeMode.dark;
    } else {
      return ThemeMode.system;
    }
  }

  // 새로고침 간격 저장
  Future<bool> setRefreshInterval(int seconds) async {
    return await _prefs.setInt(_keyRefreshInterval, seconds);
  }

  // 새로고침 간격 불러오기
  int getRefreshInterval() {
    return _prefs.getInt(_keyRefreshInterval) ??
        TimeConstants.defaultRefreshIntervalSeconds;
  }

  // 푸시 알림 설정 저장
  Future<bool> setPushNotificationsEnabled(bool enabled) async {
    return await _prefs.setBool(_keyPushNotifications, enabled);
  }

  // 푸시 알림 설정 불러오기
  bool getPushNotificationsEnabled() {
    return _prefs.getBool(_keyPushNotifications) ?? true;
  }

  // 생체 인증 설정 저장
  Future<bool> setBiometricAuthEnabled(bool enabled) async {
    return await _prefs.setBool(_keyBiometricAuth, enabled);
  }

  // 생체 인증 설정 불러오기
  bool getBiometricAuthEnabled() {
    return _prefs.getBool(_keyBiometricAuth) ?? false;
  }

  // 언어 설정 저장
  Future<bool> setLanguage(String language) async {
    return await _prefs.setString(_keyLanguage, language);
  }

  // 언어 설정 불러오기
  String getLanguage() {
    return _prefs.getString(_keyLanguage) ?? '한국어';
  }

  // 모든 설정 기본값으로 초기화
  Future<void> resetToDefaults() async {
    await _prefs.remove(_keyThemeMode);
    await _prefs.remove(_keyRefreshInterval);
    await _prefs.remove(_keyPushNotifications);
    await _prefs.remove(_keyBiometricAuth);
    await _prefs.remove(_keyLanguage);
  }
}
