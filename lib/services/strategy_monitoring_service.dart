import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../model/strategy_alert_model.dart';
import '../model/coin_model.dart';
import '../services/crypto_api_service.dart';
import '../utils/strategy_templates.dart';

/// 전략 기반 알림 모니터링 포그라운드 서비스
/// 대기중인 알림을 주기적으로 체크하여 조건이 만족되면 로컬 푸시 알림을 발송합니다.
class StrategyMonitoringService extends TaskHandler {
  static const String _channelId = 'strategy_alerts_channel';
  static const String _channelName = '전략 기반 알림';
  static const String _channelDescription = '단타매매 전략 기반 코인 알림';

  static FlutterLocalNotificationsPlugin? _notifications;
  static Box<StrategyAlert>? _alertsBox;
  static CryptoApiService? _cryptoApiService;
  static Timer? _monitoringTimer;

  /// 포그라운드 서비스 초기화
  static Future<void> initialize() async {
    // 로컬 알림 플러그인 초기화
    _notifications = FlutterLocalNotificationsPlugin();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications!.initialize(initSettings);

    // 알림 채널 생성 (Android)
    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
      playSound: true,
    );

    await _notifications!
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(androidChannel);

    // Hive Box 초기화
    if (!Hive.isBoxOpen('strategy_alerts')) {
      _alertsBox = await Hive.openBox<StrategyAlert>('strategy_alerts');
    } else {
      _alertsBox = Hive.box<StrategyAlert>('strategy_alerts');
    }

