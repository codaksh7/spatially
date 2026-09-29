import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../design_system/design_system.dart';
import '../../services/attendee_identity.dart';
import '../../services/auth_service.dart';
import '../../services/offline_service.dart';
import '../explore/data/event_cache_manager.dart';
import '../../screens/my_tickets_screen.dart';
import '../../screens/event_list_screen.dart';
import 'widgets/home_greeting.dart';
import 'widgets/event_hero.dart';
import 'widgets/home_beacon_status.dart';
import 'widgets/home_mini_map.dart';
import 'widgets/home_no_events.dart';
import 'widgets/home_up_next.dart';
import '../connect/connect_screen.dart';
import '../explore/models/spatially_event.dart';
import '../safety/safety_screen.dart';
import '../notifications/data/notification_repository.dart';
import '../notifications/models/notification_models.dart';
import '../notifications/notification_center_screen.dart';
import '../map/data/venue_map_repository.dart';
import '../map/data/supabase_venue_map_repository_impl.dart';
import '../map/models/venue_map_models.dart';
import '../event_content/data/event_content_repository.dart';
import '../event_content/models/spatially_session.dart';
import '../event_content/sessions/session_detail_screen.dart';

/// Spatially Attendee — Home Screen (Phase 3A & Phase 7C).
///
/// The attendee's personal event companion.
///
/// Adapts between two context states:
/// - Before event: Shows greeting, next upcoming event, quick actions.
/// - During event: Shows active event context, crowd state, mini-map, live agenda.
///
/// Uses real Supabase data:
/// - [events] table: status = 'upcoming' | 'live'
/// - [tickets] table: joined with events, for this attendee's device ID.
/// - [volunteer_counts] / [event_zones]: production spatial crowd telemetry.
/// - [sessions]: dynamic temporal status (Upcoming / Live / Completed).
///
/// Design: typography-first hierarchy, one dominant violet accent,
/// cyan for spatial context only, no card overload.
class HomeScreen extends StatefulWidget {
  final VoidCallback? onNavigateToExplore;
  final VoidCallback? onNavigateToMap;

  const HomeScreen({
    super.key,
    this.onNavigateToExplore,
    this.onNavigateToMap,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final NotificationRepository _notificationRepo = NotificationRepositoryImpl();
  final VenueMapRepository _venueMapRepo = SupabaseVenueMapRepositoryImpl();
  final EventContentRepository _contentRepo = EventContentRepositoryImpl();

  StreamSubscription? _authSub;
  Timer? _liveTicker;
  AppLifecycleListener? _lifecycleListener;

  bool _loading = true;
  String? _error;
  bool _isOfflineData = false;
  String? _lastSyncFormatted;

  /// The primary event for the home screen.
  /// Priority: live event with ticket → upcoming event with ticket → any live → any upcoming.
  Map<String, dynamic>? _primaryEvent;

  /// The attendee's ticket for the primary event (null if not ticketed).
  Map<String, dynamic>? _primaryTicket;

  /// Production spatial crowd telemetry for the primary event.
  SpatialCrowdState? _primaryCrowdState;

  /// Multi-level spatial snapshot for glanceable mini-map.
  SpatialMapSnapshot? _spatialSnapshot;

  /// Live or nearest upcoming session for the primary event.
  SpatiallySession? _activeSession;

  @override
  void initState() {
    super.initState();
    _loadData();
    _authSub = AuthService().onAuthStateChange.listen((_) {
      if (mounted) {
        _loadData();
      }
    });

    // 30-second live status ticker while Home is visible
    _liveTicker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && _primaryEvent != null) {
        final eventId = _primaryEvent!['id']?.toString();
        if (eventId != null) {
          _refreshLiveSessionState(eventId);
        }
      }
    });

