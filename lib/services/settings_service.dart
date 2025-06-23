import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'dart:math';
import '../core/constants.dart';

// 설정 관리를 위한 서비스 클래스 (Hive 기반)
class SettingsService {
  // Hive Box 인스턴스
  late Box _box;

  // 싱글톤 인스턴스
  static final SettingsService _instance = SettingsService._internal();

  // 팩토리 생성자
  factory SettingsService() {
    return _instance;
  }

  // 내부 생성자
  SettingsService._internal();

  // Hive Box 키 상수
  static const String _keyThemeMode = 'theme_mode';
  static const String _keyRefreshInterval = 'refresh_interval';
  static const String _keyPushNotifications = 'push_notifications';
  static const String _keyBiometricAuth = 'biometric_auth';
  static const String _keyLanguage = 'language';
  static const String _keySavedEmail = 'saved_email';
  static const String _keySaveLoginInfo = 'save_login_info';
  static const String _keyPassword = 'saved_password'; // 참고: 실제 앱에서는 안전하게 저장 필요
  static const String _keyCoinOrder = 'coin_order'; // 코인 순서 저장 키

  // API 키 저장 상수
  static const String _keyUpbitAccessKey = 'upbit_access_key';
  static const String _keyUpbitSecretKey = 'upbit_secret_key';
  static const String _keyBinanceApiKey = 'binance_api_key';
  static const String _keyBinanceSecretKey = 'binance_secret_key';

  // 초기화 (앱 시작 시 1회만 호출)
  Future<void> initialize() async {
    _box = await Hive.openBox('settings');
    debugPrint('SettingsService(Hive): 초기화 완료');
  }

  // 테마 모드 저장
  Future<bool> setThemeMode(ThemeMode themeMode) async {
    await _box.put(_keyThemeMode, themeMode.toString());
    return true;
  }

  // 테마 모드 불러오기
  ThemeMode getThemeMode() {
    final themeModeStr = _box.get(_keyThemeMode);
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
    await _box.put(_keyRefreshInterval, seconds);
    return true;
  }

  // 새로고침 간격 불러오기
  int getRefreshInterval() {
    return _box.get(_keyRefreshInterval) ??
        TimeConstants.defaultRefreshIntervalSeconds;
  }

  // 푸시 알림 설정 저장
  Future<bool> setPushNotificationsEnabled(bool enabled) async {
    await _box.put(_keyPushNotifications, enabled);
    return true;
  }

  // 푸시 알림 설정 불러오기
  bool getPushNotificationsEnabled() {
    return _box.get(_keyPushNotifications) ?? true;
  }

  // 생체 인증 설정 저장
  Future<bool> setBiometricAuthEnabled(bool enabled) async {
    await _box.put(_keyBiometricAuth, enabled);
    return true;
  }

  // 생체 인증 설정 불러오기
  bool getBiometricAuthEnabled() {
    return _box.get(_keyBiometricAuth) ?? false;
  }

  // 언어 설정 저장
  Future<bool> setLanguage(String language) async {
    await _box.put(_keyLanguage, language);
    return true;
  }

  // 언어 설정 불러오기
  String getLanguage() {
    return _box.get(_keyLanguage) ?? '한국어';
  }

  // 로그인 정보 저장 설정
  Future<bool> setSaveLoginInfo(bool save) async {
    await _box.put(_keySaveLoginInfo, save);
    return true;
  }

  // 로그인 정보 저장 설정 불러오기
  bool getSaveLoginInfo() {
    return _box.get(_keySaveLoginInfo) ?? false;
  }

  // 이메일(아이디) 저장
  Future<bool> setSavedEmail(String email) async {
    await _box.put(_keySavedEmail, email);
    return true;
  }

  // 저장된 이메일(아이디) 불러오기
  String? getSavedEmail() {
    return _box.get(_keySavedEmail);
  }

  // 비밀번호 저장 (참고: 실제 앱에서는 더 안전한 방법 사용 필요)
  Future<bool> setSavedPassword(String password) async {
    await _box.put(_keyPassword, password);
    return true;
  }

  // 저장된 비밀번호 불러오기
  String? getSavedPassword() {
    return _box.get(_keyPassword);
  }

  // 저장된 로그인 정보 삭제
  Future<void> clearLoginInfo() async {
    await _box.delete(_keySavedEmail);
    await _box.delete(_keyPassword);
    await _box.delete(_keySaveLoginInfo);
  }

  // Upbit API 키 저장
  Future<bool> setUpbitApiKeys(String accessKey, String secretKey) async {
    debugPrint(
      'SettingsService: Upbit API 키 저장 시도 - Access 키 길이: ${accessKey.length}, Secret 키 길이: ${secretKey.length}',
    );
    await _box.put(_keyUpbitAccessKey, accessKey);
    await _box.put(_keyUpbitSecretKey, secretKey);
    return true;
  }

