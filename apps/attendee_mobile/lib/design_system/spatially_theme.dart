import 'package:flutter/material.dart';
import 'spatially_colors.dart';
import 'spatially_typography.dart';
import 'spatially_radius.dart';

/// Centralized Spatially Theme Definition based on SPATIALLY_DESIGN.md.
/// 
/// Provides unified light and dark [ThemeData] configurations.
abstract final class SpatiallyTheme {
  // --- Light Theme ---
  static ThemeData get lightTheme {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: SpatiallyColors.violet,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFEDE7FF),
      onPrimaryContainer: SpatiallyColors.violet,
      secondary: SpatiallyColors.spatialCyan,
      onSecondary: Colors.black,
      secondaryContainer: Color(0xFFE0F7FA),
      onSecondaryContainer: Color(0xFF006064),
      tertiary: SpatiallyColors.purple,
      onTertiary: Colors.white,
      error: SpatiallyColors.error,
      onError: Colors.white,
      surface: SpatiallyColors.lightSurface,
      onSurface: SpatiallyColors.lightTextPrimary,
      surfaceContainerHighest: SpatiallyColors.lightBorderSubdued,
      outline: SpatiallyColors.lightBorderSubdued,
      outlineVariant: Color(0xFFDFE2EC),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: SpatiallyColors.lightBackground,
      textTheme: SpatiallyTypography.buildTextTheme(isDark: false),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: SpatiallyColors.lightTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: const CardThemeData(
        color: SpatiallyColors.lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: SpatiallyRadius.borderMd,
          side: BorderSide(color: SpatiallyColors.lightBorderSubdued),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: SpatiallyColors.violet,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: const RoundedRectangleBorder(
            borderRadius: SpatiallyRadius.borderSm,
          ),
          textStyle: SpatiallyTypography.button(),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: SpatiallyColors.lightTextPrimary,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          side: const BorderSide(color: SpatiallyColors.lightBorderSubdued),
          shape: const RoundedRectangleBorder(
            borderRadius: SpatiallyRadius.borderSm,
          ),
          textStyle: SpatiallyTypography.button(),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: SpatiallyColors.violet,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: const RoundedRectangleBorder(
            borderRadius: SpatiallyRadius.borderSm,
          ),
          textStyle: SpatiallyTypography.button(),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: SpatiallyColors.lightSurface,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: SpatiallyRadius.borderSm,
          borderSide: BorderSide(color: SpatiallyColors.lightBorderSubdued),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: SpatiallyRadius.borderSm,
          borderSide: BorderSide(color: SpatiallyColors.lightBorderSubdued),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: SpatiallyRadius.borderSm,
          borderSide: BorderSide(color: SpatiallyColors.neonBlue, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: SpatiallyRadius.borderSm,
          borderSide: BorderSide(color: SpatiallyColors.error),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: SpatiallyColors.lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: SpatiallyRadius.borderXl,
          side: BorderSide(color: SpatiallyColors.lightBorderSubdued),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: SpatiallyColors.lightSurface,
        modalBackgroundColor: SpatiallyColors.lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: SpatiallyRadius.bottomSheetBorder,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: SpatiallyColors.lightBorderSubdued,
        thickness: 1,
        space: 1,
      ),
    );
  }

  // --- Dark Theme ---
  static ThemeData get darkTheme {
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: SpatiallyColors.neonBlue,
      onPrimary: Colors.black,
      primaryContainer: Color(0xFF1E2638),
      onPrimaryContainer: SpatiallyColors.neonBlue,
      secondary: SpatiallyColors.spatialCyan,
      onSecondary: Colors.black,
      secondaryContainer: Color(0xFF162E3B),
      onSecondaryContainer: SpatiallyColors.spatialCyan,
      tertiary: SpatiallyColors.purple,
      onTertiary: Colors.white,
      error: SpatiallyColors.error,
      onError: Colors.white,
      surface: SpatiallyColors.darkSurface,
      onSurface: SpatiallyColors.darkTextPrimary,
      surfaceContainerHighest: SpatiallyColors.darkBorderSubdued,
      outline: SpatiallyColors.darkBorderSubdued,
      outlineVariant: Color(0xFF383844),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: SpatiallyColors.darkBackground,
      textTheme: SpatiallyTypography.buildTextTheme(isDark: true),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: SpatiallyColors.darkTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: const CardThemeData(
        color: SpatiallyColors.darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: SpatiallyRadius.borderMd,
          side: BorderSide(color: SpatiallyColors.darkBorderSubdued),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: SpatiallyColors.neonBlue,
          foregroundColor: Colors.black,
          elevation: 0,
          shadowColor: Colors.transparent,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: const RoundedRectangleBorder(
            borderRadius: SpatiallyRadius.borderSm,
          ),
          textStyle: SpatiallyTypography.button(),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: SpatiallyColors.darkTextPrimary,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          side: const BorderSide(color: SpatiallyColors.darkBorderSubdued),
          shape: const RoundedRectangleBorder(
            borderRadius: SpatiallyRadius.borderSm,
          ),
          textStyle: SpatiallyTypography.button(),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: SpatiallyColors.neonBlue,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: const RoundedRectangleBorder(
            borderRadius: SpatiallyRadius.borderSm,
          ),
          textStyle: SpatiallyTypography.button(),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: SpatiallyColors.darkSurface,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: SpatiallyRadius.borderSm,
          borderSide: BorderSide(color: SpatiallyColors.darkBorderSubdued),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: SpatiallyRadius.borderSm,
          borderSide: BorderSide(color: SpatiallyColors.darkBorderSubdued),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: SpatiallyRadius.borderSm,
          borderSide: BorderSide(color: SpatiallyColors.neonBlue, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: SpatiallyRadius.borderSm,
          borderSide: BorderSide(color: SpatiallyColors.error),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: SpatiallyColors.darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: SpatiallyRadius.borderXl,
          side: BorderSide(color: SpatiallyColors.darkBorderSubdued),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: SpatiallyColors.darkSurface,
        modalBackgroundColor: SpatiallyColors.darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: SpatiallyRadius.bottomSheetBorder,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: SpatiallyColors.darkBorderSubdued,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
