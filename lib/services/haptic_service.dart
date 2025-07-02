import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 햅틱 피드백 서비스 클래스
/// 다양한 햅틱 피드백을 제공하여 사용자 경험을 향상시킵니다.
class HapticService {
  /// 싱글톤 인스턴스
  static final HapticService _instance = HapticService._internal();

  /// 팩토리 생성자
  factory HapticService() => _instance;

  /// 내부 생성자
  HapticService._internal();

  /// 햅틱 피드백 활성화 여부
  bool _isEnabled = true;

  /// 햅틱 피드백 활성화 여부 확인
  bool get isEnabled => _isEnabled;

  /// 햅틱 피드백 활성화/비활성화 설정
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    debugPrint('햅틱 피드백 ${enabled ? '활성화' : '비활성화'}');
  }

  /// 가벼운 햅틱 피드백 (버튼 탭 등)
  /// 가장 가벼운 진동으로 일반적인 UI 상호작용에 사용
  Future<void> lightImpact() async {
    if (!_isEnabled || kIsWeb) return;

    try {
      await HapticFeedback.heavyImpact();
      debugPrint('햅틱: 가벼운 임팩트');
    } catch (e) {
      debugPrint('햅틱 피드백 오류 (lightImpact): $e');
    }
  }

  /// 중간 강도 햅틱 피드백 (네비게이션 등)
  /// 보통 강도의 진동으로 중요한 액션에 사용
  Future<void> mediumImpact() async {
    if (!_isEnabled || kIsWeb) return;

    try {
      await HapticFeedback.mediumImpact();
      debugPrint('햅틱: 중간 임팩트');
    } catch (e) {
      debugPrint('햅틱 피드백 오류 (mediumImpact): $e');
    }
  }

  /// 강한 햅틱 피드백 (중요한 액션)
  /// 가장 강한 진동으로 중요한 피드백이 필요한 경우 사용
  Future<void> heavyImpact() async {
    if (!_isEnabled || kIsWeb) return;

    try {
      await HapticFeedback.heavyImpact();
      debugPrint('햅틱: 강한 임팩트');
    } catch (e) {
      debugPrint('햅틱 피드백 오류 (heavyImpact): $e');
    }
  }

  /// 선택 햅틱 피드백 (스위치, 슬라이더 등)
  /// 선택 변경 시 사용하는 부드러운 진동
  Future<void> selectionClick() async {
    if (!_isEnabled || kIsWeb) return;

    try {
      await HapticFeedback.selectionClick();
      debugPrint('햅틱: 선택 클릭');
    } catch (e) {
      debugPrint('햅틱 피드백 오류 (selectionClick): $e');
    }
  }

  /// 진동 패턴 햅틱 피드백 (Android만 지원)
  /// 사용자 정의 진동 패턴 실행
  Future<void> vibrate({int duration = 100}) async {
    if (!_isEnabled || kIsWeb) return;

    try {
      await HapticFeedback.vibrate();
      debugPrint('햅틱: 진동 (${duration}ms)');
    } catch (e) {
      debugPrint('햅틱 피드백 오류 (vibrate): $e');
    }
  }

  /// 네비게이션 전용 햅틱 피드백
  /// 바텀 네비게이션 버튼 터치 시 사용
  Future<void> navigationTap() async {
    await mediumImpact();
  }

  /// 버튼 터치 전용 햅틱 피드백
  /// 일반 버튼 터치 시 사용
  Future<void> buttonTap() async {
    await lightImpact();
  }

  /// 성공 피드백 햅틱
  /// 성공적인 액션 완료 시 사용
  Future<void> success() async {
    await lightImpact();
    await Future.delayed(const Duration(milliseconds: 50));
    await lightImpact();
  }

  /// 오류 피드백 햅틱
  /// 오류 발생 시 사용
  Future<void> error() async {
    await heavyImpact();
  }

  /// 경고 피드백 햅틱
  /// 경고 메시지 표시 시 사용
  Future<void> warning() async {
    await mediumImpact();
  }

  /// 알림 피드백 햅틱
  /// 새로운 알림이나 메시지 도착 시 사용
  Future<void> notification() async {
    await lightImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    await lightImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    await lightImpact();
  }

  /// 데이터 새로고침 햅틱
  /// 새로고침 완료 시 사용
  Future<void> refresh() async {
    await mediumImpact();
  }

  /// 스위치 토글 햅틱
  /// 설정 스위치 변경 시 사용
  Future<void> toggle() async {
    await selectionClick();
  }

  /// 페이지 전환 햅틱
  /// 페이지나 탭 전환 시 사용
  Future<void> pageTransition() async {
    await lightImpact();
  }
}
