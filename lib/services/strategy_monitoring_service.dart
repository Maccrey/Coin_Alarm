import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../model/strategy_alert_model.dart';
import '../model/price_alert_model.dart';
import '../model/coin_model.dart';
import '../services/crypto_api_service.dart';
import '../utils/strategy_templates.dart';

/// 전략 기반 알림 및 가격 알림 모니터링 포그라운드 서비스
/// 대기중인 알림을 주기적으로 체크하여 조건이 만족되면 로컬 푸시 알림을 발송합니다.
class StrategyMonitoringService extends TaskHandler {
  static const String _channelId = 'strategy_alerts_channel';
  static const String _channelName = '코인 알림';
  static const String _channelDescription = '가격 알림 및 전략 기반 코인 알림';

  static FlutterLocalNotificationsPlugin? _notifications;
  static Box<StrategyAlert>? _strategyAlertsBox;
  static Box<PriceAlert>? _priceAlertsBox;
  static CryptoApiService? _cryptoApiService;
  static Timer? _monitoringTimer;

  /// 포그라운드 서비스 초기화
  static Future<void> initialize() async {
    try {
      print('[전략서비스] 포그라운드 서비스 초기화 시작');

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

      try {
        await _notifications!.initialize(initSettings);
        print('[전략서비스] 로컬 알림 초기화 성공');
      } catch (e) {
        print('[전략서비스] 로컬 알림 초기화 실패 (계속 진행): $e');
        // 알림 초기화 실패해도 서비스는 계속 진행
      }

      // 알림 채널 생성 (Android)
      try {
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

        print('[전략서비스] Android 알림 채널 생성 성공');
      } catch (e) {
        print('[전략서비스] Android 알림 채널 생성 실패 (계속 진행): $e');
        // 채널 생성 실패해도 서비스는 계속 진행
      }

      // Hive Box 초기화 (전략 알림 + 가격 알림)
      try {
        // 전략 알림 박스
        if (!Hive.isBoxOpen('strategy_alerts')) {
          _strategyAlertsBox = await Hive.openBox<StrategyAlert>(
            'strategy_alerts',
          );
        } else {
          _strategyAlertsBox = Hive.box<StrategyAlert>('strategy_alerts');
        }

        // 가격 알림 박스
        if (!Hive.isBoxOpen('price_alerts')) {
          _priceAlertsBox = await Hive.openBox<PriceAlert>('price_alerts');
        } else {
          _priceAlertsBox = Hive.box<PriceAlert>('price_alerts');
        }

        print(
          '[전략서비스] Hive Box 초기화 성공 (전략: ${_strategyAlertsBox?.length ?? 0}개, 가격: ${_priceAlertsBox?.length ?? 0}개)',
        );
      } catch (e) {
        print('[전략서비스] Hive Box 초기화 실패: $e');
        throw e; // 이건 치명적이므로 예외 발생
      }

      // API 서비스 초기화
      try {
        final factory = CryptoServiceFactory();
        _cryptoApiService = factory.getPreferredService();
        print('[전략서비스] API 서비스 초기화 성공');
      } catch (e) {
        print('[전략서비스] API 서비스 초기화 실패: $e');
        throw e; // 이것도 치명적이므로 예외 발생
      }

      print('[전략서비스] 포그라운드 서비스 초기화 완료');
    } catch (e) {
      print('[전략서비스] 초기화 중 치명적 오류: $e');
      rethrow;
    }
  }

