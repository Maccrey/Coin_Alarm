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
  late ScrollController _scrollController;
  int _visibleStartIndex = 0;
  int _visibleEndIndex = 0;
  double _maxPrice = 0;
  double _minPrice = 0;
  double _maxVolume = 0;

  // 날짜 포맷터
  final DateFormat _dateFormat = DateFormat('MM-dd HH:mm');
  final DateFormat _shortDateFormat = DateFormat('HH:mm');

  // 가격 포맷터
  final NumberFormat _priceFormat = NumberFormat.currency(
    symbol: '',
    decimalDigits: 2,
  );

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_updateVisibleIndices);

    // 초기 표시 범위 계산
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculateInitialVisibleIndices();
    });
  }

  @override
  void didUpdateWidget(CandleChartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.chartData != oldWidget.chartData) {
      // 데이터가 변경되면 표시 범위 재계산
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _calculateInitialVisibleIndices();
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateVisibleIndices);
    _scrollController.dispose();
    super.dispose();
  }

  // 초기 표시 범위 계산
  void _calculateInitialVisibleIndices() {
    if (widget.chartData.candles.isEmpty) return;

    // 항상 모든 캔들이 화면에 표시되도록 설정
    _visibleStartIndex = 0;
    _visibleEndIndex = widget.chartData.candles.length - 1;

    _updatePriceRange();
  }

  // 스크롤 시 표시 범위 업데이트
  void _updateVisibleIndices() {
    if (widget.chartData.candles.isEmpty) return;

    // 스크롤 위치에 따라 표시 범위 계산
    // 여기서는 간단한 예시로, 실제로는 더 복잡한 계산이 필요할 수 있음
    final scrollPosition = _scrollController.position;
    final itemWidth =
        scrollPosition.maxScrollExtent / widget.chartData.candles.length;

    if (itemWidth <= 0) return;

    final startIndex = (scrollPosition.pixels / itemWidth).floor();
    final visibleCount = (scrollPosition.viewportDimension / itemWidth).ceil();

    setState(() {
      _visibleStartIndex = max(0, startIndex);
      _visibleEndIndex = min(
        widget.chartData.candles.length - 1,
        startIndex + visibleCount,
      );
      _updatePriceRange();
    });
  }

  // 표시 범위의 가격 범위 계산
  void _updatePriceRange() {
    if (_visibleStartIndex >= _visibleEndIndex) return;

    double maxPrice = double.negativeInfinity;
    double minPrice = double.infinity;
    double maxVolume = 0;

    for (int i = _visibleStartIndex; i <= _visibleEndIndex; i++) {
      final candle = widget.chartData.candles[i];
      maxPrice = max(maxPrice, candle.high);
      minPrice = min(minPrice, candle.low);
      maxVolume = max(maxVolume, candle.volume);
    }

    // 여백 추가
    final priceRange = maxPrice - minPrice;
    maxPrice += priceRange * 0.05;
    minPrice -= priceRange * 0.05;

    setState(() {
      _maxPrice = maxPrice;
      _minPrice = minPrice;
      _maxVolume = maxVolume;
    });
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

    // 가격 레이블의 너비 (오른쪽 여백)
    const priceLabelsWidth = 70.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final candles = widget.chartData.candles;

        // 화면 너비에 맞게 캔들 너비 동적 계산
        final availableWidth = constraints.maxWidth - priceLabelsWidth;
        final dynamicCandleWidth =
            (availableWidth / candles.length) * 0.7; // 70%는 캔들, 30%는 간격
        final dynamicCandleSpacing = (availableWidth / candles.length) * 0.3;

        // 캔들 너비가 너무 작거나 크지 않도록 제한
        final effectiveCandleWidth = dynamicCandleWidth.clamp(
          2.0,
          widget.candleWidth,
        );
        final effectiveCandleSpacing = dynamicCandleSpacing.clamp(
          1.0,
          widget.candleSpacing,
        );

        final totalCandleWidth = effectiveCandleWidth + effectiveCandleSpacing;
        final totalWidth = totalCandleWidth * candles.length;
        final visibleWidth =
            constraints.maxWidth - priceLabelsWidth; // 가격 레이블 공간 제외
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
                  max(0.0, totalWidth * _scale - visibleWidth),
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

              // 차트 영역 (가격 레이블 공간을 제외한 영역)
              Positioned(
                left: 0,
                top: 0,
                width: visibleWidth,
                height: constraints.maxHeight,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  child: SizedBox(
                    width: max(totalWidth * _scale, visibleWidth),
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
                        candleWidth: effectiveCandleWidth,
                        candleSpacing: effectiveCandleSpacing,
                        scale: _scale,
                        scrollOffset: _scrollOffset,
                        selectedCandleIndex: _selectedCandleIndex,
                        chartHeight: chartHeight,
                        volumeHeight: volumeHeight,
                        isDarkMode: isDarkMode,
                        visibleStartIndex: _visibleStartIndex,
                        visibleEndIndex: _visibleEndIndex,
                      ),
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
                  right: priceLabelsWidth + 8, // 가격 레이블 공간을 고려한 위치 조정
                  child: _buildTooltip(
                    candles[_selectedCandleIndex!],
                    isDarkMode,
                  ),
                ),

              // 가격 레이블 (우측)
              Positioned(
                top: 0,
                right: 0,
                width: priceLabelsWidth,
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
                right: priceLabelsWidth, // 가격 레이블 공간을 제외
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
            _priceFormat.format(maxPrice),
            style: TextStyle(fontSize: 10, color: textColor),
          ),
          Text(
            _priceFormat.format(minPrice + (maxPrice - minPrice) * 0.75),
            style: TextStyle(fontSize: 10, color: textColor),
          ),
          Text(
            _priceFormat.format(minPrice + (maxPrice - minPrice) * 0.5),
            style: TextStyle(fontSize: 10, color: textColor),
          ),
          Text(
            _priceFormat.format(minPrice + (maxPrice - minPrice) * 0.25),
            style: TextStyle(fontSize: 10, color: textColor),
          ),
          Text(
            _priceFormat.format(minPrice),
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
    final timeframe = widget.chartData.timeframe;

    // 화면에 표시되는 캔들만 필터링
    final visibleCandles = candles.sublist(
      _visibleStartIndex,
      _visibleEndIndex + 1,
    );

    // 표시할 레이블 개수 (5개로 고정)
    const int labelCount = 5;

    // 최신 데이터가 있는지 확인 (오늘 또는 현재 시간과 일치하는지)
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final hasCurrentData =
        visibleCandles.isNotEmpty &&
        (visibleCandles.last.timestamp.isAfter(today) ||
            (visibleCandles.last.timestamp.year == today.year &&
                visibleCandles.last.timestamp.month == today.month &&
                visibleCandles.last.timestamp.day == today.day));

    return Container(
      height: 20,
      color: backgroundColor,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final labelWidth = constraints.maxWidth / labelCount;

          // 균등하게 분포된 인덱스 계산
          final List<int> labelIndices = [];
          if (visibleCandles.length >= labelCount) {
            // 마지막 캔들(최신 데이터)은 항상 포함
            labelIndices.add(visibleCandles.length - 1);

            // 나머지 인덱스 계산
            if (labelCount > 1) {
              final step = (visibleCandles.length - 1) / (labelCount - 1);
              for (int i = 0; i < labelCount - 1; i++) {
                final idx = (i * step).round();
                if (!labelIndices.contains(idx)) {
                  labelIndices.add(idx);
                }
              }
            }

            // 인덱스 정렬
            labelIndices.sort();
          } else {
            // 캔들이 5개 미만인 경우 모든 캔들에 레이블 표시
            for (int i = 0; i < visibleCandles.length; i++) {
              labelIndices.add(i);
            }
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (int i = 0; i < labelIndices.length; i++)
                SizedBox(
                  width: labelWidth,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2.0),
                    child: Text(
                      _formatDateLabel(
                        visibleCandles[labelIndices[i]].timestamp,
                        timeframe,
                        isLatest:
                            labelIndices[i] == visibleCandles.length - 1 &&
                            hasCurrentData,
                      ),
                      style: TextStyle(
                        fontSize: 10,
                        color:
                            labelIndices[i] == visibleCandles.length - 1 &&
                                hasCurrentData
                            ? Colors
                                  .green // 최신 데이터는 녹색으로 강조
                            : textColor,
                        fontWeight:
                            labelIndices[i] == visibleCandles.length - 1 &&
                                hasCurrentData
                            ? FontWeight
                                  .bold // 최신 데이터는 볼드체로 강조
                            : FontWeight.normal,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  // 날짜 레이블 포맷팅
  String _formatDateLabel(
    DateTime timestamp,
    ChartTimeframe timeframe, {
    bool isLatest = false,
  }) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    // 최신 데이터인 경우 특별 표시
    if (isLatest) {
      if (timeframe == ChartTimeframe.days1 ||
          timeframe == ChartTimeframe.days7 ||
          timeframe == ChartTimeframe.days30) {
        if (timestamp.year == today.year &&
            timestamp.month == today.month &&
            timestamp.day == today.day) {
          return '오늘';
        }
      } else {
        // 분 단위 타임프레임에서는 '현재'로 표시
        final diff = now.difference(timestamp);
        if (diff.inMinutes < 15) {
          return '현재';
        }
      }
    }

    // 일반 포맷팅
    if (timestamp.year == today.year &&
        timestamp.month == today.month &&
        timestamp.day == today.day) {
      // 오늘인 경우
      if (_isMinutesTimeframe(timeframe)) {
        return DateFormat('HH:mm').format(timestamp);
      } else {
        return '오늘';
      }
    } else if (timestamp.year == yesterday.year &&
        timestamp.month == yesterday.month &&
        timestamp.day == yesterday.day) {
      // 어제인 경우
      if (_isMinutesTimeframe(timeframe)) {
        return DateFormat('HH:mm').format(timestamp);
      } else {
        return '어제';
      }
    } else {
      // 그 외
      if (_isMinutesTimeframe(timeframe)) {
        return DateFormat('HH:mm').format(timestamp);
      } else {
        return DateFormat('MM/dd').format(timestamp);
      }
    }
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
            _priceFormat.format(candle.open),
            tooltipLabelColor,
            tooltipTextColor,
          ),
          _buildTooltipRow(
            '고가',
            _priceFormat.format(candle.high),
            tooltipLabelColor,
            tooltipTextColor,
          ),
          _buildTooltipRow(
            '저가',
            _priceFormat.format(candle.low),
            tooltipLabelColor,
            tooltipTextColor,
          ),
          _buildTooltipRow(
            '종가',
            _priceFormat.format(candle.close),
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
  final int visibleStartIndex;
  final int visibleEndIndex;

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
    required this.visibleStartIndex,
    required this.visibleEndIndex,
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

    for (int i = visibleStartIndex; i <= visibleEndIndex; i++) {
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
        oldDelegate.isDarkMode != isDarkMode ||
        oldDelegate.visibleStartIndex != visibleStartIndex ||
        oldDelegate.visibleEndIndex != visibleEndIndex;
  }
}
