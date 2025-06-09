import 'package:hive/hive.dart';
import 'dart:convert';

part 'strategy_alert_model.g.dart';

/// 전략 기반 알림 모델 클래스
/// 단타매매 전략을 기반으로 한 고급 알림 시스템을 위한 데이터 모델
@HiveType(typeId: 11)
class StrategyAlert {
  /// 고유 식별자
  @HiveField(0)
  final String id;

  /// 사용자 ID
  @HiveField(1)
  final String userId;

  /// 코인 ID (예: bitcoin, ethereum)
  @HiveField(2)
  final String coinId;

  /// 코인 심볼 (예: BTC, ETH)
  @HiveField(3)
  final String coinSymbol;

  /// 전략명 (breakout, pullback, rsi_reversal, golden_cross, candle_pattern)
  @HiveField(4)
  final String strategyName;

  /// 위험도 (low, medium, high)
  @HiveField(5)
  final String riskLevel;

  /// 트리거 조건 (JSON 형태로 저장)
  @HiveField(6)
  final String triggerConditionJson;

  /// 알림 발생 여부
  @HiveField(7)
  final bool isTriggered;

  /// 알림 발생 시각
  @HiveField(8)
  final DateTime? triggeredAt;

  /// 생성 시각
  @HiveField(9)
  final DateTime createdAt;

  /// 사용자 메모
  @HiveField(10)
  final String? notes;

  /// 알림 활성화 상태
  @HiveField(11)
  final bool isEnabled;

  /// 알림 유형 (strategy: 전략 기반, manual: 수동 설정)
  @HiveField(12)
  final String alertType;

  StrategyAlert({
    required this.id,
    required this.userId,
    required this.coinId,
    required this.coinSymbol,
    required this.strategyName,
    required this.riskLevel,
    required this.triggerConditionJson,
    required this.isTriggered,
    this.triggeredAt,
    required this.createdAt,
    this.notes,
    required this.isEnabled,
    required this.alertType,
  });

  /// JSON에서 StrategyAlert 객체 생성
  factory StrategyAlert.fromJson(Map<String, dynamic> json) {
    return StrategyAlert(
      id: json['id'].toString(),
      userId: json['user_id'] ?? '',
      coinId: json['coin_id'] ?? '',
      coinSymbol: json['coin_symbol'] ?? '',
      strategyName: json['strategy_name'] ?? '',
      riskLevel: json['risk_level'] ?? 'medium',
      triggerConditionJson: json['trigger_condition_json'] ?? '{}',
      isTriggered: json['is_triggered'] ?? false,
      triggeredAt: json['triggered_at'] != null
          ? DateTime.parse(json['triggered_at'])
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      notes: json['notes'],
      isEnabled: json['is_enabled'] ?? true,
      alertType: json['alert_type'] ?? 'strategy',
    );
  }

