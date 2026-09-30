import 'package:flutter/material.dart';
import '../../../design_system/design_system.dart';
import '../../map/map_screen.dart';
import '../models/safety_models.dart';

/// Card displaying an individual Lost or Found item with status and map bridge.
class LostFoundItemCard extends StatelessWidget {
  final LostFoundReport report;

  const LostFoundItemCard({
    super.key,
    required this.report,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = isDark ? SpatiallyColors.darkTextPrimary : SpatiallyColors.lightTextPrimary;
    final textSecondary = isDark ? SpatiallyColors.darkTextSecondary : SpatiallyColors.lightTextSecondary;

    final isLost = report.type == LostFoundType.lost;
    final typeBadgeColor = isLost ? const Color(0xFFEF4444) : const Color(0xFF10B981);

    return SpatiallyCard(
      padding: const EdgeInsets.all(SpatiallySpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Category Icon, Title, and Type/Status badges
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: typeBadgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(SpatiallyRadius.sm),
                ),
                child: Center(
                  child: Icon(report.category.icon, color: typeBadgeColor, size: 22),
                ),
              ),
              SpatiallySpacing.gapHorizontalMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: typeBadgeColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(SpatiallyRadius.xs),
                          ),
                          child: Text(
                            report.type.label.toUpperCase(),
                            style: SpatiallyTypography.caption(color: typeBadgeColor).copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 9,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: report.status.color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(SpatiallyRadius.xs),
                          ),
                          child: Text(
                            report.status.label,
                            style: SpatiallyTypography.caption(color: report.status.color).copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 9,
                            ),
                          ),
                        ),
                        if (report.isCurrentUser)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: SpatiallyColors.violet.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(SpatiallyRadius.xs),
                            ),
                            child: Text(
                              'YOUR REPORT',
                              style: SpatiallyTypography.caption(color: SpatiallyColors.violet).copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 9,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      report.title,
                      style: SpatiallyTypography.subheading(color: textPrimary).copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          SpatiallySpacing.gapVerticalSm,

          // Description
          Text(
            report.description,
            style: SpatiallyTypography.caption(color: textSecondary).copyWith(
              height: 1.35,
            ),
          ),

          SpatiallySpacing.gapVerticalSm,

          // Venue Location strip (tappable map bridge)
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(SpatiallyRadius.sm),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MapScreen(
                      initialZoneId: report.venueZoneId,
                    ),
                  ),
                );
              },
              child: Container(
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
                        report.specificLocation != null
                            ? '${report.venueZoneName} (${report.specificLocation})'
                            : report.venueZoneName,
                        style: SpatiallyTypography.caption(color: textPrimary).copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Map',
                          style: SpatiallyTypography.caption(color: SpatiallyColors.spatialCyan).copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(Icons.chevron_right_rounded, size: 14, color: SpatiallyColors.spatialCyan),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (report.pickupInstructions != null) ...[
            SpatiallySpacing.gapVerticalXs,
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 14, color: textSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    report.pickupInstructions!,
                    style: SpatiallyTypography.caption(color: textSecondary).copyWith(
                      fontStyle: FontStyle.italic,
                      fontSize: 11,
                    ),
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
