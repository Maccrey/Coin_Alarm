import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/firebase_service.dart';
import '../model/coin_model.dart';
import '../core/constants.dart';

// 코인 데이터 관련 ViewModel 클래스
class CoinViewModel extends ChangeNotifier {
  final FirebaseService _firebaseService;

  // 상태 관리
  bool _isLoading = false;
  List<Coin> _coins = [];
  List<String> _favoriteCoins = DefaultSettings.defaultFavoriteCoins;
  Coin? _selectedCoin;
  String? _errorMessage;

  // 자동 갱신 타이머
  Timer? _refreshTimer;

  // 생성자
  CoinViewModel(this._firebaseService) {
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
      // Firebase 서비스에 해당 기능이 구현되어 있지 않으므로 더미 데이터 사용
      _coins = DefaultSettings.defaultCoins;
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

  // ID로 코인 정보 가져오기
  Coin? getCoinById(String coinId) {
    try {
      return _coins.firstWhere((coin) => coin.id == coinId);
    } catch (e) {
      debugPrint('코인 ID로 조회 실패: $e');
      return null;
    }
  }

  // 특정 코인 선택
  Future<void> selectCoin(String coinId) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Firebase 서비스에 해당 기능이 구현되어 있지 않으므로 로컬에서 찾기
      _selectedCoin = getCoinById(coinId);
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
      // Firebase 서비스에 해당 기능이 구현되어 있지 않으므로 로컬에서 찾기
      final updatedCoin = getCoinById(_selectedCoin!.id);
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
    // Firebase 서비스에 해당 기능이 구현되어 있지 않으므로 로컬 상태만 업데이트
    debugPrint('즐겨찾기 업데이트: ${_favoriteCoins.join(', ')}');
  }

  // 에러 메시지 초기화
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
