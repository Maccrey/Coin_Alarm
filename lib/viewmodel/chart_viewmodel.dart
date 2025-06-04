import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import '../model/chart_data_model.dart';
import '../model/coin_model.dart';
import '../services/chart_api_service.dart';
import '../services/chart_cache_service.dart';
import '../services/settings_service.dart';

/// 차트 데이터 관리 ViewModel
class ChartViewModel extends ChangeNotifier {
  final ChartApiServiceFactory _serviceFactory = ChartApiServiceFactory();
  final ChartCacheService _cacheService = ChartCacheService();
  final SettingsService _settingsService = SettingsService();
  final InternetConnectionChecker _connectionChecker =
      InternetConnectionChecker.createInstance();

  // 상태 변수
  ChartApiService? _apiService;
  bool _isLoading = false;
  String? _error;
  bool _isOfflineMode = false;
  bool _isConnected = true;
  StreamSubscription? _connectivitySubscription;

  // 차트 데이터
  CandleChartData? _candleChartData;
  ChartData? _lineChartData;

  // 가격 정보
  double _currentPrice = 0.0;
  double _highPrice = 0.0;
  double _lowPrice = 0.0;
  double _priceChange = 0.0;
  double _priceChangePercent = 0.0;

  // 선택된 코인 및 설정
  String _selectedSymbol = 'BTC';
  ChartTimeframe _selectedTimeframe = ChartTimeframe.days1;
  ChartType _selectedChartType = ChartType.candlestick;

  // 자동 갱신 타이머
  Timer? _refreshTimer;

  // 생성자
  ChartViewModel() {
    _initialize();
  }

  // 게터
  CandleChartData? get candleChartData => _candleChartData;
  ChartData? get lineChartData => _lineChartData;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get selectedSymbol => _selectedSymbol;
  ChartTimeframe get selectedTimeframe => _selectedTimeframe;
  ChartType get selectedChartType => _selectedChartType;
  bool get isOfflineMode => _isOfflineMode;
  bool get isConnected => _isConnected;

  // 가격 정보 게터
  double get currentPrice => _currentPrice;
  double get highPrice => _highPrice;
  double get lowPrice => _lowPrice;
  double get priceChange => _priceChange;
  double get priceChangePercent => _priceChangePercent;

  // 초기화
  Future<void> _initialize() async {
    debugPrint('ChartViewModel: 초기화 시작');

    try {
      // 캐시 서비스 초기화
      await _cacheService.initialize();

      // API 서비스 초기화
      _apiService = _serviceFactory.getPreferredService();

      if (_apiService == null) {
        _error = '차트 데이터를 가져올 수 있는 API 서비스가 없습니다.';
        debugPrint('ChartViewModel: API 서비스 없음');
      } else {
        debugPrint(
          'ChartViewModel: ${_apiService!.exchangeName} API 서비스 초기화 완료',
        );
      }

      // 만료된 캐시 정리
      await _cacheService.clearExpiredCache();

      // 네트워크 연결 상태 초기화 및 모니터링
      _initConnectivity();
      _setupConnectivityMonitoring();
    } catch (e) {
      _error = '초기화 오류: $e';
      debugPrint('ChartViewModel: 초기화 오류 - $e');
    }

    notifyListeners();
    debugPrint('ChartViewModel: 초기화 완료');
  }

  // 네트워크 연결 상태 초기화
  Future<void> _initConnectivity() async {
    try {
      final result = await _connectionChecker.hasConnection;
      _updateConnectionStatus(result);
    } catch (e) {
      debugPrint('ChartViewModel: 연결 상태 확인 오류 - $e');
      _isConnected = false;
    }
  }

  // 네트워크 연결 상태 모니터링 설정
  void _setupConnectivityMonitoring() {
    _connectivitySubscription = _connectionChecker.onStatusChange.listen((
      InternetConnectionStatus status,
    ) {
      final isConnected = status == InternetConnectionStatus.connected;
      _updateConnectionStatus(isConnected);
    });
  }

