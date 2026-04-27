import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Centralized typography tokens for WatchParty.
/// Three-layer font hierarchy:
///   - Display: Instrument Serif (cinematic headline serif)
///   - Body:    Inter (clean sans-serif)
///   - Meta:    JetBrains Mono / Consolas (monospace for codes & metadata)
class AppTypography {
  AppTypography._();

  static String? get _fontFamily => 'Inter';
  static String? get _fontFamilySerif => 'Instrument Serif';
  static String? get _fontFamilyMono => 'JetBrains Mono';

  static const _fallbackFonts = [
    'Segoe UI',
    'Roboto',
    'Noto Sans Arabic',
    'sans-serif',
  ];
  static const _fallbackSerifFonts = ['Times New Roman', 'Georgia', 'serif'];
  static const _fallbackMonoFonts = [
    'Consolas',
    'Cascadia Code',
    'Courier New',
    'monospace',
  ];

  // -- Display (hero text) ---------------------------------------------------
  static TextStyle get displayHero => TextStyle(
    fontFamily: _fontFamilySerif,
    fontFamilyFallback: _fallbackSerifFonts,
    fontSize: 56, // Increased to match editorial feel
    fontWeight: FontWeight.w400, // Instrument Serif is usually regular/italic
    fontStyle: FontStyle.italic,
    color: AppColors.textPrimary,
    letterSpacing: -1.5,
    height: 1.0,
  );

  static TextStyle get display => TextStyle(
    fontFamily: _fontFamilySerif,
    fontFamilyFallback: _fallbackSerifFonts,
    fontSize: 40,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    letterSpacing: -1.0,
    height: 1.1,
  );

  // -- Title (screen titles, section headers) ----------------------------------
  static TextStyle get titleLarge => TextStyle(
    fontFamily: _fontFamily,
    fontFamilyFallback: _fallbackFonts,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
    height: 1.2,
  );

  static TextStyle get title => TextStyle(
    fontFamily: _fontFamily,
    fontFamilyFallback: _fallbackFonts,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: -0.3,
    height: 1.3,
  );

  static TextStyle get titleSmall => TextStyle(
    fontFamily: _fontFamily,
    fontFamilyFallback: _fallbackFonts,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: -0.2,
    height: 1.3,
  );

  // -- Section label (all caps dividers) ---------------------------------------
  static TextStyle get sectionLabel => TextStyle(
    fontFamily: _fontFamily,
    fontFamilyFallback: _fallbackFonts,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: AppColors.textMuted,
    letterSpacing: 1.5,
    height: 1.4,
  );

  // -- Body --------------------------------------------------------------------
  static TextStyle get bodyLarge => TextStyle(
    fontFamily: _fontFamily,
    fontFamilyFallback: _fallbackFonts,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.5,
  );

  static TextStyle get body => TextStyle(
    fontFamily: _fontFamily,
    fontFamilyFallback: _fallbackFonts,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.5,
  );

  static TextStyle get bodySmall => TextStyle(
    fontFamily: _fontFamily,
    fontFamilyFallback: _fallbackFonts,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.5,
  );

  // -- Caption -----------------------------------------------------------------
  static TextStyle get caption => TextStyle(
    fontFamily: _fontFamily,
    fontFamilyFallback: _fallbackFonts,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textMuted,
    height: 1.4,
  );

  static TextStyle get captionSmall => TextStyle(
    fontFamily: _fontFamily,
    fontFamilyFallback: _fallbackFonts,
    fontSize: 10,
    fontWeight: FontWeight.w500,
    color: AppColors.textMuted,
    height: 1.4,
  );

  // -- Button ------------------------------------------------------------------
  static TextStyle get button => TextStyle(
    fontFamily: _fontFamily,
    fontFamilyFallback: _fallbackFonts,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: 0.2,
    height: 1.2,
  );

  static TextStyle get buttonSmall => TextStyle(
    fontFamily: _fontFamily,
    fontFamilyFallback: _fallbackFonts,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: 0.2,
    height: 1.2,
  );

  // -- Chip / Badge ------------------------------------------------------------
  static TextStyle get chip => TextStyle(
    fontFamily: _fontFamily,
    fontFamilyFallback: _fallbackFonts,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  static TextStyle get badge => TextStyle(
    fontFamily: _fontFamily,
    fontFamilyFallback: _fallbackFonts,
    fontSize: 10,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.5,
    height: 1.2,
  );

  // -- Tab ---------------------------------------------------------------------
  static TextStyle get tab => TextStyle(
    fontFamily: _fontFamily,
    fontFamilyFallback: _fallbackFonts,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  // -- Monospace (JetBrains Mono / Consolas) -----------------------------------
  static TextStyle get mono => TextStyle(
    fontFamily: _fontFamilyMono,
    fontFamilyFallback: _fallbackMonoFonts,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.5,
    height: 1.2,
  );

  static TextStyle get monoLarge => TextStyle(
    fontFamily: _fontFamilyMono,
    fontFamilyFallback: _fallbackMonoFonts,
    fontSize: 40,
    fontWeight: FontWeight.w700,
    letterSpacing: 8,
    height: 1.2,
  );

  static TextStyle get monoCode => TextStyle(
    fontFamily: _fontFamilyMono,
    fontFamilyFallback: _fallbackMonoFonts,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    letterSpacing: 6,
    height: 1.2,
  );
}
