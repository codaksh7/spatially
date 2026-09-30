import 'package:flutter/material.dart';
import '../../../design_system/design_system.dart';
import '../../../utils/date_formatter.dart';
import '../models/passport_progress.dart';
import '../models/event_history_item.dart';

/// Current event header card in the Passport screen.
/// 
/// Shows event metadata, verified check-in / registered state,
/// and allows switching events when the attendee holds multiple passes.
class PassportEventCard extends StatelessWidget {
  final PassportEventContext eventContext;
  final List<EventHistoryItem> allEvents;
  final ValueChanged<String>? onSelectEvent;
  final VoidCallback? onOpenTicketPass;

  const PassportEventCard({
    super.key,
    required this.eventContext,
    this.allEvents = const [],
    this.onSelectEvent,
    this.onOpenTicketPass,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = isDark ? SpatiallyColors.darkTextPrimary : SpatiallyColors.lightTextPrimary;
    final textSecondary = isDark ? SpatiallyColors.darkTextSecondary : SpatiallyColors.lightTextSecondary;

    final dateStr = SpatiallyDateFormatter.formatDateTime(eventContext.eventDate, includeYear: true);

    return SpatiallyCard(
      hasSubtleGlow: eventContext.isLive,
      padding: const EdgeInsets.all(SpatiallySpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status row: Check-in / Registered badge & Event switcher
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildAttendanceBadge(),
              if (allEvents.length > 1)
                InkWell(
                  onTap: () => _showEventPicker(context),
                  borderRadius: SpatiallyRadius.borderSm,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Switch Event',
                          style: SpatiallyTypography.caption(color: SpatiallyColors.violet)
                              .copyWith(fontWeight: FontWeight.w600),
                        ),
                        const Icon(Icons.arrow_drop_down_rounded, size: 18, color: SpatiallyColors.violet),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          SpatiallySpacing.gapVerticalMd,

          // Event Title
          Text(
            eventContext.eventName,
            style: SpatiallyTypography.headingLarge(color: textPrimary),
          ),
          SpatiallySpacing.gapVerticalMd,

          // Date & Venue Details
          Row(
            children: [
              const Icon(Icons.calendar_today_rounded, size: 14, color: SpatiallyColors.violet),
              SpatiallySpacing.gapHorizontalXs,
              Expanded(
                child: Text(
                  dateStr,
                  style: SpatiallyTypography.caption(color: textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SpatiallySpacing.gapVerticalXs,
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 14, color: SpatiallyColors.spatialCyan),
              SpatiallySpacing.gapHorizontalXs,
              Expanded(
                child: Text(
                  eventContext.venue,
                  style: SpatiallyTypography.caption(color: textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          if (eventContext.isRegistered && onOpenTicketPass != null) ...[
            SpatiallySpacing.gapVerticalLg,
            SpatiallySoftButton(
              label: eventContext.isCheckedIn ? 'View Admittance Pass' : 'Open Ticket Pass (QR)',
              icon: const Icon(Icons.qr_code_rounded, size: 18, color: SpatiallyColors.violet),
              onPressed: onOpenTicketPass,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAttendanceBadge() {
    if (eventContext.isCheckedIn) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: SpatiallyColors.success.withValues(alpha: 0.14),
          borderRadius: SpatiallyRadius.borderFull,
          border: Border.all(
            color: SpatiallyColors.success.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded, size: 13, color: SpatiallyColors.success),
            SpatiallySpacing.gapHorizontalXs,
            Text(
              'CHECKED IN',
              style: SpatiallyTypography.badge(color: SpatiallyColors.success),
            ),
          ],
        ),
      );
    }

    if (eventContext.isRegistered) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: SpatiallyColors.info.withValues(alpha: 0.14),
          borderRadius: SpatiallyRadius.borderFull,
          border: Border.all(
            color: SpatiallyColors.info.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.confirmation_number_outlined, size: 13, color: SpatiallyColors.info),
            SpatiallySpacing.gapHorizontalXs,
            Text(
              'REGISTERED',
              style: SpatiallyTypography.badge(color: SpatiallyColors.info),
            ),
          ],
        ),
      );
    }

    return const SpatiallyStatusBadge(
      label: 'PUBLIC OVERVIEW',
      variant: SpatiallyBadgeVariant.custom,
    );
  }

  void _showEventPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: SpatiallySpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: SpatiallySpacing.lg, vertical: SpatiallySpacing.xs),
                  child: Text(
                    'Select Event Passport',
                    style: SpatiallyTypography.sectionHeading(),
                  ),
                ),
                const Divider(),
                ...allEvents.map((item) {
                  final isSelected = item.eventId == eventContext.eventId;
                  return ListTile(
                    leading: Icon(
                      item.isAttended
                          ? Icons.verified_rounded
                          : Icons.confirmation_number_rounded,
                      color: item.isAttended ? SpatiallyColors.success : SpatiallyColors.violet,
                    ),
                    title: Text(item.eventName, style: SpatiallyTypography.subheading()),
                    subtitle: Text(
                      '${item.venue} • ${item.isAttended ? 'Attended' : 'Registered'}',
                      style: SpatiallyTypography.caption(),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_rounded, color: SpatiallyColors.violet)
                        : null,
                    onTap: () {
                      Navigator.of(ctx).pop();
                      if (onSelectEvent != null) {
                        onSelectEvent!(item.eventId);
                      }
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}
