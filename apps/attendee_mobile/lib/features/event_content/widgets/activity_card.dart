import 'package:flutter/material.dart';
import '../../../design_system/design_system.dart';
import '../models/spatially_activity.dart';

/// Compact interactive card for event quests, challenges, and checkpoints.
class ActivityCard extends StatelessWidget {
  final SpatiallyActivity activity;
  final bool isCompleted;
  final VoidCallback? onTap;
  final VoidCallback? onMapTap;

  const ActivityCard({
    super.key,
    required this.activity,
    this.isCompleted = false,
    this.onTap,
    this.onMapTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = isDark ? SpatiallyColors.darkTextPrimary : SpatiallyColors.lightTextPrimary;
    final textSecondary = isDark ? SpatiallyColors.darkTextSecondary : SpatiallyColors.lightTextSecondary;

    return Semantics(
      label: '${activity.title}, ${activity.typeDisplayName}, ${activity.points} points, ${isCompleted ? 'Completed' : 'Available'}',
      button: true,
      child: SpatiallyCard(
        padding: const EdgeInsets.all(SpatiallySpacing.md),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Activity Type + Points Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: SpatiallyColors.warning.withValues(alpha: 0.14),
                    borderRadius: SpatiallyRadius.borderSm,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(activity.typeIcon, size: 13, color: SpatiallyColors.warning),
                      SpatiallySpacing.gapHorizontalXxs,
                      Text(
                        activity.typeDisplayName.toUpperCase(),
                        style: SpatiallyTypography.badge(color: SpatiallyColors.warning).copyWith(fontSize: 10),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? SpatiallyColors.success.withValues(alpha: 0.16)
                        : SpatiallyColors.violet.withValues(alpha: 0.12),
                    borderRadius: SpatiallyRadius.borderFull,
                    border: isCompleted
                        ? Border.all(color: SpatiallyColors.success.withValues(alpha: 0.4))
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isCompleted) ...[
                        const Icon(Icons.check_circle_rounded, size: 12, color: SpatiallyColors.success),
                        SpatiallySpacing.gapHorizontalXxs,
                      ],
                      Text(
                        isCompleted ? 'Completed +${activity.points} PTS' : 'Available +${activity.points} PTS',
                        style: SpatiallyTypography.badge(
                          color: isCompleted ? SpatiallyColors.success : SpatiallyColors.violet,
                        ).copyWith(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            SpatiallySpacing.gapVerticalSm,

            // Activity Title
            Text(
              activity.title,
              style: SpatiallyTypography.subheading(color: textPrimary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            SpatiallySpacing.gapVerticalXs,

            // Description
            Text(
              activity.description,
              style: SpatiallyTypography.secondary(color: textSecondary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            SpatiallySpacing.gapVerticalSm,
            const Divider(height: 1),
            SpatiallySpacing.gapVerticalSm,

            // Bottom Row: Verification method & Location
            Row(
              children: [
                Icon(activity.verificationIcon, size: 14, color: textSecondary),
                SpatiallySpacing.gapHorizontalXs,
                Expanded(
                  child: Text(
                    activity.verificationDisplayName,
                    style: SpatiallyTypography.caption(color: textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (activity.poiId != null || activity.zoneId != null)
                  InkWell(
                    onTap: onMapTap,
                    borderRadius: SpatiallyRadius.borderSm,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_on_rounded, size: 13, color: SpatiallyColors.spatialCyan),
                          SpatiallySpacing.gapHorizontalXxs,
                          Text(
                            'Map',
                            style: SpatiallyTypography.caption(color: SpatiallyColors.spatialCyan).copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
