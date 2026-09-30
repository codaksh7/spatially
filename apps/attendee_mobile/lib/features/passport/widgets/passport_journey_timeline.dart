import 'package:flutter/material.dart';
import '../../../design_system/design_system.dart';
import '../../../utils/date_formatter.dart';
import '../models/journey_entry.dart';

/// Vertical timeline displaying verified milestones in the attendee's journey.
/// 
/// Shows an intentional, informative empty state when no milestones are verified yet.
class PassportJourneyTimeline extends StatelessWidget {
  final List<JourneyEntry> entries;
  final bool isCheckedIn;
  final ValueChanged<JourneyEntry>? onEntryTap;

  const PassportJourneyTimeline({
    super.key,
    required this.entries,
    this.isCheckedIn = false,
    this.onEntryTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = isDark ? SpatiallyColors.darkTextPrimary : SpatiallyColors.lightTextPrimary;
    final textSecondary = isDark ? SpatiallyColors.darkTextSecondary : SpatiallyColors.lightTextSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SpatiallySectionHeader(
          title: 'Your Journey',
          subtitle: 'Verified timeline milestones',
          action: entries.isNotEmpty
              ? SpatiallyStatusBadge(
                  label: '${entries.length} ${entries.length == 1 ? 'EVENT' : 'EVENTS'}',
                  variant: SpatiallyBadgeVariant.live,
                )
              : null,
        ),
        SpatiallySpacing.gapVerticalSm,
        if (entries.isEmpty)
          _buildEmptyState(context, textPrimary, textSecondary, isDark)
        else
          _buildTimeline(context, textPrimary, textSecondary, isDark),
      ],
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    Color textPrimary,
    Color textSecondary,
    bool isDark,
  ) {
    return SpatiallyCard(
      padding: const EdgeInsets.all(SpatiallySpacing.lg),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: SpatiallyColors.violet.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.route_rounded,
              color: SpatiallyColors.violet,
              size: 26,
            ),
          ),
          SpatiallySpacing.gapVerticalMd,
          Text(
            'No verified journey yet',
            style: SpatiallyTypography.sectionHeading(color: textPrimary),
            textAlign: TextAlign.center,
          ),
          SpatiallySpacing.gapVerticalXs,
          Text(
            isCheckedIn
                ? 'You are checked in! As you attend sessions, visit booths, and complete quests, your verified milestones will record here.'
                : 'Your journey starts when you check in and explore the event. Sessions, booths, and quests will appear here as they are verified.',
            style: SpatiallyTypography.body(color: textSecondary),
            textAlign: TextAlign.center,
          ),
          SpatiallySpacing.gapVerticalMd,
          Container(
            padding: const EdgeInsets.all(SpatiallySpacing.md),
            decoration: BoxDecoration(
              color: isDark ? SpatiallyColors.darkSurface : SpatiallyColors.lightSurface,
              borderRadius: SpatiallyRadius.borderMd,
              border: Border.all(
                color: isDark ? SpatiallyColors.darkBorderSubdued : SpatiallyColors.lightBorderSubdued,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildGuideRow(
                  icon: isCheckedIn ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  iconColor: isCheckedIn ? SpatiallyColors.success : textSecondary,
                  title: isCheckedIn ? 'Checked in to venue' : 'Check in at venue entrance',
                  textSecondary: textSecondary,
                ),
                SpatiallySpacing.gapVerticalXs,
                _buildGuideRow(
                  icon: Icons.radio_button_unchecked_rounded,
                  iconColor: textSecondary,
                  title: 'Attend verified stages & keynotes',
                  textSecondary: textSecondary,
                ),
                SpatiallySpacing.gapVerticalXs,
                _buildGuideRow(
                  icon: Icons.radio_button_unchecked_rounded,
                  iconColor: textSecondary,
                  title: 'Visit partner exhibition showcases',
                  textSecondary: textSecondary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required Color textSecondary,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: iconColor),
        SpatiallySpacing.gapHorizontalSm,
        Expanded(
          child: Text(
            title,
            style: SpatiallyTypography.caption(color: textSecondary),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeline(
    BuildContext context,
    Color textPrimary,
    Color textSecondary,
    bool isDark,
  ) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final isLast = index == entries.length - 1;
        final timeStr = SpatiallyDateFormatter.formatTime(entry.timestamp);

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Timeline Node & Connector Line
              SizedBox(
                width: 36,
                child: Column(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: entry.type.color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: entry.type.color,
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        entry.type.icon,
                        size: 14,
                        color: entry.type.color,
                      ),
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 2,
                          color: isDark ? SpatiallyColors.darkBorderSubdued : SpatiallyColors.lightBorderSubdued,
                        ),
                      ),
                  ],
                ),
              ),
              SpatiallySpacing.gapHorizontalSm,

              // Content Card
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : SpatiallySpacing.md),
                  child: InkWell(
                    onTap: onEntryTap != null ? () => onEntryTap!(entry) : null,
                    borderRadius: SpatiallyRadius.borderMd,
                    child: SpatiallyCard(
                      padding: const EdgeInsets.all(SpatiallySpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: entry.type.color.withValues(alpha: 0.12),
                                  borderRadius: SpatiallyRadius.borderXs,
                                ),
                                child: Text(
                                  entry.type.label,
                                  style: SpatiallyTypography.caption(color: entry.type.color).copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              Row(
                                children: [
                                  Text(
                                    timeStr,
                                    style: SpatiallyTypography.caption(color: textSecondary).copyWith(
                                      fontSize: 11,
                                    ),
                                  ),
                                  SpatiallySpacing.gapHorizontalXs,
                                  const Icon(Icons.verified_rounded, size: 14, color: SpatiallyColors.success),
                                ],
                              ),
                            ],
                          ),
                          SpatiallySpacing.gapVerticalXs,
                          Text(
                            entry.title,
                            style: SpatiallyTypography.body(color: textPrimary).copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SpatiallySpacing.gapVerticalXxs,
                          Text(
                            entry.subtitle,
                            style: SpatiallyTypography.caption(color: textSecondary),
                          ),
                          if (entry.locationName != null) ...[
                            SpatiallySpacing.gapVerticalXs,
                            Row(
                              children: [
                                const Icon(Icons.location_on_outlined, size: 12, color: SpatiallyColors.spatialCyan),
                                SpatiallySpacing.gapHorizontalXxs,
                                Expanded(
                                  child: Text(
                                    entry.locationName!,
                                    style: SpatiallyTypography.caption(color: textSecondary).copyWith(
                                      fontSize: 11,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
