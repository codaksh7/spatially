import 'package:flutter/material.dart';
import '../../../design_system/design_system.dart';
import '../../map/map_screen.dart';
import '../models/safety_models.dart';

/// Reusable tile for venue assistance resources (Help Desk, Accessibility Support).
class SafetyResourceTile extends StatelessWidget {
  final SafetyResource resource;

  const SafetyResourceTile({
    super.key,
    required this.resource,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = isDark ? SpatiallyColors.darkTextPrimary : SpatiallyColors.lightTextPrimary;
    final textSecondary = isDark ? SpatiallyColors.darkTextSecondary : SpatiallyColors.lightTextSecondary;

    return SpatiallyCard(
      padding: const EdgeInsets.all(SpatiallySpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: SpatiallyColors.spatialCyan.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(SpatiallyRadius.sm),
                ),
                child: Center(
                  child: Icon(resource.icon, color: SpatiallyColors.spatialCyan, size: 22),
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
              TextButton.icon(
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
                icon: const Icon(Icons.place_outlined, size: 16),
                label: const Text('Map'),
                style: TextButton.styleFrom(
                  foregroundColor: SpatiallyColors.spatialCyan,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          SpatiallySpacing.gapVerticalXs,
          Text(
            resource.guidance,
            style: SpatiallyTypography.caption(color: textSecondary).copyWith(
              height: 1.35,
            ),
          ),
          if (resource.contactChannel != null) ...[
            SpatiallySpacing.gapVerticalXs,
            Row(
              children: [
                Icon(Icons.headset_mic_outlined, size: 14, color: textSecondary),
                const SizedBox(width: 4),
                Text(
                  resource.contactChannel!,
                  style: SpatiallyTypography.caption(color: SpatiallyColors.violet).copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
