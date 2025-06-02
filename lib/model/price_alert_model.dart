// 가격 알림 모델 클래스

class PriceAlert {
  final String id;
  final String userId;
  final String coinId;
  final String coinSymbol;
  final double priceTarget;
  final bool isAbove;
  final bool isTriggered;
  final DateTime createdAt;
  final DateTime? triggeredAt;
  final String? notes;

  PriceAlert({
    required this.id,
    required this.userId,
    required this.coinId,
    required this.coinSymbol,
    required this.priceTarget,
    required this.isAbove,
    this.isTriggered = false,
    required this.createdAt,
    this.triggeredAt,
    this.notes,
  });

  // JSON 데이터로부터 PriceAlert 객체 생성
  factory PriceAlert.fromJson(Map<String, dynamic> json) {
    return PriceAlert(
      id: json['id'],
      userId: json['user_id'],
      coinId: json['coin_id'],
      coinSymbol: json['coin_symbol'] ?? json['coin_id'].toUpperCase(),
      priceTarget: json['price_target']?.toDouble() ?? 0.0,
      isAbove: json['is_above'] ?? true,
      isTriggered: json['is_triggered'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      triggeredAt: json['triggered_at'] != null
          ? DateTime.parse(json['triggered_at'])
          : null,
      notes: json['notes'],
    );
  }

  // PriceAlert 객체를 JSON 데이터로 변환
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
    };
  }

  // 알림 설명 텍스트 생성
  String get description {
    final direction = isAbove ? '이상' : '이하';
    return '$coinSymbol이(가) $priceTarget $direction일 때 알림';
  }

  // 알림 상태 텍스트 생성
  String get status {
    if (isTriggered) {
      return '발생됨';
    } else {
      return '대기중';
    }
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
    );
  }
}
