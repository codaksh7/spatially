import 'package:flutter/material.dart';
import '../../../design_system/spatially_colors.dart';
import '../../../design_system/spatially_typography.dart';
import '../../../design_system/spatially_spacing.dart';
import '../../../design_system/spatially_radius.dart';
import '../../../design_system/components/spatially_card.dart';
import '../../../design_system/components/spatially_button.dart';
import '../models/venue_map_models.dart';

/// Floating Route Navigation preview card.
/// 
/// Shows turn instructions, estimated distance/time, accessibility mode toggle,
/// and an honest prototype navigation disclaimer.
class MapRouteSheet extends StatelessWidget {
  final MapRoute route;
  final bool isAccessible;
  final ValueChanged<bool> onAccessibilityToggled;
  final VoidCallback onClose;

  const MapRouteSheet({
    super.key,
    required this.route,
    required this.isAccessible,
    required this.onAccessibilityToggled,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = isDark ? SpatiallyColors.darkTextPrimary : SpatiallyColors.lightTextPrimary;
    final textSecondary = isDark ? SpatiallyColors.darkTextSecondary : SpatiallyColors.lightTextSecondary;

    return SpatiallyCard(
      padding: const EdgeInsets.all(SpatiallySpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Origin -> Destination
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: (isAccessible ? SpatiallyColors.spatialCyan : SpatiallyColors.violet)
                      .withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isAccessible ? Icons.accessible_rounded : Icons.directions_walk_rounded,
                  color: isAccessible ? SpatiallyColors.spatialCyan : SpatiallyColors.violet,
                  size: 20,
                ),
              ),
              SpatiallySpacing.gapHorizontalMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ROUTE TO ${route.destinationName.toUpperCase()}',
                      style: SpatiallyTypography.badge(
                        color: isAccessible ? SpatiallyColors.spatialCyan : SpatiallyColors.violet,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'From: ${route.originName}',
                      style: SpatiallyTypography.caption(color: textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                color: textSecondary,
                tooltip: 'Exit Route',
                onPressed: onClose,
              ),
            ],
          ),

          SpatiallySpacing.gapVerticalMd,

          // Metrics strip: Distance, time, honest status
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: SpatiallySpacing.md,
              vertical: SpatiallySpacing.sm,
            ),
            decoration: BoxDecoration(
              color: isDark ? SpatiallyColors.darkSurfaceElevated : const Color(0xFFF1F4FA),
              borderRadius: SpatiallyRadius.borderSm,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.timer_outlined, size: 16, color: SpatiallyColors.violet),
                    const SizedBox(width: 6),
                    Text(
                      '~${route.estimatedMinutes} min',
                      style: SpatiallyTypography.secondaryMedium(color: textPrimary),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.straighten_rounded, size: 16, color: SpatiallyColors.spatialCyan),
                    const SizedBox(width: 6),
                    Text(
                      '${route.distanceMeters.toStringAsFixed(0)}m',
                      style: SpatiallyTypography.secondaryMedium(color: textPrimary),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: SpatiallyColors.spatialCyan.withValues(alpha: 0.15),
                    borderRadius: SpatiallyRadius.borderXs,
                  ),
                  child: Text(
                    'PROTOTYPE ROUTE',
                    style: SpatiallyTypography.badge(color: SpatiallyColors.spatialCyan).copyWith(
                      fontSize: 9,
                    ),
                  ),
                ),
              ],
            ),
          ),

          SpatiallySpacing.gapVerticalSm,

          // Turn-by-turn guidance description
          Text(
            route.instructions,
            style: SpatiallyTypography.caption(color: textSecondary).copyWith(fontSize: 12),
          ),

          SpatiallySpacing.gapVerticalMd,

          // Accessibility Toggle & Close Actions
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => onAccessibilityToggled(!isAccessible),
                  borderRadius: SpatiallyRadius.borderFull,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isAccessible
                          ? SpatiallyColors.spatialCyan.withValues(alpha: 0.12)
                          : (isDark ? SpatiallyColors.darkSurfaceElevated : const Color(0xFFECEFF6)),
                      borderRadius: SpatiallyRadius.borderFull,
                      border: Border.all(
                        color: isAccessible
                            ? SpatiallyColors.spatialCyan
                            : (isDark ? SpatiallyColors.darkBorderSubdued : SpatiallyColors.lightBorderSubdued),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.accessible_forward_rounded,
                          size: 16,
                          color: isAccessible ? SpatiallyColors.spatialCyan : textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isAccessible ? 'Accessible: ON' : 'Step-free route',
                          style: SpatiallyTypography.caption(
                            color: isAccessible ? SpatiallyColors.spatialCyan : textSecondary,
                          ).copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SpatiallySpacing.gapHorizontalMd,
              Expanded(
                child: SpatiallySecondaryButton(
                  label: 'Exit Route',
                  onPressed: onClose,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
