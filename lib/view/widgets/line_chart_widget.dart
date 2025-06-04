import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../model/chart_data_model.dart';
import 'dart:math';

/// 라인 차트 위젯
class LineChartWidget extends StatefulWidget {
  final ChartData chartData;
  final bool showGrid;
  final bool showTooltip;
  final bool showGradient;
  final Color lineColor;
  final Color gridColor;
  final Color textColor;
  final Color gradientStartColor;
  final Color gradientEndColor;

  const LineChartWidget({
    super.key,
    required this.chartData,
    this.showGrid = true,
    this.showTooltip = true,
    this.showGradient = true,
    this.lineColor = const Color(0xFF1976D2), // 파란색
    this.gridColor = const Color(0x22000000), // 연한 회색
    this.textColor = const Color(0xFF757575), // 중간 회색
    this.gradientStartColor = const Color(0x661976D2), // 반투명 파란색
    this.gradientEndColor = const Color(0x001976D2), // 투명 파란색
  });

  @override
  State<LineChartWidget> createState() => _LineChartWidgetState();
}

class _LineChartWidgetState extends State<LineChartWidget> {
  // 줌 및 스크롤 관련 변수
  double _scale = 1.0;
  double _previousScale = 1.0;
  double _startScrollOffset = 0.0;
  double _scrollOffset = 0.0;
  int? _selectedPointIndex;
  final ScrollController _scrollController = ScrollController();

  // 표시할 데이터 포인트 범위
  int _visibleStartIndex = 0;
  int _visibleEndIndex = 0;

  @override
  void initState() {
    super.initState();
    _calculateVisibleIndices();
  }

