import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import '../model/strategy_alert_model.dart';
import '../model/coin_model.dart';

/// 전략 기반 알림 서비스 클래스
/// Hive 로컬 저장소를 사용하여 전략 알림을 관리합니다.
class StrategyAlertService {
  static const String _boxName = 'strategy_alerts';
  static Box<StrategyAlert>? _box;
  static const _uuid = Uuid();

  /// Hive Box 초기화
  static Future<void> init() async {
    if (_box == null || !_box!.isOpen) {
      _box = await Hive.openBox<StrategyAlert>(_boxName);
    }
  }

  /// Box가 초기화되었는지 확인
  static void _ensureInitialized() {
    if (_box == null || !_box!.isOpen) {
      throw Exception('StrategyAlertService가 초기화되지 않았습니다. init()를 먼저 호출하세요.');
    }
  }

  /// 새로운 전략 알림 생성
  /// [userId] 사용자 ID
  /// [coinId] 코인 ID
  /// [coinSymbol] 코인 심볼
  /// [strategyName] 전략명 (breakout, pullback, rsi_reversal, golden_cross, dead_cross, candle_pattern)
  /// [riskLevel] 위험도 (low, medium, high)
  /// [triggerCondition] 트리거 조건 (Map 형태)
  /// [notes] 사용자 메모 (선택사항)
  /// 반환: 생성된 StrategyAlert 객체
  static Future<StrategyAlert> createAlert({
    required String userId,
    required String coinId,
    required String coinSymbol,
    required String strategyName,
    required String riskLevel,
    required Map<String, dynamic> triggerCondition,
    String? notes,
  }) async {
    _ensureInitialized();

    final alert = StrategyAlert(
      id: _uuid.v4(),
      userId: userId,
      coinId: coinId,
      coinSymbol: coinSymbol,
      strategyName: strategyName,
      riskLevel: riskLevel,
      triggerConditionJson: json.encode(triggerCondition),
      isTriggered: false,
      createdAt: DateTime.now(),
      notes: notes,
      isEnabled: true,
      alertType: 'strategy',
    );

    await _box!.put(alert.id, alert);
    return alert;
  }

  /// 모든 전략 알림 조회
  /// [userId] 사용자 ID (선택사항, 지정하면 해당 사용자만)
  /// 반환: StrategyAlert 목록
  static Future<List<StrategyAlert>> getAllAlerts([String? userId]) async {
    _ensureInitialized();

    final alerts = _box!.values.toList();

    if (userId != null) {
      return alerts.where((alert) => alert.userId == userId).toList();
    }

    return alerts;
  }

  /// 특정 사용자의 활성화된 전략 알림 조회
  /// [userId] 사용자 ID
  /// 반환: 활성화된 StrategyAlert 목록
  static Future<List<StrategyAlert>> getActiveAlerts(String userId) async {
    _ensureInitialized();

    return _box!.values
        .where(
          (alert) =>
              alert.userId == userId && alert.isEnabled && !alert.isTriggered,
        )
        .toList();
  }

  /// 특정 코인의 전략 알림 조회
  /// [userId] 사용자 ID
  /// [coinId] 코인 ID
  /// 반환: 해당 코인의 StrategyAlert 목록
  static Future<List<StrategyAlert>> getAlertsByCoin(
    String userId,
    String coinId,
  ) async {
    _ensureInitialized();

    return _box!.values
        .where((alert) => alert.userId == userId && alert.coinId == coinId)
        .toList();
  }

  /// 특정 전략의 알림 조회
  /// [userId] 사용자 ID
  /// [strategyName] 전략명
  /// 반환: 해당 전략의 StrategyAlert 목록
  static Future<List<StrategyAlert>> getAlertsByStrategy(
    String userId,
    String strategyName,
  ) async {
    _ensureInitialized();

    return _box!.values
        .where(
          (alert) =>
              alert.userId == userId && alert.strategyName == strategyName,
        )
        .toList();
  }

  /// 알림 ID로 특정 알림 조회
  /// [alertId] 알림 ID
  /// 반환: StrategyAlert 객체 또는 null
  static Future<StrategyAlert?> getAlertById(String alertId) async {
    _ensureInitialized();

    return _box!.get(alertId);
  }

  /// 전략 알림 업데이트
  /// [alertId] 업데이트할 알림 ID
  /// [updates] 업데이트할 필드들
  /// 반환: 업데이트된 StrategyAlert 객체 또는 null
  static Future<StrategyAlert?> updateAlert(
    String alertId,
    Map<String, dynamic> updates,
  ) async {
    _ensureInitialized();

    final existingAlert = _box!.get(alertId);
    if (existingAlert == null) {
      return null;
    }

    // 업데이트할 필드들을 적용하여 새로운 객체 생성
    final updatedAlert = existingAlert.copyWith(
      strategyName:
          updates['strategyName'] as String? ?? existingAlert.strategyName,
      riskLevel: updates['riskLevel'] as String? ?? existingAlert.riskLevel,
      triggerConditionJson:
          updates['triggerConditionJson'] as String? ??
          existingAlert.triggerConditionJson,
      isTriggered: updates['isTriggered'] as bool? ?? existingAlert.isTriggered,
      triggeredAt:
          updates['triggeredAt'] as DateTime? ?? existingAlert.triggeredAt,
      notes: updates['notes'] as String? ?? existingAlert.notes,
      isEnabled: updates['isEnabled'] as bool? ?? existingAlert.isEnabled,
    );

    await _box!.put(alertId, updatedAlert);
    return updatedAlert;
  }

