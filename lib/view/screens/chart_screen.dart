import 'package:flutter/material.dart';
import 'dart:math';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../model/coin_model.dart';
import '../../viewmodel/crypto_viewmodel.dart';
import 'dart:async';
import '../widgets/chart_offline_indicator.dart';
import '../widgets/chart_offline_toggle.dart';
import '../../viewmodel/chart_viewmodel.dart';
import '../../model/chart_data_model.dart';
import '../../services/chart_cache_service.dart';
import '../widgets/candle_chart_widget.dart';
import '../widgets/line_chart_widget.dart';

// 차트 화면
class ChartScreen extends StatefulWidget {
  // 선택된 코인 (옵션)
  final Coin? selectedCoin;

  const ChartScreen({this.selectedCoin, super.key});

  @override
  State<ChartScreen> createState() => _ChartScreenState();
}

// 캔들스틱 데이터 구조 (전역)
class CandleData {
  final double x;
  final double open;
  final double high;
  final double low;
  final double close;
  CandleData({
    required this.x,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
  });
}

class _ChartScreenState extends State<ChartScreen> {
  // 선택된 코인
  Coin? _selectedCoin;

  // 차트 기간 옵션
  final List<String> _timeframes = ['1일', '1주일', '1개월', '3개월', '1년', '전체'];
  String _selectedTimeframe = '1일';

  // 차트 유형 옵션
  final List<String> _chartTypes = ['캔들스틱', '라인'];
  String _selectedChartType = '캔들스틱';

  // 지표 표시 옵션
  final List<String> _indicators = ['이동평균선', 'MACD', 'RSI', 'OBV'];
  final Set<String> _selectedIndicators = {'이동평균선'};

  // 차트 데이터 (과거+현재)
  List<Point<double>> _chartData = [];

  // 캔들스틱 데이터 리스트
  List<CandleData> _candleDataList = [];

  // 타이머
  Timer? _refreshTimer;

  // 확대/축소 관련 변수
  double _zoomLevel = 1.0;
  final double _minZoomLevel = 0.5;
  final double _maxZoomLevel = 2.0;

