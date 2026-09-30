import 'package:flutter/material.dart';

/// Centralized Spatially Elevation and Shadow Tokens based on SPATIALLY_DESIGN.md.
/// 
/// Avoids heavy black shadows in favor of soft, tinted, restrained depth.
abstract final class SpatiallyShadows {
  /// Subtle elevation for chips, list items, and minor cards
  static const List<BoxShadow> subtle = [
    BoxShadow(
      color: Color(0x0A000000), // ~4% opacity
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  /// Standard card elevation
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x0F000000), // ~6% opacity
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];

  /// Elevated surfaces (bottom sheets, modals, floating action bars)
  static const List<BoxShadow> elevated = [
    BoxShadow(
      color: Color(0x14000000), // ~8% opacity
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];

  /// Restrained brand glow for hero moments, live beacon, or selected state
  static const List<BoxShadow> brandGlow = [
    BoxShadow(
      color: Color(0x2E00D1FF), // ~18% cyan glow
      blurRadius: 18,
      spreadRadius: 0,
      offset: Offset(0, 4),
    ),
  ];

  /// Restrained violet glow
  static const List<BoxShadow> violetGlow = [
    BoxShadow(
      color: Color(0x2E8A5CFF), // ~18% violet glow
      blurRadius: 18,
      spreadRadius: 0,
      offset: Offset(0, 4),
    ),
  ];

  /// Dark mode subtle elevation
  static const List<BoxShadow> darkElevated = [
    BoxShadow(
      color: Color(0x40000000),
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];

  /// Returns appropriate card shadow list depending on theme mode
  static List<BoxShadow> cardShadow({required bool isDark}) =>
      isDark ? darkElevated : card;

  /// Returns subtle shadow depending on theme mode
  static List<BoxShadow> subtleShadow({required bool isDark}) =>
      isDark ? const [] : subtle;
}
