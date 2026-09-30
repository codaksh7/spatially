import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../design_system/design_system.dart';
import '../../services/attendee_identity.dart';
import '../../services/offline_service.dart';
import '../../utils/date_formatter.dart';
import 'data/event_cache_manager.dart';
import 'event_detail_screen.dart';
import 'models/spatially_event.dart';
import '../tickets/data/ticket_repository.dart';

/// Spatially Attendee Explore Screen.
/// 
/// Answers "What can I attend or explore?" by loading live and upcoming events
/// from Supabase, providing real-time search, event-agnostic filters, and
/// detailed event discovery cards.
class ExploreScreen extends StatefulWidget {
  final VoidCallback? onNavigateToMap;

  const ExploreScreen({
    super.key,
    this.onNavigateToMap,
  });

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  bool _loading = true;
  String? _error;
  bool _isOffline = false;
  String? _lastSyncFormatted;
  List<SpatiallyEvent> _allEvents = [];
  Set<String> _registeredEventIds = {};
  Map<String, String> _ticketStatusByEventId = {};

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _selectedFilterIndex = 0;

  static const List<String> _filters = [
    'All',
    'Live Now',
    'Upcoming',
    'My Tickets',
  ];

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final isOnline = await OfflineService().checkConnectivity();
      if (!isOnline) {
        await _loadFromCache();
        return;
      }

      // 1. Fetch active and upcoming events
      final eventsData = await Supabase.instance.client
          .from('events')
          .select()
          .inFilter('status', ['live', 'upcoming'])
          .order('event_date', ascending: true)
          .timeout(const Duration(seconds: 4));

      final eventsList = (eventsData as List)
          .map((row) => SpatiallyEvent.fromJson(Map<String, dynamic>.from(row)))
          .toList();

      // 2. Fetch attendee's tickets with check-in status
      final registeredIds = <String>{};
      final ticketStatusMap = <String, String>{};
      try {
        final myTickets = await TicketRepositoryImpl().getMyTickets();
        for (final t in myTickets) {
          final eventId = t['event_id']?.toString();
          final status = t['status']?.toString().toLowerCase() ?? 'valid';
          if (eventId != null && eventId.isNotEmpty) {
            registeredIds.add(eventId);
            ticketStatusMap[eventId] = status;
          }
        }
      } catch (e) {
        debugPrint('Explore: Error fetching ticket status: $e');
      }

      // Cache events locally
      await EventCacheManager().cacheExploreEvents(eventsList);
      OfflineService().reportSuccessfulOnlineRequest();

