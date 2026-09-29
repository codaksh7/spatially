import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../design_system/design_system.dart';
import '../../../screens/my_tickets_screen.dart';
import '../../../screens/event_list_screen.dart';
import '../../map/models/venue_map_models.dart';

/// The primary event hero section for the Home screen.
///
/// Features:
/// - Unboxed event title sitting boldly on the background canvas.
/// - Clear status hierarchy: Live/Upcoming context → Title → Unified venue/time metadata.
/// - Single coherent event context card with ticket status, crowd intelligence, and dual thumb actions.
/// - Violet primary button ('My Ticket' / 'Open Ticket') and Cyan-accented secondary button ('Venue Map').
class EventHero extends StatelessWidget {
  final Map<String, dynamic> event;
  final Map<String, dynamic>? ticket;
  final VoidCallback? onNavigateToMap;
  final SpatialCrowdState? crowdState;

  const EventHero({
    super.key,
    required this.event,
    this.ticket,
    this.onNavigateToMap,
    this.crowdState,
  });

  bool get _isLive => (event['status'] as String?) == 'live';
  String get _eventName => (event['name'] as String?) ?? 'Unnamed Event';
  String get _venue => (event['venue'] as String?) ?? 'Venue TBA';

  /// Human-readable contextual time string.
  String _contextualTime() {
    final dateStr = event['event_date'] as String?;
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();
      final diff = date.difference(now);

      if (_isLive) return 'Live now';
      if (diff.isNegative) return 'Event ended';

      final hour = date.hour.toString().padLeft(2, '0');
      final min = date.minute.toString().padLeft(2, '0');

      if (diff.inDays == 0 && date.day == now.day) {
        return 'Today · $hour:$min';
      }
      if (diff.inDays <= 1 && date.day == now.day + 1) {
        return 'Tomorrow · $hour:$min';
      }
      if (diff.inDays < 7) {
        return 'In ${diff.inDays} days';
      }
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${months[date.month - 1]} ${date.day}';
    } catch (_) {
      return '';
    }
  }

  String get _ticketStatus {
    final status = ticket?['status'] as String?;
    if (status == 'checked_in') return 'CHECKED IN';
    if (status == 'purchased') return 'TICKET READY';
    return 'NO TICKET';
  }

  bool get _hasTicket => ticket != null;
  bool get _isCheckedIn => (ticket?['status'] as String?) == 'checked_in';

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

    final contextualTime = _contextualTime();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- 1. Small live/status context row ---
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _isLive
                    ? SpatiallyColors.success.withValues(alpha: 0.12)
                    : SpatiallyColors.violet.withValues(alpha: 0.1),
                borderRadius: SpatiallyRadius.borderXs,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isLive) ...[
                    _LivePulseDot(),
                    const SizedBox(width: 5),
                  ],
                  Text(
                    _isLive ? 'NOW LIVE' : 'UPCOMING',
                    style: SpatiallyTypography.badge(
                      color: _isLive ? SpatiallyColors.success : SpatiallyColors.violet,
                    ).copyWith(fontSize: 10, letterSpacing: 0.6),
                  ),
                ],
              ),
            ),
            if (contextualTime.isNotEmpty && !_isLive) ...[
              const SizedBox(width: 8),
              Text(
                contextualTime,
                style: SpatiallyTypography.caption(color: textSecondary),
              ),
            ],
          ],
        ),

        const SizedBox(height: 8),

        // --- 2. Large Event Title — directly on canvas ---
        Text(
          _eventName,
          style: GoogleFonts.inter(
            fontSize: 27,
            fontWeight: FontWeight.w700,
            height: 1.15,
            letterSpacing: -0.5,
            color: textPrimary,
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),

        const SizedBox(height: 6),

        // --- 3. Unified Venue + Context line ---
        Row(
          children: [
            Icon(
              Icons.place_rounded,
              size: 14,
              color: SpatiallyColors.spatialCyan,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                _venue,
                style: SpatiallyTypography.secondary(color: textSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        // --- 4. Event Context Card ---
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: SpatiallyRadius.borderLg,
            border: Border.all(color: border),
            boxShadow: SpatiallyShadows.cardShadow(isDark: isDark),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ticket Status & Crowd Intelligence Row
              Row(
                children: [
                  Icon(
                    _isCheckedIn
                        ? Icons.check_circle_rounded
                        : (_hasTicket
                            ? Icons.confirmation_number_outlined
                            : Icons.info_outline_rounded),
                    size: 16,
                    color: _isCheckedIn
                        ? SpatiallyColors.success
                        : (_hasTicket ? SpatiallyColors.violet : textSecondary),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _ticketStatus,
                    style: SpatiallyTypography.badge(
                      color: _isCheckedIn
                          ? SpatiallyColors.success
                          : (_hasTicket ? SpatiallyColors.violet : textSecondary),
                    ).copyWith(fontSize: 11),
                  ),
                  const Spacer(),
                  if (_isLive)
                    _buildCrowdWidget(textSecondary)
                  else if (_hasTicket)
                    Text(
                      'Ready for entry',
                      style: SpatiallyTypography.caption(color: textSecondary),
                    ),
                ],
              ),

              const SizedBox(height: 12),
              Divider(height: 1, color: border),
              const SizedBox(height: 12),

              // Thumb-friendly Dual Action Buttons
              Row(
                children: [
                  if (_hasTicket)
                    Expanded(
                      child: SpatiallyPrimaryButton(
                        label: _isCheckedIn ? 'Open Ticket' : 'My Ticket',
                        height: 46,
                        icon: const Icon(
                          Icons.confirmation_number_rounded,
                          size: 17,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const MyTicketsScreen(),
                            ),
                          );
                        },
                      ),
                    )
                  else
                    Expanded(
                      child: SpatiallyPrimaryButton(
                        label: 'Get Ticket',
                        height: 46,
                        icon: const Icon(
                          Icons.add_rounded,
                          size: 17,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const EventListScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(width: 10),
                  if (_isLive && onNavigateToMap != null)
                    SpatiallySecondaryButton(
                      label: 'Venue Map',
                      height: 46,
                      fullWidth: false,
                      icon: const Icon(
                        Icons.map_outlined,
                        size: 17,
                        color: SpatiallyColors.spatialCyan,
                      ),
                      onPressed: onNavigateToMap,
                    )
                  else
                    SpatiallySecondaryButton(
                      label: 'Details',
                      height: 46,
                      fullWidth: false,
                      icon: const Icon(Icons.info_outline_rounded, size: 17),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const EventListScreen(),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCrowdWidget(Color textSecondary) {
    final state = crowdState;
    if (state == null || state.freshness == SpatialCrowdFreshness.unavailable) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 13,
            color: textSecondary,
          ),
          const SizedBox(width: 5),
          Text(
            'Crowd unavailable',
            style: SpatiallyTypography.caption(color: textSecondary),
          ),
        ],
      );
    }

    String labelText;
    switch (state.freshness) {
      case SpatialCrowdFreshness.live:
        labelText = 'Live';
        break;
      case SpatialCrowdFreshness.recent:
        labelText = 'Recent';
        break;
      case SpatialCrowdFreshness.stale:
        labelText = 'Stale';
        break;
      case SpatialCrowdFreshness.unavailable:
        labelText = 'Crowd unavailable';
        break;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SpatiallyCrowdIndicator(
          level: state.crowdLevel,
          compact: true,
        ),
        const SizedBox(width: 6),
        Text(
          labelText,
          style: SpatiallyTypography.caption(color: textSecondary),
        ),
      ],
    );
  }
}

/// Animated pulsing dot for live state.
class _LivePulseDot extends StatefulWidget {
  @override
  State<_LivePulseDot> createState() => _LivePulseDotState();
}

class _LivePulseDotState extends State<_LivePulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _opacityAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: false);
    _scaleAnim = Tween<double>(begin: 1.0, end: 2.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _opacityAnim = Tween<double>(begin: 0.6, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 12,
      height: 12,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: _scaleAnim.value,
                child: Opacity(
                  opacity: _opacityAnim.value,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: SpatiallyColors.success,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: SpatiallyColors.success,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
