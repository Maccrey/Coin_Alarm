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

    // 실시간성을 높이기 위해 5초마다 백그라운드 업데이트
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      // 매 5초마다 백그라운드 새로고침
      refreshBackground();

      // 설정된 간격에 따라 전체 새로고침
      if (timer.tick % (interval ~/ 5) == 0) {
        refresh();
      }
    });

    debugPrint('CryptoViewModel: 새로고침 타이머 시작됨 - 전체 새로고침 간격: $interval초');
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
    _settingsService.setRefreshInterval(seconds);
    _startRefreshTimer();
    notifyListeners();
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

  // Getters
  List<Coin> get topCoins => _topCoins;
  List<Coin> get coins => _topCoins; // CoinViewModel과의 호환성을 위한 getter
  List<CryptoApiService> get availableServices => _availableServices;
  CryptoApiService? get activeService => _activeService;
  bool get isLoading => _isLoading;
  String? get error => _error;
  DateTime get lastUpdated => _lastUpdated;
  bool get hasServices => _availableServices.isNotEmpty;

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}
