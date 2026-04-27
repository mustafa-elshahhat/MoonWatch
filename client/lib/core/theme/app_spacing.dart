import 'package:flutter/material.dart';

/// Centralized spacing, radius, elevation, icon sizing, and animation tokens.
class AppSpacing {
  AppSpacing._();

  // —— Spacing scale (4px base) ————————————————————————————————————
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 40;
  static const double massive = 48;

  // —— Backward compatibility ——————————————————————————————————————
  static const double xl2 = xxl;
  static const double xl4 = huge;
  static const double radiusSm = AppRadius.sm;
  static const double radiusMd = AppRadius.md;
  static const double radiusLg = AppRadius.lg;
  static const double radiusXl = AppRadius.xl;

  // —— Common padding presets ——————————————————————————————————————
  static const screenH = EdgeInsets.symmetric(horizontal: 24);
  static const screenAll = EdgeInsets.all(24);
  static const cardPadding = EdgeInsets.all(16);
  static const cardPaddingLarge = EdgeInsets.all(20);
  static const listItemPadding = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 8,
  );
  static const chipPadding = EdgeInsets.symmetric(horizontal: 10, vertical: 4);
}

/// Border radius tokens.
class AppRadius {
  AppRadius._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double pill = 100;

  static BorderRadius get xsBorder => BorderRadius.circular(xs);
  static BorderRadius get smBorder => BorderRadius.circular(sm);
  static BorderRadius get mdBorder => BorderRadius.circular(md);
  static BorderRadius get lgBorder => BorderRadius.circular(lg);
  static BorderRadius get xlBorder => BorderRadius.circular(xl);
  static BorderRadius get pillBorder => BorderRadius.circular(pill);
}

/// Elevation / shadow presets for dark theme.
class AppElevation {
  AppElevation._();

  static List<BoxShadow> get none => [];

  static List<BoxShadow> get low => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.2),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> get medium => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.3),
      blurRadius: 8,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get high => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.4),
      blurRadius: 16,
      offset: const Offset(0, 8),
    ),
  ];
}

/// Icon size tokens.
class AppIconSize {
  AppIconSize._();

  static const double xs = 14;
  static const double sm = 16;
  static const double md = 20;
  static const double lg = 24;
  static const double xl = 28;
  static const double xxl = 32;
  static const double huge = 48;
  static const double display = 56;
}

/// Animation duration and curve tokens.
class AppAnimation {
  AppAnimation._();

  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);
  static const Duration pulse = Duration(milliseconds: 1500);

  static const Curve defaultCurve = Curves.easeInOut;
  static const Curve enterCurve = Curves.easeOut;
  static const Curve exitCurve = Curves.easeIn;
}

/// Responsive breakpoints.
class AppBreakpoint {
  AppBreakpoint._();

  static const double mobile = 480;
  static const double tablet = 720;
  static const double desktop = 1024;

  /// Desktop-aware constrained width.
  static double contentWidth(double screenWidth) {
    if (screenWidth >= desktop) return 560;
    if (screenWidth >= tablet) return 520;
    return screenWidth * 0.9;
  }

  /// Grid cross-axis count based on screen width.
  static int gridColumns(double screenWidth) {
    if (screenWidth >= desktop) return 4;
    if (screenWidth >= tablet) return 3;
    return 2;
  }
}
