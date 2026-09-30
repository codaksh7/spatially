import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../design_system/design_system.dart';
import '../../services/attendee_identity.dart';
import '../../utils/date_formatter.dart';
import '../../screens/ticket_detail_screen.dart';
import '../map/map_screen.dart';
import '../connect/connect_screen.dart';
import '../safety/safety_screen.dart';
import 'models/spatially_event.dart';

// Event Content Hub imports (Phase 3D)
import '../event_content/data/event_content_repository.dart';
import '../event_content/models/spatially_session.dart';
import '../event_content/models/spatially_booth.dart';
import '../event_content/models/spatially_activity.dart';
import '../event_content/widgets/session_card.dart';
import '../event_content/sessions/sessions_screen.dart';
import '../event_content/sessions/session_detail_screen.dart';
import '../event_content/booths/booths_screen.dart';
import '../event_content/activities/activities_screen.dart';

/// Spatially Attendee Event Detail & Content Hub Screen.
/// 
/// The central overview hub for an event, exposing:
/// 1. Event Overview (Hero, Schedule, Venue, Zones, About, Admittance Pass)
/// 2. Clear, first-class entry points into dedicated experience directories:
///    - Sessions & Talks (SessionsScreen)
///    - Exhibition & Booths (BoothsScreen)
///    - Quests & Activities (ActivitiesScreen)
/// 3. Featured / Live Session preview card for immediate on-site utility.
class EventDetailScreen extends StatefulWidget {
  final SpatiallyEvent event;
  final VoidCallback? onNavigateToMap;

  const EventDetailScreen({
    super.key,
    required this.event,
    this.onNavigateToMap,
  });

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  final EventContentRepository _contentRepo = EventContentRepositoryImpl();

  bool _checkingTicket = true;
  bool _claimingTicket = false;
  Map<String, dynamic>? _existingTicket;
  String? _errorMessage;

  // Event content counts and previews
  bool _loadingContent = true;
  List<SpatiallySession> _sessions = [];
  List<SpatiallyBooth> _booths = [];
  List<SpatiallyActivity> _activities = [];

