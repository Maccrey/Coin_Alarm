import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../model/chart_data_model.dart';
import 'dart:math';

/// 캔들스틱 차트 위젯
class CandleChartWidget extends StatefulWidget {
  final CandleChartData chartData;
  final bool showVolume;
  final bool showGrid;
  final bool showTooltip;
  final Color upColor;
  final Color downColor;
  final Color gridColor;
  final Color textColor;
  final double candleWidth;
  final double candleSpacing;

  const CandleChartWidget({
    super.key,
    required this.chartData,
    this.showVolume = true,
    this.showGrid = true,
    this.showTooltip = true,
    this.upColor = const Color(0xFF1976D2), // 파란색
    this.downColor = const Color(0xFFD32F2F), // 빨간색
    this.gridColor = const Color(0x22000000), // 연한 회색
    this.textColor = const Color(0xFF757575), // 중간 회색
    this.candleWidth = 10.0,
    this.candleSpacing = 2.0,
  });

  @override
  State<CandleChartWidget> createState() => _CandleChartWidgetState();
}

class _CandleChartWidgetState extends State<CandleChartWidget> {
  // 줌 및 스크롤 관련 변수
  double _scale = 1.0;
  double _previousScale = 1.0;
  double _startScrollOffset = 0.0;
  double _scrollOffset = 0.0;
  int? _selectedCandleIndex;
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.chartData.candles.isEmpty) {
      return const Center(child: Text('데이터가 없습니다'));
    }

    // 테마에 따른 색상 조정
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode
        ? Theme.of(context).scaffoldBackgroundColor
        : Colors.white;
    final labelBackgroundColor = isDarkMode
        ? Colors.black.withOpacity(0.7)
        : Colors.white.withOpacity(0.7);
    final gridColor = isDarkMode
        ? Colors.white.withOpacity(0.1)
        : Colors.black.withOpacity(0.1);
    final textColor = isDarkMode ? Colors.white70 : Colors.black54;

    return LayoutBuilder(
      builder: (context, constraints) {
        final candles = widget.chartData.candles;
        final totalCandleWidth = widget.candleWidth + widget.candleSpacing;
        final totalWidth = totalCandleWidth * candles.length * _scale;
        final visibleWidth = constraints.maxWidth;
        final chartHeight =
            constraints.maxHeight * (widget.showVolume ? 0.8 : 1.0);
        final volumeHeight =
            constraints.maxHeight * (widget.showVolume ? 0.2 : 0.0);

        return GestureDetector(
          onScaleStart: (details) {
            _previousScale = _scale;
            _startScrollOffset = _scrollOffset;
          },
          onScaleUpdate: (details) {
            setState(() {
              // 확대/축소
              _scale = (_previousScale * details.scale).clamp(1.0, 5.0);

              // 스크롤 위치 조정
              if (details.scale == 1.0) {
                final delta = details.focalPointDelta.dx;
                _scrollOffset = (_scrollOffset - delta).clamp(
                  0.0,
                  max(0.0, totalWidth - visibleWidth),
                );
              }
            });
          },
          onTapUp: (details) {
            final localPosition = details.localPosition;
            final candleIndex = _getCandleIndexAtPosition(
              localPosition.dx,
              totalCandleWidth,
            );

            setState(() {
              _selectedCandleIndex = candleIndex;
            });
          },
          child: Stack(
            children: [
              // 배경
              Container(
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                color: backgroundColor,
              ),

              // 차트 영역
              SingleChildScrollView(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                child: SizedBox(
                  width: totalWidth,
                  height: constraints.maxHeight,
                  child: CustomPaint(
                    painter: CandlestickChartPainter(
                      candles: candles,
                      upColor: widget.upColor,
                      downColor: widget.downColor,
                      gridColor: gridColor,
                      textColor: textColor,
                      showGrid: widget.showGrid,
                      showVolume: widget.showVolume,
                      candleWidth: widget.candleWidth,
                      candleSpacing: widget.candleSpacing,
                      scale: _scale,
                      scrollOffset: _scrollOffset,
                      selectedCandleIndex: _selectedCandleIndex,
                      chartHeight: chartHeight,
                      volumeHeight: volumeHeight,
                      isDarkMode: isDarkMode,
                    ),
                  ),
                ),
              ),

              // 툴팁 (선택된 캔들이 있는 경우)
              if (widget.showTooltip &&
                  _selectedCandleIndex != null &&
                  _selectedCandleIndex! < candles.length)
                Positioned(
                  top: 8,
                  right: 8,
                  child: _buildTooltip(
                    candles[_selectedCandleIndex!],
                    isDarkMode,
                  ),
                ),

              // 가격 레이블 (우측)
              Positioned(
                top: 0,
                right: 0,
                bottom: widget.showVolume ? volumeHeight : 0,
                child: _buildPriceLabels(
                  candles,
                  chartHeight,
                  labelBackgroundColor,
                  textColor,
                ),
              ),

              // 날짜 레이블 (하단)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _buildDateLabels(
                  candles,
                  labelBackgroundColor,
                  textColor,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 가격 레이블 위젯
  Widget _buildPriceLabels(
    List<CandleData> candles,
    double chartHeight,
    Color backgroundColor,
    Color textColor,
  ) {
    // 최대/최소 가격 계산
    double minPrice = double.infinity;
    double maxPrice = -double.infinity;

    for (final candle in candles) {
      minPrice = min(minPrice, candle.low);
      maxPrice = max(maxPrice, candle.high);
    }

    // 가격 범위에 여유 공간 추가
    final range = maxPrice - minPrice;
    final buffer = range * 0.05;
    minPrice -= buffer;
    maxPrice += buffer;

    return Container(
      width: 70,
      color: backgroundColor,
      padding: const EdgeInsets.only(right: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _formatPrice(maxPrice),
            style: TextStyle(fontSize: 10, color: textColor),
          ),
          Text(
            _formatPrice(minPrice + (maxPrice - minPrice) * 0.75),
            style: TextStyle(fontSize: 10, color: textColor),
          ),
          Text(
            _formatPrice(minPrice + (maxPrice - minPrice) * 0.5),
            style: TextStyle(fontSize: 10, color: textColor),
          ),
          Text(
            _formatPrice(minPrice + (maxPrice - minPrice) * 0.25),
            style: TextStyle(fontSize: 10, color: textColor),
          ),
          Text(
            _formatPrice(minPrice),
            style: TextStyle(fontSize: 10, color: textColor),
          ),
        ],
      ),
    );
  }

  // 날짜 레이블 위젯
  Widget _buildDateLabels(
    List<CandleData> candles,
    Color backgroundColor,
    Color textColor,
  ) {
    final dateFormat = DateFormat('MM/dd');
    final timeFormat = DateFormat('HH:mm');

    // 시간 프레임에 따라 표시할 날짜 개수 조정
    final timeframe = widget.chartData.timeframe;
    int skipFactor;

    switch (timeframe) {
      case ChartTimeframe.minutes1:
      case ChartTimeframe.minutes3:
      case ChartTimeframe.minutes5:
        skipFactor = 10;
        break;
      case ChartTimeframe.minutes10:
      case ChartTimeframe.minutes15:
      case ChartTimeframe.minutes30:
        skipFactor = 6;
        break;
      case ChartTimeframe.minutes60:
      case ChartTimeframe.minutes240:
        skipFactor = 4;
        break;
      default:
        skipFactor = 2;
    }

    return Container(
      height: 20,
      color: backgroundColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (int i = 0; i < candles.length; i += skipFactor)
            if (i < candles.length)
              SizedBox(
                width: 50,
                child: Text(
                  _isMinutesTimeframe(timeframe)
                      ? timeFormat.format(candles[i].timestamp)
                      : dateFormat.format(candles[i].timestamp),
                  style: TextStyle(fontSize: 10, color: textColor),
                  textAlign: TextAlign.center,
                ),
              ),
        ],
      ),
    );
  }

  // 툴팁 위젯
  Widget _buildTooltip(CandleData candle, bool isDarkMode) {
    final dateFormat = DateFormat('yyyy-MM-dd');
    final timeFormat = DateFormat('HH:mm:ss');

    final tooltipBackgroundColor = isDarkMode
        ? Colors.white.withOpacity(0.15)
        : Colors.black.withOpacity(0.7);
    final tooltipTextColor = isDarkMode ? Colors.white : Colors.white;
    final tooltipLabelColor = isDarkMode ? Colors.white70 : Colors.grey;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: tooltipBackgroundColor,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${dateFormat.format(candle.timestamp)} ${timeFormat.format(candle.timestamp)}',
            style: TextStyle(color: tooltipTextColor, fontSize: 12),
          ),
          const SizedBox(height: 4),
          _buildTooltipRow(
            '시가',
            _formatPrice(candle.open),
            tooltipLabelColor,
            tooltipTextColor,
          ),
          _buildTooltipRow(
            '고가',
            _formatPrice(candle.high),
            tooltipLabelColor,
            tooltipTextColor,
          ),
          _buildTooltipRow(
            '저가',
            _formatPrice(candle.low),
            tooltipLabelColor,
            tooltipTextColor,
          ),
          _buildTooltipRow(
            '종가',
            _formatPrice(candle.close),
            tooltipLabelColor,
            tooltipTextColor,
          ),
          _buildTooltipRow(
            '거래량',
            _formatVolume(candle.volume),
            tooltipLabelColor,
            tooltipTextColor,
          ),
        ],
      ),
    );
  }

  // 툴팁 행 위젯
  Widget _buildTooltipRow(
    String label,
    String value,
    Color labelColor,
    Color valueColor,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              label,
              style: TextStyle(color: labelColor, fontSize: 12),
            ),
          ),
          Text(value, style: TextStyle(color: valueColor, fontSize: 12)),
        ],
      ),
    );
  }

  // 가격 포맷팅
  String _formatPrice(double price) {
    if (price >= 1000000) {
      return '${(price / 1000000).toStringAsFixed(2)}M';
    } else if (price >= 1000) {
      return '${(price / 1000).toStringAsFixed(2)}K';
    } else if (price >= 1) {
      return price.toStringAsFixed(2);
    } else {
      return price.toStringAsFixed(6);
    }
  }

  // 거래량 포맷팅
  String _formatVolume(double volume) {
    if (volume >= 1000000) {
      return '${(volume / 1000000).toStringAsFixed(2)}M';
    } else if (volume >= 1000) {
      return '${(volume / 1000).toStringAsFixed(2)}K';
    } else {
      return volume.toStringAsFixed(2);
    }
  }

  // 분 단위 시간 프레임인지 확인
  bool _isMinutesTimeframe(ChartTimeframe timeframe) {
    return timeframe == ChartTimeframe.minutes1 ||
        timeframe == ChartTimeframe.minutes3 ||
        timeframe == ChartTimeframe.minutes5 ||
        timeframe == ChartTimeframe.minutes10 ||
        timeframe == ChartTimeframe.minutes15 ||
        timeframe == ChartTimeframe.minutes30 ||
        timeframe == ChartTimeframe.minutes60 ||
        timeframe == ChartTimeframe.minutes240;
  }

  // 특정 위치의 캔들 인덱스 계산
  int? _getCandleIndexAtPosition(double position, double totalCandleWidth) {
    final adjustedPosition = position + _scrollOffset;
    final index = (adjustedPosition / (totalCandleWidth * _scale)).floor();

    if (index >= 0 && index < widget.chartData.candles.length) {
      return index;
    }
    return null;
  }
}

