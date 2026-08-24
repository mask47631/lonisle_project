import 'package:flutter/material.dart';

/// LonIsle 深色主题：深灰蓝沉浸 + 现代极简，类 Discord 风格
class LonIsleTheme {
  LonIsleTheme._();

  // 色板
  static const Color primary = Color(0xFF5865F2);
  static const Color primaryDark = Color(0xFF4752C4);
  static const Color accentBlue = Color(0xFF3B82F6);

  static const Color bg = Color(0xFF1E1F22);
  static const Color bg2 = Color(0xFF2B2D31);
  static const Color bg3 = Color(0xFF313338);

  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textDim = Color(0xFFB5BAC1);
  static const Color textMuted = Color(0xFFDBDEE1);

  static const Color green = Color(0xFF23A55A);
  static const Color red = Color(0xFFF23F43);
  static const Color amber = Color(0xFFF0B232);

  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: bg,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: accentBlue,
        surface: bg2,
        error: red,
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textWhite,
          fontFamily: 'PingFang SC',
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: textWhite,
          fontFamily: 'PingFang SC',
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: textMuted,
          fontFamily: 'PingFang SC',
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bg2,
        foregroundColor: textWhite,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bg3,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        hintStyle: const TextStyle(color: textDim),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
    );
  }
}
