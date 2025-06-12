import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../model/price_alert_model.dart';
import '../model/coin_model.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/supabase_service.dart';

/// 가격 알림 관련 서비스
class PriceAlertService {
  static const String _alertBoxName = 'price_alerts';

  late Box<PriceAlert> _alertBox;
  bool _isInitialized = false;

  /// 싱글톤 인스턴스
  static final PriceAlertService _instance = PriceAlertService._internal();

  /// 팩토리 생성자
  factory PriceAlertService() => _instance;

  /// 내부 생성자
  PriceAlertService._internal();

  /// 초기화 메서드
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('PriceAlertService: 이미 초기화되었습니다.');
      return;
    }

    try {
      debugPrint('PriceAlertService: 초기화 시작');

      // Hive 어댑터 등록 (이미 등록되어 있지 않은 경우)
      if (!Hive.isAdapterRegistered(10)) {
        Hive.registerAdapter(PriceAlertAdapter());
      }

      // 박스 열기
      _alertBox = await Hive.openBox<PriceAlert>(_alertBoxName);

      _isInitialized = true;
      debugPrint('PriceAlertService: 초기화 완료');
    } catch (e) {
      debugPrint('PriceAlertService: 초기화 오류 - $e');
      rethrow;
    }
  }

  /// 사용자의 모든 알림 가져오기
  Future<List<PriceAlert>> getAlerts(String userId) async {
    await _ensureInitialized();

    try {
      final alerts = _alertBox.values
          .where((alert) => alert.userId == userId)
          .toList();
      debugPrint('PriceAlertService: ${alerts.length}개의 알림을 불러왔습니다.');
      return alerts;
    } catch (e) {
      debugPrint('PriceAlertService: 알림 불러오기 오류 - $e');
      return [];
    }
  }

  /// 새 알림 저장
  Future<PriceAlert?> createAlert(
    String userId,
    String coinId,
    String coinSymbol,
    double priceTarget,
    bool isAbove, {
    String? notes,
  }) async {
    await _ensureInitialized();

    try {
      final alertId = const Uuid().v4();
      final newAlert = PriceAlert(
        id: alertId,
        userId: userId,
        coinId: coinId,
        coinSymbol: coinSymbol,
        priceTarget: priceTarget,
        isAbove: isAbove,
        isTriggered: false,
        createdAt: DateTime.now(),
        notes: notes,
      );

      await _alertBox.put(alertId, newAlert);
      debugPrint(
        'PriceAlertService: 새 알림이 생성되었습니다 - $coinSymbol (${isAbove ? '이상' : '이하'} $priceTarget)',
      );
      return newAlert;
    } catch (e) {
      debugPrint('PriceAlertService: 알림 생성 오류 - $e');
      return null;
    }
  }

  /// 알림 업데이트
  Future<bool> updateAlert(PriceAlert alert) async {
    await _ensureInitialized();

    try {
      await _alertBox.put(alert.id, alert);
      debugPrint('PriceAlertService: 알림 업데이트 완료 - ${alert.id}');
      return true;
    } catch (e) {
      debugPrint('PriceAlertService: 알림 업데이트 오류 - $e');
      return false;
    }
  }

  /// 알림 삭제
  Future<bool> deleteAlert(String alertId) async {
    await _ensureInitialized();

    try {
      await _alertBox.delete(alertId);
      debugPrint('PriceAlertService: 알림 삭제 완료 - $alertId');
      return true;
    } catch (e) {
      debugPrint('PriceAlertService: 알림 삭제 오류 - $e');
      return false;
    }
  }

  /// 사용자의 모든 알림 삭제
  Future<bool> deleteAllAlerts(String userId) async {
    await _ensureInitialized();

    try {
      final userAlertKeys = _alertBox.values
          .where((alert) => alert.userId == userId)
          .map((alert) => alert.id)
          .toList();

      for (final key in userAlertKeys) {
        await _alertBox.delete(key);
      }

      debugPrint('PriceAlertService: 모든 알림 삭제 완료 - $userId');
      return true;
    } catch (e) {
      debugPrint('PriceAlertService: 모든 알림 삭제 오류 - $e');
      return false;
    }
  }

  /// 알림 발생 여부 확인 및 업데이트
  Future<List<PriceAlert>> checkAndUpdateAlerts(
    List<Coin> coins,
    String userId,
  ) async {
    await _ensureInitialized();

    final triggeredAlerts = <PriceAlert>[];
    final userAlerts = _alertBox.values
        .where((alert) => alert.userId == userId && !alert.isTriggered)
        .toList();

    for (final alert in userAlerts) {
      final coin = coins.firstWhere(
        (coin) => coin.id == alert.coinId,
        orElse: () => Coin(
          id: '',
          symbol: '',
          name: '',
          currentPrice: 0,
          priceChangePercentage24h: 0,
          lastUpdated: DateTime.now(),
        ),
      );

      if (coin.id.isEmpty) continue;

      final isTriggered = alert.isAbove
          ? coin.currentPrice >= alert.priceTarget
          : coin.currentPrice <= alert.priceTarget;

      if (isTriggered) {
        final updatedAlert = alert.copyWith(
          isTriggered: true,
          triggeredAt: DateTime.now(),
        );

        await _alertBox.put(alert.id, updatedAlert);
        triggeredAlerts.add(updatedAlert);

        debugPrint(
          'PriceAlertService: 알림 발생 - \\${alert.coinSymbol} (\\${alert.isAbove ? '이상' : '이하'} \\${alert.priceTarget})',
        );

        // 이메일 전송 (Gmail SMTP)
        await sendAlertEmail(userId, updatedAlert);
      }
    }

    return triggeredAlerts;
  }

  /// 알림 발생 시 이메일 전송 (Gmail SMTP)
  Future<void> sendAlertEmail(String userId, PriceAlert alert) async {
    final email = await SupabaseService().getUserEmailById(userId);
    final subject = '[코인알람] 알림 발생: ${alert.coinSymbol}';
    final body =
        '알림 조건: ${alert.conditionText}\n발생 시각: ${alert.triggeredAt}\n메모: ${alert.notes ?? ''}';

    // Gmail SMTP 정보 (앱 비밀번호 사용)
    // TODO: 추후 변경 실제 이메일로 변경
    final gmailUser = dotenv.env['GMAIL_USER'] ?? 'maccrey@gmail.com';
    final gmailAppPassword =
        dotenv.env['GMAIL_APP_PASSWORD'] ?? 'Maccrey03120214';
    final smtpServer = gmail(gmailUser, gmailAppPassword);

    final message = Message()
      ..from = Address(gmailUser, '코인알람')
      ..recipients.add(email)
      ..subject = subject
      ..text = body;

    try {
      final sendReport = await send(message, smtpServer);
      print('이메일 전송 성공: ' + sendReport.toString());
    } on MailerException catch (e) {
      print('이메일 전송 실패: $e');
    }
  }

  /// 초기화 확인 및 필요시 초기화
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }
}
