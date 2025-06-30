import 'package:hive/hive.dart';

part 'price_alert_model.g.dart';

// 가격 알림 모델 클래스

@HiveType(typeId: 10)
class PriceAlert {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String userId;

  @HiveField(2)
  final String coinId;

  @HiveField(3)
  final String coinSymbol;

  @HiveField(4)
  final double priceTarget;

  @HiveField(5)
  final bool isAbove; // true: 가격이 목표가 이상일 때, false: 가격이 목표가 이하일 때

  @HiveField(6)
  final bool isTriggered; // 알림 발생 여부

  @HiveField(7)
  final DateTime createdAt;

  @HiveField(8)
  final DateTime? triggeredAt; // 알림 발생 시각

  @HiveField(9)
  final String? notes; // 사용자 메모

  @HiveField(10)
  final double? triggeredPrice; // 알림 발생 시 현재 가격

  PriceAlert({
    required this.id,
    required this.userId,
    required this.coinId,
    required this.coinSymbol,
    required this.priceTarget,
    required this.isAbove,
    required this.isTriggered,
    required this.createdAt,
    this.triggeredAt,
    this.notes,
    this.triggeredPrice,
  });

  // JSON에서 변환
  factory PriceAlert.fromJson(Map<String, dynamic> json) {
    return PriceAlert(
      id: json['id'].toString(),
      userId: json['user_id'],
      coinId: json['coin_id'] ?? '',
      coinSymbol: json['coin_symbol'] ?? '',
      priceTarget: (json['price_target'] ?? 0.0).toDouble(),
      isAbove: json['is_above'] ?? false,
      isTriggered: json['is_triggered'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      triggeredAt: json['triggered_at'] != null
          ? DateTime.parse(json['triggered_at'])
          : null,
      notes: json['notes'],
      triggeredPrice: json['triggered_price'] != null
          ? (json['triggered_price'] as num).toDouble()
          : null,
    );
  }

  // JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'coin_id': coinId,
      'coin_symbol': coinSymbol,
      'price_target': priceTarget,
      'is_above': isAbove,
      'is_triggered': isTriggered,
      'created_at': createdAt.toIso8601String(),
      'triggered_at': triggeredAt?.toIso8601String(),
      'notes': notes,
      'triggered_price': triggeredPrice,
    };
  }

  // 알림 상태 텍스트 반환
  String get statusText => isTriggered ? '발생됨' : '대기중';

  // 알림 상태 반환 (UI 표시용)
  String get status => isTriggered ? '발생됨' : '대기중';

  // 알림 조건 텍스트 반환
  String get conditionText {
    if (isAbove) {
      return '$coinSymbol 가격이 ₩$priceTarget 이상일 때';
    } else {
      return '$coinSymbol 가격이 ₩$priceTarget 이하일 때';
    }
  }

  // 알림 설명 텍스트 생성
  String get description {
    final direction = isAbove ? '이상' : '이하';
    return '$coinSymbol이(가) $priceTarget $direction일 때 알림';
  }

  // PriceAlert 객체 복사본 생성 (필드 업데이트 가능)
  PriceAlert copyWith({
    String? id,
    String? userId,
    String? coinId,
    String? coinSymbol,
    double? priceTarget,
    bool? isAbove,
    bool? isTriggered,
    DateTime? createdAt,
    DateTime? triggeredAt,
    String? notes,
    double? triggeredPrice,
  }) {
    return PriceAlert(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      coinId: coinId ?? this.coinId,
      coinSymbol: coinSymbol ?? this.coinSymbol,
      priceTarget: priceTarget ?? this.priceTarget,
      isAbove: isAbove ?? this.isAbove,
      isTriggered: isTriggered ?? this.isTriggered,
      createdAt: createdAt ?? this.createdAt,
      triggeredAt: triggeredAt ?? this.triggeredAt,
      notes: notes ?? this.notes,
      triggeredPrice: triggeredPrice ?? this.triggeredPrice,
    );
  }
}
