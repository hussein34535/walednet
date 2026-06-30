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
      seedColor: const Color(0xFF0A84FF), // Apple iOS Dark Blue
      brightness: Brightness.dark,
      primary: const Color(0xFF0A84FF),
      secondary: const Color(0xFF30D158), // Apple iOS Dark Green
      surface: const Color(0xFF1C1C1E), // Apple System Gray 6 (Dark Card)
      onSurface: Colors.white,
    ),
    textTheme: _getTextTheme(true),
    iconTheme: const IconThemeData(color: Colors.white),
    cardTheme: CardThemeData(
      elevation: 0,
      color: const Color(0xFF1C1C1E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: Colors.white.withOpacity(0.06), width: 1.5),
      ),
    ),
    scaffoldBackgroundColor: const Color(0xFF000000), // True Black background
  );

  static final ThemeData _colorfulTheme = ThemeData(
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF007AFF), // Apple iOS Light Blue
      brightness: Brightness.light,
      primary: const Color(0xFF007AFF),
      secondary: const Color(0xFF34C759), // Apple iOS Light Green
      surface: Colors.white, // White cards
      onSurface: Colors.black, // Black text on cards
    ),
    textTheme: _getTextTheme(false),
    iconTheme: const IconThemeData(color: Colors.black87),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: Colors.black.withOpacity(0.04), width: 1.5),
      ),
    ),
    scaffoldBackgroundColor: const Color(0xFFF2F2F7), // Apple iOS System Gray 6 (Light Background)
  );
}