    // API 서비스 초기화
    final factory = CryptoServiceFactory();
    _cryptoApiService = factory.getPreferredService();
  }

  /// 포그라운드 서비스 시작
  static Future<bool> startService() async {
    await initialize();

    final result = await FlutterForegroundTask.startService(
      serviceId: 256,
      notificationTitle: '전략 기반 알림 모니터링',
      notificationText: '단타매매 전략을 모니터링하고 있습니다',
      notificationIcon: null,
      notificationButtons: [const NotificationButton(id: 'stop', text: '중지')],
      callback: startCallback,
    );

    return result != null;
  }

  /// 포그라운드 서비스 중지
  static Future<bool> stopService() async {
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
    final result = await FlutterForegroundTask.stopService();
    return result != null;
  }

  /// 서비스 실행 상태 확인
  static Future<bool> get isRunning => FlutterForegroundTask.isRunningService;

  /// 포그라운드 서비스 콜백 함수
  @pragma('vm:entry-point')
  static void startCallback() {
    FlutterForegroundTask.setTaskHandler(StrategyMonitoringService());
  }

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    print('[StrategyMonitoringService] 전략 모니터링 서비스 시작됨: $timestamp');

    // 30초마다 전략 알림 조건을 체크
    _monitoringTimer = Timer.periodic(const Duration(seconds: 30), (
      timer,
    ) async {
      await _checkStrategyAlerts();
    });
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // 주기적 실행 시 호출됨 (현재는 사용하지 않음)
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    print('[StrategyMonitoringService] 전략 모니터링 서비스 종료됨: $timestamp');
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
  }

  @override
  void onNotificationButtonPressed(String id) {
    print('[StrategyMonitoringService] 알림 버튼 클릭됨: $id');

    if (id == 'stop') {
      FlutterForegroundTask.stopService();
    }
  }

  @override
  void onNotificationPressed() {
    // 알림 클릭 시 처리 (필요시 구현)
    print('[StrategyMonitoringService] 포그라운드 서비스 알림 클릭됨');
  }

  /// 전략 알림 조건 체크 및 알림 발송
  static Future<void> _checkStrategyAlerts() async {
    try {
      if (_alertsBox == null || _cryptoApiService == null) {
        print('[StrategyMonitoringService] 서비스가 초기화되지 않았습니다.');
        return;
      }

      // 활성화된 대기중인 알림 목록 가져오기
      final activeAlerts = _alertsBox!.values
          .where((alert) => alert.isEnabled && !alert.isTriggered)
          .toList();

      if (activeAlerts.isEmpty) {
        print('[StrategyMonitoringService] 활성화된 알림이 없습니다.');
        return;
      }

      print(
        '[StrategyMonitoringService] ${activeAlerts.length}개의 활성 알림을 체크합니다.',
      );

      // 각 알림의 조건을 체크
      for (final alert in activeAlerts) {
        try {
          final isTriggered = await _checkAlertCondition(alert);

          if (isTriggered) {
            await _triggerAlert(alert);
          }
        } catch (e) {
          print('[StrategyMonitoringService] 알림 ${alert.id} 체크 중 오류: $e');
        }
      }
    } catch (e) {
      print('[StrategyMonitoringService] 전략 알림 체크 중 오류: $e');
    }
  }

  /// 개별 알림 조건 체크
  static Future<bool> _checkAlertCondition(StrategyAlert alert) async {
    try {
      // 코인의 현재 가격 데이터 가져오기
      final coinData = await _cryptoApiService!.getCoinBySymbol(
        alert.coinSymbol,
      );
      if (coinData == null) {
        print(
          '[StrategyMonitoringService] ${alert.coinSymbol} 데이터를 가져올 수 없습니다.',
        );
        return false;
      }

      final triggerCondition = alert.triggerCondition;

      // 전략별 조건 체크
      switch (alert.strategyName) {
        case 'breakout':
          return await _checkBreakoutCondition(
            alert,
            coinData,
            triggerCondition,
          );

        case 'pullback':
          return await _checkPullbackCondition(
            alert,
            coinData,
            triggerCondition,
          );

        case 'rsi_reversal':
          return await _checkRsiReversalCondition(
            alert,
            coinData,
            triggerCondition,
          );

        case 'golden_cross':
        case 'dead_cross':
          return await _checkCrossCondition(alert, coinData, triggerCondition);

        case 'candle_pattern':
          return await _checkCandlePatternCondition(
            alert,
            coinData,
            triggerCondition,
          );

        default:
          print('[StrategyMonitoringService] 알 수 없는 전략: ${alert.strategyName}');
          return false;
      }
    } catch (e) {
      print('[StrategyMonitoringService] 알림 조건 체크 중 오류: $e');
      return false;
    }
  }

  /// 돌파매매 조건 체크
  static Future<bool> _checkBreakoutCondition(
    StrategyAlert alert,
    Coin coinData,
    Map<String, dynamic> condition,
  ) async {
    try {
      final period = condition['period'] ?? 24;
      final breakoutType = condition['breakout_type'] ?? 'upward';
      final volumeConfirmation = condition['volume_confirmation'] ?? true;
      final minVolumeRatio = condition['min_volume_ratio']?.toDouble() ?? 1.5;

      // 간단한 돌파 조건 체크 (실제 차트 데이터가 없으므로 기본 데이터 활용)
      final currentPrice = coinData.currentPrice;
      final high24h = coinData.high24h ?? currentPrice;
      final low24h = coinData.low24h ?? currentPrice;

      bool priceBreakout = false;

      if (breakoutType == 'upward') {
        // 상향 돌파: 현재가가 24시간 최고가 근처 (95% 이상)
        priceBreakout = currentPrice >= (high24h * 0.95);
      } else {
        // 하향 돌파: 현재가가 24시간 최저가 근처 (105% 이하)
        priceBreakout = currentPrice <= (low24h * 1.05);
      }

      // 거래량 확인 (24시간 거래량이 평균보다 높은지 간단 체크)
      bool volumeCheck = true;
      if (volumeConfirmation) {
        final volume24h = coinData.volume24h ?? 0;
        // 임시로 거래량이 0보다 크면 통과로 처리
        volumeCheck = volume24h > 0;
      }

      return priceBreakout && volumeCheck;
    } catch (e) {
      print('[StrategyMonitoringService] 돌파매매 조건 체크 오류: $e');
      return false;
    }
  }

  /// 눌림목 매매 조건 체크 (간단한 구현)
  static Future<bool> _checkPullbackCondition(
    StrategyAlert alert,
    Coin coinData,
    Map<String, dynamic> condition,
  ) async {
    // 실제로는 더 복잡한 추세 분석이 필요하지만, 간단히 구현
    // 여기서는 7일 이동평균 대비 5% 이상 하락 후 2% 이상 상승으로 가정
    return false; // 임시로 false 반환
  }

  /// RSI 반등 조건 체크 (간단한 구현)
  static Future<bool> _checkRsiReversalCondition(
    StrategyAlert alert,
    Coin coinData,
    Map<String, dynamic> condition,
  ) async {
    // 실제로는 RSI 계산이 필요하지만, 간단히 구현
    // 여기서는 24시간 변화율로 대체
    final changePercent = coinData.priceChangePercentage24h ?? 0;
    final threshold = condition['threshold']?.toDouble() ?? 30.0;
    final reversalType = condition['reversal_type'] ?? 'oversold_bounce';

    if (reversalType == 'oversold_bounce') {
      // 과매도 반등: 24시간 변화율이 -threshold% 이하에서 상승으로 전환
      return changePercent <= -threshold && changePercent > -(threshold + 5);
    } else {
      // 과매수 하락: 24시간 변화율이 +threshold% 이상에서 하락으로 전환
      return changePercent >= threshold && changePercent < (threshold + 5);
    }
  }

  /// 골든크로스/데드크로스 조건 체크 (간단한 구현)
  static Future<bool> _checkCrossCondition(
    StrategyAlert alert,
    Coin coinData,
    Map<String, dynamic> condition,
  ) async {
    // 실제로는 이동평균 계산이 필요하지만, 간단히 구현
    // 여기서는 가격 변화율로 대체
    final changePercent = coinData.priceChangePercentage24h ?? 0;
    final crossType = condition['cross_type'] ?? 'golden';

    if (crossType == 'golden') {
      // 골든크로스: 상승 모멘텀 (5% 이상 상승)
      return changePercent >= 5.0;
    } else {
      // 데드크로스: 하락 모멘텀 (5% 이상 하락)
      return changePercent <= -5.0;
    }
  }

  /// 캔들 패턴 조건 체크 (간단한 구현)
  static Future<bool> _checkCandlePatternCondition(
    StrategyAlert alert,
    Coin coinData,
    Map<String, dynamic> condition,
  ) async {
    // 실제로는 캔들 패턴 분석이 필요하지만, 간단히 구현
    // 여기서는 변동성으로 대체
    final changePercent = coinData.priceChangePercentage24h?.abs() ?? 0;

    // 5% 이상의 변동성이 있을 때 패턴 발생으로 간주
    return changePercent >= 5.0;
  }

  /// 알림 트리거 및 로컬 푸시 알림 발송
  static Future<void> _triggerAlert(StrategyAlert alert) async {
    try {
      // 알림 상태 업데이트
      final updatedAlert = alert.copyWith(
        isTriggered: true,
        triggeredAt: DateTime.now(),
      );

      await _alertsBox!.put(alert.id, updatedAlert);

      // 로컬 푸시 알림 발송
      await _sendLocalNotification(alert);

      print(
        '[StrategyMonitoringService] 알림 트리거됨: ${alert.coinSymbol} - ${alert.strategyName}',
      );
    } catch (e) {
      print('[StrategyMonitoringService] 알림 트리거 중 오류: $e');
    }
  }

  /// 로컬 푸시 알림 발송
  static Future<void> _sendLocalNotification(StrategyAlert alert) async {
    try {
      if (_notifications == null) {
        return;
      }

      final strategyDisplayName = StrategyTemplates.getStrategyDisplayName(
        alert.strategyName,
      );
      final title = '${alert.coinSymbol} 전략 알림';
      final body = '$strategyDisplayName 조건이 만족되었습니다!';

      const androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications!.show(
        alert.id.hashCode,
        title,
        body,
        notificationDetails,
        payload: json.encode({
          'alertId': alert.id,
          'coinSymbol': alert.coinSymbol,
          'strategyName': alert.strategyName,
        }),
      );
    } catch (e) {
      print('[StrategyMonitoringService] 로컬 알림 발송 중 오류: $e');
    }
  }
}
