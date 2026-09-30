import 'package:flutter/material.dart';

/// Centralized Spatially Corner Radius Tokens based on SPATIALLY_DESIGN.md.
/// 
/// Core philosophy: Soft rounded geometry.
abstract final class SpatiallyRadius {
  /// Small controls, chips, compact badges: 10 px
  static const double xs = 10.0;

  /// Buttons, inputs, standard chips: 12 px
  static const double sm = 12.0;

  /// Standard cards, modal sections: 16 px
  static const double md = 16.0;

  /// Prominent cards, feature surfaces: 20 px
  static const double lg = 20.0;

  /// Large cards, hero surfaces: 24 px
  static const double xl = 24.0;

  /// Bottom sheets, major dialog containers: 28 px
  static const double xxl = 28.0;

  /// Full circular / pill controls
  static const double full = 999.0;

  // --- Radius Constants ---
  static const Radius radiusXs = Radius.circular(xs);
  static const Radius radiusSm = Radius.circular(sm);
  static const Radius radiusMd = Radius.circular(md);
  static const Radius radiusLg = Radius.circular(lg);
  static const Radius radiusXl = Radius.circular(xl);
  static const Radius radiusXxl = Radius.circular(xxl);
  static const Radius radiusFull = Radius.circular(full);

  // --- BorderRadius Constants ---
  static const BorderRadius borderXs = BorderRadius.all(radiusXs);
  static const BorderRadius borderSm = BorderRadius.all(radiusSm);
  static const BorderRadius borderMd = BorderRadius.all(radiusMd);
  static const BorderRadius borderLg = BorderRadius.all(radiusLg);
  static const BorderRadius borderXl = BorderRadius.all(radiusXl);
  static const BorderRadius borderXxl = BorderRadius.all(radiusXxl);
  static const BorderRadius borderFull = BorderRadius.all(radiusFull);

  /// Top rounded radius for bottom sheets
  static const BorderRadius bottomSheetBorder = BorderRadius.vertical(top: radiusXxl);
}
