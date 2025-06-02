import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/supabase_service.dart';
import '../model/coin_model.dart';
import '../core/constants.dart';

// 코인 데이터 관련 ViewModel 클래스
class CoinViewModel extends ChangeNotifier {
  final SupabaseService _supabaseService;

  // 상태 관리
  bool _isLoading = false;
  List<Coin> _coins = [];
  List<String> _favoriteCoins = DefaultSettings.defaultFavoriteCoins;
  Coin? _selectedCoin;
  String? _errorMessage;

  // 자동 갱신 타이머
  Timer? _refreshTimer;

  // 생성자
  CoinViewModel(this._supabaseService) {
    // 초기 코인 데이터 로드
    refreshCoins();

    // 자동 갱신 타이머 설정
    _setupAutoRefresh();
  }

  // Getters
  bool get isLoading => _isLoading;
  List<Coin> get coins => _coins;
  List<Coin> get favoriteCoins =>
      _coins.where((coin) => _favoriteCoins.contains(coin.symbol)).toList();
  Coin? get selectedCoin => _selectedCoin;
  String? get errorMessage => _errorMessage;

  // 자동 갱신 타이머 설정
  void _setupAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
      Duration(seconds: TimeConstants.defaultRefreshIntervalSeconds),
      (_) => refreshCoins(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  // 코인 목록 갱신
  Future<void> refreshCoins() async {
    _isLoading = true;
    notifyListeners();

    try {
      final coins = await _supabaseService.getCoins();
      _coins = coins;
      _errorMessage = null;

      // 선택된 코인이 있으면 그 데이터도 갱신
      if (_selectedCoin != null) {
        await refreshSelectedCoin();
      }
    } catch (e) {
      _errorMessage = '코인 데이터 로드 실패: $e';
      debugPrint(_errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 특정 코인 선택
  Future<void> selectCoin(String coinId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final coin = await _supabaseService.getCoinById(coinId);
      _selectedCoin = coin;
      _errorMessage = null;
    } catch (e) {
      _errorMessage = '코인 상세정보 로드 실패: $e';
      debugPrint(_errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 선택된 코인 정보 갱신
  Future<void> refreshSelectedCoin() async {
    if (_selectedCoin == null) return;

    try {
      final updatedCoin = await _supabaseService.getCoinById(_selectedCoin!.id);
      if (updatedCoin != null) {
        _selectedCoin = updatedCoin;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('선택된 코인 갱신 실패: $e');
      // 실패해도 사용자에게는 에러 메시지 표시하지 않음
    }
  }

  // 코인 즐겨찾기에 추가/제거
  void toggleFavorite(String symbol) {
    if (_favoriteCoins.contains(symbol)) {
      _favoriteCoins.remove(symbol);
    } else {
      _favoriteCoins.add(symbol);
    }
    notifyListeners();

    // 로그인된 사용자의 즐겨찾기 DB 업데이트 (비동기)
    _updateFavoritesInDb();
  }

  // 코인이 즐겨찾기에 있는지 확인
  bool isFavorite(String symbol) {
    return _favoriteCoins.contains(symbol);
  }

  // 즐겨찾기 DB 업데이트 (로그인 필요)
  Future<void> _updateFavoritesInDb() async {
    final currentUser = _supabaseService.getCurrentUser();
    if (currentUser == null) return; // 로그인되지 않은 경우

    try {
      await _supabaseService.updateUser(currentUser.id, {
        'favorite_coins': _favoriteCoins,
      });
    } catch (e) {
      debugPrint('즐겨찾기 DB 업데이트 실패: $e');
    }
  }

  // 사용자 즐겨찾기 로드
  Future<void> loadUserFavorites(String userId) async {
    try {
      final user = await _supabaseService.updateUser(
        userId,
        {},
      ); // 빈 업데이트로 최신 데이터 가져오기
      if (user.favoriteCoins.isNotEmpty) {
        _favoriteCoins = user.favoriteCoins;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('사용자 즐겨찾기 로드 실패: $e');
    }
  }

  // 에러 메시지 초기화
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
