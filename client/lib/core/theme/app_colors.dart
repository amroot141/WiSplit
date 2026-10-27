import 'package:flutter/material.dart';

/// Obsidian & Taro Minimalist Fintech Design System Palette
class AppColors {
  AppColors._();

  // Canvas & Surfaces
  static const Color surface = Color(0xFF131313);
  static const Color surfaceDim = Color(0xFF131313);
  static const Color surfaceBright = Color(0xFF393939);
  static const Color surfaceContainerLowest = Color(0xFF0E0E0E);
  static const Color surfaceContainerLow = Color(0xFF1B1B1B);
  static const Color surfaceContainer = Color(0xFF1F1F1F);
  static const Color surfaceContainerHigh = Color(0xFF2A2A2A);
  static const Color surfaceContainerHighest = Color(0xFF353535);

  // Pure Constants
  static const Color pureBlack = Color(0xFF000000);
  static const Color pureWhite = Color(0xFFFFFFFF);

  // Taro Lavender Accents (Primary Action & Financial Inflows)
  static const Color primary = Color(0xFFD7C2FF);
  static const Color primaryContainer = Color(0xFFBFA2FA); // Soft Taro Lavender
  static const Color onPrimary = Color(0xFF3A1E6E);
  static const Color onPrimaryFixed = Color(0xFF250059);
  static const Color onPrimaryContainer = Color(0xFF4E3483);
  static const Color inversePrimary = Color(0xFF6A4FA0);

  // Secondaries & Tertiaries
  static const Color secondary = Color(0xFFCFC0E7);
  static const Color onSecondary = Color(0xFF352B4A);
  static const Color secondaryContainer = Color(0xFF4C4162);
  static const Color onSecondaryContainer = Color(0xFFBDAFD5);
  static const Color tertiary = Color(0xFFD8D05C);
  static const Color tertiaryContainer = Color(0xFFBCB443);

  // Typographic Tones & Muted Architectural Grays
  static const Color onSurface = Color(0xFFE2E2E2);
  static const Color onSurfaceVariant = Color(0xFFCBC4D2);
  static const Color outline = Color(0xFF8E8E93);
  static const Color outlineVariant = Color(0xFF494550);
  static const Color subtleGray = Color(0xFF666666);

  // Alerts & Errors
  static const Color error = Color(0xFFFFB4AB);
  static const Color errorContainer = Color(0xFF93000A);
  static const Color onError = Color(0xFF690005);

  // Touch & Ghost Fills
  static const Color touchFeedback = Color(0x14FFFFFF); // rgba(255, 255, 255, 0.08)
  static const Color chipBackground = Color(0x0FFFFFFF); // rgba(255, 255, 255, 0.06)
}
