import 'package:flutter/material.dart';
import '../spatially_colors.dart';
import '../spatially_typography.dart';
import '../spatially_spacing.dart';
import '../spatially_radius.dart';

/// Centralized Category / Filter Chip based on SPATIALLY_DESIGN.md.
/// 
/// Used for event-agnostic filters (All, Live Now, Upcoming, My Tickets).
/// Compact pill shape: ~32–34px visual height.
/// Active state: filled Spatially violet.
/// Inactive state: subtle surface background with border.
class SpatiallyCategoryChip extends StatelessWidget {
  final String label;
  final Widget? icon;
  final bool isSelected;
  final VoidCallback? onTap;

  const SpatiallyCategoryChip({
    super.key,
    required this.label,
    this.icon,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final backgroundColor = isSelected
        ? SpatiallyColors.violet
        : (isDark ? SpatiallyColors.darkSurfaceElevated : SpatiallyColors.lightSurface);

    final textColor = isSelected
        ? Colors.white
        : (isDark ? SpatiallyColors.darkTextPrimary : SpatiallyColors.lightTextPrimary);

    final borderColor = isSelected
        ? Colors.transparent
        : (isDark ? SpatiallyColors.darkBorderSubdued : SpatiallyColors.lightBorderSubdued);

    return Material(
      color: backgroundColor,
      borderRadius: SpatiallyRadius.borderFull,
      child: InkWell(
        borderRadius: SpatiallyRadius.borderFull,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: SpatiallyRadius.borderFull,
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                icon!,
                SpatiallySpacing.gapHorizontalXs,
              ],
              Text(
                label,
                style: SpatiallyTypography.badge(color: textColor).copyWith(fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
