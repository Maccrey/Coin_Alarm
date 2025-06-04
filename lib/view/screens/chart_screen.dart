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
    return Consumer<CryptoViewModel>(
      builder: (context, cryptoViewModel, child) {
        // 실시간 업데이트를 위한 코인 데이터 확인
        if (_selectedCoin != null && cryptoViewModel.topCoins.isNotEmpty) {
          final apiCoin = cryptoViewModel.topCoins.firstWhere(
            (coin) => coin.symbol == _selectedCoin.symbol,
            orElse: () => _selectedCoin,
          );

          // [개선] 코인 데이터가 업데이트되었으면 현재가만 갱신
          if (apiCoin.lastUpdated != _selectedCoin.lastUpdated) {
            _selectedCoin = apiCoin;
            _updateCurrentPrice(apiCoin.currentPrice);
            _updateCurrentCandle(apiCoin.currentPrice);
          }
        }

        return Column(
          children: [
            // 코인 선택 드롭다운
            _buildCoinSelector(cryptoViewModel),

            // 마지막 업데이트 시간 표시
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 4.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '마지막 업데이트: ${DateFormat('HH:mm:ss').format(cryptoViewModel.lastUpdated)}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  if (cryptoViewModel.activeService != null)
                    Text(
                      '${cryptoViewModel.activeService!.exchangeName}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                ],
              ),
            ),

            // 차트 영역
            Expanded(
              child: ListView(
                children: [
                  // 차트 영역
                  _buildChartArea(),
                  // 시세 정보
                  _buildPriceInfo(),

                  // 차트 설정 영역
                  _buildChartSettings(),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // 코인 선택 드롭다운
  Widget _buildCoinSelector(CryptoViewModel cryptoViewModel) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor, width: 1),
        ),
      ),
      child: Row(
        children: [
          // 코인 아이콘
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(16),
            ),
            child: _selectedCoin.imageUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      _selectedCoin.imageUrl!,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.currency_bitcoin),
                    ),
                  )
                : const Icon(Icons.currency_bitcoin),
          ),
          const SizedBox(width: 12),

          // 코인 드롭다운
          Expanded(
            child: DropdownButton<String>(
              value: _selectedCoin.symbol,
              isExpanded: true,
              underline: const SizedBox(),
              icon: const Icon(Icons.keyboard_arrow_down),
              items: cryptoViewModel.topCoins.map((coin) {
                return DropdownMenuItem<String>(
                  value: coin.symbol,
                  child: Text(
                    '${coin.name} (${coin.symbol})',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  final coin = cryptoViewModel.topCoins.firstWhere(
                    (coin) => coin.symbol == value,
                    orElse: () => _selectedCoin,
                  );
                  _updateSelectedCoin(coin);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  // 차트 영역
  Widget _buildChartArea() {
    return Column(
      children: [
        _buildZoomControls(),
        if (_selectedChartType == '라인')
          SizedBox(height: 200, child: _buildChart())
        else
          SizedBox(height: 200, child: _buildCandleChart()),
      ],
    );
  }

  // 확대/축소 컨트롤
  Widget _buildZoomControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          '확대/축소: ${(_zoomLevel * 100).toInt()}%',
          style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.zoom_out),
          iconSize: 20,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: _zoomLevel > _minZoomLevel
              ? () => _updateZoomLevel(-0.1)
              : null,
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: const Icon(Icons.zoom_in),
          iconSize: 20,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: _zoomLevel < _maxZoomLevel
              ? () => _updateZoomLevel(0.1)
              : null,
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: () {
            setState(() {
              _zoomLevel = 1.0;
            });
          },
          child: const Text('초기화'),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: Size.zero,
            textStyle: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }

  // 차트 위젯
  Widget _buildChart() {
    if (_chartData.isEmpty) {
      return const Center(child: Text('차트 데이터가 없습니다'));
    }

    // 차트 데이터의 최소/최대값 계산
    double minY = double.infinity;
    double maxY = -double.infinity;

    for (final point in _chartData) {
      if (point.y < minY) minY = point.y;
      if (point.y > maxY) maxY = point.y;
    }

    // [개선1] 차트 범위 여유(버퍼) 더 크게, min/max가 너무 가까우면 고정 폭 적용
    final range = maxY - minY;
    double buffer = range * 0.15;
    if (buffer < minY * 0.05) buffer = minY * 0.05; // 최소 버퍼
    if (range < minY * 0.05) {
      // 변동이 거의 없을 때
      minY -= minY * 0.05;
      maxY += minY * 0.05;
    } else {
      minY -= buffer;
      maxY += buffer;
    }

    // 확대/축소 적용 - 가격 범위 조정
    final zoomedRange = (maxY - minY) / _zoomLevel;
    final mid = (maxY + minY) / 2;
    final zoomedMinY = mid - zoomedRange / 2;
    final zoomedMaxY = mid + zoomedRange / 2;

    // 가격 상승/하락에 따른 차트 색상 결정
    final chartColor = (_selectedCoin.priceChangePercentage24h ?? 0) >= 0
        ? AppTheme.positiveColor
        : Colors.red;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight - 40;

        return GestureDetector(
          onScaleUpdate: (details) {
            if (details.scale != 1.0) {
              final newZoomLevel = _zoomLevel * details.scale;
              setState(() {
                _zoomLevel = newZoomLevel.clamp(_minZoomLevel, _maxZoomLevel);
              });
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white, // [개선3] 차트 배경 밝게
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 0,
            ), // [개선4] 패딩 조정
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Y축 최대값
                Text(
                  '₩${_formatPrice(zoomedMaxY)}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).hintColor,
                    fontWeight: FontWeight.bold, // [개선3] 폰트 진하게
                  ),
                ),
                // 실제 차트
                SizedBox(
                  width: width,
                  height: height,
                  child: CustomPaint(
                    painter: SmoothLineChartPainter(
                      points: _chartData,
                      minX: 0,
                      maxX: _chartData.length - 1.0,
                      minY: zoomedMinY,
                      maxY: zoomedMaxY,
                      color: chartColor,
                    ),
                  ),
                ),
                // X축 및 Y축 최소값
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _getStartTimeLabel(),
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).hintColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '₩${_formatPrice(zoomedMinY)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).hintColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '현재',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).hintColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 차트 설정 영역
  Widget _buildChartSettings() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor, width: 1),
        ),
      ),
      child: Column(
        children: [
          // 기간 선택 버튼
          Row(
            children: [
              const Text('기간:'),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _timeframes.map((timeframe) {
                      final isSelected = timeframe == _selectedTimeframe;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(timeframe),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              _updateTimeframe(timeframe);
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 차트 유형 선택
          Row(
            children: [
              const Text('차트 유형:'),
              const SizedBox(width: 8),
              ...List<Widget>.generate(_chartTypes.length, (index) {
                final type = _chartTypes[index];
                final isSelected = type == _selectedChartType;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(type),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        _updateChartType(type);
                      }
                    },
                  ),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  // 시세 정보 영역
  Widget _buildPriceInfo() {
    // 가격 변화 표시
    final priceChangeText = (_selectedCoin.priceChangePercentage24h ?? 0) >= 0
        ? '+${_selectedCoin.priceChangePercentage24h?.toStringAsFixed(2) ?? '0.00'}%'
        : '${_selectedCoin.priceChangePercentage24h?.toStringAsFixed(2) ?? '0.00'}%';

    // 가격 변화 색상
    final priceChangeColor = (_selectedCoin.priceChangePercentage24h ?? 0) >= 0
        ? AppTheme
              .positiveColor // 파란색으로 변경
        : Colors.red;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor, width: 1),
        ),
      ),
      child: Column(
        children: [
          // 현재가
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('현재가', style: TextStyle(fontWeight: FontWeight.bold)),
              Row(
                children: [
                  Text(
                    '₩${_formatPrice(_selectedCoin.currentPrice)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: priceChangeColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      priceChangeText,
                      style: TextStyle(
                        fontSize: 12,
                        color: priceChangeColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 주요 지표 정보를 그리드로 표시 (공간 효율화)
          Row(
            children: [
              // 왼쪽 열
              Expanded(
                child: Column(
                  children: [
                    _buildInfoRow(
                      '24시간 고가',
                      '₩${_formatPrice(_selectedCoin.high24h ?? 0)}',
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      '24시간 저가',
                      '₩${_formatPrice(_selectedCoin.low24h ?? 0)}',
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // 오른쪽 열
              Expanded(
                child: Column(
                  children: [
                    _buildInfoRow(
                      '24시간 거래량',
                      '₩${_formatPrice(_selectedCoin.volume24h ?? 0)}',
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      '시가총액',
                      '₩${_formatPrice(_selectedCoin.marketCap ?? 0)}',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 정보 행 위젯 (레이아웃 일관성 유지)
  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13)),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        ),
      ],
    );
  }

  // 가격 포맷팅 함수
  String _formatPrice(double price) {
    if (price >= 1000000000) {
      return '${(price / 1000000000).toStringAsFixed(2)}B';
    } else if (price >= 1000000) {
      return '${(price / 1000000).toStringAsFixed(2)}M';
    } else if (price >= 1000) {
      return '${price.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}';
    } else if (price >= 1) {
      return price.toStringAsFixed(2);
    } else {
      return price.toStringAsFixed(6);
    }
  }

  // 시작 시간 레이블
  String _getStartTimeLabel() {
    final now = DateTime.now();

    switch (_selectedTimeframe) {
      case '1일':
        return '24시간 전';
      case '1주일':
        return '${now.subtract(const Duration(days: 7)).month}/${now.subtract(const Duration(days: 7)).day}';
      case '1개월':
        return '${now.subtract(const Duration(days: 30)).month}/${now.subtract(const Duration(days: 30)).day}';
      case '3개월':
        return '${now.subtract(const Duration(days: 90)).month}/${now.subtract(const Duration(days: 90)).day}';
      case '1년':
        return '${now.subtract(const Duration(days: 365)).year}';
      case '전체':
        return '시작';
      default:
        return '';
    }
  }

  // 캔들스틱 차트 영역
  Widget _buildCandleChart() {
    if (_candleDataList.isEmpty) {
      return const Center(child: Text('차트 데이터가 없습니다'));
    }
    // min/max 계산 (빈 데이터 방어)
    double minY = _candleDataList.isNotEmpty
        ? _candleDataList.map((c) => c.low).reduce((a, b) => a < b ? a : b)
        : 0;
    double maxY = _candleDataList.isNotEmpty
        ? _candleDataList.map((c) => c.high).reduce((a, b) => a > b ? a : b)
        : 1;
    final range = maxY - minY;
    double buffer = range * 0.15;
    if (buffer < minY * 0.05) buffer = minY * 0.05;
    if (range < minY * 0.05) {
      minY -= minY * 0.05;
      maxY += minY * 0.05;
    } else {
      minY -= buffer;
      maxY += buffer;
    }
    final zoomedRange = (maxY - minY) / _zoomLevel;
    final mid = (maxY + minY) / 2;
    final zoomedMinY = mid - zoomedRange / 2;
    final zoomedMaxY = mid + zoomedRange / 2;
    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: CustomPaint(
        painter: ExchangeStyleCandleStickPainter(
          candles: _candleDataList,
          minX: 0,
          maxX: _candleDataList.length - 1.0,
          minY: zoomedMinY,
          maxY: zoomedMaxY,
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