      if (mounted) {
        setState(() {
          _allEvents = eventsList;
          _registeredEventIds = registeredIds;
          _ticketStatusByEventId = ticketStatusMap;
          _isOffline = false;
          _loading = false;
        });
      }
    } catch (_) {
      OfflineService().reportFailedNetworkRequest();
      await _loadFromCache();
    }
  }

  Future<void> _loadFromCache() async {
    final cached = await EventCacheManager().getCachedExploreEvents();
    final lastSync = await EventCacheManager().getLastSyncTime();

    final registeredIds = <String>{};
    final ticketStatusMap = <String, String>{};
    try {
      final myTickets = await TicketRepositoryImpl().getMyTickets();
      for (final t in myTickets) {
        final eventId = t['event_id']?.toString();
        final status = t['status']?.toString().toLowerCase() ?? 'valid';
        if (eventId != null && eventId.isNotEmpty) {
          registeredIds.add(eventId);
          ticketStatusMap[eventId] = status;
        }
      }
    } catch (_) {}

    String? syncStr;
    if (lastSync != null) {
      final diff = DateTime.now().difference(lastSync);
      if (diff.inMinutes < 1) {
        syncStr = 'Last synced just now';
      } else if (diff.inMinutes < 60) {
        syncStr = 'Last synced ${diff.inMinutes}m ago';
      } else if (diff.inHours < 24) {
        syncStr = 'Last synced ${diff.inHours}h ago';
      } else {
        syncStr = 'Last synced ${diff.inDays}d ago';
      }
    }

    if (mounted) {
      if (cached.isNotEmpty) {
        setState(() {
          _allEvents = cached;
          _registeredEventIds = registeredIds;
          _ticketStatusByEventId = ticketStatusMap;
          _isOffline = true;
          _lastSyncFormatted = syncStr;
          _loading = false;
          _error = null;
        });
      } else {
        setState(() {
          _error = 'Offline. No cached events found. Please check connection.';
          _loading = false;
        });
      }
    }
  }

  List<SpatiallyEvent> get _filteredEvents {
    return _allEvents.where((event) {
      // 1. Search Query Filter
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchesName = event.name.toLowerCase().contains(q);
        final matchesVenue = event.venue.toLowerCase().contains(q);
        final matchesAddress = event.locationAddress.toLowerCase().contains(q);
        if (!matchesName && !matchesVenue && !matchesAddress) {
          return false;
        }
      }

      // 2. Status / Registration Filter
      switch (_selectedFilterIndex) {
        case 1: // Live Now
          return event.isLive;
        case 2: // Upcoming
          return event.isUpcoming;
        case 3: // My Tickets / Registered
          return _registeredEventIds.contains(event.id);
        case 0: // All
        default:
          return true;
      }
    }).toList();
  }

  void _clearSearchAndFilter() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _selectedFilterIndex = 0;
    });
  }

  Future<void> _openEventDetails(SpatiallyEvent event) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EventDetailScreen(
          event: event,
          onNavigateToMap: widget.onNavigateToMap,
        ),
      ),
    );

    // Refresh tickets in case the user registered inside EventDetailScreen
    if (mounted) {
      final attendeeId = AttendeeIdentity.deviceId;
      if (attendeeId != null) {
        try {
          final ticketsData = await Supabase.instance.client
              .from('tickets')
              .select('event_id')
              .eq('attendee_id', attendeeId);

          final updatedIds = <String>{};
          for (final row in ticketsData as List) {
            final eventId = row['event_id']?.toString();
            if (eventId != null && eventId.isNotEmpty) {
              updatedIds.add(eventId);
            }
          }
          if (mounted) {
            setState(() {
              _registeredEventIds = updatedIds;
            });
          }
        } catch (_) {}
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = isDark ? SpatiallyColors.darkTextPrimary : SpatiallyColors.lightTextPrimary;
    final textSecondary = isDark ? SpatiallyColors.darkTextSecondary : SpatiallyColors.lightTextSecondary;
    final surfaceColor = isDark ? SpatiallyColors.darkSurface : SpatiallyColors.lightSurface;
    final borderColor = isDark ? SpatiallyColors.darkBorderSubdued : SpatiallyColors.lightBorderSubdued;

    return Scaffold(
      appBar: const SpatiallyAppBar(
        title: 'Explore',
        automaticallyImplyLeading: false,
      ),
      body: RefreshIndicator(
        onRefresh: _loadEvents,
        color: SpatiallyColors.violet,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: SpatiallySpacing.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Functional Search Bar
              Container(
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: SpatiallyRadius.borderSm,
                  border: Border.all(color: borderColor),
                  boxShadow: SpatiallyShadows.cardShadow(isDark: isDark),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.trim();
                    });
                  },
                  style: SpatiallyTypography.body(color: textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Search events or venues...',
                    hintStyle: SpatiallyTypography.body(color: textSecondary),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: SpatiallyColors.violet,
                      size: 22,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.close_rounded,
                              color: textSecondary,
                              size: 18,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ),

              SpatiallySpacing.gapVerticalMd,

              // 2. Event-Agnostic Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(_filters.length, (index) {
                    final label = _filters[index];
                    final isSelected = _selectedFilterIndex == index;
                    return Padding(
                      padding: const EdgeInsets.only(right: SpatiallySpacing.xs),
                      child: SpatiallyCategoryChip(
                        label: label,
                        isSelected: isSelected,
                        onTap: () {
                          setState(() {
                            _selectedFilterIndex = index;
                          });
                        },
                      ),
                    );
                  }),
                ),
              ),

              if (_isOffline || !OfflineService().isOnline) ...[
                SpatiallySpacing.gapVerticalMd,
                SpatiallyOfflineBanner(
                  message: 'Offline Mode • Showing cached events',
                  syncTime: _lastSyncFormatted,
                  onRetry: _loadEvents,
                ),
              ],

              SpatiallySpacing.gapVerticalXxl,

              // 3. Section Header with Result Count
              if (!_loading && _error == null) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _selectedFilterIndex == 3
                          ? 'MY TICKETS'
                          : _selectedFilterIndex == 1
                              ? 'LIVE NOW'
                              : 'EVENTS CATALOG',
                      style: SpatiallyTypography.badge(color: textSecondary),
                    ),
                    Text(
                      '${_filteredEvents.length} ${_filteredEvents.length == 1 ? 'event' : 'events'}',
                      style: SpatiallyTypography.caption(color: textSecondary),
                    ),
                  ],
                ),
                SpatiallySpacing.gapVerticalSm,
              ],

              // 4. Content Area
              _buildContent(textPrimary: textPrimary, textSecondary: textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent({
    required Color textPrimary,
    required Color textSecondary,
  }) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60.0),
        child: SpatiallyLoadingState(message: 'Discovering live events...'),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40.0),
        child: SpatiallyErrorState(
          error: _error!,
          onRetry: _loadEvents,
        ),
      );
    }

    if (_allEvents.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40.0),
        child: SpatiallyEmptyState(
          title: 'No Events Available',
          description: 'There are no active or upcoming events scheduled at this time.',
          icon: Icons.event_busy_rounded,
        ),
      );
    }

    final events = _filteredEvents;

    if (events.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40.0),
        child: SpatiallyEmptyState(
          title: 'No Matching Events',
          description: 'No events match your search or filter selection.',
          icon: Icons.search_off_rounded,
          actionLabel: 'Reset Filters',
          onAction: _clearSearchAndFilter,
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: events.length,
      separatorBuilder: (context, index) => SpatiallySpacing.gapVerticalMd,
      itemBuilder: (context, index) {
        final event = events[index];
        final ticketStatus = _ticketStatusByEventId[event.id];
        final isRegistered = ticketStatus != null || _registeredEventIds.contains(event.id);
        final isCheckedIn = ticketStatus == 'checked_in';
        return _buildEventCard(
          event: event,
          isRegistered: isRegistered,
          isCheckedIn: isCheckedIn,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
        );
      },
    );
  }

  Widget _buildEventCard({
    required SpatiallyEvent event,
    required bool isRegistered,
    required bool isCheckedIn,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final dateTimeStr = SpatiallyDateFormatter.formatDateTime(event.eventDate);

    return SpatiallyCard(
      hasSubtleGlow: event.isLive,
      padding: const EdgeInsets.all(SpatiallySpacing.md),
      child: InkWell(
        borderRadius: SpatiallyRadius.borderMd,
        onTap: () => _openEventDetails(event),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Status Badge + Registered/Checked-in Tag
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                event.isLive
                    ? SpatiallyStatusBadge.live()
                    : SpatiallyStatusBadge.upcoming(),
                if (isRegistered)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isCheckedIn
                          ? SpatiallyColors.success.withValues(alpha: 0.12)
                          : SpatiallyColors.success.withValues(alpha: 0.12),
                      borderRadius: SpatiallyRadius.borderFull,
                      border: Border.all(
                        color: isCheckedIn
                            ? SpatiallyColors.success.withValues(alpha: 0.3)
                            : SpatiallyColors.success.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isCheckedIn ? Icons.verified_rounded : Icons.check_circle_rounded,
                          size: 12,
                          color: isCheckedIn ? SpatiallyColors.success : SpatiallyColors.success,
                        ),
                        SpatiallySpacing.gapHorizontalXs,
                        Text(
                          isCheckedIn ? 'CHECKED IN' : 'TICKET READY',
                          style: SpatiallyTypography.badge(
                            color: isCheckedIn ? SpatiallyColors.success : SpatiallyColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            SpatiallySpacing.gapVerticalSm,

            // Event Title
            Text(
              event.name,
              style: SpatiallyTypography.subheading(color: textPrimary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SpatiallySpacing.gapVerticalSm,

            // Location Row
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

            // Date / Time Row
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

            SpatiallySpacing.gapVerticalSm,

            // Action Row
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  isCheckedIn
                      ? 'Pass Active'
                      : (isRegistered ? 'View Pass' : 'View Details'),
                  style: SpatiallyTypography.secondary(
                    color: isCheckedIn ? SpatiallyColors.success : SpatiallyColors.violet,
                  ),
                ),
                SpatiallySpacing.gapHorizontalXs,
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 14,
                  color: isCheckedIn ? SpatiallyColors.success : SpatiallyColors.violet,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