  /// 포그라운드 서비스 시작
  static Future<bool> startService() async {
    try {
      print('[전략서비스] 서비스 시작 시도');

      // 초기화 시도 (실패해도 계속 진행)
      try {
        await initialize();
        print('[전략서비스] 초기화 성공');
      } catch (e) {
        print('[전략서비스] 초기화 실패하지만 서비스 시작 시도: $e');
        // 초기화 실패해도 포그라운드 서비스 시작은 시도
      }

      final result = await FlutterForegroundTask.startService(
        serviceId: 256,
        notificationTitle: '코인 알림 모니터링',
        notificationText: '가격 알림과 전략 알림을 모니터링하고 있습니다',
        notificationIcon: null,
        notificationButtons: [const NotificationButton(id: 'stop', text: '중지')],
        callback: startCallback,
      );

      final success = result != null;
      print('[전략서비스] 포그라운드 서비스 시작 결과: $success');

      if (success) {
        print('[전략서비스] 전략 모니터링 서비스가 성공적으로 시작되었습니다');
      } else {
        print('[전략서비스] 포그라운드 서비스 시작 실패');
      }

      return success;
    } catch (e) {
      print('[전략서비스] 서비스 시작 중 오류: $e');
      return false;
    }
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
    print('[StrategyMonitoringService] 코인 알림 모니터링 서비스 시작됨: $timestamp');

    // 30초마다 전략 알림과 가격 알림 조건을 체크
    _monitoringTimer = Timer.periodic(const Duration(seconds: 30), (
      timer,
    ) async {
      await _checkAllAlerts();
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

  /// 모든 알림 조건 체크 및 알림 발송 (전략 알림 + 가격 알림)
  static Future<void> _checkAllAlerts() async {
    try {
      print('[알림체크] 모든 알림 체크 시작');

      // 전략 알림 체크
      await _checkStrategyAlerts();

      // 가격 알림 체크
      await _checkPriceAlerts();

      print('[알림체크] 모든 알림 체크 완료');
    } catch (e) {
      print('[알림체크] 알림 체크 중 오류: $e');
    }
  }

  /// 전략 알림 조건 체크 및 알림 발송
  static Future<void> _checkStrategyAlerts() async {
    try {
      if (_strategyAlertsBox == null || _cryptoApiService == null) {
        print('[StrategyMonitoringService] 서비스가 초기화되지 않았습니다.');
        return;
      }

      // 활성화된 대기중인 알림 목록 가져오기
      final activeAlerts = _strategyAlertsBox!.values
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

  /// 돌파 매매 전략 조건 체크
  static Future<bool> _checkBreakoutCondition(
    StrategyAlert alert,
    dynamic coinData,
    Map<String, dynamic> condition,
  ) async {
    try {
      final period = condition['period'] ?? 24; // 기간 (시간)
      final minVolumeRatio = condition['minVolumeRatio'] ?? 1.5; // 최소 거래량 비율
      final breakoutType =
          condition['breakoutType'] ?? 'upward'; // 'upward' or 'downward'
      final threshold = condition['threshold'] ?? 2.0; // 돌파 임계값 (%)

      final currentPrice = coinData.currentPrice ?? 0.0;
      final high24h = coinData.high24h ?? currentPrice;
      final low24h = coinData.low24h ?? currentPrice;
      final volume24h = coinData.volume24h ?? 0.0;
      final avgVolume =
          coinData.avgVolume ?? volume24h; // 평균 거래량 (없으면 현재 거래량 사용)
      final change24h = coinData.changePercent24h ?? 0.0;

      // 1. 가격 돌파 조건 확인
      bool priceBreakout = false;

      if (breakoutType == 'upward') {
        // 상향 돌파: 현재가가 24시간 고가를 돌파하거나 임계값 이상 상승
        final highBreakout = currentPrice > high24h;
        final thresholdBreakout = change24h >= threshold;
        priceBreakout = highBreakout || thresholdBreakout;

        print(
          '[돌파매매] 상향 체크: 현재가=$currentPrice, 고가=$high24h, 변화율=$change24h%, 임계값=$threshold%',
        );
      } else {
        // 하향 돌파: 현재가가 24시간 저가를 하향 돌파하거나 임계값 이상 하락
        final lowBreakout = currentPrice < low24h;
        final thresholdBreakout = change24h <= -threshold;
        priceBreakout = lowBreakout || thresholdBreakout;

        print(
          '[돌파매매] 하향 체크: 현재가=$currentPrice, 저가=$low24h, 변화율=$change24h%, 임계값=-$threshold%',
        );
      }

      // 2. 거래량 돌파 조건 확인
      bool volumeBreakout = false;
      if (avgVolume > 0) {
        final volumeRatio = volume24h / avgVolume;
        volumeBreakout = volumeRatio >= minVolumeRatio;
        print(
          '[돌파매매] 거래량 체크: 현재=$volume24h, 평균=$avgVolume, 비율=$volumeRatio, 임계값=$minVolumeRatio',
        );
      } else {
        // 평균 거래량 정보가 없으면 현재 거래량이 0이 아니면 통과
        volumeBreakout = volume24h > 0;
        print('[돌파매매] 거래량 체크 (평균없음): 현재=$volume24h > 0');
      }

      // 3. 최종 돌파 조건 확인
      final isBreakout = priceBreakout && volumeBreakout;

      print(
        '[돌파매매] ${alert.coinSymbol} 최종 결과: 가격돌파=$priceBreakout, 거래량돌파=$volumeBreakout, 전체=$isBreakout',
      );

      return isBreakout;
    } catch (e) {
      print('[StrategyMonitoringService] 돌파 매매 조건 체크 오류: $e');
      return false;
    }
  }

  /// 풀백 매매 전략 조건 체크
  static Future<bool> _checkPullbackCondition(
    StrategyAlert alert,
    dynamic coinData,
    Map<String, dynamic> condition,
  ) async {
    try {
      final pullbackPercent = condition['pullbackPercent'] ?? 3.0; // 풀백 비율 (%)
      final supportLevel = condition['supportLevel'] ?? 0.0; // 지지선 가격
      final trendDirection =
          condition['trendDirection'] ?? 'upward'; // 'upward' or 'downward'
      final minVolume = condition['minVolume'] ?? 0.0;

      final currentPrice = coinData.currentPrice ?? 0.0;
      final high24h = coinData.high24h ?? currentPrice;
      final low24h = coinData.low24h ?? currentPrice;
      final change24h = coinData.changePercent24h ?? 0.0;
      final volume24h = coinData.volume24h ?? 0.0;

      bool pullbackCondition = false;

      if (trendDirection == 'upward') {
        // 상승 트렌드에서의 풀백: 고점에서 일정 비율 하락 후 지지선 근처에서 반등
        final pullbackFromHigh = ((high24h - currentPrice) / high24h) * 100;
        final nearSupport = supportLevel > 0
            ? (currentPrice >= supportLevel * 0.98)
            : true;

        pullbackCondition =
            pullbackFromHigh >= pullbackPercent &&
            pullbackFromHigh <= (pullbackPercent * 2) &&
            nearSupport &&
            change24h > -10.0; // 너무 큰 하락은 제외

        print(
          '[풀백매매] 상승트렌드 체크: 고점하락=$pullbackFromHigh%, 지지선근처=$nearSupport, 24h변화=$change24h%',
        );
      } else {
        // 하락 트렌드에서의 풀백: 저점에서 일정 비율 상승 후 저항선 근처에서 하락
        final pullbackFromLow = ((currentPrice - low24h) / low24h) * 100;
        final nearResistance = supportLevel > 0
            ? (currentPrice <= supportLevel * 1.02)
            : true;

        pullbackCondition =
            pullbackFromLow >= pullbackPercent &&
            pullbackFromLow <= (pullbackPercent * 2) &&
            nearResistance &&
            change24h < 10.0; // 너무 큰 상승은 제외

        print(
          '[풀백매매] 하락트렌드 체크: 저점상승=$pullbackFromLow%, 저항선근처=$nearResistance, 24h변화=$change24h%',
        );
      }

      // 거래량 조건 확인
      final volumeCondition = volume24h >= minVolume;

      final isPullback = pullbackCondition && volumeCondition;
      print(
        '[풀백매매] ${alert.coinSymbol} 최종 결과: 풀백조건=$pullbackCondition, 거래량조건=$volumeCondition, 전체=$isPullback',
      );

      return isPullback;
    } catch (e) {
      print('[StrategyMonitoringService] 풀백 매매 조건 체크 오류: $e');
      return false;
    }
  }

  /// RSI 역전 전략 조건 체크
  static Future<bool> _checkRsiReversalCondition(
    StrategyAlert alert,
    dynamic coinData,
    Map<String, dynamic> condition,
  ) async {
    try {
      final rsiLowerThreshold =
          condition['rsiLowerThreshold'] ?? 30.0; // RSI 과매도 임계값
      final rsiUpperThreshold =
          condition['rsiUpperThreshold'] ?? 70.0; // RSI 과매수 임계값
      final reversalType =
          condition['reversalType'] ?? 'oversold'; // 'oversold' or 'overbought'
      final confirmationPeriod = condition['confirmationPeriod'] ?? 1; // 확인 기간

      final currentPrice = coinData.currentPrice ?? 0.0;
      final change24h = coinData.changePercent24h ?? 0.0;
      final volume24h = coinData.volume24h ?? 0.0;

      // 실제 RSI 계산 대신 24시간 변화율을 기준으로 한 간소화된 로직
      double approximateRSI = 50.0; // 기본값

      if (change24h > 0) {
        // 상승 시: 변화율이 클수록 RSI가 높아짐 (최대 80)
        approximateRSI = 50.0 + (change24h * 2).clamp(0.0, 30.0);
      } else {
        // 하락 시: 변화율이 클수록 RSI가 낮아짐 (최소 20)
        approximateRSI = 50.0 + (change24h * 2).clamp(-30.0, 0.0);
      }

      bool reversalCondition = false;

      if (reversalType == 'oversold') {
        // 과매도 상태에서 반등 신호
        reversalCondition =
            approximateRSI <= rsiLowerThreshold && change24h > -15.0;
        print(
          '[RSI역전] 과매도 체크: 근사RSI=$approximateRSI, 임계값=$rsiLowerThreshold, 24h변화=$change24h%',
        );
      } else if (reversalType == 'overbought') {
        // 과매수 상태에서 하락 신호
        reversalCondition =
            approximateRSI >= rsiUpperThreshold && change24h < 15.0;
        print(
          '[RSI역전] 과매수 체크: 근사RSI=$approximateRSI, 임계값=$rsiUpperThreshold, 24h변화=$change24h%',
        );
      }

      // 거래량 확인 (급격한 변화 시 거래량도 증가해야 함)
      final volumeConfirmation = volume24h > 0;

      final isReversal = reversalCondition && volumeConfirmation;
      print(
        '[RSI역전] ${alert.coinSymbol} 최종 결과: 역전조건=$reversalCondition, 거래량확인=$volumeConfirmation, 전체=$isReversal',
      );

      return isReversal;
    } catch (e) {
      print('[StrategyMonitoringService] RSI 역전 조건 체크 오류: $e');
      return false;
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

  /// 알림 발송 및 상태 업데이트
  static Future<void> _triggerAlert(StrategyAlert alert) async {
    try {
      print(
        '[StrategyMonitoringService] 🔔 알림 발송 시작: ${alert.coinSymbol} - ${alert.strategyName}',
      );

      // 알림 상태를 "발생됨"으로 업데이트
      final updatedAlert = StrategyAlert(
        id: alert.id,
        userId: alert.userId,
        coinId: alert.coinId,
        coinSymbol: alert.coinSymbol,
        strategyName: alert.strategyName,
        riskLevel: alert.riskLevel,
        triggerConditionJson: alert.triggerConditionJson,
        isTriggered: true,
        triggeredAt: DateTime.now(),
        createdAt: alert.createdAt,
        notes: alert.notes,
        isEnabled: alert.isEnabled,
        alertType: alert.alertType,
      );

      await _strategyAlertsBox!.put(alert.id, updatedAlert);
      print('[StrategyMonitoringService] ✅ 알림 상태 업데이트 완료: ${alert.id}');

      // 로컬 푸시 알림 발송
      final notificationTitle =
          '${alert.coinSymbol} ${_getStrategyDisplayName(alert.strategyName)} 알림';
      final notificationBody = '설정한 ${alert.riskLevel} 위험도 조건이 충족되었습니다.';

      await _notifications!.show(
        alert.id.hashCode, // 고유 ID
        notificationTitle,
        notificationBody,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'strategy_alerts',
            '전략 기반 알림',
            channelDescription: '단타매매 전략 알림',
            importance: Importance.high,
            priority: Priority.high,
            showWhen: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );

      print('[StrategyMonitoringService] 🚀 로컬 알림 발송 완료');
      print(
        '[StrategyMonitoringService] 📊 알림 내용: $notificationTitle - $notificationBody',
      );
    } catch (e) {
      print('[StrategyMonitoringService] ❌ 알림 발송 오류: $e');
      print('[StrategyMonitoringService] 🔍 오류 상세: ${e.toString()}');

      // 에러 발생 시에도 알림 상태는 업데이트 (중복 발송 방지)
      try {
        final errorAlert = StrategyAlert(
          id: alert.id,
          userId: alert.userId,
          coinId: alert.coinId,
          coinSymbol: alert.coinSymbol,
          strategyName: alert.strategyName,
          riskLevel: alert.riskLevel,
          triggerConditionJson: alert.triggerConditionJson,
          isTriggered: true,
          triggeredAt: DateTime.now(),
          createdAt: alert.createdAt,
          notes: '${alert.notes}\n[오류] 알림 발송 실패: ${DateTime.now()}',
          isEnabled: alert.isEnabled,
          alertType: alert.alertType,
        );
        await _strategyAlertsBox!.put(alert.id, errorAlert);
        print('[StrategyMonitoringService] ⚠️ 에러 상태로 알림 업데이트 완료');
      } catch (updateError) {
        print('[StrategyMonitoringService] 💥 알림 상태 업데이트도 실패: $updateError');
      }
    }
  }

  /// 전략명을 사용자 친화적인 이름으로 변환
  static String _getStrategyDisplayName(String strategyName) {
    switch (strategyName) {
      case 'breakout':
        return '돌파 매매';
      case 'pullback':
        return '풀백 매매';
      case 'rsi_reversal':
        return 'RSI 역전';
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

  /// 가격 알림 조건 체크 및 알림 발송
  static Future<void> _checkPriceAlerts() async {
    try {
      if (_priceAlertsBox == null || _cryptoApiService == null) {
        print('[가격알림] 서비스가 초기화되지 않았습니다.');
        return;
      }

      // 활성화된 대기중인 가격 알림 목록 가져오기
      final activePriceAlerts = _priceAlertsBox!.values
          .where((alert) => !alert.isTriggered)
          .toList();

      if (activePriceAlerts.isEmpty) {
        print('[가격알림] 활성화된 가격 알림이 없습니다.');
        return;
      }

      print('[가격알림] ${activePriceAlerts.length}개의 가격 알림을 체크합니다.');

      // 각 가격 알림의 조건을 체크
      for (final alert in activePriceAlerts) {
        try {
          final isTriggered = await _checkPriceAlertCondition(alert);

          if (isTriggered) {
            await _triggerPriceAlert(alert);
          }
        } catch (e) {
          print('[가격알림] 알림 ${alert.id} 체크 중 오류: $e');
        }
      }
    } catch (e) {
      print('[가격알림] 가격 알림 체크 중 오류: $e');
    }
  }

  /// 개별 가격 알림 조건 체크
  static Future<bool> _checkPriceAlertCondition(PriceAlert alert) async {
    try {
      print('[가격알림] 🔍 알림 조건 체크 시작: ${alert.coinSymbol} (ID: ${alert.id})');
      print(
        '[가격알림] 📊 알림 설정: ${alert.isAbove ? "이상" : "이하"} ${alert.priceTarget}원',
      );

      // 코인의 현재 가격 데이터 가져오기
      final coinData = await _cryptoApiService!.getCoinBySymbol(
        alert.coinSymbol,
      );
      if (coinData == null) {
        print('[가격알림] ❌ ${alert.coinSymbol} 데이터를 가져올 수 없습니다.');
        return false;
      }

      final currentPrice = coinData.currentPrice ?? 0.0;
      final targetPrice = alert.priceTarget;

      print('[가격알림] 💰 현재가: ${currentPrice}원, 목표가: ${targetPrice}원');

      // 조건 체크: "이상"일 때는 현재가 >= 목표가, "이하"일 때는 현재가 <= 목표가
      bool isTriggered = false;

      if (alert.isAbove) {
        // "이상" 조건: 현재가가 목표가보다 같거나 높을 때
        isTriggered = currentPrice >= targetPrice;
        print(
          '[가격알림] ⬆️ 이상 조건 체크: ${currentPrice} >= ${targetPrice} => $isTriggered',
        );
        if (isTriggered) {
          print('[가격알림] 🎯 이상 조건 달성! 알림 발송 준비');
        } else {
          final diff = targetPrice - currentPrice;
          print('[가격알림] ⏳ 이상 조건 미달성 (${diff.toStringAsFixed(2)}원 부족)');
        }
      } else {
        // "이하" 조건: 현재가가 목표가보다 같거나 낮을 때
        isTriggered = currentPrice <= targetPrice;
        print(
          '[가격알림] ⬇️ 이하 조건 체크: ${currentPrice} <= ${targetPrice} => $isTriggered',
        );
        if (isTriggered) {
          print('[가격알림] 🎯 이하 조건 달성! 알림 발송 준비');
        } else {
          final diff = currentPrice - targetPrice;
          print('[가격알림] ⏳ 이하 조건 미달성 (${diff.toStringAsFixed(2)}원 초과)');
        }
      }

      return isTriggered;
    } catch (e) {
      print('[가격알림] ❌ 가격 알림 조건 체크 중 오류: $e');
      return false;
    }
  }

  /// 가격 알림 발송 및 상태 업데이트
  static Future<void> _triggerPriceAlert(PriceAlert alert) async {
    try {
      print(
        '[가격알림] 🔔 가격 알림 발송 시작: ${alert.coinSymbol} - ${alert.isAbove ? '이상' : '이하'} ${alert.priceTarget}',
      );
      print('[가격알림] 📝 알림 ID: ${alert.id}');

      // 알림 상태를 "발생됨"으로 업데이트
      final updatedAlert = alert.copyWith(
        isTriggered: true,
        triggeredAt: DateTime.now(),
      );

      await _priceAlertsBox!.put(alert.id, updatedAlert);
      print('[가격알림] ✅ 알림 상태 업데이트 완료: ${alert.id}');
      print('[가격알림] 📅 발생 시간: ${updatedAlert.triggeredAt}');

      // 현재 가격 정보 가져오기
      final coinData = await _cryptoApiService!.getCoinBySymbol(
        alert.coinSymbol,
      );
      final currentPrice = coinData?.currentPrice ?? 0.0;
      print('[가격알림] 💰 알림 발송 시점 현재가: ${currentPrice}원');

      // 로컬 푸시 알림 발송
      final direction = alert.isAbove ? '이상' : '이하';
      final notificationTitle = '${alert.coinSymbol} 가격 알림';
      final notificationBody =
          '목표가 ${alert.priceTarget}원 $direction 달성! (현재: ${currentPrice.toStringAsFixed(0)}원)';

      print('[가격알림] 📢 알림 내용: $notificationTitle - $notificationBody');

      await _notifications!.show(
        alert.id.hashCode, // 고유 ID
        notificationTitle,
        notificationBody,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'strategy_alerts',
            '코인 알림',
            channelDescription: '가격 알림 및 전략 알림',
            importance: Importance.high,
            priority: Priority.high,
            showWhen: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );

      print('[가격알림] 🚀 로컬 알림 발송 완료');
      print('[가격알림] 🔢 알림 ID (hashCode): ${alert.id.hashCode}');
    } catch (e) {
      print('[가격알림] ❌ 알림 발송 중 오류: $e');
      print('[가격알림] 🔍 오류 상세: ${e.toString()}');

      // 에러 발생 시에도 상태는 업데이트 (중복 발송 방지)
      try {
        final errorAlert = alert.copyWith(
          isTriggered: true,
          triggeredAt: DateTime.now(),
        );
        await _priceAlertsBox!.put(alert.id, errorAlert);
        print('[가격알림] ⚠️ 에러 상태로 알림 업데이트 완료');
      } catch (updateError) {
        print('[가격알림] 💥 알림 상태 업데이트도 실패: $updateError');
      }
    }
  }
}
