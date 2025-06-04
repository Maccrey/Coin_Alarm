// 가격 알림 모델 클래스

class PriceAlert {
  final String id;
  final String userId;
  final String coinId;
  final String coinSymbol;
  final double priceTarget;
  final bool isAbove; // true: 가격이 목표가 이상일 때, false: 가격이 목표가 이하일 때
  final bool isTriggered; // 알림 발생 여부
  final DateTime createdAt;
  final DateTime? triggeredAt; // 알림 발생 시각
  final String? notes; // 사용자 메모

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
  });

  // JSON에서 변환
  factory PriceAlert.fromJson(Map<String, dynamic> json) {
    return PriceAlert(
      id: json['id'].toString(),
      userId: json['user_id'],
      coinId: json['symbol'] ?? '',
      coinSymbol: json['symbol'] ?? '',
      priceTarget: (json['target_price'] ?? 0.0).toDouble(),
      isAbove: json['is_above'] ?? false,
      isTriggered: false, // Supabase에서는 아직 이 필드를 관리하지 않음
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      triggeredAt: null, // Supabase에서는 아직 이 필드를 관리하지 않음
      notes: json['notes'],
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
