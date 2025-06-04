import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:ui'; // TextDirection을 위해 필요
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../data/dummy_coins.dart';
import '../../model/coin_model.dart';
import '../../viewmodel/crypto_viewmodel.dart';
import '../../core/theme.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../core/constants.dart';
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
  late Coin _selectedCoin;

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
  double _minZoomLevel = 0.5;
  double _maxZoomLevel = 2.0;

  @override
  void initState() {
    super.initState();

    // 차트 초기화
    _initChart();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // CryptoViewModel과 연결하여 데이터 자동 갱신
      final cryptoViewModel = Provider.of<CryptoViewModel>(
        context,
        listen: false,
      );

      // 설정된 새로고침 간격으로 타이머 설정
      _setupRefreshTimer();
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
    final settingsInterval = cryptoViewModel.refreshInterval;
    debugPrint('ChartScreen: 새로고침 타이머 설정 - $settingsInterval초');
    _refreshTimer = Timer.periodic(Duration(seconds: settingsInterval), (
      timer,
    ) {
      if (mounted) {
        setState(() {
          final coin = cryptoViewModel.topCoins.firstWhere(
            (c) => c.symbol == _selectedCoin.symbol,
            orElse: () => _selectedCoin,
          );
          _updateCurrentPrice(coin.currentPrice); // 라인 차트용
          _updateCurrentCandle(coin.currentPrice); // 캔들스틱 차트용
        });
      }
    });
  }

  // 차트 초기화
  void _initChart() {
    if (widget.selectedCoin != null) {
      _selectedCoin = widget.selectedCoin!;
    } else {
      _selectedCoin = DummyCoins.popularCoins.first;
    }
    _initChartData(); // 라인 차트용
    _initCandleDataList(); // 캔들스틱 차트용
  }

  // 과거 데이터 고정, 현재가만 실시간 업데이트
  void _initChartData() {
    final random = Random();
    final pointCount = _getPointCount();
    _chartData = [];
    // 과거 데이터: 랜덤 변동 (마지막 전까지)
    for (int i = 0; i < pointCount - 1; i++) {
      final y =
          _selectedCoin.currentPrice * (0.97 + 0.06 * random.nextDouble());
      _chartData.add(Point(i.toDouble(), y));
    }
    // 마지막 포인트(현재가)
    _chartData.add(
      Point((pointCount - 1).toDouble(), _selectedCoin.currentPrice),
    );
  }

  // 캔들스틱 데이터 초기화 (과거+현재)
  void _initCandleDataList() {
    final random = Random();
    final pointCount = _getPointCount();
    _candleDataList = [];
    double prevClose =
        _selectedCoin.currentPrice * (0.97 + 0.06 * random.nextDouble());
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
    final close = _selectedCoin.currentPrice;
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
        widget.selectedCoin != oldWidget.selectedCoin) {
      _updateSelectedCoin(widget.selectedCoin!);
    }
  }

  // 코인 변경 시 차트 업데이트
  void _updateSelectedCoin(Coin coin) {
    setState(() {
      _selectedCoin = coin;
      _initChartData();
      _initCandleDataList();
      _zoomLevel = 1.0;
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

    // 코인이 전달된 경우 해당 코인으로 차트 데이터 로드
    if (widget.selectedCoin != null &&
        widget.selectedCoin!.symbol != chartViewModel.selectedSymbol) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        chartViewModel.selectCoin(widget.selectedCoin!);
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.selectedCoin?.name ?? '차트'),
        actions: [
          // 오프라인 모드 토글 버튼
          const ChartOfflineToggle(),

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
      body: Column(
        children: [
          // 오프라인 모드 표시
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [ChartOfflineIndicator()],
            ),
          ),

          // 차트 타입 선택 탭
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildChartTypeSelector(context),
          ),

          // 시간 프레임 선택 탭
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: _buildTimeframeSelector(context),
          ),

          // 차트 영역
          Expanded(child: _buildChartArea(context)),
        ],
      ),
    );
  }

  // 차트 타입 선택 위젯
  Widget _buildChartTypeSelector(BuildContext context) {
    final chartViewModel = Provider.of<ChartViewModel>(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
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
    );
  }

  // 차트 타입 버튼
  Widget _buildChartTypeButton(
    BuildContext context,
    ChartType type,
    bool isSelected,
  ) {
    final chartViewModel = Provider.of<ChartViewModel>(context);

    return ElevatedButton(
      onPressed: () => chartViewModel.selectChartType(type),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.surface,
        foregroundColor: isSelected
            ? Theme.of(context).colorScheme.onPrimary
            : Theme.of(context).colorScheme.onSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      child: Text(chartViewModel.getChartTypeString(type)),
    );
  }

  // 시간 프레임 선택 위젯
  Widget _buildTimeframeSelector(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Row(
          children: [
            // 시간 프레임 그룹: 분 단위
            _buildTimeframeGroup(context, '분', [
              ChartTimeframe.minutes1,
              ChartTimeframe.minutes3,
              ChartTimeframe.minutes5,
              ChartTimeframe.minutes10,
              ChartTimeframe.minutes15,
              ChartTimeframe.minutes30,
              ChartTimeframe.minutes60,
            ]),

            const SizedBox(width: 12),

            // 시간 프레임 그룹: 일/주/월 단위
            _buildTimeframeGroup(context, '일/주/월', [
              ChartTimeframe.minutes240,
              ChartTimeframe.days1,
              ChartTimeframe.days7,
              ChartTimeframe.days30,
            ]),
          ],
        ),
      ),
    );
  }

  // 시간 프레임 그룹 위젯
  Widget _buildTimeframeGroup(
    BuildContext context,
    String groupName,
    List<ChartTimeframe> timeframes,
  ) {
    final chartViewModel = Provider.of<ChartViewModel>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 그룹 이름
        Padding(
          padding: const EdgeInsets.only(left: 4.0, bottom: 4.0),
          child: Text(
            groupName,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white70
                  : Colors.black54,
            ),
          ),
        ),

        // 시간 프레임 버튼들
        Row(
          children: timeframes.map((timeframe) {
            return _buildTimeframeButton(context, timeframe);
          }).toList(),
        ),
      ],
    );
  }

  // 시간 프레임 버튼
  Widget _buildTimeframeButton(BuildContext context, ChartTimeframe timeframe) {
    final chartViewModel = Provider.of<ChartViewModel>(context);
    final isSelected = chartViewModel.selectedTimeframe == timeframe;

    // 시간 프레임에 따라 요청 데이터 개수 최적화
    int dataPoints;
    switch (timeframe) {
      case ChartTimeframe.minutes1:
      case ChartTimeframe.minutes3:
        dataPoints = 60; // 1시간 분량
        break;
      case ChartTimeframe.minutes5:
      case ChartTimeframe.minutes10:
      case ChartTimeframe.minutes15:
        dataPoints = 72; // 6시간 분량
        break;
      case ChartTimeframe.minutes30:
      case ChartTimeframe.minutes60:
        dataPoints = 48; // 1일 분량
        break;
      case ChartTimeframe.minutes240:
        dataPoints = 30; // 5일 분량
        break;
      case ChartTimeframe.days1:
        dataPoints = 90; // 3개월 분량
        break;
      case ChartTimeframe.days7:
        dataPoints = 12; // 3개월 분량
        break;
      case ChartTimeframe.days30:
        dataPoints = 12; // 1년 분량
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Tooltip(
        message:
            '${chartViewModel.getTimeframeString(timeframe)} (약 $dataPoints개 데이터)',
        child: ElevatedButton(
          onPressed: () => chartViewModel.selectTimeframe(timeframe),
          style: ElevatedButton.styleFrom(
            backgroundColor: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.surface,
            foregroundColor: isSelected
                ? Theme.of(context).colorScheme.onPrimary
                : Theme.of(context).colorScheme.onSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            elevation: isSelected ? 2 : 0,
          ),
          child: Text(chartViewModel.getTimeframeString(timeframe)),
        ),
      ),
    );
  }

  // 차트 영역 위젯
  Widget _buildChartArea(BuildContext context) {
    final chartViewModel = Provider.of<ChartViewModel>(context);

    if (chartViewModel.isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('차트 데이터를 불러오는 중...', style: TextStyle(fontSize: 14)),
          ],
        ),
      );
    }

    if (chartViewModel.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              chartViewModel.error!,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
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
      );
    }

    // 차트 타입에 따라 다른 차트 위젯 반환
    if (chartViewModel.selectedChartType == ChartType.candlestick) {
      if (chartViewModel.candleChartData == null) {
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bar_chart, size: 48, color: Colors.grey),
              SizedBox(height: 16),
              Text('캔들스틱 차트 데이터가 없습니다.'),
            ],
          ),
        );
      }

      // 캔들스틱 차트 구현
      return Padding(
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
              child: CandleChartWidget(
                chartData: chartViewModel.candleChartData!,
                showVolume: true,
                showGrid: true,
                showTooltip: true,
                upColor: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF4CAF50) // 다크 모드에서는 녹색
                    : const Color(0xFF1976D2), // 라이트 모드에서는 파란색
                downColor: const Color(0xFFD32F2F), // 빨간색
              ),
            ),
          ],
        ),
      );
    } else {
      if (chartViewModel.lineChartData == null) {
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.show_chart, size: 48, color: Colors.grey),
              SizedBox(height: 16),
              Text('라인 차트 데이터가 없습니다.'),
            ],
          ),
        );
      }

      // 라인 차트 구현
      return Padding(
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
              child: LineChartWidget(
                chartData: chartViewModel.lineChartData!,
                showGrid: true,
                showTooltip: true,
                showGradient: true,
                lineColor: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF4CAF50) // 다크 모드에서는 녹색
                    : const Color(0xFF1976D2), // 라이트 모드에서는 파란색
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
        return AlertDialog(
          title: const Text('차트 설정'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 오프라인 모드 설정
              StatefulBuilder(
                builder: (context, setState) {
                  return SwitchListTile(
                    title: const Text('오프라인 모드'),
                    subtitle: const Text('인터넷 연결 없이 캐시된 데이터 사용'),
                    value: chartViewModel.isOfflineMode,
                    onChanged: (value) {
                      chartViewModel.setOfflineMode(value);
                      setState(() {});
                    },
                  );
                },
              ),

              // 캐시 정보
              FutureBuilder<int>(
                future: Provider.of<ChartCacheService>(
                  context,
                  listen: false,
                ).getCacheSize(),
                builder: (context, snapshot) {
                  final cacheSize = snapshot.data ?? 0;
                  final cacheSizeInMB = (cacheSize / (1024 * 1024))
                      .toStringAsFixed(2);

                  return ListTile(
                    title: const Text('캐시 크기'),
                    subtitle: Text('$cacheSizeInMB MB'),
                    trailing: TextButton(
                      onPressed: () async {
                        await Provider.of<ChartCacheService>(
                          context,
                          listen: false,
                        ).clearAllCache();
                        if (context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                      child: const Text('캐시 삭제'),
                    ),
                  );
                },
              ),
            ],
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
