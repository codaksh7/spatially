import 'package:flutter/material.dart';
import '../spatially_colors.dart';
import '../spatially_typography.dart';
import '../spatially_spacing.dart';
import '../spatially_radius.dart';

enum SpatiallyBadgeVariant {
  live,
  upcoming,
  purchased,
  checkedIn,
  advertising,
  idle,
  custom,
}

/// Centralized Status Badge component based on SPATIALLY_DESIGN.md.
/// 
/// Replaces unstyled raw text badges with unified tinted pill indicators.
class SpatiallyStatusBadge extends StatelessWidget {
  final String label;
  final SpatiallyBadgeVariant variant;
  final Color? customColor;
  final bool showDot;

  const SpatiallyStatusBadge({
    super.key,
    required this.label,
    this.variant = SpatiallyBadgeVariant.custom,
    this.customColor,
    this.showDot = true,
  });

  /// Factory for Live badge (Green)
  factory SpatiallyStatusBadge.live({String label = 'LIVE'}) =>
      SpatiallyStatusBadge(label: label, variant: SpatiallyBadgeVariant.live);

  /// Factory for Upcoming badge (Blue)
  factory SpatiallyStatusBadge.upcoming({String label = 'UPCOMING'}) =>
      SpatiallyStatusBadge(label: label, variant: SpatiallyBadgeVariant.upcoming);

  /// Factory for Purchased badge (Green)
  factory SpatiallyStatusBadge.purchased({String label = 'PURCHASED'}) =>
      SpatiallyStatusBadge(label: label, variant: SpatiallyBadgeVariant.purchased);

  /// Factory for Checked In badge (Subdued Grey)
  factory SpatiallyStatusBadge.checkedIn({String label = 'CHECKED IN'}) =>
      SpatiallyStatusBadge(label: label, variant: SpatiallyBadgeVariant.checkedIn);

  /// Factory for Advertising beacon badge (Cyan)
  factory SpatiallyStatusBadge.advertising({String label = 'BROADCASTING'}) =>
      SpatiallyStatusBadge(label: label, variant: SpatiallyBadgeVariant.advertising);

  /// Factory for Idle beacon badge
  factory SpatiallyStatusBadge.idle({String label = 'IDLE'}) =>
      SpatiallyStatusBadge(label: label, variant: SpatiallyBadgeVariant.idle);

  Color _resolveColor() {
    switch (variant) {
      case SpatiallyBadgeVariant.live:
        return SpatiallyColors.success;
      case SpatiallyBadgeVariant.upcoming:
        return SpatiallyColors.info;
      case SpatiallyBadgeVariant.purchased:
        return SpatiallyColors.success;
      case SpatiallyBadgeVariant.checkedIn:
        return SpatiallyColors.lightTextSecondary;
      case SpatiallyBadgeVariant.advertising:
        return SpatiallyColors.spatialCyan;
      case SpatiallyBadgeVariant.idle:
        return SpatiallyColors.lightTextTertiary;
      case SpatiallyBadgeVariant.custom:
        return customColor ?? SpatiallyColors.violet;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _resolveColor();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: SpatiallyRadius.borderFull,
        border: Border.all(
          color: color.withValues(alpha: 0.28),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (showDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            SpatiallySpacing.gapHorizontalXs,
          ],
          Text(
            label.toUpperCase(),
            style: SpatiallyTypography.badge(color: color),
          ),
        ],
      ),
    );
  }
}
