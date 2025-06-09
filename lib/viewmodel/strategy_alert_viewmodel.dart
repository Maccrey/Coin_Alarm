import 'package:flutter/foundation.dart';
import '../model/strategy_alert_model.dart';
import '../services/strategy_alert_service.dart';
import '../utils/strategy_templates.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// 전략 기반 알림 ViewModel 클래스
/// Provider 패턴을 사용하여 전략 알림의 상태 관리와 비즈니스 로직을 처리합니다.
class StrategyAlertViewModel extends ChangeNotifier {
  // Private 멤버 변수
  List<StrategyAlert> _alerts = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _currentUserId;
  String? _selectedStrategyFilter;
  String? _selectedRiskFilter;
  String? _selectedCoinFilter;
  String? _selectedStatusFilter;
  bool _boxListenerRegistered = false;

  // Public Getters

  /// 현재 알림 목록 (필터링 적용됨)
  List<StrategyAlert> get alerts => _applyFilters(_alerts);

  /// 필터링 없는 전체 알림 목록
  List<StrategyAlert> get allAlerts => _alerts;

  /// 로딩 상태
  bool get isLoading => _isLoading;

  /// 에러 메시지
  String? get errorMessage => _errorMessage;

  /// 현재 사용자 ID
  String? get currentUserId => _currentUserId;

  /// 선택된 전략 필터
  String? get selectedStrategyFilter => _selectedStrategyFilter;

  /// 선택된 위험도 필터
  String? get selectedRiskFilter => _selectedRiskFilter;

  /// 선택된 코인 필터
  String? get selectedCoinFilter => _selectedCoinFilter;

  /// 선택된 상태 필터
  String? get selectedStatusFilter => _selectedStatusFilter;

  /// 대기중인 알림 목록
  List<StrategyAlert> get pendingAlerts =>
      alerts.where((alert) => !alert.isTriggered && alert.isEnabled).toList();

  /// 발생된 알림 목록
  List<StrategyAlert> get triggeredAlerts =>
      alerts.where((alert) => alert.isTriggered).toList();

  /// 비활성화된 알림 목록
  List<StrategyAlert> get disabledAlerts =>
      alerts.where((alert) => !alert.isEnabled).toList();

  /// 활성화된 알림 목록
  List<StrategyAlert> get activeAlerts =>
      alerts.where((alert) => alert.isEnabled && !alert.isTriggered).toList();

  // Public Methods

  /// 사용자 ID 설정 및 해당 사용자의 알림 로드
  /// [userId] 설정할 사용자 ID
  Future<void> setUserId(String userId) async {
    if (_currentUserId == userId) return;

    _currentUserId = userId;
    await loadUserAlerts(userId);
  }

