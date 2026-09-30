import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'spatially_colors.dart';

/// Centralized Spatially Typography Scale based on SPATIALLY_DESIGN.md.
/// 
/// Uses **Inter** as the primary application UI font.
/// Retains the established Audiowide + Poppins branding font treatment
/// exclusively for the Spatially wordmark/logo.
abstract final class SpatiallyTypography {
  // --- Brand Logo / Wordmark Styles ---

  /// "Spatially" wordmark font (Audiowide bold)
  static TextStyle brandTitle({
    double fontSize = 18,
    Color? color,
  }) {
    return GoogleFonts.audiowide(
      fontSize: fontSize,
      fontWeight: FontWeight.bold,
      color: color,
      letterSpacing: 0.2,
    );
  }

  /// "for Attendee" / "for Volunteer" subtitle font (Poppins w300)
  static TextStyle brandSubtitle({
    double fontSize = 14,
    Color? color,
  }) {
    return GoogleFonts.poppins(
      fontSize: fontSize,
      fontWeight: FontWeight.w300,
      color: color,
    );
  }

  // --- Core Application UI Styles (Inter) ---

  /// Display text (32-36 px, bold)
  static TextStyle display({Color? color}) => GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: -0.5,
        color: color,
      );

  /// Large heading / Heading 1 (24-28 px, bold)
  static TextStyle headingLarge({Color? color}) => GoogleFonts.inter(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        height: 1.25,
        letterSpacing: -0.3,
        color: color,
      );

  /// Section heading / Heading 2 (18-20 px, semi-bold)
  static TextStyle sectionHeading({Color? color}) => GoogleFonts.inter(
        fontSize: 19,
        fontWeight: FontWeight.w600,
        height: 1.3,
        letterSpacing: -0.2,
        color: color,
      );

  /// Subheading / Heading 3 (16 px, semi-bold)
  static TextStyle subheading({Color? color}) => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.35,
        color: color,
      );

  /// Primary body text (15-16 px, regular)
  static TextStyle body({Color? color}) => GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.45,
        color: color,
      );

  /// Primary body medium (15-16 px, medium)
  static TextStyle bodyMedium({Color? color}) => GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        height: 1.45,
        color: color,
      );

  /// Secondary metadata / caption-like body (13-14 px, regular)
  static TextStyle secondary({Color? color}) => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: color,
      );

  /// Secondary metadata medium (13-14 px, medium)
  static TextStyle secondaryMedium({Color? color}) => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        height: 1.4,
        color: color,
      );

  /// Caption text (11-12 px, medium)
  static TextStyle caption({Color? color}) => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        height: 1.35,
        letterSpacing: 0.1,
        color: color,
      );

  /// Button / Action label (15-16 px, semi-bold)
  static TextStyle button({Color? color}) => GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        height: 1.2,
        letterSpacing: 0.1,
        color: color,
      );

  /// Badge / Chip label (12-13 px, semi-bold)
  static TextStyle badge({Color? color}) => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: 1.2,
        letterSpacing: 0.2,
        color: color,
      );

  /// Builds a complete Flutter [TextTheme] adhering to the Spatially scale.
  static TextTheme buildTextTheme({required bool isDark}) {
    final primary = isDark ? SpatiallyColors.darkTextPrimary : SpatiallyColors.lightTextPrimary;
    final secondaryText = isDark ? SpatiallyColors.darkTextSecondary : SpatiallyColors.lightTextSecondary;

    return TextTheme(
      displayLarge: display(color: primary),
      displayMedium: display(color: primary).copyWith(fontSize: 28),
      displaySmall: headingLarge(color: primary),
      headlineLarge: headingLarge(color: primary),
      headlineMedium: sectionHeading(color: primary).copyWith(fontSize: 22),
      headlineSmall: sectionHeading(color: primary),
      titleLarge: sectionHeading(color: primary),
      titleMedium: subheading(color: primary),
      titleSmall: subheading(color: secondaryText).copyWith(fontSize: 14),
      bodyLarge: body(color: primary).copyWith(fontSize: 16),
      bodyMedium: body(color: primary),
      bodySmall: secondary(color: secondaryText),
      labelLarge: button(color: primary),
      labelMedium: badge(color: secondaryText),
      labelSmall: caption(color: secondaryText),
    );
  }
}
