import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// 앱의 테마(색상, 서체, 스타일 등)을 정의하는 파일입니다.

class AppTheme {
  // 라이트 테마 정의
  static ThemeData lightTheme() {
    return ThemeData(
      // 색상 스키마
      colorScheme: ColorScheme.light(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: Colors.white,
        background: Color(0xFFF8F9FA),
        error: errorColor,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textColorDark,
        onBackground: textColorDark,
        onError: Colors.white,
      ),

      // 앱바 테마
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        foregroundColor: textColorDark,
        titleTextStyle: GoogleFonts.notoSans(
          fontWeight: FontWeight.w600,
          fontSize: 18,
          color: textColorDark,
        ),
      ),

      // 카드 테마
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: Colors.white,
        shadowColor: Colors.black.withOpacity(0.1),
      ),

      // 버튼 테마
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 1,
          textStyle: GoogleFonts.notoSans(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),

      // 텍스트 테마
      textTheme: GoogleFonts.notoSansTextTheme().copyWith(
        displayLarge: GoogleFonts.notoSans(
          fontWeight: FontWeight.bold,
          fontSize: 32,
          color: textColorDark,
        ),
        displayMedium: GoogleFonts.notoSans(
          fontWeight: FontWeight.bold,
          fontSize: 28,
          color: textColorDark,
        ),
        displaySmall: GoogleFonts.notoSans(
          fontWeight: FontWeight.bold,
          fontSize: 24,
          color: textColorDark,
        ),
        headlineMedium: GoogleFonts.notoSans(
          fontWeight: FontWeight.w600,
          fontSize: 20,
          color: textColorDark,
        ),
        headlineSmall: GoogleFonts.notoSans(
          fontWeight: FontWeight.w600,
          fontSize: 18,
          color: textColorDark,
        ),
        titleLarge: GoogleFonts.notoSans(
          fontWeight: FontWeight.w600,
          fontSize: 16,
          color: textColorDark,
        ),
        bodyLarge: GoogleFonts.notoSans(
          fontWeight: FontWeight.normal,
          fontSize: 16,
          color: textColorDark,
        ),
        bodyMedium: GoogleFonts.notoSans(
          fontWeight: FontWeight.normal,
          fontSize: 14,
          color: textColorDark,
        ),
        bodySmall: GoogleFonts.notoSans(
          fontWeight: FontWeight.normal,
          fontSize: 12,
          color: textColorMedium,
        ),
      ),

