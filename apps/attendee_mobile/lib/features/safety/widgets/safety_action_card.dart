import 'package:flutter/material.dart';
import '../../../design_system/design_system.dart';
import '../../map/map_screen.dart';
import '../models/safety_models.dart';

/// Reusable card for primary venue emergency actions.
class SafetyActionCard extends StatelessWidget {
  final SafetyResource resource;
  final VoidCallback? onGuidanceTap;

  const SafetyActionCard({
    super.key,
    required this.resource,
    this.onGuidanceTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = isDark ? SpatiallyColors.darkTextPrimary : SpatiallyColors.lightTextPrimary;
    final textSecondary = isDark ? SpatiallyColors.darkTextSecondary : SpatiallyColors.lightTextSecondary;

    Color accentColor;
    Color bgTint;
    switch (resource.category) {
      case SafetyCategory.medical:
        accentColor = SpatiallyColors.error;
        bgTint = SpatiallyColors.error.withValues(alpha: 0.12);
        break;
      case SafetyCategory.security:
        accentColor = SpatiallyColors.violet;
        bgTint = SpatiallyColors.violet.withValues(alpha: 0.12);
        break;
      case SafetyCategory.emergencyExit:
        accentColor = const Color(0xFF10B981); // Emerald green for emergency exit
        bgTint = const Color(0xFF10B981).withValues(alpha: 0.12);
        break;
      default:
        accentColor = SpatiallyColors.spatialCyan;
        bgTint = SpatiallyColors.spatialCyan.withValues(alpha: 0.12);
    }

    return SpatiallyCard(
      padding: const EdgeInsets.all(SpatiallySpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: bgTint,
                  borderRadius: BorderRadius.circular(SpatiallyRadius.md),
                ),
                child: Center(
                  child: Icon(resource.icon, color: accentColor, size: 24),
                ),
              ),
              SpatiallySpacing.gapHorizontalMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      resource.title,
                      style: SpatiallyTypography.subheading(color: textPrimary).copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      resource.subtitle,
                      style: SpatiallyTypography.caption(color: textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: bgTint,
                  borderRadius: BorderRadius.circular(SpatiallyRadius.full),
                ),
                child: Text(
                  resource.availability == ResourceAvailability.evacuationOnly
                      ? 'EVACUATION'
                      : 'STAFFED',
                  style: SpatiallyTypography.caption(color: accentColor).copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 9,
                  ),
                ),
              ),
            ],
          ),

          SpatiallySpacing.gapVerticalSm,

          // Location badge & guidance
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: SpatiallySpacing.sm,
              vertical: SpatiallySpacing.xs,
            ),
            decoration: BoxDecoration(
              color: isDark ? SpatiallyColors.darkSurfaceElevated : const Color(0xFFF1F4FA),
              borderRadius: BorderRadius.circular(SpatiallyRadius.sm),
            ),
            child: Row(
              children: [
                Icon(Icons.place_outlined, size: 14, color: textSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    resource.zoneName,
                    style: SpatiallyTypography.caption(color: textPrimary).copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          SpatiallySpacing.gapVerticalSm,

          // Action buttons: Find on Map & Guidance
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => MapScreen(
                          initialPoiId: resource.poiId,
                          initialZoneId: resource.zoneId,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.navigation_rounded, size: 16),
                  label: const Text('Find on Map'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: accentColor,
                    side: BorderSide(color: accentColor.withValues(alpha: 0.5)),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(SpatiallyRadius.sm),
                    ),
                  ),
                ),
              ),
              if (resource.guidance.isNotEmpty) ...[
                SpatiallySpacing.gapHorizontalSm,
                IconButton(
                  icon: const Icon(Icons.info_outline_rounded, size: 20),
                  color: textSecondary,
                  tooltip: 'Emergency Guidance',
                  onPressed: onGuidanceTap ??
                      () => _showGuidanceDialog(context, resource, textPrimary, textSecondary),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _showGuidanceDialog(
    BuildContext context,
    SafetyResource resource,
    Color textPrimary,
    Color textSecondary,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(resource.icon, color: SpatiallyColors.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                resource.title,
                style: SpatiallyTypography.sectionHeading(color: textPrimary),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Location: ${resource.zoneName}',
              style: SpatiallyTypography.body(color: textPrimary).copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (resource.contactChannel != null) ...[
              const SizedBox(height: 4),
              Text(
                'Channel: ${resource.contactChannel}',
                style: SpatiallyTypography.caption(color: textSecondary),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              resource.guidance,
              style: SpatiallyTypography.body(color: textSecondary).copyWith(
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => MapScreen(
                    initialPoiId: resource.poiId,
                    initialZoneId: resource.zoneId,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.navigation_rounded, size: 16),
            label: const Text('Navigate to Station'),
            style: ElevatedButton.styleFrom(
              backgroundColor: SpatiallyColors.violet,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
