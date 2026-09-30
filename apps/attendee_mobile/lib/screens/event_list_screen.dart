import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../design_system/design_system.dart';
import '../features/explore/event_detail_screen.dart';
import '../features/explore/models/spatially_event.dart';
import '../utils/date_formatter.dart';
import 'my_tickets_screen.dart';

/// Spatially Attendee Event List Screen.
/// 
/// Modernized catalog view listing active and upcoming events with Spatially
/// design tokens, clean cards, and direct navigation to EventDetailScreen.
class EventListScreen extends StatefulWidget {
  const EventListScreen({super.key});

  @override
  State<EventListScreen> createState() => _EventListScreenState();
}

class _EventListScreenState extends State<EventListScreen> {
  bool _loading = true;
  String? _error;
  List<SpatiallyEvent> _events = [];

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await Supabase.instance.client
          .from('events')
          .select()
          .inFilter('status', ['upcoming', 'live'])
          .order('event_date', ascending: true);

      final list = (response as List)
          .map((row) => SpatiallyEvent.fromJson(Map<String, dynamic>.from(row)))
          .toList();

      if (mounted) {
        setState(() {
          _events = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Unable to load event catalog: $e';
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
      appBar: SpatiallyAppBar(
        title: 'Event Catalog',
        automaticallyImplyLeading: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.confirmation_number_rounded),
            tooltip: 'My Tickets',
            color: SpatiallyColors.violet,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MyTicketsScreen()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadEvents,
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
        child: SpatiallyLoadingState(message: 'Loading events catalog...'),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: SpatiallySpacing.screenPadding,
          child: SpatiallyErrorState(
            error: _error!,
            onRetry: _loadEvents,
          ),
        ),
      );
    }

    if (_events.isEmpty) {
      return const Center(
        child: Padding(
          padding: SpatiallySpacing.screenPadding,
          child: SpatiallyEmptyState(
            title: 'No Events Found',
            description: 'There are no active or upcoming events available right now.',
            icon: Icons.event_busy_rounded,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: SpatiallySpacing.screenPadding,
      itemCount: _events.length,
      separatorBuilder: (context, index) => SpatiallySpacing.gapVerticalMd,
      itemBuilder: (context, index) {
        final event = _events[index];
        final dateTimeStr = SpatiallyDateFormatter.formatDateTime(event.eventDate);

        return SpatiallyCard(
          hasSubtleGlow: event.isLive,
          padding: const EdgeInsets.all(SpatiallySpacing.md),
          child: InkWell(
            borderRadius: SpatiallyRadius.borderMd,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => EventDetailScreen(event: event),
                ),
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    event.isLive
                        ? SpatiallyStatusBadge.live()
                        : SpatiallyStatusBadge.upcoming(),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: textSecondary,
                    ),
                  ],
                ),
                SpatiallySpacing.gapVerticalSm,
                Text(
                  event.name,
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
                        event.venue,
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
