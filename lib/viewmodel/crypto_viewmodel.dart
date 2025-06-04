import 'dart:async';
import 'package:flutter/foundation.dart';
import '../model/coin_model.dart';
import '../services/crypto_api_service.dart';
import '../services/settings_service.dart';

// 암호화폐 데이터 관리 ViewModel
class CryptoViewModel extends ChangeNotifier {
  final CryptoServiceFactory _serviceFactory = CryptoServiceFactory();
  final SettingsService _settingsService;

  // 상태 변수
  List<Coin> _topCoins = [];
  List<CryptoApiService> _availableServices = [];
  CryptoApiService? _activeService;
  bool _isLoading = false;
  bool _isBackgroundLoading = false; // 백그라운드 로딩 상태
  String? _error;
  DateTime _lastUpdated = DateTime.now();
  Timer? _refreshTimer;
  Map<String, double> _previousPrices = {}; // 이전 가격 저장용
  Map<String, bool> _priceIncreased = {}; // 가격 상승/하락 상태 저장
  Map<String, int> _userDefinedOrder = {}; // 사용자 정의 순서 저장용

  // 생성자
  CryptoViewModel({SettingsService? settingsService})
    : _settingsService = settingsService ?? SettingsService() {
    _initialize();
  }

  // 초기화
  Future<void> _initialize() async {
    debugPrint('CryptoViewModel: 초기화 시작');
    await _settingsService.initialize();

    final upbitKey = _settingsService.getUpbitAccessKey();
    final binanceKey = _settingsService.getBinanceApiKey();
    debugPrint(
      'CryptoViewModel: API 키 확인 - Upbit: ${upbitKey != null ? "설정됨" : "없음"}, Binance: ${binanceKey != null ? "설정됨" : "없음"}',
    );

    _checkAvailableServices();
    debugPrint(
      'CryptoViewModel: 사용 가능한 서비스 - ${_availableServices.length}개, 활성 서비스: ${_activeService?.exchangeName ?? "없음"}',
    );

    // 저장된 사용자 정의 순서 불러오기
    _loadUserDefinedOrder();

    await refresh();
    _startRefreshTimer();
    debugPrint('CryptoViewModel: 초기화 완료');
  }

  // 사용 가능한 API 서비스 확인
  void _checkAvailableServices() {
    debugPrint('CryptoViewModel: 사용 가능한 서비스 확인 중');
    _availableServices = _serviceFactory.getAvailableServices();
    _activeService = _serviceFactory.getPreferredService();

    // 각 API 서비스 유형별 상태 확인
    final upbitService =
        _availableServices
            .where((service) => service is UpbitApiService)
            .isEmpty
        ? null
        : _availableServices.firstWhere(
            (service) => service is UpbitApiService,
          );

    final binanceService =
        _availableServices
            .where((service) => service is BinanceApiService)
            .isEmpty
        ? null
        : _availableServices.firstWhere(
            (service) => service is BinanceApiService,
          );

    debugPrint(
      'CryptoViewModel: API 서비스 상태 - 업비트: ${upbitService != null ? "구성됨" : "없음"}, 바이낸스: ${binanceService != null ? "구성됨" : "없음"}',
    );

    if (_availableServices.isEmpty) {
      debugPrint('CryptoViewModel: 사용 가능한 API 서비스가 없습니다');
    } else {
      debugPrint(
        'CryptoViewModel: 사용 가능한 API 서비스 - ${_availableServices.map((s) => s.exchangeName).join(', ')}',
      );
    }

    notifyListeners();
  }