  // 연결 상태 업데이트
  void _updateConnectionStatus(bool isConnected) {
    final wasConnected = _isConnected;
    _isConnected = isConnected;

    debugPrint(
      'ChartViewModel: 네트워크 상태 변경 - ${_isConnected ? "연결됨" : "연결 끊김"}',
    );

    // 연결 상태가 변경된 경우에만 처리
    if (wasConnected != _isConnected) {
      if (_apiService != null) {
        // 오프라인 모드가 아닌 경우에만 API 서비스에 연결 상태 전달
        if (!_isOfflineMode) {
          _apiService!.offlineMode = !_isConnected;
        }

        // 연결이 복구된 경우 데이터 새로고침
        if (_isConnected && !_isOfflineMode) {
          loadChartData();
        }
      }

      notifyListeners();
    }
  }

  // 오프라인 모드 설정
  void setOfflineMode(bool value) {
    if (_isOfflineMode != value) {
      _isOfflineMode = value;

      if (_apiService != null) {
        _apiService!.offlineMode = value;
        debugPrint('ChartViewModel: 오프라인 모드 ${value ? "활성화" : "비활성화"}');
      }

      // 오프라인 모드를 끄고 네트워크가 연결된 경우 데이터 새로고침
      if (!value && _isConnected) {
        loadChartData();
      }

      notifyListeners();
    }
  }

  // 코인 선택
  void selectCoin(Coin coin) {
    debugPrint('ChartViewModel: 코인 선택 - ${coin.symbol}');
    _selectedSymbol = coin.symbol;
    loadChartData();
  }

  // 코인 심볼로 선택
  void selectSymbol(String symbol) {
    debugPrint('ChartViewModel: 코인 심볼 선택 - $symbol');
    _selectedSymbol = symbol;
    loadChartData();
  }

  // 차트 타입 선택
  void selectChartType(ChartType type) {
    if (_selectedChartType != type) {
      _selectedChartType = type;
      notifyListeners();
      loadChartData();
    }
  }

  // 시간 프레임 선택
  void selectTimeframe(ChartTimeframe timeframe) {
    debugPrint('ChartViewModel: 시간 프레임 선택 - ${timeframe.name}');
    _selectedTimeframe = timeframe;
    loadChartData();
  }

