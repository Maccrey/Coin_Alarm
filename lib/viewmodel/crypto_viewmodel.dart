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
  String? _error;
  DateTime _lastUpdated = DateTime.now();
  Timer? _refreshTimer;

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

  // 데이터 새로고침
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
      final coins = await _activeService!.getTopCoins(limit: 20);

      debugPrint('CryptoViewModel: API 응답 수신 - ${coins.length}개 코인');

      if (coins.isNotEmpty) {
        _topCoins = coins;
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

  // 자동 새로고침 타이머 시작
  void _startRefreshTimer() {
    // 기존 타이머 취소
    _refreshTimer?.cancel();

    // 설정된 새로고침 간격으로 타이머 설정
    final interval = _settingsService.getRefreshInterval();
    _refreshTimer = Timer.periodic(
      Duration(seconds: interval),
      (_) => refresh(),
    );
  }

  // 새로고침 간격 변경 시 타이머 재설정
  void updateRefreshInterval(int seconds) {
    _settingsService.setRefreshInterval(seconds);
    _startRefreshTimer();
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
