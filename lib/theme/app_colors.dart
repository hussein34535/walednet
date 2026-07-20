import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF6C5CE7);
  static const Color primaryLight = Color(0xFFA29BFE);
  static const Color primaryDark = Color(0xFF4834D4);

  static const Color accent = Color(0xFF00CEC9);
  static const Color accentLight = Color(0xFF81ECEC);

  static const Color success = Color(0xFF00B894);
  static const Color successLight = Color(0xFF55EFC4);

  static const Color warning = Color(0xFFFDCB6E);

  static const Color error = Color(0xFFE17055);
  static const Color errorLight = Color(0xFFFAB1A0);

  static const Color darkBg = Color(0xFF0A0E21);
  static const Color darkSurface = Color(0xFF131A35);
  static const Color darkCard = Color(0xFF1A2342);
  static const Color darkCardLight = Color(0xFF222D4F);
  static const Color darkBorder = Color(0xFF2D3A5C);

  static const Color lightBg = Color(0xFFF8F9FE);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE8ECF4);

  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  static const Color textSecondaryDark = Color(0xFF8892B0);
  static const Color textPrimaryLight = Color(0xFF1A1A2E);
  static const Color textSecondaryLight = Color(0xFF6B7280);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF6C5CE7), Color(0xFF00CEC9)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkGradient = LinearGradient(
    colors: [Color(0xFF0A0E21), Color(0xFF131A35)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF1A2342), Color(0xFF222D4F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF00B894), Color(0xFF00CEC9)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient dangerGradient = LinearGradient(
    colors: [Color(0xFFE17055), Color(0xFFD63031)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
