import 'package:flutter/material.dart';
import '../services/settings_service.dart';

/// 테마 관련 ViewModel
///
/// 앱의 테마 설정을 관리합니다.
class ThemeViewModel extends ChangeNotifier {
  final SettingsService _settingsService;
  bool _isDarkMode = false;

  /// 다크 모드 여부
  bool get isDarkMode => _isDarkMode;

  /// 테마 모드
  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  /// 생성자
  ThemeViewModel(this._settingsService) {
    _loadThemeSettings();
  }

  /// 테마 설정 불러오기
  Future<void> _loadThemeSettings() async {
    _isDarkMode = await _settingsService.getDarkMode();
    notifyListeners();
  }

  /// 테마 모드 변경
  Future<void> toggleThemeMode() async {
    _isDarkMode = !_isDarkMode;
    await _settingsService.setDarkMode(_isDarkMode);
    notifyListeners();
  }

  /// 다크 모드 설정
  Future<void> setDarkMode(bool isDarkMode) async {
    if (_isDarkMode != isDarkMode) {
      _isDarkMode = isDarkMode;
      await _settingsService.setDarkMode(isDarkMode);
      notifyListeners();
    }
  }
}
