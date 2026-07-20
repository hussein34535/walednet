import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ThemeProvider with ChangeNotifier {
  ThemeData _themeData;

  ThemeProvider() : _themeData = _darkTheme;

  ThemeData get themeData => _themeData;

  bool get isDarkMode => _themeData.brightness == Brightness.dark;

  void toggleTheme() {
    _themeData = isDarkMode ? _colorfulTheme : _darkTheme;
    notifyListeners();
  }

  static TextTheme _getTextTheme(bool isDark) {
    final baseTheme = TextTheme(
      headlineMedium: TextStyle(
        fontWeight: FontWeight.bold,
        color: isDark ? Colors.white : Colors.black,
      ),
      bodyLarge: TextStyle(color: isDark ? Colors.white : Colors.black),
      labelLarge: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
    );

    if (Platform.isWindows) {
      return baseTheme;
    }

    return GoogleFonts.cairoTextTheme(baseTheme);
  }

  static final ThemeData _darkTheme = ThemeData(
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF0A84FF),
      brightness: Brightness.dark,
      primary: const Color(0xFF0A84FF),
      secondary: const Color(0xFF10B981),
      tertiary: const Color(0xFF6366F1),
      surface: const Color(0xFF121622),
      onSurface: const Color(0xFFF8FAFC),
    ),
    textTheme: _getTextTheme(true),
    iconTheme: const IconThemeData(color: Color(0xFFF8FAFC)),
    cardTheme: CardThemeData(
      elevation: 0,
      color: const Color(0xFF121622),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: Colors.white.withOpacity(0.08), width: 1.0),
      ),
    ),
    scaffoldBackgroundColor: const Color(0xFF07090E),
  );

  static final ThemeData _colorfulTheme = ThemeData(
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF0284C7),
      brightness: Brightness.light,
      primary: const Color(0xFF0284C7),
      secondary: const Color(0xFF10B981),
      tertiary: const Color(0xFF6366F1),
      surface: const Color(0xFFFFFFFF),
      onSurface: const Color(0xFF0F172A),
    ),
    textTheme: _getTextTheme(false),
    iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: Colors.black.withOpacity(0.05), width: 1.0),
      ),
    ),
    scaffoldBackgroundColor: const Color(0xFFF8FAFC),
  );
}
