import 'package:flutter/material.dart';

/// Rideality UI tokens — modern-minimal (onboarding + home).
abstract final class AppColors {
  static const Color background = Color(0xFFF8F9FB);
  static const Color surface = Color(0xFFF8F9FB);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF1F3F6);
  static const Color surfaceContainer = Color(0xFFEAECEF);
  static const Color surfaceContainerHigh = Color(0xFFE2E5EA);
  static const Color surfaceContainerHighest = Color(0xFFD8DCE2);
  static const Color surfaceVariant = Color(0xFFE2E5EA);

  /// Soft indigo wash — promo banners, nav indicator, avatar fill.
  static const Color surfaceTint = Color(0xFFEEF2FF);

  static const Color onBackground = Color(0xFF111827);
  static const Color onSurface = Color(0xFF111827);
  static const Color onSurfaceVariant = Color(0xFF6B7280);

  static const Color primary = Color(0xFF111827);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFF0B1C3F);
  static const Color onPrimaryContainer = Color(0xFFB8C4DC);

  /// Brand blue from mocks
  static const Color secondary = Color(0xFF1565C0);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFF1E6FE5);
  static const Color onSecondaryContainer = Color(0xFFFFFFFF);

  /// Teal accent — route canvas, selection states, primary CTAs on ride flow.
  static const Color accent = Color(0xFF0D9488);
  static const Color onAccent = Color(0xFFFFFFFF);
  static const Color accentSoft = Color(0xFFCCFBF1);
  static const Color accentMuted = Color(0xFF14B8A6);
  static const Color canvasDark = Color(0xFF0B1220);
  static const Color canvasDot = Color(0xFF1E293B);

  static const Color outline = Color(0xFF9CA3AF);
  static const Color outlineVariant = Color(0xFFD1D5DB);

  static const Color error = Color(0xFFBA1A1A);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onErrorContainer = Color(0xFF93000A);

  static const Color success = Color(0xFF22C55E);
  static const Color successSoft = Color(0xFFDCFCE7);
  static const Color amber = Color(0xFFF59E0B);
  static const Color devBadge = Color(0xFFFFF1E0);
  static const Color devBadgeText = Color(0xFF7A4A12);

  /// Soft card elevation: 0 8px 24px rgba(17,24,39,0.06)
  static List<BoxShadow> get ambientShadow => const [
        BoxShadow(
          color: Color(0x0F111827),
          blurRadius: 24,
          offset: Offset(0, 8),
        ),
      ];
}
