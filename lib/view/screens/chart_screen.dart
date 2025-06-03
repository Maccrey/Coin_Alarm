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

  // 차트 데이터 (임시 데이터)
  List<Point<double>> _chartData = [];

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
    // 이전 타이머 취소
    _refreshTimer?.cancel();

    // SettingsService에서 새로고침 간격 가져오기
    final cryptoViewModel = Provider.of<CryptoViewModel>(
      context,
      listen: false,
    );
    final settingsInterval = cryptoViewModel.refreshInterval;

    debugPrint('ChartScreen: 새로고침 타이머 설정 - $settingsInterval초');

    // 타이머 설정
    _refreshTimer = Timer.periodic(Duration(seconds: settingsInterval), (
      timer,
    ) {
      if (mounted) {
        setState(() {
          // 차트 데이터 업데이트
          _generateChartData();
        });
      }
    });
  }

  // 차트 초기화
  void _initChart() {
    // 초기 코인 설정
    if (widget.selectedCoin != null) {
      _selectedCoin = widget.selectedCoin!;
    } else {
      // 기본 코인은 DummyCoins에서 가져옴
      _selectedCoin = DummyCoins.popularCoins.first;
    }

    // 임시 차트 데이터 생성
    _generateChartData();
  }

  // 차트 데이터 생성 (더미 데이터)
  void _generateChartData() {
    final random = Random();
    final pointCount = _getPointCount();

    // 기존 데이터 초기화
    _chartData = [];

    // 랜덤 데이터 생성
    for (var i = 0; i < pointCount; i++) {
      final x = i.toDouble();
      final y =
          _selectedCoin.currentPrice * (0.97 + 0.06 * random.nextDouble());
      _chartData.add(Point(x, y));
    }

    debugPrint('ChartScreen: 차트 데이터 업데이트됨 - ${DateTime.now().toString()}');
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
      _generateChartData();
      _zoomLevel = 1.0; // 코인 변경 시 줌 레벨 초기화
    });
  }

  // 기간 변경 시 차트 업데이트
  void _updateTimeframe(String timeframe) {
    setState(() {
      _selectedTimeframe = timeframe;
      _generateChartData();
      _zoomLevel = 1.0; // 기간 변경 시 줌 레벨 초기화
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

          // 코인 데이터가 업데이트되었으면 차트 데이터도 업데이트
          if (apiCoin.lastUpdated != _selectedCoin.lastUpdated) {
            _selectedCoin = apiCoin;
            _generateChartData();
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

                  // 차트 설정 영역
                  _buildChartSettings(),

                  // 시세 정보
                  _buildPriceInfo(),
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
            child:
                _selectedCoin.imageUrl != null
                    ? ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        _selectedCoin.imageUrl!,
                        errorBuilder:
                            (context, error, stackTrace) =>
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
              items:
                  cryptoViewModel.topCoins.map((coin) {
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
    return Container(
      padding: const EdgeInsets.all(16),
      height: 350, // 고정 높이로 설정
      child: Column(
        children: [
          // 확대/축소 컨트롤
          _buildZoomControls(),

          // 차트
          Expanded(child: _buildChart()),
        ],
      ),
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
          onPressed:
              _zoomLevel > _minZoomLevel ? () => _updateZoomLevel(-0.1) : null,
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: const Icon(Icons.zoom_in),
          iconSize: 20,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed:
              _zoomLevel < _maxZoomLevel ? () => _updateZoomLevel(0.1) : null,
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

    // 차트 범위 여유 추가
    final range = maxY - minY;
    minY -= range * 0.05;
    maxY += range * 0.05;

    // 확대/축소 적용 - 가격 범위 조정
    final zoomedRange = range / _zoomLevel;
    final mid = (maxY + minY) / 2;
    final zoomedMinY = mid - zoomedRange / 2;
    final zoomedMaxY = mid + zoomedRange / 2;

    // 가격 상승/하락에 따른 차트 색상 결정
    final chartColor =
        (_selectedCoin.priceChangePercentage24h ?? 0) >= 0
            ? AppTheme
                .positiveColor // 파란색
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Y축 최대값
              Text(
                '₩${_formatPrice(zoomedMaxY)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).hintColor,
                ),
              ),

              // 실제 차트
              SizedBox(
                width: width,
                height: height,
                child: CustomPaint(
                  painter:
                      _selectedChartType == '라인'
                          ? LineChartPainter(
                            points: _chartData,
                            minX: 0,
                            maxX: _chartData.length - 1.0,
                            minY: zoomedMinY,
                            maxY: zoomedMaxY,
                            color: chartColor,
                          )
                          : CandleStickChartPainter(
                            points: _chartData,
                            minX: 0,
                            maxX: _chartData.length - 1.0,
                            minY: zoomedMinY,
                            maxY: zoomedMaxY,
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
                    ),
                  ),
                  Text(
                    '₩${_formatPrice(zoomedMinY)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                  Text(
                    '현재',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                ],
              ),
            ],
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
                    children:
                        _timeframes.map((timeframe) {
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
    final priceChangeText =
        (_selectedCoin.priceChangePercentage24h ?? 0) >= 0
            ? '+${_selectedCoin.priceChangePercentage24h?.toStringAsFixed(2) ?? '0.00'}%'
            : '${_selectedCoin.priceChangePercentage24h?.toStringAsFixed(2) ?? '0.00'}%';

    // 가격 변화 색상
    final priceChangeColor =
        (_selectedCoin.priceChangePercentage24h ?? 0) >= 0
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
}

// 라인 차트 페인터
class LineChartPainter extends CustomPainter {
  final List<Point<double>> points;
  final double minX;
  final double maxX;
  final double minY;
  final double maxY;
  final Color color;

  LineChartPainter({
    required this.points,
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
    this.color = Colors.blue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;

    final fillPaint =
        Paint()
          ..color = color.withOpacity(0.2)
          ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();

    bool isFirst = true;

    for (int i = 0; i < points.length; i++) {
      final point = points[i];

      // X, Y 좌표 계산
      final x = ((point.x - minX) / (maxX - minX)) * size.width;
      final y = size.height - ((point.y - minY) / (maxY - minY)) * size.height;

      // 범위를 벗어난 경우 처리
      if (y.isNaN || y.isInfinite || y < 0 || y > size.height) {
        continue;
      }

      if (isFirst) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
        isFirst = false;
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    // 채우기 경로 완성
    if (points.isNotEmpty) {
      final lastX = ((points.last.x - minX) / (maxX - minX)) * size.width;
      fillPath.lineTo(lastX, size.height);
      fillPath.close();
    }

    // 그리기
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

    // 가로 격자선
    final gridPaint =
        Paint()
          ..color = Colors.grey.withOpacity(0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5;

    for (int i = 1; i < 5; i++) {
      final y = i * size.height / 5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // 세로 격자선
    for (int i = 1; i < 5; i++) {
      final x = i * size.width / 5;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

// 캔들스틱 차트 페인터
class CandleStickChartPainter extends CustomPainter {
  final List<Point<double>> points;
  final double minX;
  final double maxX;
  final double minY;
  final double maxY;

  CandleStickChartPainter({
    required this.points,
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(42); // 일관된 랜덤 시드 사용

    // 배경 그리기
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.black.withOpacity(0.03),
    );

    // 그리드 그리기
    final gridPaint =
        Paint()
          ..color = Colors.grey.withOpacity(0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5;

    // 수평 그리드 (가격 레벨)
    for (int i = 1; i < 5; i++) {
      final y = i * size.height / 5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);

      // 가격 레이블 추가 - 텍스트 페인터 사용 제거
      // 간단한 가격 표시로 대체
      final priceLevel = minY + (maxY - minY) * (1 - i / 5);
      final paint = Paint()..color = Colors.grey.withOpacity(0.7);

      // 단순히 선으로 표시
      canvas.drawLine(Offset(0, y), Offset(10, y), paint..strokeWidth = 2);
    }

    // 수직 그리드 (시간 간격)
    for (int i = 1; i < 5; i++) {
      final x = i * size.width / 5;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    // 캔들스틱 그리기
    final candleWidth = (size.width / (points.length + 1)).clamp(2.0, 20.0);
    final candleSpacing =
        (size.width - candleWidth * points.length) / (points.length + 1);

    for (int i = 0; i < points.length; i++) {
      final point = points[i];

      // X 좌표 계산
      final x =
          candleSpacing + i * (candleWidth + candleSpacing) + candleWidth / 2;

      // 캔들스틱 데이터 생성 (더미)
      final currentValue = point.y;
      final openValue =
          currentValue * (1 + (random.nextDouble() * 0.02 - 0.01));
      final highValue =
          max(currentValue, openValue) * (1 + random.nextDouble() * 0.01);
      final lowValue =
          min(currentValue, openValue) * (1 - random.nextDouble() * 0.01);

      // Y 좌표 계산
      final yOpen =
          size.height - ((openValue - minY) / (maxY - minY)) * size.height;
      final yCurrent =
          size.height - ((currentValue - minY) / (maxY - minY)) * size.height;
      final yHigh =
          size.height - ((highValue - minY) / (maxY - minY)) * size.height;
      final yLow =
          size.height - ((lowValue - minY) / (maxY - minY)) * size.height;

      // 범위를 벗어난 경우 처리
      if (yOpen.isNaN ||
          yOpen.isInfinite ||
          yCurrent.isNaN ||
          yCurrent.isInfinite ||
          yHigh.isNaN ||
          yHigh.isInfinite ||
          yLow.isNaN ||
          yLow.isInfinite) {
        continue;
      }

      // 캔들 색상 (상승/하락)
      final isUp = currentValue >= openValue;
      final candleColor = isUp ? AppTheme.positiveColor : Colors.red;

      // 그림자 선 그리기 (고가-저가)
      canvas.drawLine(
        Offset(x, yHigh.clamp(0, size.height)),
        Offset(x, yLow.clamp(0, size.height)),
        Paint()
          ..color = candleColor
          ..strokeWidth = 1,
      );

      // 캔들 바디 그리기
      final candleRect = Rect.fromLTRB(
        x - candleWidth / 2,
        min(yOpen, yCurrent).clamp(0, size.height),
        x + candleWidth / 2,
        max(yOpen, yCurrent).clamp(0, size.height),
      );

      canvas.drawRect(
        candleRect,
        Paint()
          ..color = candleColor
          ..style = isUp ? PaintingStyle.stroke : PaintingStyle.fill
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
