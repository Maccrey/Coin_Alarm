import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// 앱의 테마(색상, 서체, 스타일 등)을 정의하는 파일입니다.

/// 앱 테마 관련 설정 클래스
class AppTheme {
  /// 주요 색상
  static const Color primaryColor = Color(0xFF5B37B7); // 보라색 계열
  static const Color secondaryColor = Color(0xFF1CD8D2); // 민트 계열
  static const Color accentColor = Color(0xFFFFA500); // 주황색 계열
  static const Color primaryDarkColor = Color(0xFF4527A0); // 어두운 보라색

  /// 배경 색상
  static const Color lightBackgroundColor = Color(0xFFF8F9FA);
  static const Color darkBackgroundColor = Color(0xFF212121);

  /// 카드 배경 색상
  static const Color lightCardColor = Colors.white;
  static const Color darkCardColor = Color(0xFF2C2C2C);

  /// 텍스트 색상
  static const Color lightTextColor = Color(0xFF1F1F1F);
  static const Color darkTextColor = Color(0xFFF1F1F1);
  static const Color lightSecondaryTextColor = Color(0xFF666666);
  static const Color darkSecondaryTextColor = Color(0xFFB3B3B3);

  /// 가격 변동 색상
  static const Color positiveColor = Color(0xFF1F7CEB); // 상승 (파란색)
  static const Color negativeColor = Color(0xFFFF5252); // 하락 (빨간색)

  /// 경고 및 알림 색상
  static const Color warningColor = Color(0xFFFFB74D);
  static const Color errorColor = Color(0xFFE53935);
  static const Color infoColor = Color(0xFF29B6F6);
  static const Color successColor = Color(0xFF43A047);

