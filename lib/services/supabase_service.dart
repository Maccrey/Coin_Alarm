import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../data/dummy_supabase.dart';
import '../model/user_model.dart' as app_user;
import '../model/coin_model.dart';
import '../model/price_alert_model.dart';
import '../model/news_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../model/chart_data_model.dart';
import '../services/settings_service.dart';

/// Supabase 서비스 클래스
class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  late final dynamic _client; // 실제 Supabase 클라이언트 또는 더미 클라이언트
  bool _initialized = false;
  bool _useRealSupabase = false; // 실제 Supabase 사용 여부

  // 싱글톤 패턴
  factory SupabaseService() {
    return _instance;
  }

  SupabaseService._internal();

  /// Supabase 초기화
  Future<void> initialize({bool useRealSupabase = false}) async {
    if (_initialized) return;
    _useRealSupabase = useRealSupabase;

    try {
      if (_useRealSupabase) {
        // 실제 Supabase 초기화
        final settingsService = SettingsService();
        String? url;
        String? anonKey;

        // 설정에서 저장된 API 키 확인
        final savedUrl = settingsService
            .getUpbitAccessKey(); // 임시로 Upbit API 키 필드 사용
        final savedAnonKey = settingsService
            .getUpbitSecretKey(); // 임시로 Upbit Secret 키 필드 사용

        if (savedUrl != null &&
            savedUrl.isNotEmpty &&
            savedAnonKey != null &&
            savedAnonKey.isNotEmpty) {
          url = savedUrl;
          anonKey = savedAnonKey;
          debugPrint('SupabaseService: 저장된 API 키 사용');
        } else {
          // 저장된 키가 없으면 .env 파일에서 환경 변수 로드
          url = dotenv.env['SUPABASE_URL'];
          anonKey = dotenv.env['SUPABASE_ANON_KEY'];
          debugPrint('SupabaseService: .env 파일의 API 키 사용');
        }

        if (url == null || anonKey == null) {
          throw Exception('SUPABASE_URL 또는 SUPABASE_ANON_KEY가 설정되지 않았습니다.');
        }

        await supabase.Supabase.initialize(url: url, anonKey: anonKey);

        _client = supabase.Supabase.instance.client;

        // API 키가 .env에서 로드된 경우 설정 서비스에 저장
        if (savedUrl == null ||
            savedUrl.isEmpty ||
            savedAnonKey == null ||
            savedAnonKey.isEmpty) {
          await settingsService.setUpbitApiKeys(url, anonKey);
          debugPrint('SupabaseService: API 키를 설정 서비스에 저장');
        }
      } else {
        // 더미 Supabase 클라이언트 사용
        _client = DummySupabaseClient();
      }

      _initialized = true;
    } catch (e) {
      throw Exception('Supabase 초기화 실패: $e');
    }
  }

  /// 로그인
  Future<app_user.User> login(String email, String password) async {
    if (!_initialized) {
      throw Exception('Supabase가 초기화되지 않았습니다.');
    }

    if (_useRealSupabase) {
      try {
        final response = await _client.auth.signInWithPassword(
          email: email,
          password: password,
        );

        final userData = response.user;
        if (userData == null) {
          throw Exception('로그인 실패: 사용자 정보를 가져올 수 없습니다.');
        }

        return app_user.User(
          id: userData.id,
          email: userData.email ?? '',
          name: userData.userMetadata?['name'] ?? '',
          createdAt: DateTime.parse(userData.createdAt),
        );
      } catch (e) {
        throw Exception('로그인 실패: $e');
      }
    } else {
      // 더미 로그인 처리
      return await (_client as DummySupabaseClient).login(email, password);
    }
  }

  /// 로그아웃
  Future<void> logout() async {
    if (!_initialized) {
      throw Exception('Supabase가 초기화되지 않았습니다.');
    }

    if (_useRealSupabase) {
      try {
        await _client.auth.signOut();
      } catch (e) {
        throw Exception('로그아웃 실패: $e');
      }
    } else {
      // 더미 로그아웃 처리
      await (_client as DummySupabaseClient).logout();
    }
  }

  /// 현재 로그인된 사용자 정보 가져오기
  Future<app_user.User?> getCurrentUser() async {
    if (!_initialized) {
      throw Exception('Supabase가 초기화되지 않았습니다.');
    }

    if (_useRealSupabase) {
      try {
        final userData = _client.auth.currentUser;
        if (userData == null) {
          return null;
        }

        return app_user.User(
          id: userData.id,
          email: userData.email ?? '',
          name: userData.userMetadata?['name'] ?? '',
          createdAt: DateTime.parse(userData.createdAt),
        );
      } catch (e) {
        debugPrint('현재 사용자 정보 가져오기 실패: $e');
        return null;
      }
    } else {
      // 더미 사용자 정보 가져오기
      return await (_client as DummySupabaseClient).getCurrentUser();
    }
  }

  /// 회원가입
  Future<app_user.User> register(
    String email,
    String password,
    String name,
  ) async {
    if (!_initialized) {
      throw Exception('Supabase가 초기화되지 않았습니다.');
    }

    if (_useRealSupabase) {
      try {
        final response = await _client.auth.signUp(
          email: email,
          password: password,
          data: {'name': name},
        );

        final userData = response.user;
        if (userData == null) {
          throw Exception('회원가입 실패: 사용자 정보를 가져올 수 없습니다.');
        }

        return app_user.User(
          id: userData.id,
          email: userData.email ?? '',
          name: name,
          createdAt: DateTime.parse(userData.createdAt),
        );
      } catch (e) {
        throw Exception('회원가입 실패: $e');
      }
    } else {
      // 더미 회원가입 처리
      return await (_client as DummySupabaseClient).register(
        email,
        password,
        name,
      );
    }
  }

  /// 차트 데이터 저장
  Future<void> saveChartData({
    required String symbol,
    required String exchange,
    required ChartTimeframe timeframe,
    required ChartType chartType,
    required List<dynamic> data,
    required DateTime timestamp,
  }) async {
    if (!_initialized) {
      throw Exception('Supabase가 초기화되지 않았습니다.');
    }

    if (_useRealSupabase) {
      try {
        await _client.from('chart_data').insert({
          'symbol': symbol,
          'exchange': exchange,
          'timeframe': timeframe.toString().split('.').last,
          'chart_type': chartType.toString().split('.').last,
          'data': data,
          'timestamp': timestamp.toIso8601String(),
        });
      } catch (e) {
        throw Exception('차트 데이터 저장 실패: $e');
      }
    } else {
      // 더미 차트 데이터 저장
      await (_client as DummySupabaseClient).saveChartData(
        symbol: symbol,
        exchange: exchange,
        timeframe: timeframe,
        chartType: chartType,
        data: data,
        timestamp: timestamp,
      );
    }
  }

  /// 차트 데이터 조회
  Future<Map<String, dynamic>?> getChartData({
    required String symbol,
    required String exchange,
    required ChartTimeframe timeframe,
    required ChartType chartType,
  }) async {
    if (!_initialized) {
      throw Exception('Supabase가 초기화되지 않았습니다.');
    }

    if (_useRealSupabase) {
      try {
        final response = await _client
            .from('chart_data')
            .select()
            .eq('symbol', symbol)
            .eq('exchange', exchange)
            .eq('timeframe', timeframe.toString().split('.').last)
            .eq('chart_type', chartType.toString().split('.').last)
            .order('timestamp', ascending: false)
            .limit(1)
            .maybeSingle();

        return response;
      } catch (e) {
        throw Exception('차트 데이터 조회 실패: $e');
      }
    } else {
      // 더미 차트 데이터 조회
      return await (_client as DummySupabaseClient).getChartData(
        symbol: symbol,
        exchange: exchange,
        timeframe: timeframe,
        chartType: chartType,
      );
    }
  }

  /// 사용자 설정 저장
  Future<void> saveUserSettings({
    required String userId,
    required Map<String, dynamic> settings,
  }) async {
    if (!_initialized) {
      throw Exception('Supabase가 초기화되지 않았습니다.');
    }

    if (_useRealSupabase) {
      try {
        // upsert 사용 (없으면 생성, 있으면 업데이트)
        await _client.from('user_settings').upsert({
          'user_id': userId,
          'settings': settings,
          'updated_at': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        throw Exception('사용자 설정 저장 실패: $e');
      }
    } else {
      // 더미 사용자 설정 저장
      await (_client as DummySupabaseClient).saveUserSettings(
        userId: userId,
        settings: settings,
      );
    }
  }

  /// 사용자 설정 조회
  Future<Map<String, dynamic>?> getUserSettings({
    required String userId,
  }) async {
    if (!_initialized) {
      throw Exception('Supabase가 초기화되지 않았습니다.');
    }

    if (_useRealSupabase) {
      try {
        final response = await _client
            .from('user_settings')
            .select('settings')
            .eq('user_id', userId)
            .maybeSingle();

        return response?['settings'];
      } catch (e) {
        throw Exception('사용자 설정 조회 실패: $e');
      }
    } else {
      // 더미 사용자 설정 조회
      return await (_client as DummySupabaseClient).getUserSettings(
        userId: userId,
      );
    }
  }

  /// 알림 설정 저장
  Future<void> saveAlertSetting({
    required String userId,
    required String symbol,
    required double targetPrice,
    required bool isAbove,
    required bool isActive,
  }) async {
    if (!_initialized) {
      throw Exception('Supabase가 초기화되지 않았습니다.');
    }

    if (_useRealSupabase) {
      try {
        await _client.from('price_alerts').insert({
          'user_id': userId,
          'symbol': symbol,
          'target_price': targetPrice,
          'is_above': isAbove,
          'is_active': isActive,
          'created_at': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        throw Exception('알림 설정 저장 실패: $e');
      }
    } else {
      // 더미 알림 설정 저장
      await (_client as DummySupabaseClient).saveAlertSetting(
        userId: userId,
        symbol: symbol,
        targetPrice: targetPrice,
        isAbove: isAbove,
        isActive: isActive,
      );
    }
  }

  /// 알림 설정 조회
  Future<List<Map<String, dynamic>>> getAlertSettings({
    required String userId,
  }) async {
    if (!_initialized) {
      throw Exception('Supabase가 초기화되지 않았습니다.');
    }

    if (_useRealSupabase) {
      try {
        final response = await _client
            .from('price_alerts')
            .select()
            .eq('user_id', userId)
            .order('created_at', ascending: false);

        return List<Map<String, dynamic>>.from(response);
      } catch (e) {
        throw Exception('알림 설정 조회 실패: $e');
      }
    } else {
      // 더미 알림 설정 조회
      return await (_client as DummySupabaseClient).getAlertSettings(
        userId: userId,
      );
    }
  }

  /// 알림 설정 업데이트
  Future<void> updateAlertSetting({
    required int alertId,
    required bool isActive,
  }) async {
    if (!_initialized) {
      throw Exception('Supabase가 초기화되지 않았습니다.');
    }

    if (_useRealSupabase) {
      try {
        await _client
            .from('price_alerts')
            .update({
              'is_active': isActive,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', alertId);
      } catch (e) {
        throw Exception('알림 설정 업데이트 실패: $e');
      }
    } else {
      // 더미 알림 설정 업데이트
      await (_client as DummySupabaseClient).updateAlertSetting(
        alertId: alertId,
        isActive: isActive,
      );
    }
  }

  /// 알림 설정 삭제
  Future<void> deleteAlertSetting({required int alertId}) async {
    if (!_initialized) {
      throw Exception('Supabase가 초기화되지 않았습니다.');
    }

    if (_useRealSupabase) {
      try {
        await _client.from('price_alerts').delete().eq('id', alertId);
      } catch (e) {
        throw Exception('알림 설정 삭제 실패: $e');
      }
    } else {
      // 더미 알림 설정 삭제
      await (_client as DummySupabaseClient).deleteAlertSetting(
        alertId: alertId,
      );
    }
  }

  /// 비밀번호 재설정 이메일 전송
  ///
  /// 사용자가 입력한 이메일로 비밀번호 재설정 링크를 전송합니다.
  /// Supabase의 resetPasswordForEmail API를 사용하거나, 더미 모드에서는 가상의 처리를 수행합니다.
  ///
  /// [email] 비밀번호를 재설정할 사용자의 이메일 주소
  Future<void> resetPassword(String email) async {
    if (!_initialized) {
      throw Exception('Supabase가 초기화되지 않았습니다.');
    }

    if (_useRealSupabase) {
      try {
        await _client.auth.resetPasswordForEmail(email);
        debugPrint('비밀번호 재설정 이메일 전송 완료: $email');
      } catch (e) {
        throw Exception('비밀번호 재설정 이메일 전송 실패: $e');
      }
    } else {
      // 더미 비밀번호 재설정 처리
      await Future.delayed(const Duration(seconds: 1));
      debugPrint('더미 비밀번호 재설정 이메일 전송 완료: $email');
    }
  }
}

/// 더미 Supabase 클라이언트 클래스
class DummySupabaseClient {
  final Map<String, app_user.User> _users = {};
  final Map<String, Map<String, dynamic>> _userSettings = {};
  final List<Map<String, dynamic>> _priceAlerts = [];
  final List<Map<String, dynamic>> _chartData = [];
  app_user.User? _currentUser;

  DummySupabaseClient() {
    // 기본 사용자 추가
    _users['user@example.com'] = app_user.User(
      id: '1',
      email: 'user@example.com',
      name: '테스트 사용자',
      createdAt: DateTime.now(),
    );
  }

  /// 더미 로그인
  Future<app_user.User> login(String email, String password) async {
    await Future.delayed(const Duration(seconds: 1)); // 네트워크 지연 시뮬레이션

    if (_users.containsKey(email)) {
      _currentUser = _users[email];
      return _currentUser!;
    }

    throw Exception('로그인 실패: 사용자를 찾을 수 없습니다.');
  }

  /// 더미 로그아웃
  Future<void> logout() async {
    await Future.delayed(const Duration(seconds: 1)); // 네트워크 지연 시뮬레이션
    _currentUser = null;
  }

  /// 더미 회원가입
  Future<app_user.User> register(
    String email,
    String password,
    String name,
  ) async {
    await Future.delayed(const Duration(seconds: 1)); // 네트워크 지연 시뮬레이션

    if (_users.containsKey(email)) {
      throw Exception('회원가입 실패: 이미 존재하는 이메일입니다.');
    }

    final user = app_user.User(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      email: email,
      name: name,
      createdAt: DateTime.now(),
    );

    _users[email] = user;
    _currentUser = user;

    return user;
  }

  /// 더미 차트 데이터 저장
  Future<void> saveChartData({
    required String symbol,
    required String exchange,
    required ChartTimeframe timeframe,
    required ChartType chartType,
    required List<dynamic> data,
    required DateTime timestamp,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500)); // 네트워크 지연 시뮬레이션

    _chartData.add({
      'id': DateTime.now().millisecondsSinceEpoch,
      'symbol': symbol,
      'exchange': exchange,
      'timeframe': timeframe.toString().split('.').last,
      'chart_type': chartType.toString().split('.').last,
      'data': data,
      'timestamp': timestamp.toIso8601String(),
    });
  }

  /// 더미 차트 데이터 조회
  Future<Map<String, dynamic>?> getChartData({
    required String symbol,
    required String exchange,
    required ChartTimeframe timeframe,
    required ChartType chartType,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500)); // 네트워크 지연 시뮬레이션

    final filteredData = _chartData
        .where(
          (data) =>
              data['symbol'] == symbol &&
              data['exchange'] == exchange &&
              data['timeframe'] == timeframe.toString().split('.').last &&
              data['chart_type'] == chartType.toString().split('.').last,
        )
        .toList();

    if (filteredData.isEmpty) {
      return null;
    }

    // 가장 최신 데이터 반환
    filteredData.sort(
      (a, b) => DateTime.parse(
        b['timestamp'],
      ).compareTo(DateTime.parse(a['timestamp'])),
    );
    return filteredData.first;
  }

  /// 더미 사용자 설정 저장
  Future<void> saveUserSettings({
    required String userId,
    required Map<String, dynamic> settings,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500)); // 네트워크 지연 시뮬레이션
    _userSettings[userId] = settings;
  }

  /// 더미 사용자 설정 조회
  Future<Map<String, dynamic>?> getUserSettings({
    required String userId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500)); // 네트워크 지연 시뮬레이션
    return _userSettings[userId];
  }

  /// 더미 알림 설정 저장
  Future<void> saveAlertSetting({
    required String userId,
    required String symbol,
    required double targetPrice,
    required bool isAbove,
    required bool isActive,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500)); // 네트워크 지연 시뮬레이션

    _priceAlerts.add({
      'id': DateTime.now().millisecondsSinceEpoch,
      'user_id': userId,
      'symbol': symbol,
      'target_price': targetPrice,
      'is_above': isAbove,
      'is_active': isActive,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// 더미 알림 설정 조회
  Future<List<Map<String, dynamic>>> getAlertSettings({
    required String userId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500)); // 네트워크 지연 시뮬레이션

    return _priceAlerts.where((alert) => alert['user_id'] == userId).toList()
      ..sort(
        (a, b) => DateTime.parse(
          b['created_at'],
        ).compareTo(DateTime.parse(a['created_at'])),
      );
  }

  /// 더미 알림 설정 업데이트
  Future<void> updateAlertSetting({
    required int alertId,
    required bool isActive,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500)); // 네트워크 지연 시뮬레이션

    final index = _priceAlerts.indexWhere((alert) => alert['id'] == alertId);
    if (index != -1) {
      _priceAlerts[index]['is_active'] = isActive;
      _priceAlerts[index]['updated_at'] = DateTime.now().toIso8601String();
    }
  }

  /// 더미 알림 설정 삭제
  Future<void> deleteAlertSetting({required int alertId}) async {
    await Future.delayed(const Duration(milliseconds: 500)); // 네트워크 지연 시뮬레이션
    _priceAlerts.removeWhere((alert) => alert['id'] == alertId);
  }

  /// 더미 현재 로그인된 사용자 정보 가져오기
  Future<app_user.User?> getCurrentUser() async {
    await Future.delayed(const Duration(milliseconds: 500)); // 네트워크 지연 시뮬레이션
    return _currentUser;
  }
}
