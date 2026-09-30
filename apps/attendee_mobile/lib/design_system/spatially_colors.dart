import 'package:flutter/material.dart';

/// Centralized Spatially Color Tokens based on SPATIALLY_DESIGN.md.
/// 
/// Contains core brand tokens, spatial accents, volunteer accents,
/// semantic colors, crowd density colors, and light/dark surface tokens.
abstract final class SpatiallyColors {
  // --- Brand Identity Colors ---
  static const Color neonBlue = Color(0xFF00D1FF);
  static const Color violet = Color(0xFF8A5CFF);
  static const Color purple = Color(0xFFD946EF);

  /// Primary Spatially linear gradient: Cyan/Blue -> Violet -> Purple
  static const LinearGradient brandGradient = LinearGradient(
    colors: [neonBlue, violet, purple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Subtle brand gradient for tinted surfaces or card borders
  static const LinearGradient brandGradientSubtle = LinearGradient(
    colors: [
      Color(0x3300D1FF),
      Color(0x338A5CFF),
      Color(0x33D946EF),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // --- Spatial & Role Accents ---
  /// Cyan/Mint: Used for location, BLE/spatial beacon indicators, live state
  static const Color spatialCyan = Color(0xFF22D3EE);

  /// Volunteer accent: Orange
  static const Color volunteerOrange = Color(0xFFFFA726);

  /// Attention / temporary state: Yellow
  static const Color attentionYellow = Color(0xFFFFD166);

  // --- Semantic Colors ---
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // --- Crowd Color Language ---
  /// Low crowd density: Green
  static const Color crowdLow = Color(0xFF22C55E);

  /// Moderate crowd density: Yellow
  static const Color crowdModerate = Color(0xFFFFD166);

  /// Busy crowd density: Orange
  static const Color crowdBusy = Color(0xFFFFA726);

  /// High crowd density: Red
  static const Color crowdHigh = Color(0xFFEF4444);

  // --- Light Theme Surfaces ---
  static const Color lightBackground = Color(0xFFF7F8FC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceElevated = Color(0xFFFFFFFF);
  static const Color lightBorderSubdued = Color(0xFFE9EBF2);
  static const Color lightTextPrimary = Color(0xFF17171C);
  static const Color lightTextSecondary = Color(0xFF6B6B76);
  static const Color lightTextTertiary = Color(0xFF9D9EA7);

  // --- Dark Theme Surfaces ---
  static const Color darkBackground = Color(0xFF0E0E12);
  static const Color darkSurface = Color(0xFF17171D);
  static const Color darkSurfaceElevated = Color(0xFF202027);
  static const Color darkBorderSubdued = Color(0xFF2C2C36);
  static const Color darkTextPrimary = Color(0xFFF5F5F7);
  static const Color darkTextSecondary = Color(0xFFA5A5B0);
  static const Color darkTextTertiary = Color(0xFF646470);

  // --- Immersive Brand Surfaces (Deep Navy) ---
  static const Color navyBackground = Color(0xFF0B0F19);
  static const Color navySurface = Color(0xFF121827);
  static const Color navyBorder = Color(0xFF1E2638);
}