  // Upbit Access Key 가져오기
  String? getUpbitAccessKey() {
    final key = _box.get(_keyUpbitAccessKey);
    debugPrint(
      'SettingsService: Upbit Access Key 조회 - ${key != null ? "존재함 (${key.length}자)" : "없음"}',
    );
    if (key != null && key.isNotEmpty) {
      debugPrint(
        'SettingsService: Upbit Access Key 샘플 - ${key.substring(0, min(4, key.length))}...',
      );
    }
    return key;
  }

  // Upbit Secret Key 가져오기
  String? getUpbitSecretKey() {
    final key = _box.get(_keyUpbitSecretKey);
    debugPrint(
      'SettingsService: Upbit Secret Key 조회 - ${key != null ? "존재함 (${key.length}자)" : "없음"}',
    );
    if (key != null && key.isNotEmpty) {
      debugPrint(
        'SettingsService: Upbit Secret Key 샘플 - ${key.substring(0, min(4, key.length))}...',
      );
    }
    return key;
  }

  // Binance API 키 저장
  Future<bool> setBinanceApiKeys(String apiKey, String secretKey) async {
    debugPrint(
      'SettingsService: Binance API 키 저장 시도 - API 키 길이: ${apiKey.length}, Secret 키 길이: ${secretKey.length}',
    );
    await _box.put(_keyBinanceApiKey, apiKey);
    await _box.put(_keyBinanceSecretKey, secretKey);
    return true;
  }

  // Binance API Key 가져오기
  String? getBinanceApiKey() {
    final key = _box.get(_keyBinanceApiKey);
    debugPrint(
      'SettingsService: Binance API Key 조회 - ${key != null ? "존재함 (${key.length}자)" : "없음"}',
    );
    return key;
  }

  // Binance Secret Key 가져오기
  String? getBinanceSecretKey() {
    final key = _box.get(_keyBinanceSecretKey);
    debugPrint(
      'SettingsService: Binance Secret Key 조회 - ${key != null ? "존재함 (${key.length}자)" : "없음"}',
    );
    return key;
  }

  // API 키 초기화
  Future<void> clearApiKeys() async {
    debugPrint('SettingsService: 모든 API 키 초기화 시도');
    await _box.delete(_keyUpbitAccessKey);
    await _box.delete(_keyUpbitSecretKey);
    await _box.delete(_keyBinanceApiKey);
    await _box.delete(_keyBinanceSecretKey);
    debugPrint('SettingsService: 모든 API 키 초기화 완료');
  }

  // 코인 목록 순서 저장
  Future<bool> setCoinOrder(Map<String, int> orderMap) async {
    debugPrint('SettingsService: 코인 순서 저장 시도 - ${orderMap.length}개 항목');
    // Map<String, int>를 String으로 변환
    final List<String> encodedEntries = [];
    orderMap.forEach((symbol, order) {
      encodedEntries.add('$symbol:$order');
    });
    final orderString = encodedEntries.join(',');
    await _box.put(_keyCoinOrder, orderString);
    debugPrint('SettingsService: 코인 순서 저장 성공');
    return true;
  }

  // 코인 목록 순서 불러오기
  Map<String, int> getCoinOrder() {
    final orderString = _box.get(_keyCoinOrder);
    final Map<String, int> orderMap = {};
    if (orderString != null && orderString.isNotEmpty) {
      final entries = orderString.split(',');
      for (final entry in entries) {
        final parts = entry.split(':');
        if (parts.length == 2) {
          final symbol = parts[0];
          final order = int.tryParse(parts[1]);
          if (order != null) {
            orderMap[symbol] = order;
          }
        }
      }
      debugPrint('SettingsService: 코인 순서 불러오기 완료 - ${orderMap.length}개 항목');
    } else {
      debugPrint('SettingsService: 저장된 코인 순서 없음');
    }
    return orderMap;
  }

  // 특정 코인의 순서 삭제
  Future<bool> removeCoinOrder(String symbol) async {
    final orderMap = getCoinOrder();
    if (orderMap.containsKey(symbol)) {
      orderMap.remove(symbol);
      return setCoinOrder(orderMap);
    }
    return true;
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
    // 코인 순서도 초기화에서 제외
    final coinOrder = getCoinOrder();
    // 설정값 초기화
    await _box.clear();
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
    // 코인 순서 복원
    if (coinOrder.isNotEmpty) {
      await setCoinOrder(coinOrder);
    }
  }

  /// 생체 인증 사용 여부 저장
  Future<void> setUseBiometrics(bool value) async {
    await _box.put('useBiometrics', value);
  }

  /// 생체 인증 사용 여부 불러오기
  Future<bool> getUseBiometrics() async {
    return _box.get('useBiometrics', defaultValue: false);
  }

  /// 생체 인증 사용 여부 삭제
  Future<void> removeUseBiometrics() async {
    await _box.delete('useBiometrics');
  }

  /// 다크 모드 설정 가져오기
  Future<bool> getDarkMode() async {
    final box = Hive.box('settings');
    return box.get('dark_mode', defaultValue: false) as bool;
  }

  /// 다크 모드 설정 저장
  Future<void> setDarkMode(bool isDarkMode) async {
    final box = Hive.box('settings');
    await box.put('dark_mode', isDarkMode);
  }
}
