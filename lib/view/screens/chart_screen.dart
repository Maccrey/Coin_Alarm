import 'package:flutter/material.dart';
import 'dart:math';
import '../../data/dummy_coins.dart';
import '../../model/coin_model.dart';
import '../../core/theme.dart';

// 차트 화면
class ChartScreen extends StatefulWidget {
  const ChartScreen({super.key});

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
  String _selectedChartType = '라인';

  // 차트 데이터 (더미 데이터)
  List<Point<double>> _chartData = [];

  @override
  void initState() {
    super.initState();
    _selectedCoin = DummyCoins.popularCoins.first;
    _generateChartData();
  }

  // 차트 데이터 생성 (더미 데이터)
  void _generateChartData() {
    final random = Random();
    final pointCount = _getPointCount();
    final startValue = _selectedCoin.currentPrice;
    final volatility = _getVolatility();

    _chartData = List.generate(pointCount, (index) {
      // 시간 경과에 따른 약간의 트렌드 추가
      final trend = sin(index / (pointCount / 4)) * volatility * 0.5;

      // 랜덤 가격 변동 생성
      final randomChange = (random.nextDouble() * 2 - 1) * volatility;

      // 최종 가격 계산
      final value = startValue * (1 + index * 0.001 + trend + randomChange);

      return Point<double>(index.toDouble(), value);
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

  // 기간별 변동성 결정
  double _getVolatility() {
    switch (_selectedTimeframe) {
      case '1일':
        return 0.005; // 일간 변동성 낮음
      case '1주일':
        return 0.02;
      case '1개월':
        return 0.05;
      case '3개월':
        return 0.08;
      case '1년':
        return 0.15;
      case '전체':
        return 0.25; // 장기 변동성 높음
      default:
        return 0.01;
    }
  }

  // 코인 변경 시 차트 업데이트
  void _updateSelectedCoin(Coin coin) {
    setState(() {
      _selectedCoin = coin;
      _generateChartData();
    });
  }

  // 기간 변경 시 차트 업데이트
  void _updateTimeframe(String timeframe) {
    setState(() {
      _selectedTimeframe = timeframe;
      _generateChartData();
    });
  }

  // 차트 유형 변경
  void _updateChartType(String chartType) {
    setState(() {
      _selectedChartType = chartType;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('차트')),
      body: Column(
        children: [
          // 코인 선택 드롭다운
          _buildCoinSelector(),

          // 차트 영역
          _buildChartArea(),

          // 차트 설정 영역
          _buildChartSettings(),

          // 시세 정보
          _buildPriceInfo(),
        ],
      ),
    );
  }

  // 코인 선택 드롭다운
  Widget _buildCoinSelector() {
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
              items: DummyCoins.popularCoins.map((coin) {
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
                  final coin = DummyCoins.getCoinBySymbol(value);
                  if (coin != null) {
                    _updateSelectedCoin(coin);
                  }
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
    return Expanded(
      child: Container(padding: const EdgeInsets.all(16), child: _buildChart()),
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

    final width = MediaQuery.of(context).size.width - 32; // 패딩 제외
    final height = MediaQuery.of(context).size.height * 0.4; // 차트 높이

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Y축 최대값
        Text(
          '₩${_formatPrice(maxY)}',
          style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
        ),
        const SizedBox(height: 4),

        // 실제 차트
        SizedBox(
          width: width,
          height: height,
          child: CustomPaint(
            painter: _selectedChartType == '라인'
                ? LineChartPainter(
                    points: _chartData,
                    minX: 0,
                    maxX: _chartData.length - 1.0,
                    minY: minY,
                    maxY: maxY,
                    color: (_selectedCoin.priceChangePercentage24h ?? 0) >= 0
                        ? Colors.green
                        : Colors.red,
                  )
                : CandleStickChartPainter(
                    points: _chartData,
                    minX: 0,
                    maxX: _chartData.length - 1.0,
                    minY: minY,
                    maxY: maxY,
                  ),
          ),
        ),

        const SizedBox(height: 4),
        // Y축 최소값
        Text(
          '₩${_formatPrice(minY)}',
          style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
        ),

        // X축 레이블
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
              '현재',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).hintColor,
              ),
            ),
          ],
        ),
      ],
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
        ? Colors.green
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

          // 고가/저가
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('24시간 고가'),
              Text('₩${_formatPrice(_selectedCoin.high24h ?? 0)}'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('24시간 저가'),
              Text('₩${_formatPrice(_selectedCoin.low24h ?? 0)}'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('24시간 거래량'),
              Text('₩${_formatPrice(_selectedCoin.volume24h ?? 0)}'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('시가총액'),
              Text('₩${_formatPrice(_selectedCoin.marketCap ?? 0)}'),
            ],
          ),
        ],
      ),
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
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final fillPaint = Paint()
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
    final gridPaint = Paint()
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

    // 그리드 그리기
    final gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.3)
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
    final candleWidth = size.width / (points.length + 1);

    for (int i = 0; i < points.length; i++) {
      final point = points[i];

      // X 좌표 계산
      final x = ((point.x - minX) / (maxX - minX)) * size.width;

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

      // 캔들 색상 (상승/하락)
      final isUp = currentValue >= openValue;
      final candleColor = isUp ? Colors.green : Colors.red;

      // 선 그리기 (고가-저가)
      canvas.drawLine(
        Offset(x, yHigh),
        Offset(x, yLow),
        Paint()
          ..color = candleColor
          ..strokeWidth = 1,
      );

      // 캔들 바디 그리기
      final candleRect = Rect.fromLTRB(
        x - candleWidth / 3,
        min(yOpen, yCurrent),
        x + candleWidth / 3,
        max(yOpen, yCurrent),
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
