import 'package:flutter/material.dart';

import '../../design_system/design_system.dart';
import '../../screens/my_tickets_screen.dart';
import '../../services/attendee_identity.dart';
import '../../services/offline_service.dart';
import 'data/passport_repository.dart';
import 'models/achievement_badge.dart';
import 'models/event_history_item.dart';
import 'models/journey_entry.dart';
import 'models/passport_progress.dart';
import 'widgets/passport_achievements_section.dart';
import 'widgets/passport_event_card.dart';
import 'widgets/passport_history_section.dart';
import 'widgets/passport_journey_timeline.dart';
import 'widgets/passport_progress_grid.dart';

/// Spatially Attendee Passport Destination Screen.
/// 
/// The attendee's personal event journey record:
/// Answers "What did I experience at this event?" through verified
/// milestones, progress metrics, locked/unearned achievements, and event history.
/// 
/// Strictly separates real verified participation from demo content.
class PassportScreen extends StatefulWidget {
  final PassportRepository? repository;
  final String? initialEventId;

  const PassportScreen({
    super.key,
    this.repository,
    this.initialEventId,
  });

  @override
  State<PassportScreen> createState() => _PassportScreenState();
}

class _PassportScreenState extends State<PassportScreen> {
  late final PassportRepository _repository;

  bool _isLoading = true;
  String? _errorMessage;

  String? _selectedEventId;
  PassportEventContext? _eventContext;
  PassportProgress? _progress;
  List<JourneyEntry> _timeline = [];
  List<AchievementBadge> _achievements = [];
  List<EventHistoryItem> _history = [];

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? PassportRepositoryImpl();
    _selectedEventId = widget.initialEventId;
    _loadPassportData();
  }

  Future<void> _loadPassportData({String? eventId}) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final attendeeId = AttendeeIdentity.deviceId ?? '';

      // 1. Fetch user's registered & attended event passes
      final history = await _repository.getEventHistory(attendeeId);

      // 2. Resolve selected or current event context
      final targetEventId = eventId ?? _selectedEventId;
      final eventContext = await _repository.getSelectedEventContext(targetEventId, attendeeId);

      if (eventContext != null) {
        // 3. Concurrently fetch verified progress, timeline, and achievements
        final results = await Future.wait([
          _repository.getEventProgress(eventContext.eventId, attendeeId),
          _repository.getJourneyTimeline(eventContext.eventId, attendeeId),
          _repository.getAchievements(eventContext.eventId, attendeeId),
        ]);

        if (mounted) {
          setState(() {
            _history = history;
            _eventContext = eventContext;
            _selectedEventId = eventContext.eventId;
            _progress = results[0] as PassportProgress;
            _timeline = results[1] as List<JourneyEntry>;
            _achievements = results[2] as List<AchievementBadge>;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _history = history;
            _eventContext = null;
            _progress = null;
            _timeline = [];
            _achievements = [];
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Unable to load Passport data. Please try again.';
        });
      }
    }
  }

  void _onSelectEvent(String eventId) {
    if (_selectedEventId == eventId) return;
    _loadPassportData(eventId: eventId);
  }

  void _openTicketWallet() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MyTicketsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SpatiallyAppBar(
        title: 'Event Passport',
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.confirmation_number_outlined),
            tooltip: 'My Passes',
            onPressed: _openTicketWallet,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () => _loadPassportData(eventId: _selectedEventId),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const SpatiallyLoadingState(
        message: 'Loading your event journey...',
      );
    }

    if (_errorMessage != null) {
      return SpatiallyErrorState(
        error: _errorMessage!,
        onRetry: () => _loadPassportData(eventId: _selectedEventId),
      );
    }

    if (_eventContext == null && _history.isEmpty) {
      return SpatiallyEmptyState(
        icon: Icons.badge_outlined,
        title: 'No Event Passes Found',
        description:
            'Your Passport records your verified journey, milestones, and achievements once you register for an event.',
        actionLabel: 'Browse Events',
        onAction: () {
          // Switch to Explore tab if within shell
          final navigator = Navigator.of(context);
          if (navigator.canPop()) {
            navigator.pop();
          }
        },
      );
    }

    return RefreshIndicator(
      color: SpatiallyColors.violet,
      onRefresh: () => _loadPassportData(eventId: _selectedEventId),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: SpatiallySpacing.screenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!OfflineService().isOnline) ...[
              SpatiallyOfflineBanner(
                message: 'Offline Mode • Showing cached passport journey',
                onRetry: () => _loadPassportData(eventId: _selectedEventId),
              ),
            ],

            // 1. Current / Selected Event Header Card
            if (_eventContext != null) ...[
              PassportEventCard(
                eventContext: _eventContext!,
                allEvents: _history,
                onSelectEvent: _onSelectEvent,
                onOpenTicketPass: _openTicketWallet,
              ),
              SpatiallySpacing.gapVerticalLg,
            ],

            // 2. Compact Progress Grid (verified metrics only)
            if (_progress != null) ...[
              PassportProgressGrid(
                progress: _progress!,
              ),
              SpatiallySpacing.gapVerticalLg,
            ],

            // 3. Event Journey Timeline
            PassportJourneyTimeline(
              entries: _timeline,
              isCheckedIn: _eventContext?.isCheckedIn ?? false,
            ),
            SpatiallySpacing.gapVerticalLg,

            // 4. Achievements Section (locked definitions + verified unlocks)
            if (_achievements.isNotEmpty) ...[
              PassportAchievementsSection(
                badges: _achievements,
              ),
              SpatiallySpacing.gapVerticalLg,
            ],

            // 5. Event History Section (attended vs registered)
            PassportHistorySection(
              history: _history,
              currentEventId: _selectedEventId,
              onSelectEvent: _onSelectEvent,
              onViewTickets: _openTicketWallet,
            ),
            SpatiallySpacing.gapVerticalXl,
          ],
        ),
      ),
    );
  }
}
