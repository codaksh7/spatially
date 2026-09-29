import 'package:flutter/material.dart';

/// Centralized Spatially Spacing Scale based on SPATIALLY_DESIGN.md.
/// 
/// Values: 4, 8, 12, 16, 20, 24, 32, 40, 48
abstract final class SpatiallySpacing {
  static const double xxs = 4.0;
  static const double xs = 8.0;
  static const double sm = 12.0;
  static const double md = 16.0;
  static const double lg = 20.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double xxxl = 40.0;
  static const double huge = 48.0;

  // --- EdgeInsets Shortcuts ---
  static const EdgeInsets paddingAllXxs = EdgeInsets.all(xxs);
  static const EdgeInsets paddingAllXs = EdgeInsets.all(xs);
  static const EdgeInsets paddingAllSm = EdgeInsets.all(sm);
  static const EdgeInsets paddingAllMd = EdgeInsets.all(md);
  static const EdgeInsets paddingAllLg = EdgeInsets.all(lg);
  static const EdgeInsets paddingAllXl = EdgeInsets.all(xl);

  static const EdgeInsets paddingHorizontalXs = EdgeInsets.symmetric(horizontal: xs);
  static const EdgeInsets paddingHorizontalSm = EdgeInsets.symmetric(horizontal: sm);
  static const EdgeInsets paddingHorizontalMd = EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets paddingHorizontalLg = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets paddingHorizontalXl = EdgeInsets.symmetric(horizontal: xl);

  static const EdgeInsets paddingVerticalXs = EdgeInsets.symmetric(vertical: xs);
  static const EdgeInsets paddingVerticalSm = EdgeInsets.symmetric(vertical: sm);
  static const EdgeInsets paddingVerticalMd = EdgeInsets.symmetric(vertical: md);
  static const EdgeInsets paddingVerticalLg = EdgeInsets.symmetric(vertical: lg);
  static const EdgeInsets paddingVerticalXl = EdgeInsets.symmetric(vertical: xl);

  /// Standard screen edge insets (20 horizontal, 16 vertical)
  static const EdgeInsets screenPadding = EdgeInsets.symmetric(horizontal: lg, vertical: md);

  // --- SizedBox Gap Spacers ---
  static const Widget gapVerticalXxs = SizedBox(height: xxs);
  static const Widget gapVerticalXs = SizedBox(height: xs);
  static const Widget gapVerticalSm = SizedBox(height: sm);
  static const Widget gapVerticalMd = SizedBox(height: md);
  static const Widget gapVerticalLg = SizedBox(height: lg);
  static const Widget gapVerticalXl = SizedBox(height: xl);
  static const Widget gapVerticalXxl = SizedBox(height: xxl);
  static const Widget gapVerticalXxxl = SizedBox(height: xxxl);
  static const Widget gapVerticalHuge = SizedBox(height: huge);

  static const Widget gapHorizontalXxs = SizedBox(width: xxs);
  static const Widget gapHorizontalXs = SizedBox(width: xs);
  static const Widget gapHorizontalSm = SizedBox(width: sm);
  static const Widget gapHorizontalMd = SizedBox(width: md);
  static const Widget gapHorizontalLg = SizedBox(width: lg);
  static const Widget gapHorizontalXl = SizedBox(width: xl);
  static const Widget gapHorizontalXxl = SizedBox(width: xxl);
}