/// 캔들스틱 차트 페인터
class CandlestickChartPainter extends CustomPainter {
  final List<CandleData> candles;
  final Color upColor;
  final Color downColor;
  final Color gridColor;
  final Color textColor;
  final bool showGrid;
  final bool showVolume;
  final double candleWidth;
  final double candleSpacing;
  final double scale;
  final double scrollOffset;
  final int? selectedCandleIndex;
  final double chartHeight;
  final double volumeHeight;
  final bool isDarkMode;

  CandlestickChartPainter({
    required this.candles,
    required this.upColor,
    required this.downColor,
    required this.gridColor,
    required this.textColor,
    required this.showGrid,
    required this.showVolume,
    required this.candleWidth,
    required this.candleSpacing,
    required this.scale,
    required this.scrollOffset,
    required this.selectedCandleIndex,
    required this.chartHeight,
    required this.volumeHeight,
    required this.isDarkMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (candles.isEmpty) return;

    // 가격 범위 계산
    double minPrice = double.infinity;
    double maxPrice = -double.infinity;
    double maxVolume = 0;

    for (final candle in candles) {
      minPrice = min(minPrice, candle.low);
      maxPrice = max(maxPrice, candle.high);
      maxVolume = max(maxVolume, candle.volume);
    }

    // 가격 범위에 여유 공간 추가
    final range = maxPrice - minPrice;
    final buffer = range * 0.05;
    minPrice -= buffer;
    maxPrice += buffer;

    // 그리드 그리기
    if (showGrid) {
      _drawGrid(canvas, size, minPrice, maxPrice);
    }

    // 캔들스틱 그리기
    final effectiveCandleWidth = candleWidth * scale;
    final effectiveCandleSpacing = candleSpacing * scale;
    final totalCandleWidth = effectiveCandleWidth + effectiveCandleSpacing;

    for (int i = 0; i < candles.length; i++) {
      final candle = candles[i];
      final x = i * totalCandleWidth - scrollOffset;

      // 화면에 보이는 캔들만 그리기 (성능 최적화)
      if (x + effectiveCandleWidth < 0 ||
          x - effectiveCandleWidth > size.width) {
        continue;
      }

      // 캔들스틱 그리기
      _drawCandle(
        canvas,
        x,
        candle,
        minPrice,
        maxPrice,
        effectiveCandleWidth,
        chartHeight,
      );

      // 거래량 그리기
      if (showVolume) {
        _drawVolume(
          canvas,
          x,
          candle,
          maxVolume,
          effectiveCandleWidth,
          chartHeight,
          volumeHeight,
        );
      }

      // 선택된 캔들 강조 표시
      if (selectedCandleIndex == i) {
        _drawSelectedCandle(
          canvas,
          x,
          candle,
          minPrice,
          maxPrice,
          effectiveCandleWidth,
          chartHeight,
        );
      }
    }
  }

  // 그리드 그리기
  void _drawGrid(Canvas canvas, Size size, double minPrice, double maxPrice) {
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.5;

    // 수평 그리드 (가격 레벨)
    for (int i = 0; i <= 4; i++) {
      final y = chartHeight * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // 수직 그리드 (시간)
    for (int i = 0; i <= 4; i++) {
      final x = size.width * i / 4;
      canvas.drawLine(Offset(x, 0), Offset(x, chartHeight), gridPaint);
    }
  }

  // 캔들스틱 그리기
  void _drawCandle(
    Canvas canvas,
    double x,
    CandleData candle,
    double minPrice,
    double maxPrice,
    double width,
    double height,
  ) {
    final priceRange = maxPrice - minPrice;

    // 가격을 Y좌표로 변환
    final openY = height - ((candle.open - minPrice) / priceRange) * height;
    final closeY = height - ((candle.close - minPrice) / priceRange) * height;
    final highY = height - ((candle.high - minPrice) / priceRange) * height;
    final lowY = height - ((candle.low - minPrice) / priceRange) * height;

    final isUp = candle.close >= candle.open;
    final color = isUp ? upColor : downColor;

    // 심지 (고가-저가)
    final wickPaint = Paint()
      ..color = color
      ..strokeWidth = 1.0;

    canvas.drawLine(Offset(x, highY), Offset(x, lowY), wickPaint);

    // 캔들 몸통
    final bodyPaint = Paint()
      ..color = isUp ? upColor.withOpacity(0.8) : downColor.withOpacity(0.8)
      ..style = PaintingStyle.fill;

    final bodyTop = min(openY, closeY);
    final bodyBottom = max(openY, closeY);
    final bodyHeight = bodyBottom - bodyTop;

    // 몸통이 너무 작으면 최소 크기 적용
    final effectiveBodyHeight = max(bodyHeight, 1.0);

    canvas.drawRect(
      Rect.fromLTWH(x - width / 2, bodyTop, width, effectiveBodyHeight),
      bodyPaint,
    );

    // 테두리
    final borderPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawRect(
      Rect.fromLTWH(x - width / 2, bodyTop, width, effectiveBodyHeight),
      borderPaint,
    );
  }

  // 거래량 그리기
  void _drawVolume(
    Canvas canvas,
    double x,
    CandleData candle,
    double maxVolume,
    double width,
    double chartHeight,
    double volumeHeight,
  ) {
    if (maxVolume <= 0) return;

    final isUp = candle.close >= candle.open;
    final color = isUp ? upColor : downColor;

    final volumeRatio = candle.volume / maxVolume;
    final barHeight = volumeRatio * volumeHeight;

    final volumePaint = Paint()
      ..color = color.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTWH(
        x - width / 2,
        chartHeight + volumeHeight - barHeight,
        width,
        barHeight,
      ),
      volumePaint,
    );
  }

  // 선택된 캔들 강조 표시
  void _drawSelectedCandle(
    Canvas canvas,
    double x,
    CandleData candle,
    double minPrice,
    double maxPrice,
    double width,
    double height,
  ) {
    final priceRange = maxPrice - minPrice;

    // 가격을 Y좌표로 변환
    final closePrice = candle.close;
    final closePriceY =
        height - ((closePrice - minPrice) / priceRange) * height;

    // 선택된 캔들 배경
    final highlightPaint = Paint()
      ..color = isDarkMode
          ? Colors.white.withOpacity(0.1)
          : Colors.yellow.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTWH(x - width, 0, width * 2, height),
      highlightPaint,
    );

    // 가격 선
    final pricePaint = Paint()
      ..color = isDarkMode
          ? Colors.white.withOpacity(0.3)
          : Colors.black.withOpacity(0.3)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // 점선 효과를 위한 패턴
    final dashWidth = 4.0;
    final dashSpace = 4.0;
    double startX = 0;

    while (startX < height) {
      canvas.drawLine(
        Offset(startX, closePriceY),
        Offset(startX + dashWidth, closePriceY),
        pricePaint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CandlestickChartPainter oldDelegate) {
    return oldDelegate.candles != candles ||
        oldDelegate.scale != scale ||
        oldDelegate.scrollOffset != scrollOffset ||
        oldDelegate.selectedCandleIndex != selectedCandleIndex ||
        oldDelegate.isDarkMode != isDarkMode;
  }
}