  /// 특정 사용자의 알림 목록 로드
  /// [userId] 로드할 사용자 ID
  Future<void> loadUserAlerts(String userId) async {
    try {
      _setLoading(true);
      _clearError();

      print('[StrategyAlertViewModel] 사용자 알림 로드 시작: $userId');
      _currentUserId = userId;
      _alerts = await StrategyAlertService.getAllAlerts(userId);
      print('[StrategyAlertViewModel] 로드된 알림 수: ${_alerts.length}');

      // Hive 박스 변경 리스너를 한 번만 등록
      if (!_boxListenerRegistered) {
        try {
          Hive.box<StrategyAlert>('strategy_alerts').listenable().addListener(
            () {
              print('[StrategyAlertViewModel] Hive 박스 변경 감지됨');
              notifyListeners();
            },
          );
          _boxListenerRegistered = true;
          print('[StrategyAlertViewModel] Hive 박스 리스너 등록 완료');
        } catch (e) {
          debugPrint('박스 리스너 등록 실패: $e');
        }
      }

      print('[StrategyAlertViewModel] 현재 필터: $_selectedStatusFilter');
      print(
        '[StrategyAlertViewModel] 필터링 적용 후 알림 수: ${_applyFilters(_alerts).length}',
      );
      notifyListeners();
    } catch (e) {
      print('[StrategyAlertViewModel] 알림 로드 오류: $e');
      _setError('알림 목록을 불러오는 중 오류가 발생했습니다: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// 새로운 전략 알림 생성
  /// [coinId] 코인 ID
  /// [coinSymbol] 코인 심볼
  /// [strategyName] 전략명
  /// [riskLevel] 위험도
  /// [triggerCondition] 트리거 조건
  /// [notes] 메모 (선택사항)
  /// 반환: 생성 성공 여부
  Future<bool> createStrategyAlert({
    required String coinId,
    required String coinSymbol,
    required String strategyName,
    required String riskLevel,
    required Map<String, dynamic> triggerCondition,
    String? notes,
  }) async {
    print(
      '[createStrategyAlert] userId=[32m[1m[4m[7m$_currentUserId[0m, coinId=$coinId, coinSymbol=$coinSymbol, strategyName=$strategyName, riskLevel=$riskLevel',
    );
    if (_currentUserId == null) {
      _setError('사용자 ID가 설정되지 않았습니다.');
      return false;
    }

    try {
      _setLoading(true);
      _clearError();

      final newAlert = await StrategyAlertService.createAlert(
        userId: _currentUserId!,
        coinId: coinId,
        coinSymbol: coinSymbol,
        strategyName: strategyName,
        riskLevel: riskLevel,
        triggerCondition: triggerCondition,
        notes: notes,
      );

      _alerts.add(newAlert);
      await loadUserAlerts(_currentUserId!); // 알림 추가 후 목록 새로고침
      notifyListeners();
      print('[createStrategyAlert] 알림 생성 성공: ${newAlert.id}');
      return true;
    } catch (e) {
      _setError('알림 생성 중 오류가 발생했습니다: $e');
      print('[createStrategyAlert] 알림 생성 실패: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// 전략 템플릿을 사용하여 알림 생성
  /// [coinId] 코인 ID
  /// [coinSymbol] 코인 심볼
  /// [strategyName] 전략명 (템플릿 자동 적용)
  /// [riskLevel] 위험도 (선택사항, 기본값은 전략 기본값)
  /// [notes] 메모 (선택사항)
  /// 반환: 생성 성공 여부
  Future<bool> createStrategyAlertFromTemplate({
    required String coinId,
    required String coinSymbol,
    required String strategyName,
    String? riskLevel,
    String? notes,
  }) async {
    print(
      '[createStrategyAlertFromTemplate] $coinId, $coinSymbol, $strategyName, $riskLevel',
    );
    try {
      // 전략별 기본 템플릿 가져오기
      final template = StrategyTemplates.getDefaultTemplate(strategyName);
      if (template.isEmpty) {
        _setError('지원하지 않는 전략입니다: $strategyName');
        print('[createStrategyAlertFromTemplate] 지원하지 않는 전략');
        return false;
      }

      // 기본 위험도 설정 (제공되지 않은 경우)
      final finalRiskLevel = riskLevel ?? _getDefaultRiskLevel(strategyName);

      final result = await createStrategyAlert(
        coinId: coinId,
        coinSymbol: coinSymbol,
        strategyName: strategyName,
        riskLevel: finalRiskLevel,
        triggerCondition: template,
        notes: notes,
      );
      print('[createStrategyAlertFromTemplate] result=$result');
      return result;
    } catch (e) {
      _setError('템플릿 기반 알림 생성 중 오류가 발생했습니다: $e');
      print('[createStrategyAlertFromTemplate] 오류: $e');
      return false;
    }
  }

  /// 알림 업데이트
  /// [alertId] 업데이트할 알림 ID
  /// [updates] 업데이트할 필드들
  /// 반환: 업데이트 성공 여부
  Future<bool> updateAlert(String alertId, Map<String, dynamic> updates) async {
    try {
      _setLoading(true);
      _clearError();

      final updatedAlert = await StrategyAlertService.updateAlert(
        alertId,
        updates,
      );
      if (updatedAlert == null) {
        _setError('알림을 찾을 수 없습니다.');
        return false;
      }

      // 로컬 목록 업데이트
      final index = _alerts.indexWhere((alert) => alert.id == alertId);
      if (index != -1) {
        _alerts[index] = updatedAlert;
        notifyListeners();
      }

      return true;
    } catch (e) {
      _setError('알림 업데이트 중 오류가 발생했습니다: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// 알림 활성화/비활성화 토글
  /// [alertId] 토글할 알림 ID
  /// 반환: 토글 성공 여부
  Future<bool> toggleAlert(String alertId) async {
    try {
      _clearError();

      final updatedAlert = await StrategyAlertService.toggleAlert(alertId);
      if (updatedAlert == null) {
        _setError('알림을 찾을 수 없습니다.');
        return false;
      }

      // 로컬 목록 업데이트
      final index = _alerts.indexWhere((alert) => alert.id == alertId);
      if (index != -1) {
        _alerts[index] = updatedAlert;
        await loadUserAlerts(_currentUserId!);
      }

      return true;
    } catch (e) {
      _setError('알림 상태 변경 중 오류가 발생했습니다: $e');
      return false;
    }
  }

  /// 알림 삭제
  /// [alertId] 삭제할 알림 ID
  /// 반환: 삭제 성공 여부
  Future<bool> deleteAlert(String alertId) async {
    try {
      _clearError();

      final success = await StrategyAlertService.deleteAlert(alertId);
      if (!success) {
        _setError('알림을 찾을 수 없습니다.');
        return false;
      }

      // 로컬 목록에서 제거
      _alerts.removeWhere((alert) => alert.id == alertId);
      await loadUserAlerts(_currentUserId!);

      return true;
    } catch (e) {
      _setError('알림 삭제 중 오류가 발생했습니다: $e');
      return false;
    }
  }

  /// 알림 트리거 (발생 처리)
  /// [alertId] 트리거할 알림 ID
  /// 반환: 트리거 성공 여부
  Future<bool> triggerAlert(String alertId) async {
    try {
      _clearError();

      final triggeredAlert = await StrategyAlertService.triggerAlert(alertId);
      if (triggeredAlert == null) {
        _setError('알림을 찾을 수 없습니다.');
        return false;
      }

      // 로컬 목록 업데이트
      final index = _alerts.indexWhere((alert) => alert.id == alertId);
      if (index != -1) {
        _alerts[index] = triggeredAlert;
        await loadUserAlerts(_currentUserId!);
      }

      return true;
    } catch (e) {
      _setError('알림 트리거 중 오류가 발생했습니다: $e');
      return false;
    }
  }

  /// 전략 필터 설정
  /// [strategyName] 필터할 전략명 (null이면 전체)
  void setStrategyFilter(String? strategyName) {
    _selectedStrategyFilter = strategyName;
    notifyListeners();
  }

  /// 위험도 필터 설정
  /// [riskLevel] 필터할 위험도 (null이면 전체)
  void setRiskFilter(String? riskLevel) {
    _selectedRiskFilter = riskLevel;
    notifyListeners();
  }

  /// 코인 필터 설정
  /// [coinId] 필터할 코인 ID (null이면 전체)
  void setCoinFilter(String? coinId) {
    _selectedCoinFilter = coinId;
    notifyListeners();
  }

  /// 상태 필터 설정
  /// [status] 필터할 상태 (pending, triggered, disabled, null이면 전체)
  void setStatusFilter(String? status) {
    _selectedStatusFilter = status;
    print('[StrategyAlertViewModel] 상태 필터 설정: $status');
    print('[StrategyAlertViewModel] 필터링 전 알림 수: ${_alerts.length}');
    print(
      '[StrategyAlertViewModel] 필터링 후 알림 수: ${_applyFilters(_alerts).length}',
    );
    notifyListeners();
  }

  /// 모든 필터 초기화
  void clearAllFilters() {
    _selectedStrategyFilter = null;
    _selectedRiskFilter = null;
    _selectedCoinFilter = null;
    _selectedStatusFilter = null;
    notifyListeners();
  }

  /// 트리거된 알림 정리
  /// [olderThanDays] 며칠 이전 알림을 정리할지
  /// 반환: 정리된 알림 개수
  Future<int> cleanupTriggeredAlerts({int olderThanDays = 30}) async {
    if (_currentUserId == null) return 0;

    try {
      _clearError();

      final cleanedCount = await StrategyAlertService.cleanupTriggeredAlerts(
        _currentUserId!,
        olderThanDays: olderThanDays,
      );

      // 로컬 목록 새로고침
      await loadUserAlerts(_currentUserId!);

      return cleanedCount;
    } catch (e) {
      _setError('알림 정리 중 오류가 발생했습니다: $e');
      return 0;
    }
  }

  /// 전략별 통계 조회
  /// 반환: 전략별 통계 맵
  Future<Map<String, Map<String, int>>> getStrategyStats() async {
    if (_currentUserId == null) return {};

    try {
      return await StrategyAlertService.getStrategyStats(_currentUserId!);
    } catch (e) {
      _setError('전략 통계 조회 중 오류가 발생했습니다: $e');
      return {};
    }
  }

  /// 위험도별 통계 조회
  /// 반환: 위험도별 통계 맵
  Future<Map<String, Map<String, int>>> getRiskLevelStats() async {
    if (_currentUserId == null) return {};

    try {
      return await StrategyAlertService.getRiskLevelStats(_currentUserId!);
    } catch (e) {
      _setError('위험도 통계 조회 중 오류가 발생했습니다: $e');
      return {};
    }
  }

  /// 알림 목록 새로고침
  Future<void> refreshAlerts() async {
    if (_currentUserId != null) {
      print('[StrategyAlertViewModel] 알림 목록 새로고침 시작');
      _setLoading(true);
      try {
        _alerts = await StrategyAlertService.getAllAlerts(_currentUserId!);
        print('[StrategyAlertViewModel] 새로고침 후 알림 수: ${_alerts.length}');
        print(
          '[StrategyAlertViewModel] 필터링 적용 후 알림 수: ${_applyFilters(_alerts).length}',
        );
      } catch (e) {
        print('[StrategyAlertViewModel] 알림 새로고침 오류: $e');
        _setError('알림 새로고침 중 오류가 발생했습니다: $e');
      } finally {
        _setLoading(false);
      }
    }
  }

  /// 에러 메시지 초기화
  void clearError() {
    _clearError();
  }

  // Private Helper Methods

  /// 로딩 상태 설정
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// 에러 메시지 설정
  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  /// 에러 메시지 초기화
  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// 필터 적용
  List<StrategyAlert> _applyFilters(List<StrategyAlert> alerts) {
    print('[_applyFilters] 필터링 전 알림 수: ${alerts.length}');
    print(
      '[_applyFilters] 현재 필터 상태: 전략=${_selectedStrategyFilter}, 위험도=${_selectedRiskFilter}, 코인=${_selectedCoinFilter}, 상태=${_selectedStatusFilter}',
    );

    List<StrategyAlert> filteredAlerts = List.from(alerts);

    // 전략 필터
    if (_selectedStrategyFilter != null) {
      filteredAlerts = filteredAlerts
          .where((alert) => alert.strategyName == _selectedStrategyFilter)
          .toList();
      print('[_applyFilters] 전략 필터 적용 후: ${filteredAlerts.length}개');
    }

    // 위험도 필터
    if (_selectedRiskFilter != null) {
      filteredAlerts = filteredAlerts
          .where((alert) => alert.riskLevel == _selectedRiskFilter)
          .toList();
      print('[_applyFilters] 위험도 필터 적용 후: ${filteredAlerts.length}개');
    }

    // 코인 필터
    if (_selectedCoinFilter != null) {
      filteredAlerts = filteredAlerts
          .where((alert) => alert.coinId == _selectedCoinFilter)
          .toList();
      print('[_applyFilters] 코인 필터 적용 후: ${filteredAlerts.length}개');
    }

    // 상태 필터
    if (_selectedStatusFilter != null) {
      int beforeCount = filteredAlerts.length;
      switch (_selectedStatusFilter) {
        case 'pending':
          filteredAlerts = filteredAlerts
              .where((alert) => !alert.isTriggered && alert.isEnabled)
              .toList();
          print(
            '[_applyFilters] pending 필터 적용: ${beforeCount}개 -> ${filteredAlerts.length}개',
          );
          break;
        case 'triggered':
          filteredAlerts = filteredAlerts
              .where((alert) => alert.isTriggered)
              .toList();
          print(
            '[_applyFilters] triggered 필터 적용: ${beforeCount}개 -> ${filteredAlerts.length}개',
          );
          break;
        case 'disabled':
          filteredAlerts = filteredAlerts
              .where((alert) => !alert.isEnabled)
              .toList();
          print(
            '[_applyFilters] disabled 필터 적용: ${beforeCount}개 -> ${filteredAlerts.length}개',
          );
          break;
      }
    }

    print('[_applyFilters] 최종 필터링 결과: ${filteredAlerts.length}개');

    if (filteredAlerts.isEmpty && _selectedStatusFilter != null) {
      print('[_applyFilters] 경고: 필터링 결과가 없습니다. 데이터를 확인하세요.');
      // 알림 상태 디버깅을 위해 전체 알림의 상태 출력
      for (var alert in alerts) {
        print(
          '[_applyFilters] 알림 ID: ${alert.id}, 활성화: ${alert.isEnabled}, 발생됨: ${alert.isTriggered}, 전략: ${alert.strategyName}',
        );
      }
    }

    return filteredAlerts;
  }

  /// 전략별 기본 위험도 반환
  String _getDefaultRiskLevel(String strategyName) {
    final strategies = StrategyTemplates.getAllStrategies();
    final strategy = strategies.firstWhere(
      (s) => s['name'] == strategyName,
      orElse: () => {'riskLevel': 'medium'},
    );
    return strategy['riskLevel'] ?? 'medium';
  }
}
