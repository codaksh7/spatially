import 'package:flutter/material.dart';
import '../../../design_system/design_system.dart';
import '../models/passport_progress.dart';

/// Compact progress summary displaying verified attendee metrics.
/// 
/// Strictly displays real verified participation counts (no fake completion).
class PassportProgressGrid extends StatelessWidget {
  final PassportProgress progress;

  const PassportProgressGrid({
    super.key,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = isDark ? SpatiallyColors.darkTextPrimary : SpatiallyColors.lightTextPrimary;
    final textSecondary = isDark ? SpatiallyColors.darkTextSecondary : SpatiallyColors.lightTextSecondary;

    final metrics = [
      _MetricData(
        label: 'Sessions',
        value: '${progress.sessionsAttended}',
        icon: Icons.campaign_rounded,
        color: SpatiallyColors.violet,
      ),
      _MetricData(
        label: 'Booths',
        value: '${progress.boothsVisited}',
        icon: Icons.storefront_rounded,
        color: SpatiallyColors.spatialCyan,
      ),
      _MetricData(
        label: 'Activities',
        value: '${progress.activitiesCompleted}',
        icon: Icons.task_alt_rounded,
        color: SpatiallyColors.warning,
      ),
      _MetricData(
        label: 'Zones',
        value: '${progress.zonesVisited}',
        icon: Icons.explore_rounded,
        color: SpatiallyColors.info,
      ),
      _MetricData(
        label: 'Points',
        value: '${progress.pointsEarned}',
        icon: Icons.stars_rounded,
        color: SpatiallyColors.spatialCyan,
      ),
      _MetricData(
        label: 'Badges',
        value: '${progress.badgesUnlocked}',
        icon: Icons.military_tech_rounded,
        color: SpatiallyColors.violet,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SpatiallySectionHeader(
          title: 'Your Progress',
          subtitle: 'Verified on-site engagement',
        ),
        SpatiallySpacing.gapVerticalSm,
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: metrics.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: SpatiallySpacing.sm,
            crossAxisSpacing: SpatiallySpacing.sm,
            childAspectRatio: 0.98,
          ),
          itemBuilder: (context, index) {
            final m = metrics[index];
            return SpatiallyCard(
              padding: const EdgeInsets.symmetric(
                horizontal: SpatiallySpacing.xs,
                vertical: SpatiallySpacing.sm,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(m.icon, size: 20, color: m.color),
                  SpatiallySpacing.gapVerticalXs,
                  Text(
                    m.value,
                    style: SpatiallyTypography.sectionHeading(color: textPrimary).copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SpatiallySpacing.gapVerticalXxs,
                  Text(
                    m.label,
                    style: SpatiallyTypography.caption(color: textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          },
        ),
        SpatiallySpacing.gapVerticalXs,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: SpatiallySpacing.xs),
          child: Row(
            children: [
              Icon(
                Icons.verified_outlined,
                size: 13,
                color: isDark ? SpatiallyColors.darkTextTertiary : SpatiallyColors.lightTextTertiary,
              ),
              SpatiallySpacing.gapHorizontalXs,
              Expanded(
                child: Text(
                  'Metrics update strictly as your presence and actions are verified on-site.',
                  style: SpatiallyTypography.caption(color: textSecondary).copyWith(
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
}
