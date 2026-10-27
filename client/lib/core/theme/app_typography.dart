import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTypography {
  AppTypography._();

  static const List<FontFeature> tabularFeatures = [
    FontFeature.tabularFigures(),
    FontFeature.slashedZero(),
  ];

  static TextStyle get displayHero => GoogleFonts.inter(
        fontSize: 56,
        fontWeight: FontWeight.w800,
        height: 60 / 56,
        letterSpacing: -1.96, // -0.035em
        color: AppColors.onSurface,
        fontFeatures: tabularFeatures,
      );

  static TextStyle get displayHeroMobile => GoogleFonts.inter(
        fontSize: 40,
        fontWeight: FontWeight.w800,
        height: 44 / 40,
        letterSpacing: -1.2, // -0.03em
        color: AppColors.onSurface,
        fontFeatures: tabularFeatures,
      );

  static TextStyle get headlineLg => GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 38 / 32,
        letterSpacing: -0.8, // -0.025em
        color: AppColors.onSurface,
      );

  static TextStyle get headlineMd => GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 30 / 24,
        letterSpacing: -0.48, // -0.02em
        color: AppColors.onSurface,
      );

  static TextStyle get titleSm => GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 24 / 18,
        letterSpacing: -0.27, // -0.015em
        color: AppColors.onSurface,
      );

  static TextStyle get bodyLg => GoogleFonts.inter(
        fontSize: 17,
        fontWeight: FontWeight.w400,
        height: 24 / 17,
        letterSpacing: -0.17, // -0.01em
        color: AppColors.onSurface,
      );

  static TextStyle get bodyMd => GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 21 / 15,
        letterSpacing: 0,
        color: AppColors.onSurface,
      );

  static TextStyle get labelMd => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        height: 17 / 13,
        letterSpacing: 0.13, // 0.01em
        color: AppColors.outline,
      );

  static TextStyle get labelSm => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        height: 14 / 11,
        letterSpacing: 0.55, // 0.05em
        color: AppColors.outline,
      );
}
