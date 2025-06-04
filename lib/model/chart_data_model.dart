import 'package:hive/hive.dart';

part 'chart_data_model.g.dart';

/// 차트 데이터 타입 (캔들스틱, 라인)
@HiveType(typeId: 0)
enum ChartType {
  @HiveField(0)
  candlestick,

  @HiveField(1)
  line,
}

/// 차트 시간 프레임
@HiveType(typeId: 5)
enum ChartTimeframe {
  @HiveField(0)
  minutes1,

  @HiveField(1)
  minutes3,

  @HiveField(2)
  minutes5,

  @HiveField(3)
  minutes10,

  @HiveField(4)
  minutes15,

  @HiveField(5)
  minutes30,

  @HiveField(6)
  minutes60,

  @HiveField(7)
  minutes240,

  @HiveField(8)
  days1,

  @HiveField(9)
  days7,

  @HiveField(10)
  days30,
}

/// 차트 데이터 모델 (캔들스틱 또는 라인)
@HiveType(typeId: 1)
class ChartData {
  @HiveField(0)
  final String symbol;

  @HiveField(1)
  final ChartTimeframe timeframe;

  @HiveField(2)
  final List<ChartPoint> points;

  @HiveField(3)
  final DateTime lastUpdated;

  @HiveField(4)
  final ChartType type;

  ChartData({
    required this.symbol,
    required this.timeframe,
    required this.points,
    required this.lastUpdated,
    required this.type,
  });

  // 캐시 키 생성 (symbol_timeframe_type)
  String get cacheKey => '${symbol}_${timeframe.name}_${type.name}';

  // 캐시 만료 여부 확인 (기간별 만료 시간 다르게 설정)
  bool isExpired() {
    final now = DateTime.now();
    final difference = now.difference(lastUpdated);

    // 시간 프레임별 캐시 만료 시간 설정
    switch (timeframe) {
      case ChartTimeframe.minutes1:
      case ChartTimeframe.minutes3:
      case ChartTimeframe.minutes5:
        return difference.inMinutes > 5; // 5분
      case ChartTimeframe.minutes10:
      case ChartTimeframe.minutes15:
        return difference.inMinutes > 15; // 15분
      case ChartTimeframe.minutes30:
      case ChartTimeframe.minutes60:
        return difference.inMinutes > 30; // 30분
      case ChartTimeframe.minutes240:
      case ChartTimeframe.days1:
        return difference.inHours > 1; // 1시간
      case ChartTimeframe.days7:
      case ChartTimeframe.days30:
        return difference.inHours > 6; // 6시간
    }
  }
}

/// 차트 포인트 (라인 차트용)
@HiveType(typeId: 2)
class ChartPoint {
  @HiveField(0)
  final DateTime timestamp;

  @HiveField(1)
  final double price;

  ChartPoint({required this.timestamp, required this.price});

  // JSON 변환
  Map<String, dynamic> toJson() {
    return {'timestamp': timestamp.millisecondsSinceEpoch, 'price': price};
  }

  // JSON에서 생성
  factory ChartPoint.fromJson(Map<String, dynamic> json) {
    return ChartPoint(
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp']),
      price: json['price'].toDouble(),
    );
  }
}

/// 캔들스틱 차트 데이터
@HiveType(typeId: 3)
class CandleData {
  @HiveField(0)
  final DateTime timestamp;

  @HiveField(1)
  final double open;

  @HiveField(2)
  final double high;

  @HiveField(3)
  final double low;

  @HiveField(4)
  final double close;

  @HiveField(5)
  final double volume;

  CandleData({
    required this.timestamp,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  });

  // JSON 변환
  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.millisecondsSinceEpoch,
      'open': open,
      'high': high,
      'low': low,
      'close': close,
      'volume': volume,
    };
  }

  // JSON에서 생성
  factory CandleData.fromJson(Map<String, dynamic> json) {
    return CandleData(
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp']),
      open: json['open'].toDouble(),
      high: json['high'].toDouble(),
      low: json['low'].toDouble(),
      close: json['close'].toDouble(),
      volume: json['volume'].toDouble(),
    );
  }

  // 상승 캔들인지 확인
  bool get isUp => close >= open;
}

/// 캔들스틱 차트 데이터 컬렉션
@HiveType(typeId: 4)
class CandleChartData {
  @HiveField(0)
  final String symbol;

  @HiveField(1)
  final ChartTimeframe timeframe;

  @HiveField(2)
  final List<CandleData> candles;

  @HiveField(3)
  final DateTime lastUpdated;

  CandleChartData({
    required this.symbol,
    required this.timeframe,
    required this.candles,
    required this.lastUpdated,
  });

  // 캐시 키 생성 (symbol_timeframe_candle)
  String get cacheKey => '${symbol}_${timeframe.name}_candle';

  // 캐시 만료 여부 확인 (기간별 만료 시간 다르게 설정)
  bool isExpired() {
    final now = DateTime.now();
    final difference = now.difference(lastUpdated);

    // 시간 프레임별 캐시 만료 시간 설정
    switch (timeframe) {
      case ChartTimeframe.minutes1:
      case ChartTimeframe.minutes3:
      case ChartTimeframe.minutes5:
        return difference.inMinutes > 5; // 5분
      case ChartTimeframe.minutes10:
      case ChartTimeframe.minutes15:
        return difference.inMinutes > 15; // 15분
      case ChartTimeframe.minutes30:
      case ChartTimeframe.minutes60:
        return difference.inMinutes > 30; // 30분
      case ChartTimeframe.minutes240:
      case ChartTimeframe.days1:
        return difference.inHours > 1; // 1시간
      case ChartTimeframe.days7:
      case ChartTimeframe.days30:
        return difference.inHours > 6; // 6시간
    }
  }
}
