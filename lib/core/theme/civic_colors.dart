import 'package:flutter/material.dart';

/// "The Civic Ledger" (Warm Heritage) color tokens for G-TRAMS Mobile.
class CivicColors {
  CivicColors._();

  // Brand & Municipal Heritage
  static const Color gasanMaroon = Color(0xFF9E2A2B);
  static const Color gasanMaroonDeep = Color(0xFF7A1B22);
  static const Color gasanMaroonDarkest = Color(0xFF3D080D);
  static const Color gasanMaroonTint = Color(0xFFFDF2F4);
  static const Color gasanGold = Color(0xFFD4AF37);
  static const Color gasanGoldAccessible = Color(0xFFF5E6B3);

  // Light Mode Warm Paper Neutrals (Zero cool slate drift)
  static const Color warmAlabaster = Color(0xFFF6F5F3);
  static const Color purePaper = Color(0xFFFFFFFF);
  static const Color sandHairline = Color(0xFFE4E1DC);
  static const Color inkCharcoal = Color(0xFF1F1D1B);
  static const Color slateTaupe = Color(0xFF6B6761);

  // Dark Mode Warm Obsidian Neutrals
  static const Color obsidianEarth = Color(0xFF14110F);
  static const Color darkStone = Color(0xFF1C1917);
  static const Color darkUmber = Color(0xFF2E2A27);
  static const Color darkParchment = Color(0xFFF6F5F3);
  static const Color darkAsh = Color(0xFFA8A29E);

  // Semantic WCAG AA Status Bands
  static const Color civicGreen = Color(0xFF15803D);
  static const Color civicGreenLightBg = Color(0xFFDCFCE7);
  static const Color civicGreenDarkBg = Color(0xFF14532D);

  static const Color amberOchre = Color(0xFFB45309);
  static const Color amberOchreLightBg = Color(0xFFFEF3C7);
  static const Color amberOchreDarkBg = Color(0xFF451A03);

  static const Color crimsonAlert = Color(0xFFB91C1C);
  static const Color crimsonAlertLightBg = Color(0xFFFEE2E2);
  static const Color crimsonAlertDarkBg = Color(0xFF450A0A);

  static const Color neutralZinc = Color(0xFF4B5563);
  static const Color neutralZincLightBg = Color(0xFFF3F4F6);
  static const Color neutralZincDarkBg = Color(0xFF27272A);
}

enum CivicStatusTone { active, inProgress, danger, neutral }

class CivicPalette extends ThemeExtension<CivicPalette> {
  const CivicPalette({
    required this.canvas,
    required this.surface,
    required this.border,
    required this.ink,
    required this.muted,
    required this.brandAccent,
    required this.goldAccent,
    required this.subtleFill,
  });

  final Color canvas;
  final Color surface;
  final Color border;
  final Color ink;
  final Color muted;
  final Color brandAccent;
  final Color goldAccent;
  final Color subtleFill;

  static const CivicPalette light = CivicPalette(
    canvas: CivicColors.warmAlabaster,
    surface: CivicColors.purePaper,
    border: CivicColors.sandHairline,
    ink: CivicColors.inkCharcoal,
    muted: CivicColors.slateTaupe,
    brandAccent: CivicColors.gasanMaroon,
    goldAccent: CivicColors.gasanGold,
    subtleFill: CivicColors.gasanMaroonTint,
  );

  static const CivicPalette dark = CivicPalette(
    canvas: CivicColors.obsidianEarth,
    surface: CivicColors.darkStone,
    border: CivicColors.darkUmber,
    ink: CivicColors.darkParchment,
    muted: CivicColors.darkAsh,
    brandAccent: CivicColors.gasanGold,
    goldAccent: CivicColors.gasanGold,
    subtleFill: Color(0xFF2A211F),
  );

  @override
  CivicPalette copyWith({
    Color? canvas,
    Color? surface,
    Color? border,
    Color? ink,
    Color? muted,
    Color? brandAccent,
    Color? goldAccent,
    Color? subtleFill,
  }) {
    return CivicPalette(
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      border: border ?? this.border,
      ink: ink ?? this.ink,
      muted: muted ?? this.muted,
      brandAccent: brandAccent ?? this.brandAccent,
      goldAccent: goldAccent ?? this.goldAccent,
      subtleFill: subtleFill ?? this.subtleFill,
    );
  }

  @override
  CivicPalette lerp(ThemeExtension<CivicPalette>? other, double t) {
    if (other is! CivicPalette) return this;
    return CivicPalette(
      canvas: Color.lerp(canvas, other.canvas, t) ?? canvas,
      surface: Color.lerp(surface, other.surface, t) ?? surface,
      border: Color.lerp(border, other.border, t) ?? border,
      ink: Color.lerp(ink, other.ink, t) ?? ink,
      muted: Color.lerp(muted, other.muted, t) ?? muted,
      brandAccent: Color.lerp(brandAccent, other.brandAccent, t) ?? brandAccent,
      goldAccent: Color.lerp(goldAccent, other.goldAccent, t) ?? goldAccent,
      subtleFill: Color.lerp(subtleFill, other.subtleFill, t) ?? subtleFill,
    );
  }
}

extension CivicThemeContext on BuildContext {
  CivicPalette get civic =>
      Theme.of(this).extension<CivicPalette>() ?? CivicPalette.light;
}
