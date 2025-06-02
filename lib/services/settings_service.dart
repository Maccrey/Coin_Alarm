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
  static const String _keySavedEmail = 'saved_email';
  static const String _keySaveLoginInfo = 'save_login_info';
  static const String _keyPassword = 'saved_password'; // 참고: 실제 앱에서는 안전하게 저장 필요

  // API 키 저장 상수
  static const String _keyUpbitAccessKey = 'upbit_access_key';
  static const String _keyUpbitSecretKey = 'upbit_secret_key';
  static const String _keyBinanceApiKey = 'binance_api_key';
  static const String _keyBinanceSecretKey = 'binance_secret_key';

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

  // 로그인 정보 저장 설정
  Future<bool> setSaveLoginInfo(bool save) async {
    return await _prefs.setBool(_keySaveLoginInfo, save);
  }

  // 로그인 정보 저장 설정 불러오기
  bool getSaveLoginInfo() {
    return _prefs.getBool(_keySaveLoginInfo) ?? false;
  }

  // 이메일(아이디) 저장
  Future<bool> setSavedEmail(String email) async {
    return await _prefs.setString(_keySavedEmail, email);
  }

  // 저장된 이메일(아이디) 불러오기
  String? getSavedEmail() {
    return _prefs.getString(_keySavedEmail);
  }

  // 비밀번호 저장 (참고: 실제 앱에서는 더 안전한 방법 사용 필요)
  Future<bool> setSavedPassword(String password) async {
    return await _prefs.setString(_keyPassword, password);
  }

  // 저장된 비밀번호 불러오기
  String? getSavedPassword() {
    return _prefs.getString(_keyPassword);
  }

  // 저장된 로그인 정보 삭제
  Future<void> clearLoginInfo() async {
    await _prefs.remove(_keySavedEmail);
    await _prefs.remove(_keyPassword);
    await _prefs.remove(_keySaveLoginInfo);
  }

  // Upbit API 키 저장
  Future<bool> setUpbitApiKeys(String accessKey, String secretKey) async {
    final accessKeySaved = await _prefs.setString(
      _keyUpbitAccessKey,
      accessKey,
    );
    final secretKeySaved = await _prefs.setString(
      _keyUpbitSecretKey,
      secretKey,
    );
    return accessKeySaved && secretKeySaved;
  }

  // Upbit Access Key 가져오기
  String? getUpbitAccessKey() {
    return _prefs.getString(_keyUpbitAccessKey);
  }

  // Upbit Secret Key 가져오기
  String? getUpbitSecretKey() {
    return _prefs.getString(_keyUpbitSecretKey);
  }

  // Binance API 키 저장
  Future<bool> setBinanceApiKeys(String apiKey, String secretKey) async {
    final apiKeySaved = await _prefs.setString(_keyBinanceApiKey, apiKey);
    final secretKeySaved = await _prefs.setString(
      _keyBinanceSecretKey,
      secretKey,
    );
    return apiKeySaved && secretKeySaved;
  }

  // Binance API Key 가져오기
  String? getBinanceApiKey() {
    return _prefs.getString(_keyBinanceApiKey);
  }

  // Binance Secret Key 가져오기
  String? getBinanceSecretKey() {
    return _prefs.getString(_keyBinanceSecretKey);
  }

  // API 키 초기화
  Future<void> clearApiKeys() async {
    await _prefs.remove(_keyUpbitAccessKey);
    await _prefs.remove(_keyUpbitSecretKey);
    await _prefs.remove(_keyBinanceApiKey);
    await _prefs.remove(_keyBinanceSecretKey);
  }

  // 모든 설정 기본값으로 초기화
  Future<void> resetToDefaults() async {
    // 로그인 정보 제외하고 설정 초기화 (로그인 상태 유지 위함)
    final savedEmail = getSavedEmail();
    final savedPassword = getSavedPassword();
    final saveLoginInfo = getSaveLoginInfo();

    // API 키 정보 임시 저장
    final upbitAccessKey = getUpbitAccessKey();
    final upbitSecretKey = getUpbitSecretKey();
    final binanceApiKey = getBinanceApiKey();
    final binanceSecretKey = getBinanceSecretKey();

    // 설정값 초기화
    await _prefs.clear();

    // 로그인 정보 복원 (필요시)
    if (saveLoginInfo && savedEmail != null && savedPassword != null) {
      await setSaveLoginInfo(true);
      await setSavedEmail(savedEmail);
      await setSavedPassword(savedPassword);
    }

    // API 키 정보 복원 (필요시)
    if (upbitAccessKey != null && upbitSecretKey != null) {
      await setUpbitApiKeys(upbitAccessKey, upbitSecretKey);
    }

    if (binanceApiKey != null && binanceSecretKey != null) {
      await setBinanceApiKeys(binanceApiKey, binanceSecretKey);
    }
  }
}
