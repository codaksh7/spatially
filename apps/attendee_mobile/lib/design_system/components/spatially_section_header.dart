import 'package:flutter/material.dart';
import '../spatially_colors.dart';
import '../spatially_typography.dart';
import '../spatially_spacing.dart';

/// Centralized Section Header Component based on SPATIALLY_DESIGN.md.
/// 
/// Provides a clear title, optional subtitle, and optional trailing action.
class SpatiallySectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;
  final EdgeInsetsGeometry padding;

  const SpatiallySectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    this.padding = const EdgeInsets.symmetric(vertical: SpatiallySpacing.xs),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = isDark ? SpatiallyColors.darkTextPrimary : SpatiallyColors.lightTextPrimary;
    final textSecondary = isDark ? SpatiallyColors.darkTextSecondary : SpatiallyColors.lightTextSecondary;

    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: SpatiallyTypography.sectionHeading(color: textPrimary),
                ),
                if (subtitle != null) ...[
                  SpatiallySpacing.gapVerticalXxs,
                  Text(
                    subtitle!,
                    style: SpatiallyTypography.secondary(color: textSecondary),
                  ),
                ],
              ],
            ),
          ),
          if (action != null) ...[
            SpatiallySpacing.gapHorizontalMd,
            action!,
          ],
        ],
      ),
    );
  }
}
