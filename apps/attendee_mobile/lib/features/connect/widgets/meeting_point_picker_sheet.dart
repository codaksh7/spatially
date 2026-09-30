import 'package:flutter/material.dart';
import '../../../design_system/design_system.dart';
import '../models/connect_models.dart';

/// Modal bottom sheet allowing attendees to choose a verified physical meeting
/// point from venue zones and POIs.
class MeetingPointPickerSheet extends StatelessWidget {
  final List<MeetingPoint> meetingPoints;

  const MeetingPointPickerSheet({
    super.key,
    required this.meetingPoints,
  });

  static Future<MeetingPoint?> show(BuildContext context, List<MeetingPoint> points) {
    return showModalBottomSheet<MeetingPoint>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MeetingPointPickerSheet(meetingPoints: points),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isDark ? SpatiallyColors.darkSurfaceElevated : SpatiallyColors.lightSurface;
    final textPrimary = isDark ? SpatiallyColors.darkTextPrimary : SpatiallyColors.lightTextPrimary;
    final textSecondary = isDark ? SpatiallyColors.darkTextSecondary : SpatiallyColors.lightTextSecondary;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(SpatiallyRadius.lg)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: SpatiallySpacing.sm),
              decoration: BoxDecoration(
                color: textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(SpatiallyRadius.full),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: SpatiallySpacing.md,
              vertical: SpatiallySpacing.xs,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(SpatiallySpacing.xs),
                  decoration: BoxDecoration(
                    color: SpatiallyColors.spatialCyan.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(SpatiallyRadius.sm),
                  ),
                  child: const Icon(
                    Icons.pin_drop_rounded,
                    color: SpatiallyColors.spatialCyan,
                    size: 20,
                  ),
                ),
                SpatiallySpacing.gapHorizontalSm,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Suggest Meeting Point',
                        style: SpatiallyTypography.subheading(color: textPrimary),
                      ),
                      Text(
                        'Select a verified venue location with wayfinding',
                        style: SpatiallyTypography.caption(color: textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          const Divider(),

          Flexible(
            child: ListView.separated(
              padding: const EdgeInsets.all(SpatiallySpacing.md),
              shrinkWrap: true,
              itemCount: meetingPoints.length,
              separatorBuilder: (context, index) => SpatiallySpacing.gapVerticalSm,
              itemBuilder: (context, index) {
                final point = meetingPoints[index];
                return InkWell(
                  onTap: () => Navigator.of(context).pop(point),
                  borderRadius: BorderRadius.circular(SpatiallyRadius.md),
                  child: Container(
                    padding: const EdgeInsets.all(SpatiallySpacing.md),
                    decoration: BoxDecoration(
                      color: isDark
                          ? SpatiallyColors.darkSurface
                          : SpatiallyColors.lightBackground,
                      borderRadius: BorderRadius.circular(SpatiallyRadius.md),
                      border: Border.all(
                        color: isDark
                            ? SpatiallyColors.darkBorderSubdued
                            : SpatiallyColors.lightBorderSubdued,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: SpatiallyColors.violet.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(SpatiallyRadius.sm),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.place_outlined,
                              color: SpatiallyColors.violet,
                              size: 22,
                            ),
                          ),
                        ),
                        SpatiallySpacing.gapHorizontalMd,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      point.title,
                                      style: SpatiallyTypography.body(color: textPrimary).copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  if (point.roomNumber.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: SpatiallySpacing.xs,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? SpatiallyColors.darkSurfaceElevated
                                            : SpatiallyColors.lightSurface,
                                        borderRadius: BorderRadius.circular(SpatiallyRadius.xs),
                                        border: Border.all(
                                          color: isDark
                                              ? SpatiallyColors.darkBorderSubdued
                                              : SpatiallyColors.lightBorderSubdued,
                                        ),
                                      ),
                                      child: Text(
                                        point.roomNumber,
                                        style: SpatiallyTypography.caption(color: SpatiallyColors.spatialCyan).copyWith(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              SpatiallySpacing.gapVerticalXxs,
                              Text(
                                point.subtitle,
                                style: SpatiallyTypography.caption(color: textSecondary),
                              ),
                            ],
                          ),
                        ),
                        SpatiallySpacing.gapHorizontalSm,
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: textSecondary.withValues(alpha: 0.5),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          SpatiallySpacing.gapVerticalSm,
        ],
      ),
    );
  }
}
