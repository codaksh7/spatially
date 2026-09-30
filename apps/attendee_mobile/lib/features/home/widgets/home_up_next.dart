import 'package:flutter/material.dart';
import '../../../design_system/design_system.dart';
import '../../../screens/my_tickets_screen.dart';

/// Compact "Up Next" preview section for the Home screen.
///
/// Only shown when a real upcoming ticketed event or scheduled session exists
/// after the primary event. Visually subordinate to the active event hero.
class HomeUpNext extends StatelessWidget {
  final Map<String, dynamic> event;
  final Map<String, dynamic>? ticket;
  final VoidCallback? onTap;

  const HomeUpNext({
    super.key,
    required this.event,
    this.ticket,
    this.onTap,
  });

  String get _eventName => (event['name'] as String?) ?? 'Upcoming Event';
  String get _venue => (event['venue'] as String?) ?? 'Venue TBA';

  String _formatTime() {
    final dateStr = event['event_date'] as String?;
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final hour = date.hour.toString().padLeft(2, '0');
      final min = date.minute.toString().padLeft(2, '0');
      return '$hour:$min';
    } catch (_) {
      return '';
    }
  }

  String _formatDate() {
    final dateStr = event['event_date'] as String?;
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${months[date.month - 1]} ${date.day}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary =
        isDark ? SpatiallyColors.darkTextPrimary : SpatiallyColors.lightTextPrimary;
    final textSecondary =
        isDark ? SpatiallyColors.darkTextSecondary : SpatiallyColors.lightTextSecondary;
    final surface = isDark ? SpatiallyColors.darkSurface : SpatiallyColors.lightSurface;
    final border =
        isDark ? SpatiallyColors.darkBorderSubdued : SpatiallyColors.lightBorderSubdued;

    final time = _formatTime();
    final date = _formatDate();
    final hasTicket = ticket != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Row(
          children: [
            Text(
              'UP NEXT',
              style: SpatiallyTypography.badge(color: textSecondary).copyWith(
                fontSize: 11,
                letterSpacing: 0.8,
              ),
            ),
            if (time.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text(
                '· $time',
                style: SpatiallyTypography.secondary(color: textSecondary),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),

        // Compact Card
        GestureDetector(
          onTap: onTap ??
              () {
                if (hasTicket) {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MyTicketsScreen()),
                  );
                }
              },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: SpatiallyRadius.borderMd,
              border: Border.all(color: border),
              boxShadow: SpatiallyShadows.cardShadow(isDark: isDark),
            ),
            child: Row(
              children: [
                // Date/Time pill block
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: SpatiallyColors.violet.withValues(alpha: 0.1),
                    borderRadius: SpatiallyRadius.borderXs,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        date,
                        style: SpatiallyTypography.badge(
                          color: SpatiallyColors.violet,
                        ).copyWith(fontSize: 10),
                      ),
                      if (time.isNotEmpty)
                        Text(
                          time,
                          style: SpatiallyTypography.secondaryMedium(
                            color: SpatiallyColors.violet,
                          ).copyWith(fontSize: 12),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Event details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _eventName,
                        style: SpatiallyTypography.secondaryMedium(color: textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.place_outlined,
                            size: 13,
                            color: SpatiallyColors.spatialCyan,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              _venue,
                              style: SpatiallyTypography.caption(color: textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Ticket badge or forward arrow
                if (hasTicket)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: SpatiallyColors.violet.withValues(alpha: 0.12),
                      borderRadius: SpatiallyRadius.borderXs,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.confirmation_number_outlined,
                          size: 12,
                          color: SpatiallyColors.violet,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'TICKET',
                          style: SpatiallyTypography.badge(
                            color: SpatiallyColors.violet,
                          ).copyWith(fontSize: 10),
                        ),
                      ],
                    ),
                  )
                else
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: textSecondary,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
