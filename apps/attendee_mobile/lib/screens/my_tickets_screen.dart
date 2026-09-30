import 'dart:async';
import 'package:flutter/material.dart';

import '../design_system/design_system.dart';
import '../features/tickets/data/ticket_repository.dart';
import '../services/auth_service.dart';
import '../services/offline_service.dart';
import '../utils/date_formatter.dart';
import 'ticket_detail_screen.dart';

/// Spatially Attendee My Tickets Screen.
/// 
/// Modernized view displaying the attendee's active admission passes with
/// design tokens, clean card presentation, and direct ticket QR access.
///
/// Supports dual-ownership:
/// - Authenticated users view tickets where user_id = auth.uid()
/// - Guests view tickets where attendee_id = deviceId and user_id IS NULL
class MyTicketsScreen extends StatefulWidget {
  const MyTicketsScreen({super.key});

  @override
  State<MyTicketsScreen> createState() => _MyTicketsScreenState();
}

class _MyTicketsScreenState extends State<MyTicketsScreen> {
  final TicketRepository _ticketRepository = TicketRepositoryImpl();
  StreamSubscription? _authSub;

  bool _loading = true;
  String? _error;
  bool _isOffline = false;
  List<Map<String, dynamic>> _tickets = [];

  @override
  void initState() {
    super.initState();
    _loadTickets();
    _authSub = AuthService().onAuthStateChange.listen((_) {
      if (mounted) {
        _loadTickets();
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _loadTickets() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final ticketsList = await _ticketRepository.getMyTickets();
      if (mounted) {
        setState(() {
          _tickets = ticketsList;
          _isOffline = !OfflineService().isOnline;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load tickets. Please try again.';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = isDark ? SpatiallyColors.darkTextPrimary : SpatiallyColors.lightTextPrimary;
    final textSecondary = isDark ? SpatiallyColors.darkTextSecondary : SpatiallyColors.lightTextSecondary;

    return Scaffold(
      appBar: const SpatiallyAppBar(
        title: 'My Tickets',
        automaticallyImplyLeading: true,
      ),
      body: RefreshIndicator(
        onRefresh: _loadTickets,
        color: SpatiallyColors.violet,
        child: _buildBody(textPrimary: textPrimary, textSecondary: textSecondary),
      ),
    );
  }

  Widget _buildBody({
    required Color textPrimary,
    required Color textSecondary,
  }) {
    if (_loading) {
      return const Center(
        child: SpatiallyLoadingState(message: 'Loading admission passes...'),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: SpatiallySpacing.screenPadding,
          child: SpatiallyErrorState(
            error: _error!,
            onRetry: _loadTickets,
          ),
        ),
      );
    }

    if (_tickets.isEmpty) {
      return const Center(
        child: Padding(
          padding: SpatiallySpacing.screenPadding,
          child: SpatiallyEmptyState(
            title: 'No Tickets Found',
            description: 'You have not claimed any event admission passes yet.',
            icon: Icons.confirmation_number_outlined,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: SpatiallySpacing.screenPadding,
      itemCount: _tickets.length + (_isOffline ? 1 : 0),
      separatorBuilder: (context, index) => SpatiallySpacing.gapVerticalMd,
      itemBuilder: (context, index) {
        if (_isOffline && index == 0) {
          return SpatiallyOfflineBanner(
            message: 'Offline Mode • Showing cached admission passes',
            onRetry: _loadTickets,
          );
        }
        final ticketIndex = _isOffline ? index - 1 : index;
        final ticket = _tickets[ticketIndex];
        final event = ticket['events'] as Map<String, dynamic>?;
        final eventName = event?['name']?.toString() ?? 'Unknown Event';
        final venue = event?['venue']?.toString() ?? 'TBA';
        final status = (ticket['status']?.toString() ?? 'purchased').toLowerCase();
        final isCheckedIn = status == 'checked_in';

        final dateTimeStr = SpatiallyDateFormatter.formatDateTime(event?['event_date']);

        return SpatiallyCard(
          hasSubtleGlow: !isCheckedIn,
          padding: const EdgeInsets.all(SpatiallySpacing.md),
          child: InkWell(
            borderRadius: SpatiallyRadius.borderMd,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TicketDetailScreen(ticket: ticket),
                ),
              ).then((_) => _loadTickets());
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isCheckedIn
                            ? SpatiallyColors.lightTextSecondary.withValues(alpha: 0.12)
                            : SpatiallyColors.success.withValues(alpha: 0.12),
                        borderRadius: SpatiallyRadius.borderFull,
                        border: Border.all(
                          color: isCheckedIn
                              ? SpatiallyColors.lightTextSecondary.withValues(alpha: 0.3)
                              : SpatiallyColors.success.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        isCheckedIn ? 'CHECKED IN' : 'VALID PASS',
                        style: SpatiallyTypography.badge(
                          color: isCheckedIn ? SpatiallyColors.lightTextSecondary : SpatiallyColors.success,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.qr_code_rounded,
                      size: 20,
                      color: SpatiallyColors.violet,
                    ),
                  ],
                ),
                SpatiallySpacing.gapVerticalSm,
                Text(
                  eventName,
                  style: SpatiallyTypography.subheading(color: textPrimary),
                ),
                SpatiallySpacing.gapVerticalSm,
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      size: 15,
                      color: SpatiallyColors.spatialCyan,
                    ),
                    SpatiallySpacing.gapHorizontalXs,
                    Expanded(
                      child: Text(
                        venue,
                        style: SpatiallyTypography.caption(color: textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SpatiallySpacing.gapVerticalXs,
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_rounded,
                      size: 14,
                      color: SpatiallyColors.violet,
                    ),
                    SpatiallySpacing.gapHorizontalXs,
                    Expanded(
                      child: Text(
                        dateTimeStr,
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
        );
      },
    );
  }
}
