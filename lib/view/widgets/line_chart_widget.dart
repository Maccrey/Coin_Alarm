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

class _LineChartWidgetState extends State<LineChartWidget>
    with SingleTickerProviderStateMixin {
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

  // 애니메이션 컨트롤러
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _calculateVisibleIndices();

    // 애니메이션 컨트롤러 초기화
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    // 초기 애니메이션 실행
    _animationController.forward(from: 0.0);
  }

  @override
  void didUpdateWidget(LineChartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.chartData != oldWidget.chartData) {
      _calculateVisibleIndices();

      // 부드러운 업데이트를 위한 애니메이션
      if (!_animationController.isAnimating) {
        _animationController.reset();
        _animationController.forward();
      }
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
    _animationController.dispose();
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

        return AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
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
                            animationValue: _animation.value,
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
                        color: textColor,
                        fontWeight: FontWeight.normal,
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

    // 시간 프레임에 따라 포맷 변경
    if (_isMinutesTimeframe(timeframe)) {
      // 분 단위 타임프레임은 시간:분 형식으로 표시
      return DateFormat('HH:mm').format(timestamp);
    } else {
      // 일 단위 이상 타임프레임은 월/일 형식으로 표시
      return DateFormat('MM/dd').format(timestamp);
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
      return '${(price / 1000000).toStringAsFixed(0)}M';
    } else if (price >= 1000) {
      return '${(price / 1000).toStringAsFixed(0)}K';
    } else if (price >= 1) {
      return price.toStringAsFixed(0);
    } else {
      // 1보다 작은 값은 소수점 필요
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

  // 위치에 해당하는 포인트 인덱스 계산
  int? _getPointIndexAtPosition(double x, double pointWidth) {
    if (pointWidth <= 0) return null;
    final index = (x / pointWidth).floor();
    if (index < 0 || index >= widget.chartData.points.length) return null;
    return index;
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
  final double animationValue;

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
    this.selectedPointIndex,
    required this.isDarkMode,
    this.animationValue = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    // 최소/최대 가격 계산
    double minPrice = double.infinity;
    double maxPrice = -double.infinity;
    for (final point in points) {
      minPrice = min(minPrice, point.price);
      maxPrice = max(maxPrice, point.price);
    }

    // 가격 범위에 여백 추가
    final priceRange = maxPrice - minPrice;
    maxPrice += priceRange * 0.05;
    minPrice -= priceRange * 0.05;

    // 애니메이션 적용된 투명도
    final opacity = animationValue;

    // 그리드 그리기
    if (showGrid) {
      _drawGrid(canvas, size, minPrice, maxPrice);
    }

    // 라인 그리기
    _drawLine(canvas, size, minPrice, maxPrice, opacity);

    // 선택된 포인트 표시
    if (selectedPointIndex != null && selectedPointIndex! < points.length) {
      _drawSelectedPoint(
        canvas,
        size,
        points[selectedPointIndex!],
        minPrice,
        maxPrice,
        opacity,
      );
    }
  }

  // 그리드 그리기
  void _drawGrid(Canvas canvas, Size size, double minPrice, double maxPrice) {
    final gridPaint = Paint()
      ..color = gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    // 수평선
    final priceStep = (maxPrice - minPrice) / 5;
    for (int i = 0; i <= 5; i++) {
      final price = minPrice + i * priceStep;
      final y =
          size.height -
          ((price - minPrice) / (maxPrice - minPrice)) * size.height;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // 수직선
    final step = points.length ~/ 5;
    if (step > 0) {
      for (int i = 0; i <= 5; i++) {
        final index = i * step;
        if (index < points.length) {
          final x = index * pointWidth * scale;
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
        }
      }
    }
  }

  // 라인 그리기
  void _drawLine(
    Canvas canvas,
    Size size,
    double minPrice,
    double maxPrice,
    double opacity,
  ) {
    final linePaint = Paint()
      ..color = lineColor.withOpacity(opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final fillPath = Path();

    // 첫 포인트
    final firstPoint = points.first;
    final firstX = 0.0;
    final firstY =
        size.height -
        ((firstPoint.price - minPrice) / (maxPrice - minPrice)) * size.height;
    path.moveTo(firstX, firstY);
    fillPath.moveTo(firstX, size.height);
    fillPath.lineTo(firstX, firstY);

    // 나머지 포인트
    for (int i = 1; i < points.length; i++) {
      final point = points[i];
      final x = i * pointWidth * scale;
      final y =
          size.height -
          ((point.price - minPrice) / (maxPrice - minPrice)) * size.height;

      // 애니메이션 적용 (포인트별로 순차적으로 나타나는 효과)
      final pointProgress = min(1.0, animationValue * points.length / i);
      if (pointProgress < 1.0) continue;

      // 부드러운 곡선으로 연결
      if (i == 1) {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      } else {
        final prevPoint = points[i - 1];
        final prevX = (i - 1) * pointWidth * scale;
        final prevY =
            size.height -
            ((prevPoint.price - minPrice) / (maxPrice - minPrice)) *
                size.height;

        final cpX1 = prevX + (x - prevX) / 2;
        final cpX2 = prevX + (x - prevX) / 2;

        path.cubicTo(cpX1, prevY, cpX2, y, x, y);
        fillPath.cubicTo(cpX1, prevY, cpX2, y, x, y);
      }
    }

    // 그라데이션 영역 완성
    if (showGradient) {
      final lastPoint = points.last;
      final lastX = (points.length - 1) * pointWidth * scale;
      final lastY =
          size.height -
          ((lastPoint.price - minPrice) / (maxPrice - minPrice)) * size.height;

      fillPath.lineTo(lastX, size.height);
      fillPath.close();

      final gradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          gradientStartColor.withOpacity(opacity),
          gradientEndColor.withOpacity(opacity),
        ],
      );

      final gradientPaint = Paint()
        ..shader = gradient.createShader(
          Rect.fromLTWH(0, 0, size.width, size.height),
        )
        ..style = PaintingStyle.fill;

      canvas.drawPath(fillPath, gradientPaint);
    }

    // 라인 그리기
    canvas.drawPath(path, linePaint);
  }

  // 선택된 포인트 표시
  void _drawSelectedPoint(
    Canvas canvas,
    Size size,
    ChartPoint point,
    double minPrice,
    double maxPrice,
    double opacity,
  ) {
    final x = selectedPointIndex! * pointWidth * scale;
    final y =
        size.height -
        ((point.price - minPrice) / (maxPrice - minPrice)) * size.height;

    // 선택된 포인트 표시
    final dotPaint = Paint()
      ..color = lineColor.withOpacity(opacity)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = isDarkMode ? Colors.white : Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // 포인트 그리기
    canvas.drawCircle(Offset(x, y), 5.0, dotPaint);
    canvas.drawCircle(Offset(x, y), 5.0, borderPaint);

    // 수직선 그리기
    final linePaint = Paint()
      ..color = lineColor.withOpacity(0.3 * opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
  }

  @override
  bool shouldRepaint(covariant LineChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.selectedPointIndex != selectedPointIndex ||
        oldDelegate.scale != scale ||
        oldDelegate.scrollOffset != scrollOffset ||
        oldDelegate.animationValue != animationValue;
  }
}
