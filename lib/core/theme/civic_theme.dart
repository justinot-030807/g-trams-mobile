import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gtrams_mobile/core/theme/civic_colors.dart';

/// Builds Light and Dark Material 3 themes implementing "The Civic Ledger".
/// Tuned with crisp, outdoor-legible mobile font weights across every slot.
class CivicTheme {
  CivicTheme._();

  static TextStyle monoStyle({
    double fontSize = 12,
    FontWeight fontWeight = FontWeight.w600,
    Color? color,
    double? letterSpacing,
  }) {
    return GoogleFonts.jetBrainsMono(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  static ThemeData light() => _build(Brightness.light, CivicPalette.light);
  static ThemeData dark() => _build(Brightness.dark, CivicPalette.dark);

  static ThemeData _build(Brightness brightness, CivicPalette palette) {
    final isDark = brightness == Brightness.dark;
    final baseTextTheme = GoogleFonts.manropeTextTheme(
      isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
    );

    final textTheme = baseTextTheme.copyWith(
      displayLarge: baseTextTheme.displayLarge?.copyWith(
        fontSize: 34,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
        height: 1.15,
        color: palette.ink,
      ),
      displayMedium: baseTextTheme.displayMedium?.copyWith(
        fontSize: 30,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.7,
        height: 1.16,
        color: palette.ink,
      ),
      displaySmall: baseTextTheme.displaySmall?.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.6,
        height: 1.18,
        color: palette.ink,
      ),
      headlineLarge: baseTextTheme.headlineLarge?.copyWith(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        height: 1.2,
        color: palette.ink,
      ),
      headlineMedium: baseTextTheme.headlineMedium?.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.45,
        height: 1.22,
        color: palette.ink,
      ),
      headlineSmall: baseTextTheme.headlineSmall?.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
        height: 1.24,
        color: palette.ink,
      ),
      titleLarge: baseTextTheme.titleLarge?.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        height: 1.3,
        color: palette.ink,
      ),
      titleMedium: baseTextTheme.titleMedium?.copyWith(
        fontSize: 15.5,
        fontWeight: FontWeight.w700,
        height: 1.35,
        color: palette.ink,
      ),
      titleSmall: baseTextTheme.titleSmall?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        height: 1.35,
        color: palette.ink,
      ),
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(
        fontSize: 15.5,
        fontWeight: FontWeight.w500,
        height: 1.5,
        color: palette.ink,
      ),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(
        fontSize: 14.5,
        fontWeight: FontWeight.w500,
        height: 1.5,
        color: palette.ink,
      ),
      bodySmall: baseTextTheme.bodySmall?.copyWith(
        fontSize: 12.5,
        fontWeight: FontWeight.w500,
        height: 1.45,
        color: palette.muted,
      ),
      labelLarge: baseTextTheme.labelLarge?.copyWith(
        fontSize: 14.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
      ),
      labelMedium: baseTextTheme.labelMedium?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
        color: palette.ink,
      ),
      labelSmall: GoogleFonts.jetBrainsMono(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.7,
        color: palette.muted,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: CivicColors.gasanMaroon,
      onPrimary: CivicColors.purePaper,
      secondary: CivicColors.gasanGold,
      onSecondary: CivicColors.inkCharcoal,
      error: CivicColors.crimsonAlert,
      onError: CivicColors.purePaper,
      surface: palette.surface,
      onSurface: palette.ink,
      outline: palette.border,
      surfaceContainerHighest: palette.canvas,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: palette.canvas,
      textTheme: textTheme,
      extensions: [palette],
      dividerColor: palette.border,
      appBarTheme: AppBarTheme(
        backgroundColor: palette.surface,
        foregroundColor: palette.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
        shape: Border(bottom: BorderSide(color: palette.border, width: 1)),
      ),
      cardTheme: CardThemeData(
        color: palette.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: palette.border, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor:
            isDark ? CivicColors.obsidianEarth : CivicColors.warmAlabaster,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: palette.muted,
          fontWeight: FontWeight.w500,
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: palette.muted,
          fontWeight: FontWeight.w600,
        ),
        floatingLabelStyle: textTheme.bodySmall?.copyWith(
          color: isDark ? CivicColors.gasanGold : CivicColors.gasanMaroon,
          fontWeight: FontWeight.w700,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: palette.border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: palette.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: isDark ? CivicColors.gasanGold : CivicColors.gasanMaroon,
            width: 1.6,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: CivicColors.crimsonAlert,
            width: 1.2,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: CivicColors.crimsonAlert,
            width: 1.6,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: CivicColors.gasanMaroon,
          foregroundColor: CivicColors.purePaper,
          disabledBackgroundColor:
              CivicColors.gasanMaroon.withValues(alpha: 0.45),
          disabledForegroundColor: CivicColors.purePaper.withValues(alpha: 0.8),
          elevation: 0,
          minimumSize: const Size(double.infinity, 50),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: CivicColors.gasanMaroon,
          foregroundColor: CivicColors.purePaper,
          elevation: 0,
          minimumSize: const Size(double.infinity, 50),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.ink,
          backgroundColor: palette.surface,
          minimumSize: const Size(double.infinity, 50),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          side: BorderSide(color: palette.border, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor:
              isDark ? CivicColors.gasanGold : CivicColors.gasanMaroon,
          minimumSize: const Size(48, 48),
          textStyle: textTheme.labelLarge,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            isDark ? CivicColors.darkStone : CivicColors.inkCharcoal,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: CivicColors.purePaper,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
