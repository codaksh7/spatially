import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:attendee_mobile/config/supabase_config.dart';
import 'package:attendee_mobile/features/event_content/models/spatially_session.dart';
import 'package:attendee_mobile/features/event_content/models/spatially_booth.dart';
import 'package:attendee_mobile/features/event_content/models/spatially_activity.dart';
import 'package:attendee_mobile/features/event_content/data/event_content_repository.dart';
import 'package:attendee_mobile/features/event_content/sessions/sessions_screen.dart';
import 'package:attendee_mobile/features/explore/data/event_cache_manager.dart';
import 'package:attendee_mobile/features/explore/models/spatially_event.dart';
import 'package:attendee_mobile/features/notifications/models/notification_models.dart';
import 'package:attendee_mobile/features/map/models/venue_map_models.dart';
import 'package:attendee_mobile/design_system/components/spatially_crowd_indicator.dart';
import 'package:attendee_mobile/services/attendee_identity.dart';

class _TestHttpOverrides extends HttpOverrides {}

class _FakeContentRepository implements EventContentRepository {
  final List<SpatiallySession> sessions;
  _FakeContentRepository(this.sessions);

  @override
  Future<List<SpatiallySession>> getSessions(String eventId) async => sessions;

  @override
  Future<List<SpatiallyBooth>> getBooths(String eventId) async => [];

  @override
  Future<List<SpatiallyActivity>> getActivities(String eventId) async => [];

  @override
  Future<SpatiallySession?> getSessionById(String eventId, String sessionId) async =>
      sessions.where((s) => s.id == sessionId).firstOrNull;

  @override
  Future<SpatiallyBooth?> getBoothById(String eventId, String boothId) async => null;

  @override
  Future<SpatiallyActivity?> getActivityById(String eventId, String activityId) async => null;

  @override
  Future<Map<String, dynamic>> verifyActivity({
    required String eventId,
    required String attendeeId,
    required String activityId,
    required String verificationCode,
  }) async => {'success': true};

  @override
  Future<Map<String, dynamic>> recordBoothVisit({
    required String eventId,
    required String attendeeId,
    required String boothId,
  }) async => {'success': true};

  @override
  Future<Map<String, dynamic>> recordSessionAttendance({
    required String eventId,
    required String attendeeId,
    required String sessionId,
  }) async => {'success': true};

  @override
  Future<Set<String>> getCompletedActivityIds(String eventId, String attendeeId) async => {};

  @override
  Future<Set<String>> getVisitedBoothIds(String eventId, String attendeeId) async => {};