  /// 알림 활성화/비활성화 토글
  /// [alertId] 토글할 알림 ID
  /// 반환: 업데이트된 StrategyAlert 객체 또는 null
  static Future<StrategyAlert?> toggleAlert(String alertId) async {
    _ensureInitialized();

    final existingAlert = _box!.get(alertId);
    if (existingAlert == null) {
      return null;
    }

    final updatedAlert = existingAlert.copyWith(
      isEnabled: !existingAlert.isEnabled,
    );

    await _box!.put(alertId, updatedAlert);
    return updatedAlert;
  }

  /// 알림 트리거 (발생 처리)
  /// [alertId] 트리거할 알림 ID
  /// 반환: 트리거된 StrategyAlert 객체 또는 null
  static Future<StrategyAlert?> triggerAlert(String alertId) async {
    _ensureInitialized();

    final existingAlert = _box!.get(alertId);
    if (existingAlert == null) {
      return null;
    }

    final triggeredAlert = existingAlert.copyWith(
      isTriggered: true,
      triggeredAt: DateTime.now(),
    );

    await _box!.put(alertId, triggeredAlert);
    return triggeredAlert;
  }

  /// 전략 알림 삭제
  /// [alertId] 삭제할 알림 ID
  /// 반환: 삭제 성공 여부
  static Future<bool> deleteAlert(String alertId) async {
    _ensureInitialized();

    if (_box!.containsKey(alertId)) {
      await _box!.delete(alertId);
      return true;
    }
    return false;
  }

  /// 특정 사용자의 모든 알림 삭제
  /// [userId] 사용자 ID
  /// 반환: 삭제된 알림 개수
  static Future<int> deleteAllUserAlerts(String userId) async {
    _ensureInitialized();

    final userAlerts = _box!.values
        .where((alert) => alert.userId == userId)
        .toList();

    int deletedCount = 0;
    for (final alert in userAlerts) {
      await _box!.delete(alert.id);
      deletedCount++;
    }

    return deletedCount;
  }

  /// 트리거된 알림들 정리 (선택적으로 일정 기간 지난 것만)
  /// [userId] 사용자 ID
  /// [olderThanDays] 몇 일 이전 알림을 정리할지 (기본값: 30일)
  /// 반환: 정리된 알림 개수
  static Future<int> cleanupTriggeredAlerts(
    String userId, {
    int olderThanDays = 30,
  }) async {
    _ensureInitialized();

    final cutoffDate = DateTime.now().subtract(Duration(days: olderThanDays));
    final alertsToDelete = _box!.values
        .where(
          (alert) =>
              alert.userId == userId &&
              alert.isTriggered &&
              alert.triggeredAt != null &&
              alert.triggeredAt!.isBefore(cutoffDate),
        )
        .toList();

    int deletedCount = 0;
    for (final alert in alertsToDelete) {
      await _box!.delete(alert.id);
      deletedCount++;
    }

    return deletedCount;
  }

  /// 전략별 통계 조회
  /// [userId] 사용자 ID
  /// 반환: 전략별 통계 맵 {전략명: {total: 총개수, triggered: 발생개수, active: 활성개수}}
  static Future<Map<String, Map<String, int>>> getStrategyStats(
    String userId,
  ) async {
    _ensureInitialized();

    final userAlerts = _box!.values
        .where((alert) => alert.userId == userId)
        .toList();

    final stats = <String, Map<String, int>>{};

    for (final alert in userAlerts) {
      if (!stats.containsKey(alert.strategyName)) {
        stats[alert.strategyName] = {'total': 0, 'triggered': 0, 'active': 0};
      }

      stats[alert.strategyName]!['total'] =
          (stats[alert.strategyName]!['total'] ?? 0) + 1;

      if (alert.isTriggered) {
        stats[alert.strategyName]!['triggered'] =
            (stats[alert.strategyName]!['triggered'] ?? 0) + 1;
      } else if (alert.isEnabled) {
        stats[alert.strategyName]!['active'] =
            (stats[alert.strategyName]!['active'] ?? 0) + 1;
      }
    }

    return stats;
  }

  /// 위험도별 통계 조회
  /// [userId] 사용자 ID
  /// 반환: 위험도별 통계 맵 {위험도: {total: 총개수, triggered: 발생개수, active: 활성개수}}
  static Future<Map<String, Map<String, int>>> getRiskLevelStats(
    String userId,
  ) async {
    _ensureInitialized();

    final userAlerts = _box!.values
        .where((alert) => alert.userId == userId)
        .toList();

    final stats = <String, Map<String, int>>{};

    for (final alert in userAlerts) {
      if (!stats.containsKey(alert.riskLevel)) {
        stats[alert.riskLevel] = {'total': 0, 'triggered': 0, 'active': 0};
      }

      stats[alert.riskLevel]!['total'] =
          (stats[alert.riskLevel]!['total'] ?? 0) + 1;

      if (alert.isTriggered) {
        stats[alert.riskLevel]!['triggered'] =
            (stats[alert.riskLevel]!['triggered'] ?? 0) + 1;
      } else if (alert.isEnabled) {
        stats[alert.riskLevel]!['active'] =
            (stats[alert.riskLevel]!['active'] ?? 0) + 1;
      }
    }

    return stats;
  }

  /// 데이터베이스 닫기
  static Future<void> close() async {
    if (_box != null && _box!.isOpen) {
      await _box!.close();
      _box = null;
    }
  }

  /// Box가 초기화되어 있는지 확인
  static bool get isInitialized => _box != null && _box!.isOpen;

  /// 현재 저장된 알림 개수 반환
  static int get totalCount {
    _ensureInitialized();
    return _box!.length;
  }

  /// 모든 알림 데이터 초기화 (개발/테스트용)
  static Future<void> clearAll() async {
    _ensureInitialized();
    await _box!.clear();
  }
}
