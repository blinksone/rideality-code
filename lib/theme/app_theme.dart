import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Rideality light theme — Manrope (display/headline/title) + Inter (body/label).
///
/// Fonts are applied only here. Screens should use [Theme.of] text styles and
/// [TextStyle.copyWith] for weight/color overrides so they keep the families.
abstract final class AppTheme {
  static const Color textPrimary = AppColors.onSurface;
  static const Color textMuted = AppColors.onSurfaceVariant;

  /// Shared text scale: Manrope for hierarchy, Inter for reading UI.
  static TextTheme buildTextTheme(TextTheme base) {
    // Inter as the full Material scale first, then Manrope on display roles.
    final inter = GoogleFonts.interTextTheme(base);

    return inter.copyWith(
      displayLarge: GoogleFonts.manrope(
        fontWeight: FontWeight.w800,
        fontSize: 28,
        height: 34 / 28,
        letterSpacing: -0.6,
        color: textPrimary,
      ),
      displayMedium: GoogleFonts.manrope(
        fontWeight: FontWeight.w800,
        fontSize: 24,
        height: 30 / 24,
        letterSpacing: -0.4,
        color: textPrimary,
      ),
      displaySmall: GoogleFonts.manrope(
        fontWeight: FontWeight.w800,
        fontSize: 22,
        height: 28 / 22,
        letterSpacing: -0.3,
        color: textPrimary,
      ),
      headlineLarge: GoogleFonts.manrope(
        fontWeight: FontWeight.w800,
        fontSize: 26,
        height: 32 / 26,
        letterSpacing: -0.4,
        color: textPrimary,
      ),
      headlineMedium: GoogleFonts.manrope(
        fontWeight: FontWeight.w700,
        fontSize: 22,
        height: 28 / 22,
        letterSpacing: -0.3,
        color: textPrimary,
      ),
      headlineSmall: GoogleFonts.manrope(
        fontWeight: FontWeight.w700,
        fontSize: 20,
        height: 26 / 20,
        letterSpacing: -0.2,
        color: textPrimary,
      ),
      titleLarge: GoogleFonts.manrope(
        fontWeight: FontWeight.w700,
        fontSize: 18,
        height: 24 / 18,
        letterSpacing: -0.2,
        color: textPrimary,
      ),
      titleMedium: GoogleFonts.manrope(
        fontWeight: FontWeight.w700,
        fontSize: 16,
        height: 22 / 16,
        color: textPrimary,
      ),
      titleSmall: GoogleFonts.manrope(
        fontWeight: FontWeight.w700,
        fontSize: 14,
        height: 20 / 14,
        color: textPrimary,
      ),
      bodyLarge: GoogleFonts.inter(
        fontWeight: FontWeight.w400,
        fontSize: 16,
        height: 24 / 16,
        color: textPrimary,
      ),
      bodyMedium: GoogleFonts.inter(
        fontWeight: FontWeight.w400,
        fontSize: 14,
        height: 20 / 14,
        color: textMuted,
      ),
      bodySmall: GoogleFonts.inter(
        fontWeight: FontWeight.w400,
        fontSize: 12,
        height: 16 / 12,
        color: textMuted,
      ),
      // Buttons / chips — white text is applied by button themes;
      // base color is on-surface so ghost/secondary labels stay correct.
      labelLarge: GoogleFonts.inter(
        fontWeight: FontWeight.w500,
        fontSize: 15,
        height: 20 / 15,
        color: textPrimary,
      ),
      labelMedium: GoogleFonts.inter(
        fontWeight: FontWeight.w500,
        fontSize: 13,
        height: 18 / 13,
        color: textMuted,
      ),
      labelSmall: GoogleFonts.inter(
        fontWeight: FontWeight.w500,
        fontSize: 12,
        height: 16 / 12,
        color: textMuted,
      ),
    );
  }

  static ThemeData get light {
    final colorScheme = const ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      primaryContainer: AppColors.primaryContainer,
      onPrimaryContainer: AppColors.onPrimaryContainer,
      secondary: AppColors.secondary,
      onSecondary: AppColors.onSecondary,
      secondaryContainer: AppColors.secondaryContainer,
      onSecondaryContainer: AppColors.onSecondaryContainer,
      surface: AppColors.surface,
      surfaceTint: AppColors.surfaceTint,
      onSurface: AppColors.onSurface,
      onSurfaceVariant: AppColors.onSurfaceVariant,
      error: AppColors.error,
      onError: AppColors.onError,
      outline: AppColors.outline,
      outlineVariant: AppColors.outlineVariant,
    );

    // Build from a full M3 text scale so no slot stays as platform Roboto.
    final interFamily = GoogleFonts.inter().fontFamily;
    final seed = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: interFamily,
    );

    final textTheme = buildTextTheme(seed.textTheme);
    final primaryTextTheme = buildTextTheme(seed.primaryTextTheme);
    final labelLarge = textTheme.labelLarge!;
    final titleStyle = textTheme.headlineMedium!.copyWith(
      fontWeight: FontWeight.w800,
      color: AppColors.secondary,
    );

    OutlineInputBorder border([
      Color color = AppColors.outlineVariant,
      double w = 1,
    ]) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: w),
      );
    }

    return seed.copyWith(
      textTheme: textTheme,
      primaryTextTheme: primaryTextTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: titleStyle,
        toolbarTextStyle: textTheme.bodyMedium,
        iconTheme: const IconThemeData(color: AppColors.secondary, size: 24),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceContainerLowest,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: textTheme.labelMedium?.copyWith(
          color: AppColors.secondary,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.onSurfaceVariant,
        ),
        prefixIconColor: AppColors.onSurfaceVariant,
        border: border(),
        enabledBorder: border(),
        focusedBorder: border(AppColors.secondary, 1.5),
        errorBorder: border(AppColors.error),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.secondary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          textStyle: labelLarge.copyWith(color: Colors.white),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          textStyle: labelLarge.copyWith(color: Colors.white),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.onSurface,
          minimumSize: const Size.fromHeight(54),
          side: const BorderSide(color: AppColors.outlineVariant),
          backgroundColor: AppColors.surfaceContainerLowest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: labelLarge,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surfaceContainerLowest,
        indicatorColor: AppColors.surfaceTint,
        labelTextStyle: WidgetStatePropertyAll(
          textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w500,
            color: textPrimary,
          ),
        ),
        iconTheme: const WidgetStatePropertyAll(
          IconThemeData(size: 24),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelStyle: textTheme.labelLarge,
        unselectedLabelStyle: textTheme.labelLarge,
      ),
      snackBarTheme: SnackBarThemeData(
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: Colors.white,
        ),
      ),
      listTileTheme: ListTileThemeData(
        titleTextStyle: textTheme.titleMedium,
        subtitleTextStyle: textTheme.bodyMedium,
      ),
      dialogTheme: DialogThemeData(
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: textPrimary,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE5E7EB),
        thickness: 1,
        space: 1,
      ),
    );
  }
}