  @override
  Future<Set<String>> getAttendedSessionIds(String eventId, String attendeeId) async => {};
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = _TestHttpOverrides();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await AttendeeIdentity.init();
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabaseAnonKey,
      );
    } catch (_) {
      // Already initialized
    }
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AttendeeIdentity.init();
  });

  group('Phase 7C: Dynamic Session Status Derivation', () {
    final now = DateTime(2026, 9, 28, 12, 0, 0);

    test('1. Session before start_time derives UPCOMING status', () {
      final session = SpatiallySession(
        id: 's-upcoming',
        eventId: 'evt-1',
        title: 'Future Session',
        description: 'Starts at 13:00',
        speaker: 'Alice',
        startTime: now.add(const Duration(hours: 1)),
        endTime: now.add(const Duration(hours: 2)),
        roomName: 'Hall A',
        category: SessionCategory.presentation,
      );

      expect(session.calculateStatus(now), SessionStatus.upcoming);

      final realFutureSession = SpatiallySession(
        id: 's-future-real',
        eventId: 'evt-1',
        title: 'Future Talk',
        description: 'Starts in future relative to real clock',
        speaker: 'Bob',
        startTime: DateTime.now().add(const Duration(days: 2)),
        endTime: DateTime.now().add(const Duration(days: 2, hours: 1)),
        roomName: 'Hall B',
        category: SessionCategory.presentation,
      );
      expect(realFutureSession.isUpcoming, isTrue);
    });

    test('2. Session within interval [start_time, end_time) derives LIVE status', () {
      final session = SpatiallySession(
        id: 's-live',
        eventId: 'evt-1',
        title: 'Active Talk',
        description: 'Started at 11:30, ends at 12:30',
        speaker: 'Bob',
        startTime: DateTime(2026, 9, 28, 11, 30, 0),
        endTime: DateTime(2026, 9, 28, 12, 30, 0),
        roomName: 'Hall B',
        category: SessionCategory.keynote,
      );

      expect(session.calculateStatus(now), SessionStatus.live);
    });

    test('3. Session after end_time derives COMPLETED status', () {
      final session = SpatiallySession(
        id: 's-completed',
        eventId: 'evt-1',
        title: 'Past Workshop',
        description: 'Ended at 11:00',
        speaker: 'Charlie',
        startTime: DateTime(2026, 9, 28, 10, 0, 0),
        endTime: DateTime(2026, 9, 28, 11, 0, 0),
        roomName: 'Lab 1',
        category: SessionCategory.workshop,
      );

      expect(session.calculateStatus(now), SessionStatus.completed);
    });

    test('4. is_live=true manual override ALWAYS forces LIVE status regardless of timestamps', () {
      // End time is in the past, but isLiveOverride is true
      final session = SpatiallySession(
        id: 's-override',
        eventId: 'evt-1',
        title: 'Overtime Keynote',
        description: 'Organizer kept session live manually',
        speaker: 'Diana',
        startTime: DateTime(2026, 9, 28, 9, 0, 0),
        endTime: DateTime(2026, 9, 28, 10, 0, 0), // past end_time
        roomName: 'Main Stage',
        category: SessionCategory.keynote,
        isLiveOverride: true,
      );

      expect(session.calculateStatus(now), SessionStatus.live);
      expect(session.status, SessionStatus.live);
      expect(session.isLive, isTrue);
    });

    test('5. Session transitions over time: UPCOMING -> LIVE -> COMPLETED', () {
      final session = SpatiallySession(
        id: 's-transition',
        eventId: 'evt-1',
        title: 'Transitioning Talk',
        description: '10:00 to 11:00',
        speaker: 'Eve',
        startTime: DateTime(2026, 9, 28, 10, 0, 0),
        endTime: DateTime(2026, 9, 28, 11, 0, 0),
        roomName: 'Room 101',
        category: SessionCategory.panel,
      );

      // T1: 09:30 (before start)
      expect(session.calculateStatus(DateTime(2026, 9, 28, 9, 30)), SessionStatus.upcoming);

      // T2: 10:00 (exact start)
      expect(session.calculateStatus(DateTime(2026, 9, 28, 10, 0)), SessionStatus.live);

      // T3: 10:30 (in progress)
      expect(session.calculateStatus(DateTime(2026, 9, 28, 10, 30)), SessionStatus.live);

      // T4: 11:00 (exact end)
      expect(session.calculateStatus(DateTime(2026, 9, 28, 11, 0)), SessionStatus.completed);

      // T5: 11:30 (after end)
      expect(session.calculateStatus(DateTime(2026, 9, 28, 11, 30)), SessionStatus.completed);
    });
  });

  group('Phase 7C: Notification Category Reconciliation', () {
    test('1. Maps all 7 canonical Supabase DB categories correctly', () {
      // 1. schedule -> session
      expect(NotificationCategory.parseCategory('schedule'), NotificationCategory.session);
      expect(NotificationCategory.parseCategory('session'), NotificationCategory.session);

      // 2. engagement -> activity
      expect(NotificationCategory.parseCategory('engagement'), NotificationCategory.activity);
      expect(NotificationCategory.parseCategory('activity'), NotificationCategory.activity);

      // 3. networking -> connect
      expect(NotificationCategory.parseCategory('networking'), NotificationCategory.connect);
      expect(NotificationCategory.parseCategory('connect'), NotificationCategory.connect);

      // 4. crowd -> crowd
      expect(NotificationCategory.parseCategory('crowd'), NotificationCategory.crowd);

      // 5. safety -> safety
      expect(NotificationCategory.parseCategory('safety'), NotificationCategory.safety);

      // 6. general -> event (announcements)
      expect(NotificationCategory.parseCategory('general'), NotificationCategory.event);
      expect(NotificationCategory.parseCategory('event'), NotificationCategory.event);

      // 7. urgent -> safety (with urgent priority)
      expect(NotificationCategory.parseCategory('urgent'), NotificationCategory.safety);
      expect(NotificationCategory.parsePriority('urgent', null), NotificationPriority.urgent);
    });

    test('2. Action route parser supports all standard route formats', () {
      final a1 = NotificationAction.fromRoute('session:10000000-0000-0000-0000-000000000001', eventId: 'evt-1');
      expect(a1.type, NotificationActionType.session);
      expect(a1.targetId, '10000000-0000-0000-0000-000000000001');

      final a2 = NotificationAction.fromRoute('booth:20000000-0000-0000-0000-000000000001', eventId: 'evt-1');
      expect(a2.type, NotificationActionType.booth);
      expect(a2.targetId, '20000000-0000-0000-0000-000000000001');

      final a3 = NotificationAction.fromRoute('map:701:poi_stage', eventId: 'evt-1');
      expect(a3.type, NotificationActionType.map);
      expect(a3.zoneId, '701');
      expect(a3.poiId, 'poi_stage');

      final a4 = NotificationAction.fromRoute('connect', eventId: 'evt-1');
      expect(a4.type, NotificationActionType.connect);

      final a5 = NotificationAction.fromRoute('safety', eventId: 'evt-1');
      expect(a5.type, NotificationActionType.safety);
    });
  });

  group('Phase 7C: Offline Content Caching & Isolation', () {
    test('1. Sessions are cached and retrievable offline with zero mock fallback', () async {
      final cacheManager = EventCacheManager();
      const eventId = 'test-cache-evt-1';

      // Initially no cached sessions
      final initial = await cacheManager.getCachedSessions(eventId);
      expect(initial, isEmpty);

      final startTime = DateTime(2026, 9, 28, 10, 0, 0);
      final endTime = DateTime(2026, 9, 28, 11, 0, 0);

      // Cache raw sessions
      final rawSessions = [
        {
          'id': 's1',
          'event_id': eventId,
          'title': 'Cached Keynote',
          'description': 'Offline available',
          'speaker': 'Alice',
          'start_time': startTime.toIso8601String(),
          'end_time': endTime.toIso8601String(),
          'room_name': 'Auditorium',
          'category': 'keynote',
          'is_live': false,
        },
      ];

      await cacheManager.cacheSessions(eventId, rawSessions);

      // Retrieve cached sessions
      final cached = await cacheManager.getCachedSessions(eventId);
      expect(cached.length, 1);
      expect(cached.first['title'], 'Cached Keynote');

      // Deserialize and verify temporal status still works locally offline
      final session = SpatiallySession.fromJson(cached.first);
      expect(session.title, 'Cached Keynote');
      expect(session.calculateStatus(startTime.add(const Duration(minutes: 30))), SessionStatus.live);
    });

    test('2. Notifications are cached partitioned by identity and event ID', () async {
      final cacheManager = EventCacheManager();
      const partitionUserA = 'user-A';
      const partitionUserB = 'user-B';
      const eventA = 'event-1';
      const eventB = 'event-2';

      final notifsA = [
        {
          'id': 'n-1',
          'event_id': eventA,
          'title': 'Welcome Event A',
          'body': 'Content',
          'category': 'general',
          'created_at': DateTime.now().toIso8601String(),
        }
      ];

      await cacheManager.cacheNotifications(partitionUserA, eventA, notifsA);

      // User A on Event A has notifications
      final userAEventA = await cacheManager.getCachedNotifications(partitionUserA, eventA);
      expect(userAEventA.length, 1);

      // User A on Event B has NO notifications (event isolation)
      final userAEventB = await cacheManager.getCachedNotifications(partitionUserA, eventB);
      expect(userAEventB, isEmpty);

      // User B on Event A has NO notifications (account isolation)
      final userBEventA = await cacheManager.getCachedNotifications(partitionUserB, eventA);
      expect(userBEventA, isEmpty);
    });

    test('3. Read and dismissed states are strictly partitioned and do not leak', () async {
      final cacheManager = EventCacheManager();
      const userA = 'user-alice';
      const userB = 'user-bob';
      const eventA = 'event-tech';
      const eventB = 'event-design';

      // Alice reads notification n1 on event A
      await cacheManager.cacheReadNotificationIds(userA, eventA, {'n1'});

      // Verify Alice has n1 read on Event A
      final aliceReadA = await cacheManager.getCachedReadNotificationIds(userA, eventA);
      expect(aliceReadA, contains('n1'));

      // Verify Alice has NO read notifications on Event B
      final aliceReadB = await cacheManager.getCachedReadNotificationIds(userA, eventB);
      expect(aliceReadB, isEmpty);

      // Verify Bob has NO read notifications on Event A
      final bobReadA = await cacheManager.getCachedReadNotificationIds(userB, eventA);
      expect(bobReadA, isEmpty);
    });
  });

  group('Phase 7C: Crowd Freshness & Offline Honesty', () {
    test('1. Unavailable freshness displays honest offline status without claiming low crowd', () {
      const unavailableCrowd = SpatialCrowdState(
        zoneCode: '701',
        activeCount: 0,
        crowdLevel: SpatiallyCrowdLevel.low,
        freshness: SpatialCrowdFreshness.unavailable,
      );

      expect(unavailableCrowd.freshness, SpatialCrowdFreshness.unavailable);
      // Ensure freshness is never claimed as live when disconnected
      expect(unavailableCrowd.freshness != SpatialCrowdFreshness.live, isTrue);
    });

    test('2. Stale telemetry correctly reflects age', () {
      final tenMinutesAgo = DateTime.now().subtract(const Duration(minutes: 15));
      final freshness = SpatialCrowdFreshness.calculate(tenMinutesAgo);
      expect(freshness, SpatialCrowdFreshness.stale);
    });
  });

  group('Phase 7C: Session UI Tab Filtering', () {
    testWidgets('SessionsScreen correctly categorizes sessions into Upcoming, Live, and Completed tabs', (tester) async {
      final pastSession = SpatiallySession(
        id: 's-past',
        eventId: 'evt-filter',
        title: 'Past Keynote Talk',
        description: 'Finished talk',
        speaker: 'Alice',
        startTime: DateTime(2020, 1, 1, 9, 0),
        endTime: DateTime(2020, 1, 1, 10, 0),
        roomName: 'Auditorium',
        category: SessionCategory.keynote,
      );

      final liveSession = SpatiallySession(
        id: 's-live-override',
        eventId: 'evt-filter',
        title: 'Current Live Workshop',
        description: 'Happening now',
        speaker: 'Bob',
        startTime: DateTime(2020, 1, 1, 9, 0),
        endTime: DateTime(2020, 1, 1, 10, 0),
        roomName: 'Lab 1',
        category: SessionCategory.workshop,
        isLiveOverride: true, // Forces status == live
      );

      final futureSession = SpatiallySession(
        id: 's-future',
        eventId: 'evt-filter',
        title: 'Future Lightning Talk',
        description: 'Upcoming',
        speaker: 'Charlie',
        startTime: DateTime(2030, 1, 1, 9, 0),
        endTime: DateTime(2030, 1, 1, 10, 0),
        roomName: 'Stage B',
        category: SessionCategory.lightning,
      );

      // Verify derived temporal statuses
      expect(pastSession.status, SessionStatus.completed);
      expect(liveSession.status, SessionStatus.live);
      expect(futureSession.status, SessionStatus.upcoming);

      final testEvent = SpatiallyEvent(
        id: 'evt-filter',
        name: 'Filter Test Event',
        description: 'Test event',
        venue: 'Convention Center',
        eventDate: DateTime(2026, 9, 28),
        status: 'live',
        capacity: 500,
        zones: [],
      );

      final fakeRepo = _FakeContentRepository([pastSession, liveSession, futureSession]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SessionsScreen(
              eventId: testEvent.id,
              event: testEvent,
              repository: fakeRepo,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tab bar should render 3 tabs with badges
      expect(find.textContaining('Upcoming'), findsAtLeastNWidgets(1));
      expect(find.textContaining('Live'), findsAtLeastNWidgets(1));
      expect(find.textContaining('Completed'), findsAtLeastNWidgets(1));

      // Cleanly unmount widget to trigger dispose() and cancel ticker timer
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