  @override
  void initState() {
    super.initState();

    // 차트 초기화
    _initChart();

    // 임시 차트 데이터 미리 생성 (로딩 중 표시용)
    _initChartData(); // 라인 차트용 임시 데이터
    _initCandleDataList(); // 캔들스틱 차트용 임시 데이터

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 설정된 새로고침 간격으로 타이머 설정
      _setupRefreshTimer();

      // 차트 화면이 직접 열릴 때만 비트코인으로 설정 (selectedCoin이 null인 경우)
      if (widget.selectedCoin == null) {
        // Provider에서 BTC 코인을 찾아서 기본값으로 사용
        final cryptoViewModel = Provider.of<CryptoViewModel>(
          context,
          listen: false,
        );
        if (cryptoViewModel.visibleCoins.isNotEmpty) {
          _selectedCoin = cryptoViewModel.visibleCoins.firstWhere(
            (coin) => coin.symbol.toUpperCase() == 'BTC',
            orElse: () => cryptoViewModel.visibleCoins.first,
          );
        } else {
          _selectedCoin = null;
        }
      } else {
        // 외부에서 코인이 전달된 경우
        _selectedCoin = widget.selectedCoin;
      }

      // 선택된 코인이 있으면 차트 뷰모델에 설정
      if (_selectedCoin != null) {
        _updateSelectedCoin(_selectedCoin!);
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  // 새로고침 타이머 설정
  void _setupRefreshTimer() {
    _refreshTimer?.cancel();
    final cryptoViewModel = Provider.of<CryptoViewModel>(
      context,
      listen: false,
    );

    // 차트 데이터는 1분마다 새로고침
    const chartRefreshInterval = 60; // 1분 = 60초
    debugPrint('ChartScreen: 차트 새로고침 타이머 설정 - $chartRefreshInterval초');

    _refreshTimer = Timer.periodic(
      const Duration(seconds: chartRefreshInterval),
      (timer) {
        if (mounted) {
          // 차트 데이터 새로고침
          final chartViewModel = Provider.of<ChartViewModel>(
            context,
            listen: false,
          );
          chartViewModel.refreshChartData();

          // 현재가 업데이트
          setState(() {
            final coin = cryptoViewModel.topCoins.firstWhere(
              (c) => c.symbol == _selectedCoin?.symbol,
              orElse: () => cryptoViewModel.topCoins.first,
            );
            _updateCurrentPrice(coin.currentPrice); // 라인 차트용
            _updateCurrentCandle(coin.currentPrice); // 캔들스틱 차트용
          });
        }
      },
    );
  }

  // 차트 초기화
  void _initChart() {
    if (widget.selectedCoin != null) {
      _selectedCoin = widget.selectedCoin!;
    } else {
      // Provider에서 BTC 코인을 찾아서 기본값으로 사용
      final cryptoViewModel = Provider.of<CryptoViewModel>(
        context,
        listen: false,
      );
      if (cryptoViewModel.visibleCoins.isNotEmpty) {
        _selectedCoin = cryptoViewModel.visibleCoins.firstWhere(
          (coin) => coin.symbol.toUpperCase() == 'BTC',
          orElse: () => cryptoViewModel.visibleCoins.first,
        );
      } else {
        _selectedCoin = null;
      }
    }
    if (_selectedCoin != null) {
      _initChartData(); // 라인 차트용
      _initCandleDataList(); // 캔들스틱 차트용
    }
  }

  // 과거 데이터 고정, 현재가만 실시간 업데이트
  void _initChartData() {
    final random = Random();
    final pointCount = _getPointCount();
    _chartData = [];
    // 과거 데이터: 랜덤 변동 (마지막 전까지)
    for (int i = 0; i < pointCount - 1; i++) {
      final y =
          _selectedCoin!.currentPrice * (0.97 + 0.06 * random.nextDouble());
      _chartData.add(Point(i.toDouble(), y));
    }
    // 마지막 포인트(현재가)
    _chartData.add(
      Point((pointCount - 1).toDouble(), _selectedCoin!.currentPrice),
    );
  }

  // 캔들스틱 데이터 초기화 (과거+현재)
  void _initCandleDataList() {
    final random = Random();
    final pointCount = _getPointCount();
    _candleDataList = [];
    double prevClose =
        _selectedCoin!.currentPrice * (0.97 + 0.06 * random.nextDouble());
    for (int i = 0; i < pointCount - 1; i++) {
      final open = prevClose;
      final close = open * (0.98 + 0.04 * random.nextDouble());
      final high = max(open, close) * (1 + random.nextDouble() * 0.01);
      final low = min(open, close) * (1 - random.nextDouble() * 0.01);
      _candleDataList.add(
        CandleData(
          x: i.toDouble(),
          open: open,
          high: high,
          low: low,
          close: close,
        ),
      );
      prevClose = close;
    }
    // 마지막 캔들(현재가)
    final open = prevClose;
    final close = _selectedCoin!.currentPrice;
    final high = max(open, close) * (1 + random.nextDouble() * 0.01);
    final low = min(open, close) * (1 - random.nextDouble() * 0.01);
    _candleDataList.add(
      CandleData(
        x: (pointCount - 1).toDouble(),
        open: open,
        high: high,
        low: low,
        close: close,
      ),
    );
  }

  // 실시간 가격만 마지막 포인트로 업데이트 (라인 차트용)
  void _updateCurrentPrice(double newPrice) {
    if (_chartData.isNotEmpty) {
      _chartData[_chartData.length - 1] = Point(
        (_chartData.length - 1).toDouble(),
        newPrice,
      );
    }
  }

  // 실시간 가격만 마지막 캔들에 반영
  void _updateCurrentCandle(double newPrice) {
    if (_candleDataList.isNotEmpty) {
      final last = _candleDataList.last;
      final open = last.open;
      final close = newPrice;
      final high = max(last.high, max(open, close));
      final low = min(last.low, min(open, close));
      _candleDataList[_candleDataList.length - 1] = CandleData(
        x: last.x,
        open: open,
        high: high,
        low: low,
        close: close,
      );
    }
  }

  @override
  void didUpdateWidget(ChartScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 위젯이 업데이트되면서 선택된 코인이 변경되었는지 확인
    if (widget.selectedCoin != null &&
        (oldWidget.selectedCoin == null ||
            widget.selectedCoin!.symbol != oldWidget.selectedCoin!.symbol)) {
      _updateSelectedCoin(widget.selectedCoin!);

      // 코인이 변경되면 차트 데이터도 즉시 새로고침
      // 안전하게 다음 프레임에서 실행
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final chartViewModel = Provider.of<ChartViewModel>(
            context,
            listen: false,
          );
          chartViewModel.refreshChartData();
        }
      });
    }
  }

  // 선택된 코인 업데이트 및 차트 데이터 로드
  void _updateSelectedCoin(Coin coin) {
    if (!mounted) return;

    setState(() {
      _selectedCoin = coin;
    });

    // 차트 뷰모델에 코인 설정 및 데이터 로드 요청
    // 안전하게 다음 프레임에서 실행
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final chartViewModel = Provider.of<ChartViewModel>(
          context,
          listen: false,
        );

        // 차트 데이터 로드 요청
        chartViewModel.selectCoin(coin);

        // 필요시 강제 새로고침 (약간의 지연 추가)
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            chartViewModel.refreshChartData();
          }
        });
      }
    });
  }

  // 기간 변경 시 차트 업데이트
  void _updateTimeframe(String timeframe) {
    setState(() {
      _selectedTimeframe = timeframe;
      _initChartData();
      _initCandleDataList();
      _zoomLevel = 1.0;
    });
  }

  // 차트 유형 변경
  void _updateChartType(String chartType) {
    setState(() {
      _selectedChartType = chartType;
    });
  }

  // 확대/축소 레벨 업데이트
  void _updateZoomLevel(double delta) {
    setState(() {
      _zoomLevel = (_zoomLevel + delta).clamp(_minZoomLevel, _maxZoomLevel);
    });
  }

  // 기간별 데이터 포인트 수 결정
  int _getPointCount() {
    switch (_selectedTimeframe) {
      case '1일':
        return 24; // 시간별
      case '1주일':
        return 7; // 일별
      case '1개월':
        return 30; // 일별
      case '3개월':
        return 90; // 일별
      case '1년':
        return 52; // 주별
      case '전체':
        return 60; // 월별
      default:
        return 24;
    }
  }

  @override
  Widget build(BuildContext context) {
    final chartViewModel = Provider.of<ChartViewModel>(context);
    final cryptoViewModel = Provider.of<CryptoViewModel>(context);

    // 코인이 전달된 경우 해당 코인으로 차트 데이터 로드
    if (widget.selectedCoin != null &&
        widget.selectedCoin!.symbol != chartViewModel.selectedSymbol) {
      // 빌드 중에 직접 호출하지 않고 다음 프레임에서 실행
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          // 즉시 로드하기 위해 차트 뷰모델 업데이트
          chartViewModel.selectCoin(widget.selectedCoin!);
          // 필요시 강제 새로고침
          Future.microtask(() => chartViewModel.refreshChartData());
        }
      });
    }

    // visibleCoins가 비어 있으면 API 안내 메시지 표시
    if (cryptoViewModel.visibleCoins.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('차트'),
        ),
        body: const Center(
          child: Text(
            'API 키가 등록되어 있지 않습니다.\n설정에서 API 키를 등록하세요.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
        ),
      );
    }

    // 차트 데이터 준비 상태 확인
    final isCandle = chartViewModel.selectedChartType == ChartType.candlestick;
    final isLine = chartViewModel.selectedChartType == ChartType.line;
    final hasCandle = chartViewModel.candleChartData != null;
    final hasLine = chartViewModel.lineChartData != null;
    final isChartReady = (isCandle && hasCandle) || (isLine && hasLine);

    // 1. 로딩 중이지만 캐시 데이터가 있으면 차트 먼저 표시 + 안내
    if (chartViewModel.isLoading && isChartReady) {
      return Stack(
        children: [
          // 차트 본문
          _buildChartArea(context),
          // 하단 안내 메시지
          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '최신 데이터 수신 중...\n(표시 중인 데이터는 캐시입니다)',
                  style: TextStyle(color: Colors.white, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      );
    }

    // 2. 로딩 중이고 캐시 데이터도 없으면 기본 차트 데이터 표시 (빈 화면 대신)
    if (chartViewModel.isLoading && !isChartReady) {
      // 기본 차트 데이터가 없으면 임시 데이터 생성
      // 이미 initState에서 생성했으므로 여기서는 확인만 함
      bool hasLocalData = !_chartData.isEmpty && !_candleDataList.isEmpty;

      // 기본 차트 데이터로 차트 표시
      return Stack(
        children: [
          // 기본 차트 영역
          Scaffold(
            appBar: AppBar(
              automaticallyImplyLeading: false,
              title: Text('${_selectedCoin?.symbol ?? 'BTC'} 차트'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () {
                    // 안전하게 다음 프레임에서 실행
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        chartViewModel.refreshChartData();
                      }
                    });
                  },
                ),
              ],
            ),
            body: Column(
              children: [
                // 차트 상단 정보 영역
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_selectedCoin?.name ?? '비트코인'} (${_selectedCoin?.symbol ?? 'BTC'})',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '현재가: ${NumberFormat.currency(symbol: '₩', decimalDigits: 0).format(_selectedCoin?.currentPrice ?? 0)}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),

                // 임시 차트 영역
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          '차트 데이터를 업데이트 중입니다...',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '네트워크 상태에 따라 시간이 소요될 수 있습니다.',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // 현재 선택된 코인 이름 가져오기
    String coinName = '차트';
    if (widget.selectedCoin != null) {
      coinName = widget.selectedCoin!.name;
    } else {
      // 비트코인이 선택된 경우 이름 표시
      if (chartViewModel.selectedSymbol.toUpperCase() == 'BTC') {
        coinName = '비트코인';
      } else {
        // 다른 코인인 경우 심볼 표시
        coinName = chartViewModel.selectedSymbol.toUpperCase();
      }
    }

    return Scaffold(
      appBar: AppBar(
        // 뒤로가기 버튼 제거
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Text(coinName),
            const SizedBox(width: 8),
            _buildCoinSelector(context),
          ],
        ),
        actions: [
          // 오프라인 모드 토글 버튼
          // const ChartOfflineToggle(),

          // 새로고침 버튼
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed:
                chartViewModel.isOfflineMode || !chartViewModel.isConnected
                ? null // 오프라인 모드나 네트워크 연결이 없으면 비활성화
                : () => chartViewModel.refreshChartData(),
            tooltip: '새로고침',
          ),

          // 설정 버튼
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // 차트 설정 다이얼로그 표시
              _showChartSettingsDialog(context);
            },
            tooltip: '차트 설정',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 오프라인 모드 표시
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: const [ChartOfflineIndicator()],
                ),
              ),
            ),

            // 가격 정보 표시 영역
            _buildPriceInfoArea(context),

            // 시간 프레임 선택 탭
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: _buildTimeframeSelector(context),
            ),

            // 차트 영역
            Expanded(child: _buildChartArea(context)),
          ],
        ),
      ),
    );
  }

  // 코인 선택 드롭다운
  Widget _buildCoinSelector(BuildContext context) {
    final chartViewModel = Provider.of<ChartViewModel>(context);
    final cryptoViewModel = Provider.of<CryptoViewModel>(
      context,
      listen: false,
    );

    return DropdownButton<String>(
      value: chartViewModel.selectedSymbol,
      icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
      underline: Container(),
      style: TextStyle(
        color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.9),
        fontWeight: FontWeight.w500,
        fontSize: 14,
      ),
      dropdownColor: Theme.of(context).colorScheme.primary,
      items: cryptoViewModel.visibleCoins.map((coin) {
        return DropdownMenuItem<String>(
          value: coin.symbol,
          child: Text(coin.symbol),
        );
      }).toList(),
      onChanged: (symbol) {
        if (symbol != null) {
          final selectedCoin = cryptoViewModel.visibleCoins.firstWhere(
            (coin) => coin.symbol == symbol,
            orElse: () => cryptoViewModel.visibleCoins.first,
          );
          chartViewModel.selectCoin(selectedCoin);
        }
      },
    );
  }

  // 가격 정보 영역
  Widget _buildPriceInfoArea(BuildContext context) {
    final chartViewModel = Provider.of<ChartViewModel>(context);

    // 현재 선택된 코인 데이터
    final currentPrice = chartViewModel.currentPrice;
    final highPrice = chartViewModel.highPrice;
    final lowPrice = chartViewModel.lowPrice;
    final priceChange = chartViewModel.priceChange;
    final priceChangePercent = chartViewModel.priceChangePercent;

    final isPositiveChange = priceChange >= 0;
    final changeColor = isPositiveChange
        ? Colors
              .red
              .shade700 // 상승: 빨강
        : Colors.blue.shade700; // 하락: 파랑

    // 천 단위 콤마 포맷터
    final priceFormat = NumberFormat.currency(symbol: '', decimalDigits: 0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 현재가
          Row(
            children: [
              Text(
                priceFormat.format(currentPrice),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: changeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPositiveChange
                          ? Icons.arrow_upward
                          : Icons.arrow_downward,
                      size: 10,
                      color: changeColor,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '${isPositiveChange ? "+" : ""}${priceFormat.format(priceChange)} (${priceChangePercent.toStringAsFixed(0)}%)',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: changeColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // 고가/저가
          Row(
            children: [
              Text(
                '고가: ${priceFormat.format(highPrice)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                '저가: ${priceFormat.format(lowPrice)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 시간 프레임 선택 위젯
  Widget _buildTimeframeSelector(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width, // 화면 너비로 제한
      height: 60, // 높이 축소
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 제한된 시간 프레임 옵션만 표시
              _buildTimeframeButton(context, ChartTimeframe.minutes15),
              _buildTimeframeButton(context, ChartTimeframe.minutes60),
              _buildTimeframeButton(context, ChartTimeframe.minutes240),
              _buildTimeframeButton(context, ChartTimeframe.days1),
              _buildTimeframeButton(context, ChartTimeframe.days7),
            ],
          ),
        ),
      ),
    );
  }

  // 시간 프레임 버튼
  Widget _buildTimeframeButton(BuildContext context, ChartTimeframe timeframe) {
    final chartViewModel = Provider.of<ChartViewModel>(context);
    final isSelected = chartViewModel.selectedTimeframe == timeframe;

    return SizedBox(
      width: 70, // 명시적인 너비 설정
      height: 36, // 명시적인 높이 설정
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: ElevatedButton(
          onPressed: () {
            if (!isSelected) {
              chartViewModel.selectTimeframe(timeframe);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.surface,
            foregroundColor: isSelected
                ? Theme.of(context).colorScheme.onPrimary
                : Theme.of(context).colorScheme.onSurface,
            elevation: isSelected ? 2 : 0,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
            minimumSize: const Size(40, 30),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline,
                width: 1,
              ),
            ),
          ),
          child: Text(
            chartViewModel.getTimeframeString(timeframe),
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ),
    );
  }

  // 차트 영역 위젯
  Widget _buildChartArea(BuildContext context) {
    final chartViewModel = Provider.of<ChartViewModel>(context);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      switchInCurve: Curves.easeInOutCubic,
      switchOutCurve: Curves.easeInOutCubic,
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
        return Stack(
          alignment: Alignment.center,
          children: <Widget>[
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      child: _buildChartContent(context, chartViewModel),
    );
  }

  // 차트 내용 위젯 (AnimatedSwitcher의 자식으로 사용)
  Widget _buildChartContent(
    BuildContext context,
    ChartViewModel chartViewModel,
  ) {
    if (chartViewModel.isLoading) {
      return SizedBox(
        key: const ValueKey('loading'),
        width: double.infinity,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                '차트 데이터를 수신 중입니다...',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '잠시만 기다려주세요',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (chartViewModel.error != null) {
      return SizedBox(
        key: const ValueKey('error'),
        width: double.infinity,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.8,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(
                  chartViewModel.error!,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                if (!chartViewModel.isOfflineMode && chartViewModel.isConnected)
                  ElevatedButton.icon(
                    onPressed: () => chartViewModel.refreshChartData(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('다시 시도'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    // 차트 타입에 따라 다른 차트 위젯 반환
    if (chartViewModel.selectedChartType == ChartType.candlestick) {
      if (chartViewModel.candleChartData == null) {
        return SizedBox(
          key: const ValueKey('no_candle_data'),
          width: double.infinity,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.bar_chart, size: 48, color: Colors.grey),
                SizedBox(height: 16),
                Text('캔들스틱 차트 데이터가 없습니다.'),
              ],
            ),
          ),
        );
      }

      // 캔들스틱 차트 구현
      return Padding(
        key: ValueKey(
          'candle_chart_${chartViewModel.candleChartData!.lastUpdated.millisecondsSinceEpoch}',
        ),
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 마지막 업데이트 시간 표시
            Padding(
              padding: const EdgeInsets.only(left: 8.0, bottom: 4.0),
              child: Text(
                '마지막 업데이트: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(chartViewModel.candleChartData!.lastUpdated)}',
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white70
                      : Colors.black54,
                ),
              ),
            ),

            // 차트
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: CandleChartWidget(
                  key: ValueKey(
                    'candle_data_${chartViewModel.candleChartData!.lastUpdated.millisecondsSinceEpoch}',
                  ),
                  chartData: chartViewModel.candleChartData!,
                  showVolume: true,
                  showGrid: true,
                  showTooltip: true,
                  upColor: Colors.red, // 상승: 빨강
                  downColor: Colors.blue, // 하락: 파랑
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      if (chartViewModel.lineChartData == null) {
        return SizedBox(
          key: const ValueKey('no_line_data'),
          width: double.infinity,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.show_chart, size: 48, color: Colors.grey),
                SizedBox(height: 16),
                Text('라인 차트 데이터가 없습니다.'),
              ],
            ),
          ),
        );
      }

      // 라인 차트 구현
      return Padding(
        key: ValueKey(
          'line_chart_${chartViewModel.lineChartData!.lastUpdated.millisecondsSinceEpoch}',
        ),
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 마지막 업데이트 시간 표시
            Padding(
              padding: const EdgeInsets.only(left: 8.0, bottom: 4.0),
              child: Text(
                '마지막 업데이트: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(chartViewModel.lineChartData!.lastUpdated)}',
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white70
                      : Colors.black54,
                ),
              ),
            ),

            // 차트
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: LineChartWidget(
                  key: ValueKey(
                    'line_data_${chartViewModel.lineChartData!.lastUpdated.millisecondsSinceEpoch}',
                  ),
                  chartData: chartViewModel.lineChartData!,
                  showGrid: true,
                  showTooltip: true,
                  showGradient: true,
                  lineColor: chartViewModel.priceChange >= 0
                      ? Colors.red
                      : Colors.blue,
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  // 차트 설정 다이얼로그
  void _showChartSettingsDialog(BuildContext context) {
    final chartViewModel = Provider.of<ChartViewModel>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('차트 설정'),
              content: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.8,
                  maxHeight: MediaQuery.of(context).size.height * 0.6,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 차트 타입 선택
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          '차트 타입',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      _buildChartTypeSelector(context),
                      const Divider(height: 24),

                      // 오프라인 모드 설정
                      SwitchListTile(
                        title: const Text('오프라인 모드'),
                        subtitle: const Text('인터넷 연결 없이 캐시된 데이터 사용'),
                        value: chartViewModel.isOfflineMode,
                        onChanged: (value) {
                          chartViewModel.setOfflineMode(value);
                          setState(() {});
                        },
                      ),

                      // 캐시 정보
                      FutureBuilder<int>(
                        future: Provider.of<ChartCacheService>(
                          context,
                          listen: false,
                        ).getCacheSize(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const ListTile(
                              title: Text('캐시 크기'),
                              subtitle: Text('계산 중...'),
                            );
                          }

                          final cacheSize = snapshot.data ?? 0;
                          String cacheSizeText;

                          if (cacheSize < 1024) {
                            cacheSizeText = '$cacheSize B';
                          } else if (cacheSize < 1024 * 1024) {
                            cacheSizeText =
                                '${(cacheSize / 1024).toStringAsFixed(2)} KB';
                          } else {
                            cacheSizeText =
                                '${(cacheSize / (1024 * 1024)).toStringAsFixed(2)} MB';
                          }

                          return ListTile(
                            title: const Text('캐시 크기'),
                            subtitle: Text(cacheSizeText),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.refresh),
                                  tooltip: '새로고침',
                                  onPressed: () {
                                    setState(() {});
                                  },
                                ),
                                TextButton(
                                  onPressed: () async {
                                    await Provider.of<ChartCacheService>(
                                      context,
                                      listen: false,
                                    ).clearAllCache();
                                    if (context.mounted) {
                                      setState(() {});
                                    }
                                  },
                                  child: const Text('캐시 삭제'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('닫기'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 차트 타입 선택 위젯
  Widget _buildChartTypeSelector(BuildContext context) {
    final chartViewModel = Provider.of<ChartViewModel>(context);

    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.8, // 화면 너비의 80%로 제한
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildChartTypeButton(
            context,
            ChartType.candlestick,
            chartViewModel.selectedChartType == ChartType.candlestick,
          ),
          const SizedBox(width: 16),
          _buildChartTypeButton(
            context,
            ChartType.line,
            chartViewModel.selectedChartType == ChartType.line,
          ),
        ],
      ),
    );
  }

  // 차트 타입 버튼
  Widget _buildChartTypeButton(
    BuildContext context,
    ChartType chartType,
    bool isSelected,
  ) {
    final chartViewModel = Provider.of<ChartViewModel>(context);

    final icon = chartType == ChartType.candlestick
        ? Icons.candlestick_chart
        : Icons.show_chart;

    final label = chartType == ChartType.candlestick ? '캔들' : '라인';

    return SizedBox(
      width: 100, // 명시적인 너비 설정
      height: 40, // 명시적인 높이 설정
      child: ElevatedButton.icon(
        onPressed: () {
          if (!isSelected) {
            chartViewModel.selectChartType(chartType);
          }
        },
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surface,
          foregroundColor: isSelected
              ? Theme.of(context).colorScheme.onPrimary
              : Theme.of(context).colorScheme.onSurface,
          elevation: isSelected ? 2 : 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outline,
              width: 1,
            ),
          ),
        ),
      ),
    );
  }
}

// [개선2] 부드러운 라인 차트 페인터
class SmoothLineChartPainter extends CustomPainter {
  final List<Point<double>> points;
  final double minX;
  final double maxX;
  final double minY;
  final double maxY;
  final Color color;

  SmoothLineChartPainter({
    required this.points,
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
    this.color = Colors.blue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final fillPaint = Paint()
      ..color = color.withOpacity(0.15)
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();

    if (points.isEmpty) return;

    // 첫 포인트
    final first = points.first;
    double x0 = ((first.x - minX) / (maxX - minX)) * size.width;
    double y0 = size.height - ((first.y - minY) / (maxY - minY)) * size.height;
    path.moveTo(x0, y0);
    fillPath.moveTo(x0, size.height);
    fillPath.lineTo(x0, y0);

    for (int i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final curr = points[i];
      final x1 = ((curr.x - minX) / (maxX - minX)) * size.width;
      final y1 = size.height - ((curr.y - minY) / (maxY - minY)) * size.height;
      final xm = (x0 + x1) / 2;
      final ym = (y0 + y1) / 2;
      // quadraticBezierTo로 부드럽게 연결
      path.quadraticBezierTo(x0, y0, xm, ym);
      fillPath.quadraticBezierTo(x0, y0, xm, ym);
      x0 = x1;
      y0 = y1;
    }
    // 마지막 점까지 연결
    path.lineTo(x0, y0);
    fillPath.lineTo(x0, y0);
    fillPath.lineTo(x0, size.height);
    fillPath.close();

    // 그리기
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

    // [개선3] 연한 격자선
    final gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    for (int i = 1; i < 5; i++) {
      final y = i * size.height / 5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    for (int i = 1; i < 5; i++) {
      final x = i * size.width / 5;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// 거래소 스타일 캔들스틱 차트 페인터
class ExchangeStyleCandleStickPainter extends CustomPainter {
  final List<CandleData> candles;
  final double minX;
  final double maxX;
  final double minY;
  final double maxY;
  ExchangeStyleCandleStickPainter({
    required this.candles,
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
  });
  @override
  void paint(Canvas canvas, Size size) {
    // 배경
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.white,
    );
    // 연한 격자
    final gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.13)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    for (int i = 1; i < 5; i++) {
      final y = i * size.height / 5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    for (int i = 1; i < 5; i++) {
      final x = i * size.width / 5;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    // 캔들스틱 그리기
    final candleWidth = (size.width / (candles.length + 1)).clamp(6.0, 18.0);
    final candleSpacing =
        (size.width - candleWidth * candles.length) / (candles.length + 1);
    for (int i = 0; i < candles.length; i++) {
      final c = candles[i];
      final x =
          candleSpacing + i * (candleWidth + candleSpacing) + candleWidth / 2;
      // Y좌표
      final yOpen =
          size.height - ((c.open - minY) / (maxY - minY)) * size.height;
      final yClose =
          size.height - ((c.close - minY) / (maxY - minY)) * size.height;
      final yHigh =
          size.height - ((c.high - minY) / (maxY - minY)) * size.height;
      final yLow = size.height - ((c.low - minY) / (maxY - minY)) * size.height;
      // 상승/하락
      final isUp = c.close >= c.open;
      final bodyColor = isUp ? Color(0xFF1976D2) : Color(0xFFD32F2F); // 파랑/빨강
      final borderColor = isUp ? Color(0xFF1976D2) : Color(0xFFD32F2F);
      // 꼬리(고가-저가)
      canvas.drawLine(
        Offset(x, yHigh.clamp(0, size.height)),
        Offset(x, yLow.clamp(0, size.height)),
        Paint()
          ..color = borderColor
          ..strokeWidth = 2.0,
      );
      // 바디
      final rect = Rect.fromLTRB(
        x - candleWidth / 2,
        min(yOpen, yClose).clamp(0, size.height),
        x + candleWidth / 2,
        max(yOpen, yClose).clamp(0, size.height),
      );
      canvas.drawRect(
        rect,
        Paint()
          ..color = bodyColor.withOpacity(isUp ? 0.85 : 0.5)
          ..style = PaintingStyle.fill,
      );
      // 바디 테두리
      canvas.drawRect(
        rect,
        Paint()
          ..color = borderColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