  /// 라이트 테마 생성
  static ThemeData lightTheme() {
    // 라이트 테마 직접 생성
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: lightBackgroundColor,
      cardColor: lightCardColor,
      dividerColor: Colors.grey.shade300,
      colorScheme: ColorScheme.light(
        primary: primaryColor,
        primaryContainer: primaryColor.withOpacity(0.1),
        secondary: secondaryColor,
        background: lightBackgroundColor,
        surface: lightCardColor,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: lightTextColor,
        onBackground: lightTextColor,
        error: errorColor,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: lightBackgroundColor,
        foregroundColor: lightTextColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: primaryColor),
        titleTextStyle: GoogleFonts.notoSansKr(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: lightTextColor,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.grey.shade600,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
          minimumSize: const Size(double.infinity, 48),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: const BorderSide(color: primaryColor),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          minimumSize: const Size(double.infinity, 48),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primaryColor),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: errorColor),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      textTheme: _getTextTheme(
        GoogleFonts.notoSansKrTextTheme(),
        lightTextColor,
        lightSecondaryTextColor,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return primaryColor;
          }
          return null;
        }),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      radioTheme: RadioThemeData(
        fillColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return primaryColor;
          }
          return null;
        }),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return primaryColor;
          }
          return null;
        }),
        trackColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return primaryColor.withOpacity(0.5);
          }
          return null;
        }),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: primaryColor,
        thumbColor: primaryColor,
        inactiveTrackColor: primaryColor.withOpacity(0.2),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primaryColor,
      ),
      listTileTheme: const ListTileThemeData(iconColor: primaryColor),
    );
  }

  /// 다크 테마 생성
  static ThemeData darkTheme() {
    // 다크 테마 직접 생성
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: darkBackgroundColor,
      cardColor: darkCardColor,
      dividerColor: Colors.grey.shade800,
      colorScheme: ColorScheme.dark(
        primary: primaryColor,
        primaryContainer: primaryColor.withOpacity(0.1),
        secondary: secondaryColor,
        background: darkBackgroundColor,
        surface: darkCardColor,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: darkTextColor,
        onBackground: darkTextColor,
        error: errorColor,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: darkBackgroundColor,
        foregroundColor: darkTextColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: primaryColor.withOpacity(0.9)),
        titleTextStyle: GoogleFonts.notoSansKr(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: darkTextColor,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: const Color(0xFF1F1F1F),
        selectedItemColor: primaryColor.withOpacity(0.9),
        unselectedItemColor: Colors.grey.shade500,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
          minimumSize: const Size(double.infinity, 48),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor.withOpacity(0.9),
          side: BorderSide(color: primaryColor.withOpacity(0.9)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          minimumSize: const Size(double.infinity, 48),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor.withOpacity(0.9),
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF2F2F2F),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade800),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: primaryColor.withOpacity(0.9)),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: errorColor),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      textTheme: _getTextTheme(
        GoogleFonts.notoSansKrTextTheme(ThemeData.dark().textTheme),
        darkTextColor,
        darkSecondaryTextColor,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return primaryColor.withOpacity(0.9);
          }
          return null;
        }),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      radioTheme: RadioThemeData(
        fillColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return primaryColor.withOpacity(0.9);
          }
          return null;
        }),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return primaryColor.withOpacity(0.9);
          }
          return null;
        }),
        trackColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return primaryColor.withOpacity(0.4);
          }
          return null;
        }),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: primaryColor.withOpacity(0.9),
        thumbColor: primaryColor.withOpacity(0.9),
        inactiveTrackColor: primaryColor.withOpacity(0.2),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primaryColor.withOpacity(0.9),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: primaryColor.withOpacity(0.9),
      ),
    );
  }

  /// 텍스트 테마 생성
  static TextTheme _getTextTheme(
    TextTheme baseTextTheme,
    Color primaryTextColor,
    Color secondaryTextColor,
  ) {
    return baseTextTheme.copyWith(
      displayLarge: baseTextTheme.displayLarge?.copyWith(
        color: primaryTextColor,
        fontWeight: FontWeight.bold,
      ),
      displayMedium: baseTextTheme.displayMedium?.copyWith(
        color: primaryTextColor,
        fontWeight: FontWeight.bold,
      ),
      displaySmall: baseTextTheme.displaySmall?.copyWith(
        color: primaryTextColor,
        fontWeight: FontWeight.bold,
      ),
      headlineLarge: baseTextTheme.headlineLarge?.copyWith(
        color: primaryTextColor,
        fontWeight: FontWeight.bold,
      ),
      headlineMedium: baseTextTheme.headlineMedium?.copyWith(
        color: primaryTextColor,
        fontWeight: FontWeight.bold,
      ),
      headlineSmall: baseTextTheme.headlineSmall?.copyWith(
        color: primaryTextColor,
        fontWeight: FontWeight.bold,
      ),
      titleLarge: baseTextTheme.titleLarge?.copyWith(
        color: primaryTextColor,
        fontWeight: FontWeight.bold,
      ),
      titleMedium: baseTextTheme.titleMedium?.copyWith(
        color: primaryTextColor,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: baseTextTheme.titleSmall?.copyWith(
        color: primaryTextColor,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(color: primaryTextColor),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(color: primaryTextColor),
      bodySmall: baseTextTheme.bodySmall?.copyWith(color: secondaryTextColor),
      labelLarge: baseTextTheme.labelLarge?.copyWith(
        color: primaryTextColor,
        fontWeight: FontWeight.w600,
      ),
      labelMedium: baseTextTheme.labelMedium?.copyWith(
        color: secondaryTextColor,
      ),
      labelSmall: baseTextTheme.labelSmall?.copyWith(color: secondaryTextColor),
    );
  }

  /// 앱 색상 테마 이름 가져오기
  static String getThemeModeName(ThemeMode themeMode) {
    switch (themeMode) {
      case ThemeMode.system:
        return '시스템 설정 사용';
      case ThemeMode.light:
        return '라이트 모드';
      case ThemeMode.dark:
        return '다크 모드';
    }
  }
}