  // 차트 데이터 로드
  Future<void> loadChartData() async {
    if (_apiService == null) {
      _error = 'API 서비스가 설정되지 않았습니다.';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint(
        'ChartViewModel: 차트 데이터 로드 시작 - $_selectedSymbol (${_selectedTimeframe.name})',
      );

      if (_selectedChartType == ChartType.candlestick) {
        _candleChartData = await _apiService!.getCandleData(
          _selectedSymbol,
          _selectedTimeframe,
        );

        if (_candleChartData == null) {
          _error = '캔들스틱 차트 데이터를 가져올 수 없습니다.';
        } else {
          debugPrint(
            'ChartViewModel: 캔들스틱 데이터 로드 완료 - ${_candleChartData!.candles.length}개',
          );

          // 가격 정보 업데이트
          _updateCandleChartPriceInfo(_candleChartData!);
        }
      } else {
        _lineChartData = await _apiService!.getLineData(
          _selectedSymbol,
          _selectedTimeframe,
        );

        if (_lineChartData == null) {
          _error = '라인 차트 데이터를 가져올 수 없습니다.';
        } else {
          debugPrint(
            'ChartViewModel: 라인 차트 데이터 로드 완료 - ${_lineChartData!.points.length}개',
          );

          // 가격 정보 업데이트
          _updateLineChartPriceInfo(_lineChartData!);
        }
      }

      // 자동 갱신 타이머 설정
      _setupRefreshTimer();
    } catch (e) {
      _error = '데이터 로드 오류: $e';
      debugPrint('ChartViewModel: 데이터 로드 오류 - $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 가격 정보 업데이트 (캔들스틱 차트)
  void _updateCandleChartPriceInfo(CandleChartData data) {
    if (data.candles.isEmpty) return;

    // 현재가 (마지막 캔들의 종가)
    final lastCandle = data.candles.last;
    _currentPrice = lastCandle.close;

    // 고가/저가 계산
    _highPrice = data.candles
        .map((c) => c.high)
        .reduce((a, b) => a > b ? a : b);
    _lowPrice = data.candles.map((c) => c.low).reduce((a, b) => a < b ? a : b);

    // 변동폭 계산 (첫 캔들과 마지막 캔들 비교)
    final firstCandle = data.candles.first;
    _priceChange = lastCandle.close - firstCandle.open;

    // 변동률 계산
    _priceChangePercent = (lastCandle.close / firstCandle.open - 1) * 100;
  }

  // 가격 정보 업데이트 (라인 차트)
  void _updateLineChartPriceInfo(ChartData data) {
    if (data.points.isEmpty) return;

    // 현재가 (마지막 포인트)
    final lastPoint = data.points.last;
    _currentPrice = lastPoint.price;

    // 고가/저가 계산
    _highPrice = data.points
        .map((p) => p.price)
        .reduce((a, b) => a > b ? a : b);
    _lowPrice = data.points.map((p) => p.price).reduce((a, b) => a < b ? a : b);

    // 변동폭 계산 (첫 포인트와 마지막 포인트 비교)
    final firstPoint = data.points.first;
    _priceChange = lastPoint.price - firstPoint.price;

    // 변동률 계산
    _priceChangePercent = (lastPoint.price / firstPoint.price - 1) * 100;
  }

  /// 차트 데이터 새로고침
  Future<void> refreshChartData() async {
    if (_isLoading) {
      debugPrint('ChartViewModel: 이미 로딩 중이므로 새로고침 무시');
      return;
    }

    // 오프라인 모드이거나 네트워크 연결이 없는 경우 새로고침 불가
    if (_isOfflineMode || !_isConnected) {
      _error = '오프라인 상태에서는 새로고침할 수 없습니다.';
      notifyListeners();
      return;
    }

    debugPrint('ChartViewModel: 차트 데이터 새로고침 시작');
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // API 서비스 가져오기
      final apiService = _serviceFactory.getPreferredService();

      if (apiService == null) {
        throw Exception('사용 가능한 차트 API 서비스가 없습니다.');
      }

      // 캐시 삭제 후 데이터 다시 로드
      await _cacheService.clearSymbolCache(_selectedSymbol);

      // 선택된 타임프레임에 따라 차트 데이터 로드
      if (_selectedChartType == ChartType.candlestick) {
        _candleChartData = await apiService.getCandleData(
          _selectedSymbol,
          _selectedTimeframe,
        );

        // 라인 차트 데이터도 함께 업데이트 (필요시 전환할 수 있도록)
        _lineChartData = await apiService.getLineData(
          _selectedSymbol,
          _selectedTimeframe,
        );
      } else {
        _lineChartData = await apiService.getLineData(
          _selectedSymbol,
          _selectedTimeframe,
        );

        // 캔들 차트 데이터도 함께 업데이트 (필요시 전환할 수 있도록)
        _candleChartData = await apiService.getCandleData(
          _selectedSymbol,
          _selectedTimeframe,
        );
      }

      // 데이터가 없는 경우 에러 처리
      if (_selectedChartType == ChartType.candlestick &&
          _candleChartData == null) {
        throw Exception('캔들 차트 데이터를 불러올 수 없습니다.');
      } else if (_selectedChartType == ChartType.line &&
          _lineChartData == null) {
        throw Exception('라인 차트 데이터를 불러올 수 없습니다.');
      }

      // 가격 정보 업데이트 (최고가, 최저가, 변동률 등)
      _updatePriceInfoFromChartData();

      debugPrint('ChartViewModel: 차트 데이터 새로고침 완료');
    } catch (e) {
      debugPrint('ChartViewModel: 차트 데이터 새로고침 오류 - $e');
      _error = '차트 데이터를 불러올 수 없습니다.\n$e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 차트 데이터에서 가격 정보 업데이트
  void _updatePriceInfoFromChartData() {
    if (_selectedChartType == ChartType.candlestick &&
        _candleChartData != null) {
      final candles = _candleChartData!.candles;
      if (candles.isNotEmpty) {
        // 최신 데이터 (마지막 캔들)
        final lastCandle = candles.last;
        _currentPrice = lastCandle.close;

        // 고가, 저가 계산
        _highPrice = double.negativeInfinity;
        _lowPrice = double.infinity;

        for (final candle in candles) {
          if (candle.high > _highPrice) {
            _highPrice = candle.high;
          }
          if (candle.low < _lowPrice) {
            _lowPrice = candle.low;
          }
        }

        // 변동률 계산 (첫 캔들과 마지막 캔들 비교)
        final firstCandle = candles.first;
        _priceChange = lastCandle.close - firstCandle.open;
        _priceChangePercent = (_priceChange / firstCandle.open) * 100;
      }
    } else if (_lineChartData != null) {
      final points = _lineChartData!.points;
      if (points.isNotEmpty) {
        // 최신 데이터 (마지막 포인트)
        _currentPrice = points.last.price;

        // 고가, 저가 계산
        _highPrice = double.negativeInfinity;
        _lowPrice = double.infinity;

        for (final point in points) {
          if (point.price > _highPrice) {
            _highPrice = point.price;
          }
          if (point.price < _lowPrice) {
            _lowPrice = point.price;
          }
        }

        // 변동률 계산 (첫 포인트와 마지막 포인트 비교)
        final firstPoint = points.first;
        _priceChange = points.last.price - firstPoint.price;
        _priceChangePercent = (_priceChange / firstPoint.price) * 100;
      }
    }
  }

  // 자동 갱신 타이머 설정
  void _setupRefreshTimer() {
    _refreshTimer?.cancel();

    // 오프라인 모드이거나 네트워크 연결이 없는 경우 타이머 설정 안함
    if (_isOfflineMode || !_isConnected) {
      debugPrint('ChartViewModel: 오프라인 상태로 자동 갱신 타이머 설정 안함');
      return;
    }

    // 시간 프레임에 따라 갱신 주기 조정
    int refreshIntervalSeconds;

    switch (_selectedTimeframe) {
      case ChartTimeframe.minutes1:
        refreshIntervalSeconds = 30; // 30초
        break;
      case ChartTimeframe.minutes3:
      case ChartTimeframe.minutes5:
        refreshIntervalSeconds = 60; // 1분
        break;
      case ChartTimeframe.minutes10:
      case ChartTimeframe.minutes15:
        refreshIntervalSeconds = 120; // 2분
        break;
      case ChartTimeframe.minutes30:
      case ChartTimeframe.minutes60:
        refreshIntervalSeconds = 300; // 5분
        break;
      default:
        refreshIntervalSeconds = 600; // 10분
    }

    debugPrint('ChartViewModel: 자동 갱신 타이머 설정 - $refreshIntervalSeconds초');

    _refreshTimer = Timer.periodic(
      Duration(seconds: refreshIntervalSeconds),
      (_) => loadChartData(),
    );
  }

  // 시간 프레임 문자열 변환
  String getTimeframeString(ChartTimeframe timeframe) {
    switch (timeframe) {
      case ChartTimeframe.minutes1:
        return '1분';
      case ChartTimeframe.minutes3:
        return '3분';
      case ChartTimeframe.minutes5:
        return '5분';
      case ChartTimeframe.minutes10:
        return '10분';
      case ChartTimeframe.minutes15:
        return '15분';
      case ChartTimeframe.minutes30:
        return '30분';
      case ChartTimeframe.minutes60:
        return '1시간';
      case ChartTimeframe.minutes240:
        return '4시간';
      case ChartTimeframe.days1:
        return '1일';
      case ChartTimeframe.days7:
        return '1주';
      case ChartTimeframe.days30:
        return '1개월';
    }
  }

  // 차트 타입 문자열 변환
  String getChartTypeString(ChartType type) {
    switch (type) {
      case ChartType.candlestick:
        return '캔들스틱';
      case ChartType.line:
        return '라인';
    }
  }

  // 리소스 정리
  @override
  void dispose() {
    _refreshTimer?.cancel();
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}