    // Refresh on app foreground resume
    _lifecycleListener = AppLifecycleListener(
      onResume: () {
        if (mounted) {
          _loadData();
        }
      },
    );
  }

  @override
  void dispose() {
    _liveTicker?.cancel();
    _lifecycleListener?.dispose();
    _authSub?.cancel();
    _notificationRepo.unsubscribeRealtime();
    super.dispose();
  }

  void _refreshLiveSessionState(String eventId) {
    _contentRepo.getSessions(eventId).then((sessions) {
      if (mounted) {
        setState(() {
          _activeSession = _findActiveOrNextSession(sessions);
        });
      }
    }).catchError((_) {});
  }

  SpatiallySession? _findActiveOrNextSession(List<SpatiallySession> sessions) {
    if (sessions.isEmpty) return null;
    for (final s in sessions) {
      if (s.status == SpatiallySessionStatus.live) return s;
    }
    for (final s in sessions) {
      if (s.status == SpatiallySessionStatus.upcoming) return s;
    }
    return null;
  }

  Future<void> _loadData() async {
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

      final attendeeId = AttendeeIdentity.deviceId;
      final user = Supabase.instance.client.auth.currentUser;

      // 1. Fetch attendee's tickets joined with events (upcoming + live)
      List<Map<String, dynamic>> ticketsWithEvents = [];
      if (user != null) {
        final result = await Supabase.instance.client
            .from('tickets')
            .select('*, events(*)')
            .eq('user_id', user.id)
            .timeout(const Duration(seconds: 4));
        ticketsWithEvents = List<Map<String, dynamic>>.from(result);
      } else if (attendeeId != null) {
        final result = await Supabase.instance.client
            .from('tickets')
            .select('*, events(*)')
            .eq('attendee_id', attendeeId)
            .isFilter('user_id', null)
            .timeout(const Duration(seconds: 4));
        ticketsWithEvents = List<Map<String, dynamic>>.from(result);
      }

      // 2. Filter to tickets that actually have valid event data
      final validTickets = ticketsWithEvents.where((t) {
        final e = t['events'] as Map<String, dynamic>?;
        return e != null && e['status'] != null;
      }).toList();

      Map<String, dynamic>? bestEvent;
      Map<String, dynamic>? bestTicket;

      // Priority: live event first, then soonest upcoming
      final liveTicket = validTickets.cast<Map<String, dynamic>?>().firstWhere(
        (t) => (t!['events'] as Map<String, dynamic>)['status'] == 'live',
        orElse: () => null,
      );

      if (liveTicket != null) {
        bestEvent = liveTicket['events'] as Map<String, dynamic>;
        bestTicket = liveTicket;
      } else if (validTickets.isNotEmpty) {
        // Sort by event_date ascending
        validTickets.sort((a, b) {
          final da = DateTime.tryParse(
                  (a['events'] as Map<String, dynamic>)['event_date'] as String? ?? '') ??
              DateTime.now();
          final db = DateTime.tryParse(
                  (b['events'] as Map<String, dynamic>)['event_date'] as String? ?? '') ??
              DateTime.now();
          return da.compareTo(db);
        });
        bestEvent = validTickets.first['events'] as Map<String, dynamic>;
        bestTicket = validTickets.first;
      }

      // 3. Fallback: if no ticket, look for any live/upcoming event
      if (bestEvent == null) {
        final events = await Supabase.instance.client
            .from('events')
            .select()
            .inFilter('status', ['live', 'upcoming'])
            .order('event_date', ascending: true)
            .limit(1)
            .timeout(const Duration(seconds: 4));

        if (events.isNotEmpty) {
          bestEvent = Map<String, dynamic>.from(events.first);
        }
      }

      OfflineService().reportSuccessfulOnlineRequest();

      SpatialMapSnapshot? snapshot;
      SpatialCrowdState? crowdState;
      SpatiallySession? activeSession;

      // Persist in local cache for offline resilience partitioned by user
      if (bestEvent != null) {
        await EventCacheManager().cachePrimaryContext(
          event: bestEvent,
          ticket: bestTicket,
          userId: user?.id,
        );

        final eventId = bestEvent['id']?.toString();
        if (eventId != null) {
          _notificationRepo.subscribeToRealtime(eventId);

          try {
            snapshot = await _venueMapRepo.getMapSnapshot(eventId);
            if (snapshot.crowdStates.isNotEmpty) {
              SpatialCrowdState? topCrowd;
              for (final cs in snapshot.crowdStates.values) {
                if (topCrowd == null || cs.activeCount > topCrowd.activeCount) {
                  topCrowd = cs;
                }
              }
              crowdState = topCrowd;
            } else {
              crowdState = const SpatialCrowdState(
                zoneCode: '',
                activeCount: 0,
                crowdLevel: SpatiallyCrowdLevel.low,
                freshness: SpatialCrowdFreshness.unavailable,
              );
            }
          } catch (_) {
            crowdState = const SpatialCrowdState(
              zoneCode: '',
              activeCount: 0,
              crowdLevel: SpatiallyCrowdLevel.low,
              freshness: SpatialCrowdFreshness.unavailable,
            );
          }

          try {
            final sessions = await _contentRepo.getSessions(eventId);
            activeSession = _findActiveOrNextSession(sessions);
          } catch (_) {}
        }
      }

      if (mounted) {
        setState(() {
          _primaryEvent = bestEvent;
          _primaryTicket = bestTicket;
          _spatialSnapshot = snapshot;
          _primaryCrowdState = crowdState;
          _activeSession = activeSession;
          _isOfflineData = false;
          _loading = false;
        });
      }
    } catch (_) {
      OfflineService().reportFailedNetworkRequest();
      await _loadFromCache();
    }
  }

  Future<void> _loadFromCache() async {
    final user = Supabase.instance.client.auth.currentUser;
    final cachedEvent = await EventCacheManager().getCachedPrimaryEvent();
    final cachedTicket = await EventCacheManager().getCachedPrimaryTicket(userId: user?.id);
    final lastSync = await EventCacheManager().getLastSyncTime();

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
      if (cachedEvent != null) {
        final eventId = cachedEvent['id']?.toString();
        SpatialMapSnapshot? snapshot;
        SpatiallySession? activeSession;
        if (eventId != null) {
          try {
            snapshot = await _venueMapRepo.getMapSnapshot(eventId);
          } catch (_) {}
          try {
            final sessions = await _contentRepo.getSessions(eventId);
            activeSession = _findActiveOrNextSession(sessions);
          } catch (_) {}
        }

        setState(() {
          _primaryEvent = cachedEvent;
          _primaryTicket = cachedTicket;
          _spatialSnapshot = snapshot;
          _activeSession = activeSession;
          _primaryCrowdState = const SpatialCrowdState(
            zoneCode: '',
            activeCount: 0,
            crowdLevel: SpatiallyCrowdLevel.low,
            freshness: SpatialCrowdFreshness.unavailable,
          );
          _isOfflineData = true;
          _lastSyncFormatted = syncStr;
          _loading = false;
          _error = null;
        });
      } else {
        setState(() {
          _error = 'Offline. No cached event found. Please check connection.';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final background =
        isDark ? SpatiallyColors.darkBackground : SpatiallyColors.lightBackground;

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: SpatiallyColors.violet,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: StreamBuilder<int>(
                    stream: _notificationRepo.observeUnreadCount(),
                    builder: (context, snapshot) {
                      final unreadCount = snapshot.data ?? 0;
                      return HomeGreeting(
                        hasTickets: _primaryTicket != null,
                        unreadNotificationsCount: unreadCount,
                        onNotificationsTap: () {
                          final eventObj = _primaryEvent != null
                              ? SpatiallyEvent.fromJson(_primaryEvent!)
                              : null;
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => NotificationCenterScreen(event: eventObj),
                            ),
                          );
                        },
                        onTicketsTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const MyTicketsScreen(),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),

              // Main body
              SliverToBoxAdapter(
                child: _buildBody(context, isDark),
              ),

              // Bottom breathing room
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, bool isDark) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 80),
        child: Center(
          child: SpatiallyLoadingState(
            message: 'Loading your event…',
          ),
        ),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: SpatiallyErrorState(
          error: 'Could not load event data.',
          onRetry: _loadData,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Offline Status Banner ---
          if (_isOfflineData || !OfflineService().isOnline)
            SpatiallyOfflineBanner(
              syncTime: _lastSyncFormatted,
              onRetry: _loadData,
            ),

          // --- Contextual High-Value Notification Preview ---
          StreamBuilder<List<NotificationItem>>(
            stream: _notificationRepo.observeNotifications(),
            builder: (context, snapshot) {
              final notifs = snapshot.data ?? [];
              final urgent = notifs.where((n) => !n.isRead && n.priority.isHighOrUrgent).toList();
              if (urgent.isEmpty) return const SizedBox.shrink();

              final topNotice = urgent.first;
              return Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: _HomeContextualNotificationCard(
                  notification: topNotice,
                  onTap: () async {
                    await _notificationRepo.markAsRead(topNotice.id);
                    if (!context.mounted) return;
                    final eventObj = _primaryEvent != null
                        ? SpatiallyEvent.fromJson(_primaryEvent!)
                        : null;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => NotificationCenterScreen(event: eventObj),
                      ),
                    );
                  },
                  onDismiss: () => _notificationRepo.dismissNotification(topNotice.id),
                ),
              );
            },
          ),

          // --- Primary Event Hero or No Events state ---
          if (_primaryEvent != null)
            EventHero(
              event: _primaryEvent!,
              ticket: _primaryTicket,
              onNavigateToMap: widget.onNavigateToMap,
              crowdState: _primaryCrowdState,
            )
          else
            const HomeNoEvents(),

          // --- Live / Next Session Card ---
          if (_primaryEvent != null && _activeSession != null) ...[
            const SizedBox(height: 24),
            _SectionLabel(
              label: _activeSession!.status == SpatiallySessionStatus.live
                  ? 'HAPPENING NOW'
                  : 'NEXT SESSION',
              isDark: isDark,
            ),
            const SizedBox(height: 12),
            _HomeSessionCard(
              session: _activeSession!,
              onTap: () {
                final eventObj = SpatiallyEvent.fromJson(_primaryEvent!);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SessionDetailScreen(
                      session: _activeSession!,
                      event: eventObj,
                    ),
                  ),
                );
              },
            ),
          ],

          const SizedBox(height: 32),

          // --- Divider section heading: Venue Map ---
          _SectionLabel(
            label: 'VENUE MAP',
            isDark: isDark,
          ),
          const SizedBox(height: 12),

          // --- Glanceable Mini-Map ---
          HomeMiniMap(
            onTap: widget.onNavigateToMap,
            activeZone: null,
            snapshot: _spatialSnapshot,
          ),

          const SizedBox(height: 32),

          // --- Spatial Beacon status (live BLE state) ---
          const HomeBeaconStatus(),

          const SizedBox(height: 32),

          // --- Contextual Event Connect Card ---
          if (_primaryEvent != null) ...[
            _SectionLabel(
              label: 'EVENT CONNECT',
              isDark: isDark,
            ),
            const SizedBox(height: 12),
            SpatiallyCard(
              padding: const EdgeInsets.all(SpatiallySpacing.md),
              child: InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ConnectScreen(
                        eventId: _primaryEvent?['id']?.toString(),
                        eventName: _primaryEvent?['name']?.toString(),
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(SpatiallyRadius.md),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: SpatiallyColors.violet.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(SpatiallyRadius.md),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.hub_outlined,
                          color: SpatiallyColors.violet,
                          size: 24,
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
                              Text(
                                'Attendee Connect',
                                style: SpatiallyTypography.subheading(
                                  color: isDark ? SpatiallyColors.darkTextPrimary : SpatiallyColors.lightTextPrimary,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: SpatiallyColors.spatialCyan.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(SpatiallyRadius.full),
                                ),
                                child: Text(
                                  'Ready to Chat',
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
                            'Meet attendees, match interests & coordinate meeting points',
                            style: SpatiallyTypography.caption(
                              color: isDark ? SpatiallyColors.darkTextSecondary : SpatiallyColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // --- Contextual Safety & Help Card ---
            _SectionLabel(
              label: 'SAFETY & VENUE HELP',
              isDark: isDark,
            ),
            const SizedBox(height: 12),
            SpatiallyCard(
              padding: const EdgeInsets.all(SpatiallySpacing.md),
              child: InkWell(
                onTap: () {
                  final eventObj = _primaryEvent != null
                      ? SpatiallyEvent.fromJson(_primaryEvent!)
                      : null;
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SafetyScreen(event: eventObj),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(SpatiallyRadius.md),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: SpatiallyColors.error.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(SpatiallyRadius.md),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.health_and_safety_outlined,
                          color: SpatiallyColors.error,
                          size: 24,
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
                              Text(
                                'Safety & Venue Help',
                                style: SpatiallyTypography.subheading(
                                  color: isDark ? SpatiallyColors.darkTextPrimary : SpatiallyColors.lightTextPrimary,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: SpatiallyColors.error.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(SpatiallyRadius.full),
                                ),
                                child: Text(
                                  'First Aid • Exits',
                                  style: SpatiallyTypography.caption(color: SpatiallyColors.error).copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SpatiallySpacing.gapVerticalXxs,
                          Text(
                            'First aid, security, emergency exits & lost property desk',
                            style: SpatiallyTypography.caption(
                              color: isDark ? SpatiallyColors.darkTextSecondary : SpatiallyColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],

          // --- Up Next section (shown only for upcoming — not live — events with a ticket) ---
          if (_primaryEvent != null &&
              _primaryEvent!['status'] == 'upcoming' &&
              _primaryTicket != null) ...[
            const SizedBox(height: 0), // beacon already added spacing above
            HomeUpNext(
              event: _primaryEvent!,
              ticket: _primaryTicket,
            ),
            const SizedBox(height: 32),
          ],

          // --- Browse events link (subtle secondary action) ---
          if (_primaryEvent != null)
            Center(
              child: GestureDetector(
                onTap: () {
                  if (widget.onNavigateToExplore != null) {
                    widget.onNavigateToExplore!();
                  } else {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const EventListScreen(),
                      ),
                    );
                  }
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Browse all events',
                      style: SpatiallyTypography.secondaryMedium(
                        color: SpatiallyColors.violet,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 14,
                      color: SpatiallyColors.violet,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Tiny capsule section label — keeps visual weight low.
class _SectionLabel extends StatelessWidget {
  final String label;
  final bool isDark;

  const _SectionLabel({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final textSecondary =
        isDark ? SpatiallyColors.darkTextSecondary : SpatiallyColors.lightTextSecondary;

    return Text(
      label,
      style: SpatiallyTypography.badge(color: textSecondary).copyWith(
        fontSize: 11,
        letterSpacing: 0.8,
      ),
    );
  }
}

/// Subtle high-value notification card rendered on Home for active high/urgent alerts.
class _HomeContextualNotificationCard extends StatelessWidget {
  final NotificationItem notification;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _HomeContextualNotificationCard({
    required this.notification,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = isDark ? SpatiallyColors.darkTextPrimary : SpatiallyColors.lightTextPrimary;
    final textSecondary = isDark ? SpatiallyColors.darkTextSecondary : SpatiallyColors.lightTextSecondary;

    final color = notification.category.color;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? SpatiallyColors.darkSurface : SpatiallyColors.lightSurface,
        borderRadius: BorderRadius.circular(SpatiallyRadius.md),
        border: Border.all(
          color: color.withValues(alpha: 0.35),
          width: 1,
        ),
        boxShadow: SpatiallyShadows.cardShadow(isDark: isDark),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(SpatiallyRadius.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(SpatiallyRadius.md),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(SpatiallyRadius.sm),
                  ),
                  child: Center(
                    child: Icon(
                      notification.category.icon,
                      color: color,
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: SpatiallyTypography.body(color: textPrimary).copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          if (notification.priority == NotificationPriority.urgent)
                            const SpatiallyStatusBadge(
                              label: 'NOTICE',
                              variant: SpatiallyBadgeVariant.custom,
                              customColor: SpatiallyColors.error,
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        notification.body,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SpatiallyTypography.caption(color: textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: textSecondary,
                  ),
                  onPressed: onDismiss,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  tooltip: 'Dismiss',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Lightweight, glanceable card for Home screen displaying active or next session.
class _HomeSessionCard extends StatelessWidget {
  final SpatiallySession session;
  final VoidCallback onTap;

  const _HomeSessionCard({
    required this.session,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isLive = session.status == SpatiallySessionStatus.live;

    final badgeColor = isLive ? SpatiallyColors.success : SpatiallyColors.violet;
    final badgeBg = badgeColor.withValues(alpha: 0.12);
    final badgeText = isLive ? 'LIVE NOW' : 'STARTS ${session.formattedStartTime}';

    return SpatiallyCard(
      padding: const EdgeInsets.all(SpatiallySpacing.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SpatiallyRadius.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: SpatiallyRadius.borderXs,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isLive) ...[
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: SpatiallyColors.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                      ],
                      Text(
                        badgeText,
                        style: SpatiallyTypography.badge(color: badgeColor).copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  '${session.durationMinutes} min',
                  style: SpatiallyTypography.caption(
                    color: isDark ? SpatiallyColors.darkTextSecondary : SpatiallyColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
            SpatiallySpacing.gapVerticalSm,
            Text(
              session.title,
              style: SpatiallyTypography.subheading(
                color: isDark ? SpatiallyColors.darkTextPrimary : SpatiallyColors.lightTextPrimary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SpatiallySpacing.gapVerticalXs,
            Row(
              children: [
                Icon(
                  Icons.person_outline_rounded,
                  size: 14,
                  color: isDark ? SpatiallyColors.darkTextSecondary : SpatiallyColors.lightTextSecondary,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    session.speakerName,
                    style: SpatiallyTypography.secondary(
                      color: isDark ? SpatiallyColors.darkTextSecondary : SpatiallyColors.lightTextSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (session.location.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.location_on_outlined,
                    size: 14,
                    color: SpatiallyColors.spatialCyan,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    session.location,
                    style: SpatiallyTypography.caption(
                      color: SpatiallyColors.spatialCyan,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}