  /// StrategyAlert 객체를 JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'coin_id': coinId,
      'coin_symbol': coinSymbol,
      'strategy_name': strategyName,
      'risk_level': riskLevel,
      'trigger_condition_json': triggerConditionJson,
      'is_triggered': isTriggered,
      'triggered_at': triggeredAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'notes': notes,
      'is_enabled': isEnabled,
      'alert_type': alertType,
    };
  }

  /// 트리거 조건을 Map으로 파싱
  Map<String, dynamic> get triggerCondition {
    try {
      return json.decode(triggerConditionJson) as Map<String, dynamic>;
    } catch (e) {
      return {};
    }
  }

  /// 전략명을 한국어로 변환
  String get strategyDisplayName {
    switch (strategyName) {
      case 'breakout':
        return '돌파매매';
      case 'pullback':
        return '눌림목 매매';
      case 'rsi_reversal':
        return 'RSI 반등';
      case 'golden_cross':
        return '골든크로스';
      case 'dead_cross':
        return '데드크로스';
      case 'candle_pattern':
        return '캔들 패턴';
      default:
        return strategyName;
    }
  }

  /// 위험도를 한국어로 변환
  String get riskDisplayName {
    switch (riskLevel) {
      case 'low':
        return '낮음';
      case 'medium':
        return '보통';
      case 'high':
        return '높음';
      default:
        return riskLevel;
    }
  }

  /// 알림 상태 텍스트 반환
  String get statusText {
    if (!isEnabled) return '비활성';
    if (isTriggered) return '발생됨';
    return '대기중';
  }

  /// 전략 설명 텍스트 생성
  String get strategyDescription {
    switch (strategyName) {
      case 'breakout':
        return '저항선이나 지지선을 돌파할 때 알림';
      case 'pullback':
        return '상승 추세에서 일시적 하락 후 재상승 시점 포착';
      case 'rsi_reversal':
        return 'RSI 과매도/과매수 구간에서 반전 신호 포착';
      case 'golden_cross':
        return '단기 이동평균이 장기 이동평균을 상향 돌파';
      case 'dead_cross':
        return '단기 이동평균이 장기 이동평균을 하향 돌파';
      case 'candle_pattern':
        return '특정 캔들스틱 패턴 발생 시 알림';
      default:
        return '사용자 정의 전략';
    }
  }

  /// 조건 요약 텍스트 생성
  String get conditionSummary {
    final condition = triggerCondition;
    switch (strategyName) {
      case 'breakout':
        final type = condition['breakout_type'] ?? 'upward';
        final period = condition['period'] ?? 24;
        return '$period시간 ${type == 'upward' ? '상향' : '하향'} 돌파';
      case 'pullback':
        final pullbackPercent = condition['pullback_percent'] ?? 10;
        final recoveryPercent = condition['recovery_percent'] ?? 3;
        return '$pullbackPercent% 하락 후 $recoveryPercent% 반등';
      case 'rsi_reversal':
        final threshold = condition['threshold'] ?? 30;
        final type = condition['reversal_type'] ?? 'oversold_bounce';
        return 'RSI $threshold ${type.contains('oversold') ? '과매도' : '과매수'} 반전';
      case 'golden_cross':
      case 'dead_cross':
        final shortPeriod = condition['short_period'] ?? 5;
        final longPeriod = condition['long_period'] ?? 20;
        return 'MA$shortPeriod이 MA$longPeriod을 교차';
      case 'candle_pattern':
        final patternType = condition['pattern_type'] ?? 'hammer';
        return _getCandlePatternName(patternType);
      default:
        return '사용자 정의 조건';
    }
  }

  /// 캔들 패턴명을 한국어로 변환
  String _getCandlePatternName(String pattern) {
    switch (pattern) {
      case 'hammer':
        return '망치형 캔들';
      case 'doji':
        return '도지 캔들';
      case 'consecutive_up':
        return '연속 상승 캔들';
      case 'consecutive_down':
        return '연속 하락 캔들';
      case 'gap_up':
        return '갭업';
      case 'gap_down':
        return '갭다운';
      default:
        return pattern;
    }
  }

  /// StrategyAlert 객체 복사본 생성 (필드 업데이트 가능)
  StrategyAlert copyWith({
    String? id,
    String? userId,
    String? coinId,
    String? coinSymbol,
    String? strategyName,
    String? riskLevel,
    String? triggerConditionJson,
    bool? isTriggered,
    DateTime? triggeredAt,
    DateTime? createdAt,
    String? notes,
    bool? isEnabled,
    String? alertType,
  }) {
    return StrategyAlert(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      coinId: coinId ?? this.coinId,
      coinSymbol: coinSymbol ?? this.coinSymbol,
      strategyName: strategyName ?? this.strategyName,
      riskLevel: riskLevel ?? this.riskLevel,
      triggerConditionJson: triggerConditionJson ?? this.triggerConditionJson,
      isTriggered: isTriggered ?? this.isTriggered,
      triggeredAt: triggeredAt ?? this.triggeredAt,
      createdAt: createdAt ?? this.createdAt,
      notes: notes ?? this.notes,
      isEnabled: isEnabled ?? this.isEnabled,
      alertType: alertType ?? this.alertType,
    );
  }

  @override
  String toString() {
    return 'StrategyAlert{id: $id, coinSymbol: $coinSymbol, strategy: $strategyName, status: $statusText}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StrategyAlert && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
