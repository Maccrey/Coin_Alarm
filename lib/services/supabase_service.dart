import 'package:flutter/foundation.dart';
import '../data/dummy_supabase.dart';
import '../model/user_model.dart';
import '../model/coin_model.dart';
import '../model/price_alert_model.dart';
import '../model/news_model.dart';

// Supabase 서비스 클래스 (더미데이터 기반)
class SupabaseService {
  // 싱글톤 패턴
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  // 더미 Supabase 인스턴스
  final DummySupabase _supabase = DummySupabase();

  // 더미 Supabase 클라이언트
  late final DummySupabaseClient _client;

  // 서비스 초기화 여부
  bool _initialized = false;

  // 초기화 메소드
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // 더미 Supabase 초기화
      await _supabase.initialize();
      _client = DummySupabaseClient();
      _initialized = true;

      debugPrint('SupabaseService: 초기화 완료 (더미 데이터 사용)');
    } catch (e) {
      debugPrint('SupabaseService: 초기화 실패 - $e');
      rethrow;
    }
  }

  // 초기화 체크
  void _checkInitialized() {
    if (!_initialized) {
      throw Exception(
        'SupabaseService가 초기화되지 않았습니다. initialize() 메소드를 먼저 호출하세요.',
      );
    }
  }

  // 현재 로그인된 사용자 가져오기
  User? getCurrentUser() {
    _checkInitialized();

    final dummyUser = _client.auth.currentUser;
    if (dummyUser == null) return null;

    return User.fromJson(dummyUser.toJson());
  }

  // 이메일/비밀번호로 로그인
  Future<User> signInWithEmailAndPassword(String email, String password) async {
    _checkInitialized();

    try {
      final dummyUser = await _client.auth.signInWithEmailAndPassword(
        email,
        password,
      );
      return User.fromJson(dummyUser.toJson());
    } catch (e) {
      debugPrint('SupabaseService: 로그인 실패 - $e');
      rethrow;
    }
  }

  // 회원가입
  Future<User> signUp(String email, String password, {String? name}) async {
    _checkInitialized();

    try {
      final dummyUser = await _client.auth.signUp(email, password, name: name);
      return User.fromJson(dummyUser.toJson());
    } catch (e) {
      debugPrint('SupabaseService: 회원가입 실패 - $e');
      rethrow;
    }
  }

  // 로그아웃
  Future<void> signOut() async {
    _checkInitialized();

    try {
      await _client.auth.signOut();
      debugPrint('SupabaseService: 로그아웃 성공');
    } catch (e) {
      debugPrint('SupabaseService: 로그아웃 실패 - $e');
      rethrow;
    }
  }

  // 비밀번호 재설정 이메일 전송
  Future<void> resetPassword(String email) async {
    _checkInitialized();

    try {
      await _client.auth.resetPassword(email);
      debugPrint('SupabaseService: 비밀번호 재설정 이메일 전송 성공');
    } catch (e) {
      debugPrint('SupabaseService: 비밀번호 재설정 이메일 전송 실패 - $e');
      rethrow;
    }
  }

  // 코인 목록 가져오기
  Future<List<Coin>> getCoins({int limit = 20}) async {
    _checkInitialized();

    try {
      final data = await _client.from.table('coins').limit(limit).select();
      return data.map((json) => Coin.fromJson(json)).toList();
    } catch (e) {
      debugPrint('SupabaseService: 코인 목록 가져오기 실패 - $e');
      rethrow;
    }
  }

  // 코인 상세 정보 가져오기
  Future<Coin?> getCoinById(String coinId) async {
    _checkInitialized();

    try {
      final data = await _client.from
          .table('coins')
          .eq('id', coinId)
          .selectOne();
      if (data == null) return null;
      return Coin.fromJson(data);
    } catch (e) {
      debugPrint('SupabaseService: 코인 상세정보 가져오기 실패 - $e');
      rethrow;
    }
  }

  // 가격 알림 생성
  Future<PriceAlert> createPriceAlert(PriceAlert alert) async {
    _checkInitialized();

    try {
      final data = await _client.from
          .table('price_alerts')
          .insert(alert.toJson());
      return PriceAlert.fromJson(data);
    } catch (e) {
      debugPrint('SupabaseService: 가격 알림 생성 실패 - $e');
      rethrow;
    }
  }

  // 사용자의 가격 알림 목록 가져오기
  Future<List<PriceAlert>> getUserPriceAlerts(String userId) async {
    _checkInitialized();

    try {
      final data = await _client.from
          .table('price_alerts')
          .eq('user_id', userId)
          .select();
      return data.map((json) => PriceAlert.fromJson(json)).toList();
    } catch (e) {
      debugPrint('SupabaseService: 사용자 가격 알림 목록 가져오기 실패 - $e');
      rethrow;
    }
  }

  // 가격 알림 삭제
  Future<void> deletePriceAlert(String alertId) async {
    _checkInitialized();

    try {
      await _client.from.table('price_alerts').eq('id', alertId).delete();
      debugPrint('SupabaseService: 가격 알림 삭제 성공');
    } catch (e) {
      debugPrint('SupabaseService: 가격 알림 삭제 실패 - $e');
      rethrow;
    }
  }

  // 뉴스 목록 가져오기
  Future<List<News>> getNews({int limit = 10}) async {
    _checkInitialized();

    try {
      final queryBuilder = _client.from
          .table('news')
          .order('published_at', ascending: false)
          .limit(limit);

      final data = await queryBuilder.select();
      return data.map((json) => News.fromJson(json)).toList();
    } catch (e) {
      debugPrint('SupabaseService: 뉴스 목록 가져오기 실패 - $e');
      rethrow;
    }
  }

  // 특정 코인 관련 뉴스 가져오기
  Future<List<News>> getNewsByCoinId(String coinId, {int limit = 5}) async {
    _checkInitialized();

    try {
      // 실제로는 관계형 쿼리가 필요하지만 더미데이터에서는 간단하게 처리
      final allNews = await getNews(limit: 20);
      return allNews
          .where((news) => news.relatedCoins.contains(coinId))
          .take(limit)
          .toList();
    } catch (e) {
      debugPrint('SupabaseService: 코인 관련 뉴스 가져오기 실패 - $e');
      rethrow;
    }
  }

  // 사용자 정보 업데이트
  Future<User> updateUser(String userId, Map<String, dynamic> data) async {
    _checkInitialized();

    try {
      // 먼저 업데이트 수행
      await _client.from.table('users').eq('id', userId).update(data);

      // 그 다음 업데이트된 데이터 조회
      final queryBuilder = _client.from.table('users').eq('id', userId);

      final updatedData = await queryBuilder.select();

      if (updatedData.isEmpty) {
        throw Exception('사용자 정보 업데이트 실패: 데이터가 없습니다.');
      }

      return User.fromJson(updatedData.first);
    } catch (e) {
      debugPrint('SupabaseService: 사용자 정보 업데이트 실패 - $e');
      rethrow;
    }
  }

  // 코인 즐겨찾기 추가/제거
  Future<User> toggleFavoriteCoin(String userId, String coinId) async {
    _checkInitialized();

    try {
      // 현재 사용자 정보 가져오기
      final userData = await _client.from
          .table('users')
          .eq('id', userId)
          .selectOne();

      if (userData == null) {
        throw Exception('사용자를 찾을 수 없습니다.');
      }

      // 현재 즐겨찾기 목록
      final user = User.fromJson(userData);
      List<String> favorites = List.from(user.favoriteCoins);

      // 토글 처리
      if (favorites.contains(coinId)) {
        favorites.remove(coinId);
      } else {
        favorites.add(coinId);
      }

      // 업데이트
      return await updateUser(userId, {'favorite_coins': favorites});
    } catch (e) {
      debugPrint('SupabaseService: 즐겨찾기 토글 실패 - $e');
      rethrow;
    }
  }
}
