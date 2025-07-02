import 'package:flutter/material.dart';
import '../services/settings_service.dart';

/// 테마 관련 ViewModel
///
/// 앱의 테마 설정을 관리합니다.
class ThemeViewModel extends ChangeNotifier {
  final SettingsService _settingsService;
  bool _isDarkMode = false;
  ThemeMode _themeMode = ThemeMode.system;

  /// 다크 모드 여부
  bool get isDarkMode => _isDarkMode;

  /// 테마 모드
  ThemeMode get themeMode => _themeMode;

  /// 생성자
  ThemeViewModel(this._settingsService) {
    _loadThemeSettings();
  }

  /// 테마 설정 불러오기
  Future<void> _loadThemeSettings() async {
    // 다크 모드 설정 불러오기 (이전 버전 호환성 유지)
    _isDarkMode = await _settingsService.getDarkMode();

    // 테마 모드 설정 불러오기
    _themeMode = _settingsService.getThemeMode();

    // 다크 모드 설정이 있으면 테마 모드에 반영 (이전 버전 호환성)
    if (_isDarkMode && _themeMode == ThemeMode.system) {
      _themeMode = ThemeMode.dark;
    }

    notifyListeners();
    debugPrint('ThemeViewModel: 테마 설정 로드 완료 - 모드: $_themeMode');
  }

  /// 테마 모드 변경
  Future<void> toggleThemeMode() async {
    if (_themeMode == ThemeMode.light) {
      await setThemeMode(ThemeMode.dark);
    } else {
      await setThemeMode(ThemeMode.light);
    }
  }

  /// 테마 모드 설정
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode != mode) {
      _themeMode = mode;

      // 다크 모드 여부도 함께 업데이트 (이전 버전 호환성)
      _isDarkMode = (mode == ThemeMode.dark);
      await _settingsService.setDarkMode(_isDarkMode);

      // 테마 모드 저장
      await _settingsService.setThemeMode(mode);

      debugPrint('ThemeViewModel: 테마 모드 변경 - $mode');
      notifyListeners();
    }
  }

  /// 다크 모드 설정 (이전 버전 호환성)
  Future<void> setDarkMode(bool isDarkMode) async {
    if (_isDarkMode != isDarkMode) {
      _isDarkMode = isDarkMode;
      _themeMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;

      await _settingsService.setDarkMode(isDarkMode);
      await _settingsService.setThemeMode(_themeMode);

      notifyListeners();
    }
  }
}