  Timer? _statusTicker;
  AppLifecycleListener? _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _checkExistingTicket();
    _loadEventContent();
    _statusTicker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
    _lifecycleListener = AppLifecycleListener(
      onResume: () {
        if (mounted) setState(() {});
      },
    );
  }

  @override
  void dispose() {
    _statusTicker?.cancel();
    _lifecycleListener?.dispose();
    super.dispose();
  }

  Future<void> _checkExistingTicket() async {
    final attendeeId = AttendeeIdentity.deviceId;
    if (attendeeId == null) {
      if (mounted) {
        setState(() {
          _checkingTicket = false;
        });
      }
      return;
    }

    try {
      final response = await Supabase.instance.client
          .from('tickets')
          .select('*, events(*)')
          .eq('event_id', widget.event.id)
          .eq('attendee_id', attendeeId)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _existingTicket = response;
          _checkingTicket = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _checkingTicket = false;
        });
      }
    }
  }

  Future<void> _loadEventContent() async {
    try {
      final sessions = await _contentRepo.getSessions(widget.event.id);
      final booths = await _contentRepo.getBooths(widget.event.id);
      final activities = await _contentRepo.getActivities(widget.event.id);

      if (mounted) {
        setState(() {
          _sessions = sessions;
          _booths = booths;
          _activities = activities;
          _loadingContent = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingContent = false;
        });
      }
    }
  }

  Future<void> _claimTicket() async {
    final attendeeId = AttendeeIdentity.deviceId;
    if (attendeeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Device ID not initialized. Please try again.')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final isDark = theme.brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? SpatiallyColors.darkSurface : SpatiallyColors.lightSurface,
          shape: const RoundedRectangleBorder(borderRadius: SpatiallyRadius.borderMd),
          title: Text(
            'Confirm Admission',
            style: SpatiallyTypography.sectionHeading(
              color: isDark ? SpatiallyColors.darkTextPrimary : SpatiallyColors.lightTextPrimary,
            ),
          ),
          content: Text(
            'Reserve an admission pass for "${widget.event.name}"?',
            style: SpatiallyTypography.body(
              color: isDark ? SpatiallyColors.darkTextSecondary : SpatiallyColors.lightTextSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'Cancel',
                style: SpatiallyTypography.body(
                  color: isDark ? SpatiallyColors.darkTextSecondary : SpatiallyColors.lightTextSecondary,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: SpatiallyColors.violet,
                foregroundColor: Colors.white,
                shape: const RoundedRectangleBorder(borderRadius: SpatiallyRadius.borderSm),
              ),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );

    if (confirm != true || !mounted) return;

    setState(() {
      _claimingTicket = true;
      _errorMessage = null;
    });

    try {
      final ticketCode = const Uuid().v4();
      final insertData = {
        'event_id': widget.event.id,
        'attendee_id': attendeeId,
        'ticket_code': ticketCode,
        'status': 'purchased',
      };

      await Supabase.instance.client.from('tickets').insert(insertData);

      final newTicket = await Supabase.instance.client
          .from('tickets')
          .select('*, events(*)')
          .eq('event_id', widget.event.id)
          .eq('attendee_id', attendeeId)
          .maybeSingle();

      if (!mounted) return;

      setState(() {
        _existingTicket = newTicket ?? {
          ...insertData,
          'events': widget.event.toJson(),
        };
        _claimingTicket = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Admission ticket confirmed for ${widget.event.name}!'),
          backgroundColor: SpatiallyColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _claimingTicket = false;
        _errorMessage = 'Failed to claim ticket: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error getting ticket: $e'),
          backgroundColor: SpatiallyColors.error,
        ),
      );
    }
  }

  void _openTicketPass() {
    if (_existingTicket == null) return;

    final ticketData = Map<String, dynamic>.from(_existingTicket!);
    if (ticketData['events'] == null) {
      ticketData['events'] = widget.event.toJson();
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TicketDetailScreen(ticket: ticketData),
      ),
    );
  }

  void _openVenueMap({String? zoneId, String? poiId}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MapScreen(
          initialEvent: widget.event,
          initialZoneId: zoneId,
          initialPoiId: poiId,
        ),
      ),
    );
  }

  void _openSessionsDirectory() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SessionsScreen(
          event: widget.event,
          eventId: widget.event.id,
          eventName: widget.event.name,
        ),
      ),
    );
  }

  void _openBoothsDirectory() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BoothsScreen(
          event: widget.event,
          eventId: widget.event.id,
          eventName: widget.event.name,
        ),
      ),
    );
  }

  void _openActivitiesDirectory() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ActivitiesScreen(
          event: widget.event,
          eventId: widget.event.id,
          eventName: widget.event.name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = isDark ? SpatiallyColors.darkTextPrimary : SpatiallyColors.lightTextPrimary;
    final textSecondary = isDark ? SpatiallyColors.darkTextSecondary : SpatiallyColors.lightTextSecondary;

    final event = widget.event;
    final hasTicket = _existingTicket != null;
    final dateTimeStr = SpatiallyDateFormatter.formatDateTime(event.eventDate, includeYear: true);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      appBar: SpatiallyAppBar(
        title: event.name,
        automaticallyImplyLeading: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.hub_outlined),
            tooltip: 'Event Connect',
            color: textSecondary,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ConnectScreen(event: widget.event),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.shield_outlined),
            tooltip: 'Safety & Help',
            color: textSecondary,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SafetyScreen(event: widget.event),
                ),
              );
            },
          ),
          if (hasTicket)
            IconButton(
              icon: const Icon(Icons.confirmation_number_outlined),
              tooltip: 'My Ticket Pass',
              color: textSecondary,
              onPressed: _openTicketPass,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: SpatiallySpacing.screenPadding.copyWith(
          bottom: SpatiallySpacing.screenPadding.bottom +
              bottomPadding +
              SpatiallySpacing.xxxl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Hero Event Card
            _buildHeroCard(isDark, textPrimary, textSecondary, hasTicket, dateTimeStr),
            SpatiallySpacing.gapVerticalLg,

            // 2. Event Experiences Entry Hub Card
            _buildExperiencesHub(isDark, textPrimary, textSecondary),
            SpatiallySpacing.gapVerticalLg,

            // 3. Featured / Live Session Preview (if sessions exist)
            if (_sessions.isNotEmpty) ...[
              _buildFeaturedSession(),
              SpatiallySpacing.gapVerticalLg,
            ],

            // 4. Event Zones
            if (event.zones.isNotEmpty) ...[
              _buildZonesSection(isDark, textSecondary),
              SpatiallySpacing.gapVerticalLg,
            ],

            // 5. About Description
            if (event.description.isNotEmpty) ...[
              _buildAboutSection(textPrimary),
              SpatiallySpacing.gapVerticalLg,
            ],

            // 6. Admittance Pass Action Card
            _buildTicketSection(isDark, textPrimary, textSecondary, hasTicket),

            if (_errorMessage != null) ...[
              SpatiallySpacing.gapVerticalSm,
              Text(
                _errorMessage!,
                style: SpatiallyTypography.caption(color: SpatiallyColors.error),
                textAlign: TextAlign.center,
              ),
            ],

            SpatiallySpacing.gapVerticalXl,
          ],
        ),
      ),
    );
  }

  /// 1. Hero Event Card
  Widget _buildHeroCard(
    bool isDark,
    Color textPrimary,
    Color textSecondary,
    bool hasTicket,
    String dateTimeStr,
  ) {
    final event = widget.event;

    return SpatiallyCard(
      hasSubtleGlow: event.isLive,
      padding: const EdgeInsets.all(SpatiallySpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status & Registration Tag Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              event.isLive ? SpatiallyStatusBadge.live() : SpatiallyStatusBadge.upcoming(),
              if (hasTicket)
                Container(
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
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 14,
                        color: SpatiallyColors.success,
                      ),
                      SpatiallySpacing.gapHorizontalXs,
                      Text(
                        'REGISTERED',
                        style: SpatiallyTypography.badge(color: SpatiallyColors.success),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          SpatiallySpacing.gapVerticalMd,

          // Event Title
          Text(
            event.name,
            style: SpatiallyTypography.headingLarge(color: textPrimary),
          ),
          SpatiallySpacing.gapVerticalLg,

          // Date & Time Row
          _buildDetailRow(
            icon: Icons.calendar_today_rounded,
            iconColor: SpatiallyColors.violet,
            title: 'Date & Time',
            content: dateTimeStr,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          SpatiallySpacing.gapVerticalMd,

          // Venue Row
          _buildDetailRow(
            icon: Icons.location_on_rounded,
            iconColor: SpatiallyColors.spatialCyan,
            title: 'Venue',
            content: event.venue,
            subtitle: event.locationAddress.isNotEmpty && event.locationAddress != event.venue
                ? event.locationAddress
                : null,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),

          if (event.organizerName.isNotEmpty) ...[
            SpatiallySpacing.gapVerticalMd,
            _buildDetailRow(
              icon: Icons.business_rounded,
              iconColor: SpatiallyColors.info,
              title: 'Organizer',
              content: event.organizerName,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
          ],

          if (event.capacity > 0) ...[
            SpatiallySpacing.gapVerticalMd,
            _buildDetailRow(
              icon: Icons.people_outline_rounded,
              iconColor: textSecondary,
              title: 'Capacity',
              content: '${event.capacity} Attendees maximum',
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
          ],
        ],
      ),
    );
  }

  /// 2. Event Experiences Entry Hub Card
  Widget _buildExperiencesHub(bool isDark, Color textPrimary, Color textSecondary) {
    final totalPoints = _activities.fold<int>(0, (sum, a) => sum + a.points);
    final hasLiveSession = _sessions.any((s) => s.status == SpatiallySessionStatus.live);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SpatiallySectionHeader(
          title: 'Event Experiences',
          subtitle: 'Explore sessions, exhibition booths, and quests',
        ),
        SpatiallySpacing.gapVerticalSm,
        SpatiallyCard(
          padding: const EdgeInsets.all(SpatiallySpacing.md),
          child: Column(
            children: [
              _buildExperienceTile(
                icon: Icons.campaign_rounded,
                iconColor: SpatiallyColors.violet,
                title: 'Sessions & Talks',
                subtitle: _loadingContent
                    ? 'Loading schedule...'
                    : _sessions.isNotEmpty
                        ? '${_sessions.length} Scheduled Sessions'
                        : 'Browse Schedule',
                badgeText: hasLiveSession ? 'LIVE NOW' : null,
                onTap: _openSessionsDirectory,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
              const Divider(height: SpatiallySpacing.md),
              _buildExperienceTile(
                icon: Icons.storefront_rounded,
                iconColor: SpatiallyColors.spatialCyan,
                title: 'Exhibition Floor & Booths',
                subtitle: _loadingContent
                    ? 'Loading booths...'
                    : _booths.isNotEmpty
                        ? '${_booths.length} Project Booths & Demos'
                        : 'Explore Exhibits',
                onTap: _openBoothsDirectory,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
              const Divider(height: SpatiallySpacing.md),
              _buildExperienceTile(
                icon: Icons.emoji_events_rounded,
                iconColor: SpatiallyColors.warning,
                title: 'Quests & Activities',
                subtitle: _loadingContent
                    ? 'Loading quests...'
                    : _activities.isNotEmpty
                        ? '${_activities.length} Quests • $totalPoints PTS'
                        : 'Earn Badges',
                onTap: _openActivitiesDirectory,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 3. Featured / Live Session Preview Card
  Widget _buildFeaturedSession() {
    SpatiallySession? featuredSession;
    // 1. Try to find a live session
    for (final s in _sessions) {
      if (s.status == SpatiallySessionStatus.live) {
        featuredSession = s;
        break;
      }
    }
    // 2. If no live session, find the soonest upcoming session
    if (featuredSession == null) {
      for (final s in _sessions) {
        if (s.status == SpatiallySessionStatus.upcoming) {
          featuredSession = s;
          break;
        }
      }
    }
    final session = featuredSession ?? _sessions.first;
    final isLive = session.status == SpatiallySessionStatus.live;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SpatiallySectionHeader(
              title: isLive ? 'Happening Now' : 'Featured Session',
              subtitle: isLive ? 'Live session in progress' : 'Upcoming keynote & talk',
            ),
            TextButton(
              onPressed: _openSessionsDirectory,
              child: Text(
                'View All (${_sessions.length})',
                style: SpatiallyTypography.caption(color: SpatiallyColors.violet)
                    .copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        SpatiallySpacing.gapVerticalSm,
        SessionCard(
          session: session,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SessionDetailScreen(
                  session: session,
                  event: widget.event,
                  onNavigateToMap: () => _openVenueMap(zoneId: session.zoneId, poiId: session.poiId),
                ),
              ),
            );
          },
          onMapTap: () => _openVenueMap(zoneId: session.zoneId, poiId: session.poiId),
        ),
      ],
    );
  }

  /// 4. Event Zones Section
  Widget _buildZonesSection(bool isDark, Color textSecondary) {
    final event = widget.event;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SpatiallySectionHeader(
          title: 'Event Zones',
          subtitle: 'Spatial areas configured for this event',
        ),
        SpatiallySpacing.gapVerticalSm,
        SpatiallyCard(
          padding: const EdgeInsets.all(SpatiallySpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: SpatiallySpacing.xs,
                runSpacing: SpatiallySpacing.xs,
                children: event.zones.map((zone) {
                  return InkWell(
                    onTap: () => _openVenueMap(zoneId: zone),
                    borderRadius: SpatiallyRadius.borderSm,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isDark
                            ? SpatiallyColors.darkSurfaceElevated
                            : SpatiallyColors.lightBorderSubdued,
                        borderRadius: SpatiallyRadius.borderSm,
                        border: Border.all(
                          color: isDark
                              ? SpatiallyColors.darkBorderSubdued
                              : SpatiallyColors.lightBorderSubdued,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_on_outlined, size: 12, color: SpatiallyColors.spatialCyan),
                          SpatiallySpacing.gapHorizontalXxs,
                          Text(
                            'Room $zone',
                            style: SpatiallyTypography.caption(color: textSecondary),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              SpatiallySpacing.gapVerticalMd,
              SizedBox(
                width: double.infinity,
                child: SpatiallySoftButton(
                  label: 'View on Venue Map',
                  icon: const Icon(Icons.map_rounded, size: 18, color: SpatiallyColors.violet),
                  onPressed: () => _openVenueMap(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 5. About the Event Section
  Widget _buildAboutSection(Color textPrimary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SpatiallySectionHeader(title: 'About the Event'),
        SpatiallySpacing.gapVerticalSm,
        SpatiallyCard(
          padding: const EdgeInsets.all(SpatiallySpacing.md),
          child: Text(
            widget.event.description,
            style: SpatiallyTypography.body(color: textPrimary),
          ),
        ),
      ],
    );
  }

  /// 6. Admittance Pass Action Card
  Widget _buildTicketSection(
    bool isDark,
    Color textPrimary,
    Color textSecondary,
    bool hasTicket,
  ) {
    final event = widget.event;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SpatiallySectionHeader(
          title: 'Admittance Pass',
          subtitle: 'Digital ticket verified at venue entry',
        ),
        SpatiallySpacing.gapVerticalSm,
        SpatiallyCard(
          padding: const EdgeInsets.all(SpatiallySpacing.lg),
          child: _checkingTicket
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: SpatiallySpacing.md),
                  child: SpatiallyLoadingState(message: 'Checking registration...'),
                )
              : hasTicket
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: SpatiallyColors.success.withValues(alpha: 0.12),
                                borderRadius: SpatiallyRadius.borderSm,
                              ),
                              child: const Icon(
                                Icons.confirmation_number_rounded,
                                color: SpatiallyColors.success,
                                size: 24,
                              ),
                            ),
                            SpatiallySpacing.gapHorizontalMd,
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Ticket Confirmed',
                                    style: SpatiallyTypography.subheading(color: textPrimary),
                                  ),
                                  Text(
                                    'Ready for contactless entry at the venue',
                                    style: SpatiallyTypography.secondary(color: textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SpatiallySpacing.gapVerticalLg,
                        SpatiallyPrimaryButton(
                          label: 'View Ticket Pass (QR)',
                          icon: const Icon(Icons.qr_code_rounded, color: Colors.white, size: 20),
                          onPressed: _openTicketPass,
                        ),
                      ],
                    )
                  : event.isEnded
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: SpatiallySpacing.sm),
                            child: Text(
                              'This event has concluded.',
                              style: SpatiallyTypography.secondary(color: textSecondary),
                            ),
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: SpatiallyColors.violet.withValues(alpha: 0.12),
                                    borderRadius: SpatiallyRadius.borderSm,
                                  ),
                                  child: const Icon(
                                    Icons.add_task_rounded,
                                    color: SpatiallyColors.violet,
                                    size: 24,
                                  ),
                                ),
                                SpatiallySpacing.gapHorizontalMd,
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Free Admission',
                                        style: SpatiallyTypography.subheading(color: textPrimary),
                                      ),
                                      Text(
                                        'Reserve your digital ticket for event entry',
                                        style: SpatiallyTypography.secondary(color: textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            SpatiallySpacing.gapVerticalLg,
                            SpatiallyPrimaryButton(
                              label: _claimingTicket ? 'Confirming...' : 'Get Admission Ticket',
                              icon: const Icon(Icons.confirmation_number_rounded, color: Colors.white, size: 20),
                              isLoading: _claimingTicket,
                              onPressed: _claimingTicket ? null : _claimTicket,
                            ),
                          ],
                        ),
        ),
      ],
    );
  }

  Widget _buildExperienceTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    String? badgeText,
    required VoidCallback onTap,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: SpatiallyRadius.borderSm,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: SpatiallyRadius.borderSm,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            SpatiallySpacing.gapHorizontalMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: SpatiallyTypography.secondaryMedium(color: textPrimary),
                  ),
                  Text(
                    subtitle,
                    style: SpatiallyTypography.caption(color: textSecondary),
                  ),
                ],
              ),
            ),
            if (badgeText != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: SpatiallyColors.error.withValues(alpha: 0.14),
                  borderRadius: SpatiallyRadius.borderFull,
                ),
                child: Text(
                  badgeText,
                  style: SpatiallyTypography.badge(color: SpatiallyColors.error).copyWith(fontSize: 9),
                ),
              ),
              SpatiallySpacing.gapHorizontalXs,
            ],
            Icon(Icons.chevron_right_rounded, color: textSecondary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String content,
    String? subtitle,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 20),
        SpatiallySpacing.gapHorizontalMd,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: SpatiallyTypography.caption(color: textSecondary),
              ),
              SpatiallySpacing.gapVerticalXs,
              Text(
                content,
                style: SpatiallyTypography.subheading(color: textPrimary),
              ),
              if (subtitle != null && subtitle.isNotEmpty) ...[
                SpatiallySpacing.gapVerticalXs,
                Text(
                  subtitle,
                  style: SpatiallyTypography.secondary(color: textSecondary),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