  // 데이터 새로고침 (전체 UI 새로고침)
  Future<void> refresh() async {
    if (_isLoading) {
      debugPrint('CryptoViewModel: 이미 로딩 중이므로 새로고침 무시');
      return;
    }

    debugPrint('CryptoViewModel: 데이터 새로고침 시작');
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (_activeService == null) {
        debugPrint('CryptoViewModel: 활성 서비스가 없어 서비스를 다시 확인합니다');
        _checkAvailableServices();
        if (_activeService == null) {
          _error = '설정된 암호화폐 API가 없습니다.';
          _topCoins = [];
          debugPrint('CryptoViewModel: 사용 가능한 서비스가 없습니다. API 키 설정이 필요합니다.');
          return;
        }
      }

      debugPrint(
        'CryptoViewModel: ${_activeService!.exchangeName} 서비스를 통해 데이터를 요청합니다.',
      );
      final coins = await _activeService!.getTopCoins(limit: 0);

      debugPrint('CryptoViewModel: API 응답 수신 - ${coins.length}개 코인');

      if (coins.isNotEmpty) {
        _storePreviousPrices(); // 이전 가격 저장
        _topCoins = coins;
        _updatePriceChangeStatus(); // 가격 변화 상태 업데이트

        // 새로운 코인의 경우 사용자 정의 순서 초기화
        _initializeOrderForNewCoins();

        _lastUpdated = DateTime.now();
        debugPrint('CryptoViewModel: 데이터 업데이트 성공');

        // 첫 번째 코인 데이터 샘플 출력
        if (_topCoins.isNotEmpty) {
          final sample = _topCoins.first;
          debugPrint(
            'CryptoViewModel: 첫 번째 코인 - ${sample.symbol}, 가격: ${sample.currentPrice}, 변화율: ${sample.priceChangePercentage24h}%',
          );
        }
      } else {
        _error = '데이터를 가져올 수 없습니다.';
        debugPrint('CryptoViewModel: 빈 데이터 수신');
      }
    } catch (e) {
      _error = '오류 발생: $e';
      debugPrint('CryptoViewModel: 오류 발생 - $e');
    } finally {
      _isLoading = false;
      notifyListeners();
      debugPrint('CryptoViewModel: 데이터 새로고침 완료');

      debugPrint(
        'CryptoViewModel 상태: 데이터 ${_topCoins.length}개, 에러=${_error != null}, 로딩=$_isLoading',
      );
    }
  }

  // CoinViewModel과의 호환성을 위한 메서드
  Future<void> refreshCoins() async {
    return refresh();
  }

  // 백그라운드 데이터 새로고침 (UI 업데이트 최소화)
  Future<void> refreshBackground() async {
    if (_isBackgroundLoading || _activeService == null) {
      return;
    }

    _isBackgroundLoading = true;

    try {
      final coins = await _activeService!.getTopCoins(limit: 0);

      if (coins.isNotEmpty) {
        _storePreviousPrices(); // 이전 가격 저장
        _topCoins = coins;
        _updatePriceChangeStatus(); // 가격 변화 상태 업데이트
        _lastUpdated = DateTime.now();

        // UI 업데이트
        notifyListeners();
      }
    } catch (e) {
      debugPrint('CryptoViewModel: 백그라운드 새로고침 오류 - $e');
    } finally {
      _isBackgroundLoading = false;
    }
  }

  // 이전 가격 정보 저장
  void _storePreviousPrices() {
    for (final coin in _topCoins) {
      _previousPrices[coin.symbol] = coin.currentPrice;
    }
  }

  // 가격 변화 상태 업데이트
  void _updatePriceChangeStatus() {
    for (final coin in _topCoins) {
      final prevPrice = _previousPrices[coin.symbol];
      if (prevPrice != null) {
        _priceIncreased[coin.symbol] = coin.currentPrice > prevPrice;
      }
    }
  }

  // 자동 새로고침 타이머 시작
  void _startRefreshTimer() {
    // 기존 타이머 취소
    _refreshTimer?.cancel();

    // 설정에서 새로고침 간격 가져오기
    final interval = _settingsService.getRefreshInterval();
    debugPrint('CryptoViewModel: 새로고침 간격 설정 - $interval초');

    // 정확한 간격으로 타이머 설정
    _refreshTimer = Timer.periodic(Duration(seconds: interval), (timer) {
      debugPrint('CryptoViewModel: 설정된 간격($interval초)으로 새로고침 실행');
      refresh();
    });

    // 초기 데이터 로드
    if (_topCoins.isEmpty) {
      refresh();
    }

    debugPrint('CryptoViewModel: 새로고침 타이머 시작됨 - 간격: $interval초');
  }

  // 특정 코인의 가격 변화 상태 확인 (상승/하락)
  bool isPriceIncreased(String symbol) {
    return _priceIncreased[symbol] ?? false;
  }

  // 특정 코인의 가격이 방금 변경되었는지 확인
  bool hasPriceChanged(String symbol) {
    final prevPrice = _previousPrices[symbol];
    if (prevPrice == null) return false;

    final coin = _topCoins.firstWhere(
      (c) => c.symbol == symbol,
      orElse: () => _topCoins.first,
    );

    return prevPrice != coin.currentPrice;
  }

  // 새로고침 간격 변경 시 타이머 재설정
  void updateRefreshInterval(int seconds) {
    debugPrint('CryptoViewModel: 새로고침 간격 변경 - $seconds초');
    _settingsService.setRefreshInterval(seconds);
    _startRefreshTimer();
    notifyListeners(); // UI 업데이트
  }

  // API 서비스 변경
  void setActiveService(CryptoApiService service) {
    _activeService = service;
    refresh();
    notifyListeners();
  }

  // 특정 코인 조회
  Future<Coin?> getCoinBySymbol(String symbol) async {
    if (_activeService == null) {
      return null;
    }

    try {
      return await _activeService!.getCoinBySymbol(symbol);
    } catch (e) {
      debugPrint('코인 조회 오류: $e');
      return null;
    }
  }

  // 사용자 정의 순서 불러오기
  void _loadUserDefinedOrder() {
    // SettingsService에서 저장된 순서 불러오기
    _userDefinedOrder = _settingsService.getCoinOrder();
    debugPrint(
      'CryptoViewModel: 사용자 정의 순서 불러오기 완료 - ${_userDefinedOrder.length}개 항목',
    );
  }

  // 새로운 코인에 대한 순서 초기화
  void _initializeOrderForNewCoins() {
    // 새로 추가된 코인에 대해 순서 번호 할당
    int maxOrder = _userDefinedOrder.isEmpty
        ? 0
        : _userDefinedOrder.values.reduce((a, b) => a > b ? a : b);

    for (final coin in _topCoins) {
      if (!_userDefinedOrder.containsKey(coin.symbol)) {
        _userDefinedOrder[coin.symbol] = ++maxOrder;
      }
    }
  }

  // 코인 순서 재정렬
  void reorderCoins(int oldIndex, int newIndex) {
    debugPrint('CryptoViewModel: 코인 순서 변경 시작 - 이전: $oldIndex, 새로운: $newIndex');

    // ReorderableListView에서는 newIndex가 항목이 제거된 후의 인덱스이므로 조정이 필요함
    if (oldIndex < newIndex) {
      newIndex -= 1;
      debugPrint('CryptoViewModel: newIndex 조정됨 -> $newIndex');
    }

    // 정렬된 목록 가져오기
    final sortedCoins = getSortedCoins();

    debugPrint(
      'CryptoViewModel: 현재 정렬된 코인 목록 - ${sortedCoins.map((c) => "${c.symbol}:${_userDefinedOrder[c.symbol]}").join(", ")}',
    );

    if (oldIndex < 0 ||
        oldIndex >= sortedCoins.length ||
        newIndex < 0 ||
        newIndex >= sortedCoins.length) {
      debugPrint('CryptoViewModel: 인덱스가 범위를 벗어남. 재정렬 취소');
      return;
    }

    // 이동할 코인
    final movingCoin = sortedCoins[oldIndex];
    debugPrint(
      'CryptoViewModel: 이동할 코인 - ${movingCoin.symbol}, 현재 순서: ${_userDefinedOrder[movingCoin.symbol]}',
    );

    // 새로운 순서 값 계산
    int newOrderValue;

    if (newIndex == 0) {
      // 맨 앞으로 이동하는 경우
      newOrderValue = sortedCoins[0].symbol != movingCoin.symbol
          ? (_userDefinedOrder[sortedCoins[0].symbol]! - 1)
          : _userDefinedOrder[sortedCoins[0].symbol]!;
      debugPrint('CryptoViewModel: 맨 앞으로 이동, 새 순서 값: $newOrderValue');
    } else if (newIndex == sortedCoins.length - 1) {
      // 맨 뒤로 이동하는 경우
      newOrderValue =
          sortedCoins[sortedCoins.length - 1].symbol != movingCoin.symbol
          ? (_userDefinedOrder[sortedCoins[sortedCoins.length - 1].symbol]! + 1)
          : _userDefinedOrder[sortedCoins[sortedCoins.length - 1].symbol]!;
      debugPrint('CryptoViewModel: 맨 뒤로 이동, 새 순서 값: $newOrderValue');
    } else {
      // 중간으로 이동하는 경우
      final before = sortedCoins[newIndex - 1];
      final after = sortedCoins[newIndex];
      final beforeOrder = _userDefinedOrder[before.symbol]!;
      final afterOrder = _userDefinedOrder[after.symbol]!;
      newOrderValue = (beforeOrder + afterOrder) ~/ 2;
      debugPrint(
        'CryptoViewModel: 중간으로 이동, 이전 코인: ${before.symbol} (순서:$beforeOrder), 이후 코인: ${after.symbol} (순서:$afterOrder), 계산된 순서 값: $newOrderValue',
      );

      // 순서값이 같아지는 경우를 방지
      if (newOrderValue == beforeOrder || newOrderValue == afterOrder) {
        debugPrint('CryptoViewModel: 순서값 충돌 감지, 정규화 실행');
        // 전체 순서 재정렬
        _normalizeOrders(sortedCoins);
        // 이동 재시도
        debugPrint('CryptoViewModel: 정규화 후 재시도');
        reorderCoins(oldIndex, newIndex);
        return;
      }
    }

    // 이동하는 코인의 순서 설정
    _userDefinedOrder[movingCoin.symbol] = newOrderValue;
    debugPrint(
      'CryptoViewModel: 코인 ${movingCoin.symbol}의 순서를 $newOrderValue로 설정',
    );

    // 변경 사항 저장
    _saveUserDefinedOrder();

    // UI 업데이트
    notifyListeners();
    debugPrint('CryptoViewModel: 코인 순서 변경 완료');
  }

  // 순서값 정규화 (간격 균등화)
  void _normalizeOrders(List<Coin> sortedCoins) {
    debugPrint('CryptoViewModel: 코인 순서 정규화 실행');
    for (int i = 0; i < sortedCoins.length; i++) {
      _userDefinedOrder[sortedCoins[i].symbol] =
          (i + 1) * 10; // 10, 20, 30... 간격으로 설정
    }
  }

  // 사용자 정의 순서 저장
  void _saveUserDefinedOrder() {
    // SettingsService를 통해 순서 저장
    _settingsService.setCoinOrder(_userDefinedOrder);
    debugPrint(
      'CryptoViewModel: 사용자 정의 순서 저장 - ${_userDefinedOrder.length}개 항목',
    );
  }

  // Getters
  List<Coin> get topCoins => _topCoins;
  List<Coin> get coins => _topCoins; // CoinViewModel과의 호환성을 위한 getter
  List<Coin> get visibleCoins => _topCoins; // 차트 화면에서 사용할 코인 목록

  // 사용자 정의 순서로 정렬된 코인 목록 반환
  List<Coin> getSortedCoins() {
    if (_topCoins.isEmpty) return [];

    // 사용자 정의 순서가 있는 코인 목록 복사
    final sortedCoins = List<Coin>.from(_topCoins);

    // 사용자 정의 순서로 정렬
    sortedCoins.sort((a, b) {
      final orderA = _userDefinedOrder[a.symbol] ?? 999999;
      final orderB = _userDefinedOrder[b.symbol] ?? 999999;
      return orderA.compareTo(orderB);
    });

    return sortedCoins;
  }

  List<CryptoApiService> get availableServices => _availableServices;
  CryptoApiService? get activeService => _activeService;
  bool get isLoading => _isLoading;
  String? get error => _error;
  DateTime get lastUpdated => _lastUpdated;
  bool get hasServices => _availableServices.isNotEmpty;

  // 새로고침 간격 getter
  int get refreshInterval => _settingsService.getRefreshInterval();

  // 코인 순서 초기화 (기본 순서로 재설정)
  void resetCoinOrder() {
    _userDefinedOrder.clear();
    _initializeOrderForNewCoins();
    _saveUserDefinedOrder();
    notifyListeners();
    debugPrint('CryptoViewModel: 코인 순서 초기화 완료');
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}
