import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../data/dummy_supabase.dart';
import '../data/dummy_news.dart';
import '../model/user_model.dart' as app_user;
import '../model/coin_model.dart';
import '../model/price_alert_model.dart';
import '../model/news_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../model/chart_data_model.dart';
import 'package:hive/hive.dart';

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
        final url = dotenv.env['SUPABASE_URL'];
        final anonKey = dotenv.env['SUPABASE_ANON_KEY'];

        if (url == null || anonKey == null) {
          throw Exception(
            'SUPABASE_URL 또는 SUPABASE_ANON_KEY가 .env 파일에 설정되지 않았습니다.',
          );
        }

        // main.dart에서 이미 초기화된 클라이언트만 가져옴 (중복 초기화 방지)
        try {
          _client = supabase.Supabase.instance.client;
          debugPrint('SupabaseClientService: 초기화 완료');
        } catch (e) {
          throw Exception('Supabase 클라이언트 접근 실패: $e');
        }
      } else {
        // 더미 클라이언트
        _client = DummySupabaseClient();
        debugPrint('SupabaseService: 더미 Supabase 클라이언트 사용');
      }

      _initialized = true;
    } catch (e) {
      debugPrint('실제 Supabase 연동 실패: $e');
      // 실패 시 더미로 전환
      _client = DummySupabaseClient();
      _useRealSupabase = false;
      _initialized = true;
      debugPrint('SupabaseService: 더미 Supabase 클라이언트 사용');
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
        debugPrint('비밀번호 재설정 시도: $email (실제 Supabase 사용)');
        debugPrint(
          'Supabase URL: ${dotenv.env['SUPABASE_URL']?.substring(0, 10)}...',
        );
        await _client.auth.resetPasswordForEmail(email);
        debugPrint('비밀번호 재설정 이메일 전송 완료: $email');
      } catch (e) {
        debugPrint('비밀번호 재설정 이메일 전송 실패 상세 오류: $e');
        throw Exception('비밀번호 재설정 이메일 전송 실패: $e');
      }
    } else {
      // 더미 비밀번호 재설정 처리
      await Future.delayed(const Duration(seconds: 1));
      debugPrint('더미 비밀번호 재설정 이메일 전송 완료: $email');
    }
  }

  /// 뉴스 데이터 조회
  Future<List<News>> getNews({int limit = 20, int offset = 0}) async {
    if (!_initialized) {
      throw Exception('Supabase가 초기화되지 않았습니다.');
    }

    if (_useRealSupabase) {
      try {
        final response = await _client
            .from('news')
            .select()
            .order('published_at', ascending: false)
            .range(offset, offset + limit - 1);

        return List<News>.from(response.map((json) => News.fromJson(json)));
      } catch (e) {
        debugPrint('뉴스 데이터 조회 실패: $e');
        throw Exception('뉴스 데이터 조회 실패: $e');
      }
    } else {
      // 더미 뉴스 데이터 조회
      return DummyNews.getLatestNews(limit: limit);
    }
  }

  /// 특정 코인 관련 뉴스 조회
  Future<List<News>> getNewsByCoin({
    required String coinId,
    int limit = 10,
    int offset = 0,
  }) async {
    if (!_initialized) {
      throw Exception('Supabase가 초기화되지 않았습니다.');
    }

    if (_useRealSupabase) {
      try {
        final response = await _client
            .from('news')
            .select()
            .contains('related_coins', [coinId.toLowerCase()])
            .order('published_at', ascending: false)
            .range(offset, offset + limit - 1);

        return List<News>.from(response.map((json) => News.fromJson(json)));
      } catch (e) {
        debugPrint('코인 관련 뉴스 조회 실패: $e');
        throw Exception('코인 관련 뉴스 조회 실패: $e');
      }
    } else {
      // 더미 코인 관련 뉴스 조회
      return DummyNews.getNewsByCoin(coinId, limit: limit);
    }
  }

  /// 인기 뉴스 조회
  Future<List<News>> getPopularNews({int limit = 10}) async {
    if (!_initialized) {
      throw Exception('Supabase가 초기화되지 않았습니다.');
    }

    if (_useRealSupabase) {
      try {
        final response = await _client
            .from('news')
            .select()
            .gt('view_count', 0) // 조회수가 0보다 큰 뉴스만 가져옴
            .order('view_count', ascending: false) // 조회수 기준 내림차순 정렬
            .limit(limit);

        return List<News>.from(response.map((json) => News.fromJson(json)));
      } catch (e) {
        debugPrint('인기 뉴스 조회 실패: $e');
        throw Exception('인기 뉴스 조회 실패: $e');
      }
    } else {
      // 더미 인기 뉴스 조회
      return DummyNews.getPopularNews(limit: limit);
    }
  }

  /// 뉴스 검색
  Future<List<News>> searchNews({required String query, int limit = 20}) async {
    if (!_initialized) {
      throw Exception('Supabase가 초기화되지 않았습니다.');
    }

    if (_useRealSupabase) {
      try {
        // PostgreSQL의 ilike를 사용한 검색 (대소문자 무관)
        final response = await _client
            .from('news')
            .select()
            .or('title.ilike.%$query%,content.ilike.%$query%')
            .order('published_at', ascending: false)
            .limit(limit);

        return List<News>.from(response.map((json) => News.fromJson(json)));
      } catch (e) {
        debugPrint('뉴스 검색 실패: $e');
        throw Exception('뉴스 검색 실패: $e');
      }
    } else {
      // 더미 뉴스 검색
      final allNews = DummyNews.newsList;
      final queryLower = query.toLowerCase();
      return allNews
          .where(
            (news) =>
                news.title.toLowerCase().contains(queryLower) ||
                news.content.toLowerCase().contains(queryLower),
          )
          .take(limit)
          .toList();
    }
  }

  /// 뉴스 데이터 캐싱 (로컬 저장)
  Future<void> cacheNewsData(List<News> newsList) async {
    if (!_initialized) {
      throw Exception('Supabase가 초기화되지 않았습니다.');
    }

    try {
      // 뉴스 데이터 JSON 변환
      final newsJsonList = newsList.map((news) => news.toJson()).toList();

      // 로컬 저장소에 저장 (Hive 또는 shared_preferences 등 사용)
      // 여기서는 Hive를 사용한다고 가정
      final box = await Hive.openBox('news_cache');
      await box.put('cached_news', newsJsonList);
      await box.put('cache_timestamp', DateTime.now().toIso8601String());

      debugPrint('뉴스 데이터 캐싱 완료: ${newsList.length}개');
    } catch (e) {
      debugPrint('뉴스 데이터 캐싱 실패: $e');
    }
  }

  /// 캐시된 뉴스 데이터 로드
  Future<List<News>> getCachedNews() async {
    if (!_initialized) {
      throw Exception('Supabase가 초기화되지 않았습니다.');
    }

    try {
      final box = await Hive.openBox('news_cache');
      final cachedData = box.get('cached_news');
      final cacheTimestamp = box.get('cache_timestamp');

      if (cachedData == null) {
        return [];
      }

      // 캐시 타임스탬프 체크 (24시간 이상 지난 캐시는 만료)
      if (cacheTimestamp != null) {
        final cacheTime = DateTime.parse(cacheTimestamp);
        final now = DateTime.now();
        if (now.difference(cacheTime).inHours > 24) {
          debugPrint('뉴스 캐시 만료됨 (24시간 초과)');
          return [];
        }
      }

      final List<dynamic> newsJsonList = cachedData;
      return newsJsonList.map((json) => News.fromJson(json)).toList();
    } catch (e) {
      debugPrint('캐시된 뉴스 데이터 로드 실패: $e');
      return [];
    }
  }

  /// 뉴스 캐시 삭제
  Future<void> clearNewsCache() async {
    try {
      final box = await Hive.openBox('news_cache');
      await box.clear();
      debugPrint('뉴스 캐시 삭제 완료');
    } catch (e) {
      debugPrint('뉴스 캐시 삭제 실패: $e');
    }
  }

  /// 뉴스 조회수 증가
  Future<void> incrementNewsViewCount(String newsId) async {
    if (!_initialized) {
      throw Exception('Supabase가 초기화되지 않았습니다.');
    }

    if (_useRealSupabase) {
      try {
        // 현재 조회수 가져오기
        final response = await _client
            .from('news')
            .select('view_count')
            .eq('id', newsId)
            .single();

        int currentViewCount = response['view_count'] ?? 0;

        // 조회수 증가 및 업데이트
        await _client
            .from('news')
            .update({'view_count': currentViewCount + 1})
            .eq('id', newsId);

        debugPrint('뉴스 조회수 증가: $newsId, 새 조회수: ${currentViewCount + 1}');
      } catch (e) {
        debugPrint('뉴스 조회수 증가 실패: $e');
      }
    } else {
      // 더미 모드에서는 DummyNews의 해당 뉴스 조회수만 로그로 출력
      final news = DummyNews.getNewsById(newsId);
      if (news != null) {
        debugPrint('더미 모드: 뉴스 조회수 증가 (ID: $newsId, 제목: ${news.title})');
      } else {
        debugPrint('더미 모드: 뉴스 조회수 증가 실패 (ID: $newsId, 뉴스를 찾을 수 없음)');
      }
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
