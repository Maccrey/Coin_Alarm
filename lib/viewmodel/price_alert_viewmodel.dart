import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/price_alert_service.dart';
import '../model/price_alert_model.dart';
import '../model/coin_model.dart';

// 가격 알림 관련 ViewModel 클래스
class PriceAlertViewModel extends ChangeNotifier {
  final PriceAlertService _alertService;

  // 상태 관리
  bool _isLoading = false;
  List<PriceAlert> _alerts = [];
  String? _errorMessage;

  // 필터링
  String? _coinFilter;

  // 생성자
  PriceAlertViewModel(this._alertService);

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
      final alerts = await _alertService.getAlerts(userId);
      _alerts = alerts;
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
      final newAlert = await _alertService.createAlert(
        userId,
        coinId,
        coinSymbol,
        priceTarget,
        isAbove,
        notes: notes,
      );

      if (newAlert != null) {
        // 로컬 목록에 추가
        _alerts.add(newAlert);
        _errorMessage = null;
        notifyListeners();
        return true;
      }
      return false;
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
      final success = await _alertService.deleteAlert(alertId);

      if (success) {
        // 로컬 목록에서 제거
        _alerts.removeWhere((alert) => alert.id == alertId);
        _errorMessage = null;
      }
      return success;
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

  // 가격 알림이 트리거되었는지 확인
  Future<void> checkAlertsTriggered(List<Coin> currentPrices) async {
    // 로컬 사용자 ID (실제로는 인증된 사용자 ID 사용)
    const userId = 'local-user';
    final triggeredAlerts = await _alertService.checkAndUpdateAlerts(
      currentPrices,
      userId,
    );

    if (triggeredAlerts.isNotEmpty) {
      // 로컬 상태 업데이트
      for (final triggeredAlert in triggeredAlerts) {
        final index = _alerts.indexWhere((a) => a.id == triggeredAlert.id);
        if (index >= 0) {
          _alerts[index] = triggeredAlert;
        }
      }

      // 변경사항이 있으면 갱신
      notifyListeners();
    }
  }
}
