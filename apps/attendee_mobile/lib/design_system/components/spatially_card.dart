import 'package:flutter/material.dart';
import '../spatially_colors.dart';
import '../spatially_radius.dart';
import '../spatially_spacing.dart';
import '../spatially_shadows.dart';

/// Centralized Spatially Card / Surface Component based on SPATIALLY_DESIGN.md.
/// 
/// Provides soft rounded geometry, subtle depth, and surface contrast.
class SpatiallyCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final Color? borderColor;
  final List<BoxShadow>? shadows;
  final bool hasSubtleGlow;

  const SpatiallyCard({
    super.key,
    required this.child,
    this.padding = SpatiallySpacing.paddingAllMd,
    this.onTap,
    this.borderRadius,
    this.backgroundColor,
    this.borderColor,
    this.shadows,
    this.hasSubtleGlow = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final effectiveRadius = borderRadius ?? SpatiallyRadius.borderMd;
    final effectiveBg = backgroundColor ??
        (isDark ? SpatiallyColors.darkSurface : SpatiallyColors.lightSurface);
    final effectiveBorderColor = borderColor ??
        (isDark ? SpatiallyColors.darkBorderSubdued : SpatiallyColors.lightBorderSubdued);

    List<BoxShadow> effectiveShadows = shadows ?? SpatiallyShadows.cardShadow(isDark: isDark);
    if (hasSubtleGlow) {
      effectiveShadows = [
        ...effectiveShadows,
        ...SpatiallyShadows.brandGlow,
      ];
    }

    Widget content = Container(
      decoration: BoxDecoration(
        color: effectiveBg,
        borderRadius: effectiveRadius,
        border: Border.all(color: effectiveBorderColor, width: 1),
        boxShadow: effectiveShadows,
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        borderRadius: effectiveRadius,
        child: InkWell(
          borderRadius: effectiveRadius,
          onTap: onTap,
          child: content,
        ),
      );
    }

    return content;
  }
}