  @override
  void didUpdateWidget(LineChartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.chartData != oldWidget.chartData) {
      _calculateVisibleIndices();
    }
  }

  // 표시할 데이터 포인트 범위 계산
  void _calculateVisibleIndices() {
    if (widget.chartData.points.isEmpty) return;

    // 항상 최대 30개의 포인트만 표시하도록 설정
    final totalPoints = widget.chartData.points.length;
    final visibleCount = min(30, totalPoints);

    _visibleStartIndex = max(0, totalPoints - visibleCount);
    _visibleEndIndex = totalPoints - 1;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.chartData.points.isEmpty) {
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

    // 라인 색상 조정
    final lineColor = isDarkMode
        ? const Color(0xFF4CAF50) // 다크 모드에서는 녹색
        : widget.lineColor;
    final gradientStartColor = isDarkMode
        ? const Color(0x664CAF50) // 다크 모드에서는 녹색 그라데이션
        : widget.gradientStartColor;
    final gradientEndColor = isDarkMode
        ? const Color(0x004CAF50) // 다크 모드에서는 투명 녹색
        : widget.gradientEndColor;

    // 표시할 데이터 포인트
    final visiblePoints = widget.chartData.points.sublist(
      _visibleStartIndex,
      _visibleEndIndex + 1,
    );

    // 가격 레이블의 너비 (오른쪽 여백)
    const priceLabelsWidth = 70.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final pointWidth = 10.0; // 포인트 간 기본 간격
        final totalWidth = pointWidth * visiblePoints.length * _scale;
        final visibleWidth =
            constraints.maxWidth - priceLabelsWidth; // 가격 레이블 공간 제외

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
            final pointIndex = _getPointIndexAtPosition(
              localPosition.dx,
              pointWidth,
            );

            setState(() {
              _selectedPointIndex = pointIndex;
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
                    width: totalWidth,
                    height: constraints.maxHeight,
                    child: CustomPaint(
                      painter: LineChartPainter(
                        points: visiblePoints,
                        lineColor: lineColor,
                        gridColor: gridColor,
                        textColor: textColor,
                        showGrid: widget.showGrid,
                        showGradient: widget.showGradient,
                        gradientStartColor: gradientStartColor,
                        gradientEndColor: gradientEndColor,
                        pointWidth: pointWidth,
                        scale: _scale,
                        scrollOffset: _scrollOffset,
                        selectedPointIndex: _selectedPointIndex,
                        isDarkMode: isDarkMode,
                      ),
                    ),
                  ),
                ),
              ),

              // 툴팁 (선택된 포인트가 있는 경우)
              if (widget.showTooltip &&
                  _selectedPointIndex != null &&
                  _selectedPointIndex! < visiblePoints.length)
                Positioned(
                  top: 8,
                  right: priceLabelsWidth + 8, // 가격 레이블 공간을 고려한 위치 조정
                  child: _buildTooltip(
                    visiblePoints[_selectedPointIndex!],
                    isDarkMode,
                  ),
                ),

              // 가격 레이블 (우측)
              Positioned(
                top: 0,
                right: 0,
                width: priceLabelsWidth,
                bottom: 0,
                child: _buildPriceLabels(
                  visiblePoints,
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
                  visiblePoints,
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
    List<ChartPoint> points,
    Color backgroundColor,
    Color textColor,
  ) {
    // 최대/최소 가격 계산
    double minPrice = double.infinity;
    double maxPrice = -double.infinity;

    for (final point in points) {
      minPrice = min(minPrice, point.price);
      maxPrice = max(maxPrice, point.price);
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
    List<ChartPoint> points,
    Color backgroundColor,
    Color textColor,
  ) {
    final dateFormat = DateFormat('MM/dd');
    final timeFormat = DateFormat('HH:mm');
    final timeframe = widget.chartData.timeframe;

    // 표시할 레이블 개수 (5개로 고정)
    const int labelCount = 5;

    // 최신 데이터가 있는지 확인 (오늘 또는 현재 시간과 일치하는지)
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final hasCurrentData =
        points.isNotEmpty &&
        (points.last.timestamp.isAfter(today) ||
            (points.last.timestamp.year == today.year &&
                points.last.timestamp.month == today.month &&
                points.last.timestamp.day == today.day));

    return Container(
      height: 20,
      color: backgroundColor,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final labelWidth = constraints.maxWidth / labelCount;

          // 균등하게 분포된 인덱스 계산
          final List<int> labelIndices = [];
          if (points.length >= labelCount) {
            // 마지막 포인트(최신 데이터)는 항상 포함
            labelIndices.add(points.length - 1);

            // 나머지 인덱스 계산
            if (labelCount > 1) {
              final step = (points.length - 1) / (labelCount - 1);
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
            // 포인트가 5개 미만인 경우 모든 포인트에 레이블 표시
            for (int i = 0; i < points.length; i++) {
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
                        points[labelIndices[i]].timestamp,
                        timeframe,
                        isLatest:
                            labelIndices[i] == points.length - 1 &&
                            hasCurrentData,
                      ),
                      style: TextStyle(
                        fontSize: 10,
                        color:
                            labelIndices[i] == points.length - 1 &&
                                hasCurrentData
                            ? Colors
                                  .green // 최신 데이터는 녹색으로 강조
                            : textColor,
                        fontWeight:
                            labelIndices[i] == points.length - 1 &&
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
  Widget _buildTooltip(ChartPoint point, bool isDarkMode) {
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
            '${dateFormat.format(point.timestamp)} ${timeFormat.format(point.timestamp)}',
            style: TextStyle(color: tooltipTextColor, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                '가격: ',
                style: TextStyle(color: tooltipLabelColor, fontSize: 12),
              ),
              Text(
                _formatPrice(point.price),
                style: TextStyle(color: tooltipTextColor, fontSize: 12),
              ),
            ],
          ),
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

  // 특정 위치의 포인트 인덱스 계산
  int? _getPointIndexAtPosition(double position, double pointWidth) {
    final adjustedPosition = position + _scrollOffset;
    final index = (adjustedPosition / (pointWidth * _scale)).floor();

    if (index >= 0 && index < widget.chartData.points.length) {
      return index;
    }
    return null;
  }
}

/// 라인 차트 페인터
class LineChartPainter extends CustomPainter {
  final List<ChartPoint> points;
  final Color lineColor;
  final Color gridColor;
  final Color textColor;
  final bool showGrid;
  final bool showGradient;
  final Color gradientStartColor;
  final Color gradientEndColor;
  final double pointWidth;
  final double scale;
  final double scrollOffset;
  final int? selectedPointIndex;
  final bool isDarkMode;

  LineChartPainter({
    required this.points,
    required this.lineColor,
    required this.gridColor,
    required this.textColor,
    required this.showGrid,
    required this.showGradient,
    required this.gradientStartColor,
    required this.gradientEndColor,
    required this.pointWidth,
    required this.scale,
    required this.scrollOffset,
    required this.selectedPointIndex,
    required this.isDarkMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    // 가격 범위 계산
    double minPrice = double.infinity;
    double maxPrice = -double.infinity;

    for (final point in points) {
      minPrice = min(minPrice, point.price);
      maxPrice = max(maxPrice, point.price);
    }

    // 가격 범위에 여유 공간 추가
    final range = maxPrice - minPrice;
    final buffer = range * 0.05;
    minPrice -= buffer;
    maxPrice += buffer;

    // 그리드 그리기
    if (showGrid) {
      _drawGrid(canvas, size);
    }

    // 라인 그리기
    final effectivePointWidth = pointWidth * scale;
    final path = Path();
    final fillPath = Path();

    // 첫 번째 포인트
    double startX = 0 - scrollOffset;
    double startY = _calculateY(
      points.first.price,
      minPrice,
      maxPrice,
      size.height,
    );
    path.moveTo(startX, startY);
    fillPath.moveTo(startX, size.height);
    fillPath.lineTo(startX, startY);

    // 나머지 포인트
    for (int i = 0; i < points.length; i++) {
      final point = points[i];
      final x = i * effectivePointWidth - scrollOffset;
      final y = _calculateY(point.price, minPrice, maxPrice, size.height);

      // 화면에 보이는 포인트만 그리기 (성능 최적화)
      if (x < -effectivePointWidth || x > size.width + effectivePointWidth) {
        continue;
      }

      // 부드러운 곡선으로 연결 (이전 포인트와 현재 포인트 사이의 중간점을 사용)
      if (i > 0) {
        final prevPoint = points[i - 1];
        final prevX = (i - 1) * effectivePointWidth - scrollOffset;
        final prevY = _calculateY(
          prevPoint.price,
          minPrice,
          maxPrice,
          size.height,
        );

        final midX = (prevX + x) / 2;

        path.quadraticBezierTo(prevX, prevY, midX, (prevY + y) / 2);
        fillPath.quadraticBezierTo(prevX, prevY, midX, (prevY + y) / 2);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }

      // 선택된 포인트 표시
      if (selectedPointIndex == i) {
        _drawSelectedPoint(canvas, x, y, size);
      }
    }

    // 마지막 포인트
    final lastX = (points.length - 1) * effectivePointWidth - scrollOffset;
    final lastY = _calculateY(
      points.last.price,
      minPrice,
      maxPrice,
      size.height,
    );
    path.lineTo(lastX, lastY);
    fillPath.lineTo(lastX, lastY);
    fillPath.lineTo(lastX, size.height);
    fillPath.close();

    // 그라데이션 채우기
    if (showGradient) {
      final gradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [gradientStartColor, gradientEndColor],
      );

      final rect = Rect.fromLTWH(0, 0, size.width, size.height);
      final paint = Paint()
        ..shader = gradient.createShader(rect)
        ..style = PaintingStyle.fill;

      canvas.drawPath(fillPath, paint);
    }

    // 라인 그리기
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, linePaint);
  }

  // 그리드 그리기
  void _drawGrid(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.5;

    // 수평 그리드 (가격 레벨)
    for (int i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // 수직 그리드 (시간)
    for (int i = 0; i <= 4; i++) {
      final x = size.width * i / 4;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
  }

  // 선택된 포인트 표시
  void _drawSelectedPoint(Canvas canvas, double x, double y, Size size) {
    // 배경 원
    final bgPaint = Paint()
      ..color = isDarkMode ? Colors.black : Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(x, y), 8, bgPaint);

    // 테두리 원
    final borderPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawCircle(Offset(x, y), 8, borderPaint);

    // 내부 원
    final innerPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(x, y), 4, innerPaint);

    // 수직선
    final linePaint = Paint()
      ..color = isDarkMode
          ? Colors.white.withOpacity(0.3)
          : Colors.black.withOpacity(0.2)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // 점선 효과를 위한 패턴
    final dashWidth = 4.0;
    final dashSpace = 4.0;

    // 상단 점선
    double startY = 0;
    while (startY < y - 10) {
      canvas.drawLine(
        Offset(x, startY),
        Offset(x, startY + dashWidth),
        linePaint,
      );
      startY += dashWidth + dashSpace;
    }

    // 하단 점선
    startY = y + 10;
    while (startY < size.height) {
      canvas.drawLine(
        Offset(x, startY),
        Offset(x, startY + dashWidth),
        linePaint,
      );
      startY += dashWidth + dashSpace;
    }
  }

  // 가격을 Y좌표로 변환
  double _calculateY(
    double price,
    double minPrice,
    double maxPrice,
    double height,
  ) {
    return height - ((price - minPrice) / (maxPrice - minPrice)) * height;
  }

  @override
  bool shouldRepaint(covariant LineChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.scale != scale ||
        oldDelegate.scrollOffset != scrollOffset ||
        oldDelegate.selectedPointIndex != selectedPointIndex ||
        oldDelegate.isDarkMode != isDarkMode;
  }
}
