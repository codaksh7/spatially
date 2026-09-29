import 'package:flutter/material.dart';
import '../../../design_system/design_system.dart';
import '../../../utils/date_formatter.dart';
import '../models/event_history_item.dart';

/// Event history section displaying attendee's past and registered events.
/// 
/// Strictly distinguishes between REGISTERED (ticket purchased) and ATTENDED (checked in).
class PassportHistorySection extends StatelessWidget {
  final List<EventHistoryItem> history;
  final String? currentEventId;
  final ValueChanged<String>? onSelectEvent;
  final VoidCallback? onViewTickets;

  const PassportHistorySection({
    super.key,
    required this.history,
    this.currentEventId,
    this.onSelectEvent,
    this.onViewTickets,
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
          title: 'Event History',
          subtitle: 'Passes and verified experiences',
          action: onViewTickets != null
              ? InkWell(
                  onTap: onViewTickets,
                  borderRadius: SpatiallyRadius.borderSm,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text(
                      'View Passes',
                      style: SpatiallyTypography.caption(color: SpatiallyColors.violet).copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
              : null,
        ),
        SpatiallySpacing.gapVerticalSm,
        if (history.isEmpty)
          _buildEmptyHistory(context, textSecondary, isDark)
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: history.length,
            separatorBuilder: (context, index) => SpatiallySpacing.gapVerticalSm,
            itemBuilder: (context, index) {
              final item = history[index];
              final isCurrent = item.eventId == currentEventId;
              return _buildHistoryItem(context, item, isCurrent, textPrimary, textSecondary, isDark);
            },
          ),
      ],
    );
  }

  Widget _buildEmptyHistory(BuildContext context, Color textSecondary, bool isDark) {
    return SpatiallyCard(
      padding: const EdgeInsets.all(SpatiallySpacing.lg),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.confirmation_number_outlined,
              size: 32,
              color: isDark ? SpatiallyColors.darkTextTertiary : SpatiallyColors.lightTextTertiary,
            ),
            SpatiallySpacing.gapVerticalSm,
            Text(
              'No event passes found',
              style: SpatiallyTypography.body(color: textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryItem(
    BuildContext context,
    EventHistoryItem item,
    bool isCurrent,
    Color textPrimary,
    Color textSecondary,
    bool isDark,
  ) {
    final dateStr = SpatiallyDateFormatter.formatDate(item.eventDate);

    return InkWell(
      onTap: onSelectEvent != null ? () => onSelectEvent!(item.eventId) : null,
      borderRadius: SpatiallyRadius.borderMd,
      child: SpatiallyCard(
        hasSubtleGlow: isCurrent,
        padding: const EdgeInsets.all(SpatiallySpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    item.eventName,
                    style: SpatiallyTypography.body(color: textPrimary).copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SpatiallySpacing.gapHorizontalSm,
                _buildStatusBadge(item),
              ],
            ),
            SpatiallySpacing.gapVerticalXs,
            Row(
              children: [
                const Icon(Icons.calendar_today_rounded, size: 12, color: SpatiallyColors.violet),
                SpatiallySpacing.gapHorizontalXs,
                Text(
                  dateStr,
                  style: SpatiallyTypography.caption(color: textSecondary).copyWith(fontSize: 11),
                ),
                SpatiallySpacing.gapHorizontalMd,
                const Icon(Icons.location_on_outlined, size: 12, color: SpatiallyColors.spatialCyan),
                SpatiallySpacing.gapHorizontalXs,
                Expanded(
                  child: Text(
                    item.venue,
                    style: SpatiallyTypography.caption(color: textSecondary).copyWith(fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SpatiallySpacing.gapVerticalSm,
            Divider(height: 1, color: isDark ? SpatiallyColors.darkBorderSubdued : SpatiallyColors.lightBorderSubdued),
            SpatiallySpacing.gapVerticalXs,
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'PASS #${item.ticketCode.length > 8 ? item.ticketCode.substring(0, 8).toUpperCase() : item.ticketCode.toUpperCase()}',
                    style: SpatiallyTypography.caption(color: textSecondary).copyWith(
                      letterSpacing: 0.5,
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SpatiallySpacing.gapHorizontalSm,
                if (isCurrent)
                  Text(
                    'Active in Passport',
                    style: SpatiallyTypography.caption(color: SpatiallyColors.violet).copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  )
                else
                  Text(
                    'Tap to view',
                    style: SpatiallyTypography.caption(color: textSecondary).copyWith(
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(EventHistoryItem item) {
    if (item.isAttended) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: SpatiallyColors.success.withValues(alpha: 0.15),
          borderRadius: SpatiallyRadius.borderXs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.verified_rounded, size: 10, color: SpatiallyColors.success),
            SpatiallySpacing.gapHorizontalXxs,
            Text(
              'ATTENDED',
              style: SpatiallyTypography.caption(color: SpatiallyColors.success).copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 10,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: SpatiallyColors.spatialCyan.withValues(alpha: 0.15),
          borderRadius: SpatiallyRadius.borderXs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.confirmation_number_outlined, size: 10, color: SpatiallyColors.spatialCyan),
            SpatiallySpacing.gapHorizontalXxs,
            Text(
              'REGISTERED',
              style: SpatiallyTypography.caption(color: SpatiallyColors.spatialCyan).copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 10,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      );
    }
  }
}