      // 입력 필드 테마
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: borderColor, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: borderColor, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: primaryColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: errorColor, width: 1),
        ),
        labelStyle: GoogleFonts.notoSans(
          fontWeight: FontWeight.normal,
          fontSize: 14,
          color: textColorMedium,
        ),
        hintStyle: GoogleFonts.notoSans(
          fontWeight: FontWeight.normal,
          fontSize: 14,
          color: textColorLight,
        ),
      ),

      // 스위치 테마
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith<Color>((states) {
          if (states.contains(MaterialState.selected)) {
            return primaryColor;
          }
          return Colors.grey;
        }),
        trackColor: MaterialStateProperty.resolveWith<Color>((states) {
          if (states.contains(MaterialState.selected)) {
            return primaryColor.withOpacity(0.5);
          }
          return Colors.grey.withOpacity(0.5);
        }),
      ),

      // 기타 설정
      scaffoldBackgroundColor: Color(0xFFF8F9FA),
      dividerColor: borderColor,
      splashColor: primaryColor.withOpacity(0.1),
      highlightColor: primaryColor.withOpacity(0.05),
    );
  }

  // 다크 테마 정의
  static ThemeData darkTheme() {
    return ThemeData(
      // 색상 스키마
      colorScheme: ColorScheme.dark(
        primary: primaryColorDark,
        secondary: secondaryColorDark,
        surface: darkSurfaceColor,
        background: darkBackgroundColor,
        error: errorColorDark,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Colors.white,
        onBackground: Colors.white,
        onError: Colors.white,
      ),

      // 앱바 테마
      appBarTheme: AppBarTheme(
        backgroundColor: darkSurfaceColor,
        elevation: 0,
        centerTitle: true,
        foregroundColor: Colors.white,
        titleTextStyle: GoogleFonts.notoSans(
          fontWeight: FontWeight.w600,
          fontSize: 18,
          color: Colors.white,
        ),
      ),

      // 카드 테마
      cardTheme: CardThemeData(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: darkCardColor,
        shadowColor: Colors.black.withOpacity(0.3),
      ),

      // 버튼 테마
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColorDark,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 2,
          textStyle: GoogleFonts.notoSans(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),

      // 텍스트 테마
      textTheme: GoogleFonts.notoSansTextTheme().copyWith(
        displayLarge: GoogleFonts.notoSans(
          fontWeight: FontWeight.bold,
          fontSize: 32,
          color: Colors.white,
        ),
        displayMedium: GoogleFonts.notoSans(
          fontWeight: FontWeight.bold,
          fontSize: 28,
          color: Colors.white,
        ),
        displaySmall: GoogleFonts.notoSans(
          fontWeight: FontWeight.bold,
          fontSize: 24,
          color: Colors.white,
        ),
        headlineMedium: GoogleFonts.notoSans(
          fontWeight: FontWeight.w600,
          fontSize: 20,
          color: Colors.white,
        ),
        headlineSmall: GoogleFonts.notoSans(
          fontWeight: FontWeight.w600,
          fontSize: 18,
          color: Colors.white,
        ),
        titleLarge: GoogleFonts.notoSans(
          fontWeight: FontWeight.w600,
          fontSize: 16,
          color: Colors.white,
        ),
        bodyLarge: GoogleFonts.notoSans(
          fontWeight: FontWeight.normal,
          fontSize: 16,
          color: Colors.white,
        ),
        bodyMedium: GoogleFonts.notoSans(
          fontWeight: FontWeight.normal,
          fontSize: 14,
          color: Colors.white.withOpacity(0.9),
        ),
        bodySmall: GoogleFonts.notoSans(
          fontWeight: FontWeight.normal,
          fontSize: 12,
          color: Colors.white.withOpacity(0.7),
        ),
      ),

      // 입력 필드 테마
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkInputColor,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: darkBorderColor, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: darkBorderColor, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: primaryColorDark, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: errorColorDark, width: 1),
        ),
        labelStyle: GoogleFonts.notoSans(
          fontWeight: FontWeight.normal,
          fontSize: 14,
          color: Colors.white.withOpacity(0.8),
        ),
        hintStyle: GoogleFonts.notoSans(
          fontWeight: FontWeight.normal,
          fontSize: 14,
          color: Colors.white.withOpacity(0.6),
        ),
      ),

      // 스위치 테마
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith<Color>((states) {
          if (states.contains(MaterialState.selected)) {
            return primaryColorDark;
          }
          return Colors.grey;
        }),
        trackColor: MaterialStateProperty.resolveWith<Color>((states) {
          if (states.contains(MaterialState.selected)) {
            return primaryColorDark.withOpacity(0.5);
          }
          return Colors.grey.withOpacity(0.5);
        }),
      ),

      // 기타 설정
      scaffoldBackgroundColor: darkBackgroundColor,
      dividerColor: darkBorderColor,
      splashColor: primaryColorDark.withOpacity(0.1),
      highlightColor: primaryColorDark.withOpacity(0.05),
    );
  }

  // 앱 색상 정의
  // 라이트 모드 색상
  static const Color primaryColor = Color(0xFF3B82F6); // 주요 색상 (파란색)
  static const Color secondaryColor = Color(0xFF10B981); // 보조 색상 (녹색)
  static const Color accentColor = Color(0xFFF59E0B); // 강조 색상 (주황색)
  static const Color errorColor = Color(0xFFEF4444); // 오류 색상 (빨간색)
  static const Color successColor = Color(0xFF10B981); // 성공 색상 (녹색)
  static const Color warningColor = Color(0xFFF59E0B); // 경고 색상 (주황색)
  static const Color infoColor = Color(0xFF3B82F6); // 정보 색상 (파란색)

  // 텍스트 색상
  static const Color textColorDark = Color(0xFF1F2937); // 주요 텍스트 색상
  static const Color textColorMedium = Color(0xFF6B7280); // 보조 텍스트 색상
  static const Color textColorLight = Color(0xFF9CA3AF); // 가벼운 텍스트 색상

  // 경계선 색상
  static const Color borderColor = Color(0xFFE5E7EB);

  // 다크 모드 색상
  static const Color primaryColorDark = Color(0xFF60A5FA); // 주요 색상
  static const Color secondaryColorDark = Color(0xFF34D399); // 보조 색상
  static const Color accentColorDark = Color(0xFFFBBF24); // 강조 색상
  static const Color errorColorDark = Color(0xFFF87171); // 오류 색상
  static const Color darkBackgroundColor = Color(0xFF111827); // 배경 색상
  static const Color darkSurfaceColor = Color(0xFF1F2937); // 표면 색상
  static const Color darkCardColor = Color(0xFF374151); // 카드 색상
  static const Color darkInputColor = Color(0xFF1F2937); // 입력 필드 색상
  static const Color darkBorderColor = Color(0xFF4B5563); // 경계선 색상

  // 기타 색상
  static const Color positiveColor = Color(0xFF10B981); // 긍정적 변화 (녹색, 상승)
  static const Color negativeColor = Color(0xFFEF4444); // 부정적 변화 (빨간색, 하락)
  static const Color neutralColor = Color(0xFF9CA3AF); // 중립적 상태 (회색)
}
