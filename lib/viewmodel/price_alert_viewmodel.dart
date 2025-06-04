import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/supabase_service.dart';
import '../model/price_alert_model.dart';
import '../model/coin_model.dart';

// 가격 알림 관련 ViewModel 클래스
class PriceAlertViewModel extends ChangeNotifier {
  final SupabaseService _supabaseService;

  // 상태 관리
  bool _isLoading = false;
  List<PriceAlert> _alerts = [];
  String? _errorMessage;

  // 필터링
  String? _coinFilter;

  // 생성자
  PriceAlertViewModel(this._supabaseService);

  // Getters
  bool get isLoading => _isLoading;
  List<PriceAlert> get alerts => _coinFilter != null
      ? _alerts.where((alert) => alert.coinId == _coinFilter).toList()
      : _alerts;
  String? get errorMessage => _errorMessage;

  // 사용자의 가격 알림 로드
  Future<void> loadUserAlerts(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final alerts = await _supabaseService.getAlertSettings(userId: userId);
      _alerts = alerts.map((data) => PriceAlert.fromJson(data)).toList();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = '가격 알림 로드 실패: $e';
      debugPrint(_errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 가격 알림 생성
  Future<bool> createAlert(
    String userId,
    String coinId,
    String coinSymbol,
    double priceTarget,
    bool isAbove, {
    String? notes,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      // 새 알림 객체 생성
      final newAlert = PriceAlert(
        id: 'temp-${DateTime.now().millisecondsSinceEpoch}', // 임시 ID (DB에서 자동 생성됨)
        userId: userId,
        coinId: coinId,
        coinSymbol: coinSymbol,
        priceTarget: priceTarget,
        isAbove: isAbove,
        isTriggered: false,
        createdAt: DateTime.now(),
        notes: notes,
      );

      // DB에 저장
      await _supabaseService.saveAlertSetting(
        userId: userId,
        symbol: coinSymbol,
        targetPrice: priceTarget,
        isAbove: isAbove,
        isActive: true,
      );

      // 로컬 목록에 추가
      _alerts.add(newAlert);
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = '가격 알림 생성 실패: $e';
      debugPrint(_errorMessage);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 가격 알림 삭제
  Future<bool> deleteAlert(String alertId) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _supabaseService.deleteAlertSetting(alertId: int.parse(alertId));

      // 로컬 목록에서 제거
      _alerts.removeWhere((alert) => alert.id == alertId);
      _errorMessage = null;
      return true;
    } catch (e) {
      _errorMessage = '가격 알림 삭제 실패: $e';
      debugPrint(_errorMessage);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 코인별 필터 설정
  void setFilter(String? coinId) {
    _coinFilter = coinId;
    notifyListeners();
  }

  // 필터 초기화
  void clearFilter() {
    _coinFilter = null;
    notifyListeners();
  }

  // 특정 코인의 알림 개수 확인
  int getAlertCountForCoin(String coinId) {
    return _alerts.where((alert) => alert.coinId == coinId).length;
  }

  // 에러 메시지 초기화
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // 가격 알림이 트리거되었는지 확인 (실제로는 서버에서 처리)
  Future<void> checkAlertsTriggered(List<Coin> currentPrices) async {
    for (final coin in currentPrices) {
      final alertsForCoin = _alerts
          .where((alert) => alert.coinId == coin.id && !alert.isTriggered)
          .toList();

      for (final alert in alertsForCoin) {
        // 가격 조건 확인
        final isTriggered = alert.isAbove
            ? coin.currentPrice >= alert.priceTarget
            : coin.currentPrice <= alert.priceTarget;

        if (isTriggered) {
          // 실제 앱에서는 여기서 알림을 표시하고 DB에 상태 업데이트
          debugPrint('알림 발생: ${alert.description} (현재가: ${coin.currentPrice})');

          // 로컬 상태 업데이트 (실제로는 DB 업데이트 후 새로 로드)
          final index = _alerts.indexWhere((a) => a.id == alert.id);
          if (index >= 0) {
            _alerts[index] = alert.copyWith(
              isTriggered: true,
              triggeredAt: DateTime.now(),
            );
          }
        }
      }
    }

    // 변경사항이 있으면 갱신
    notifyListeners();
  }
}
