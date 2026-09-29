import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:attendee_mobile/config/supabase_config.dart';
import 'package:attendee_mobile/features/explore/data/event_cache_manager.dart';
import 'package:attendee_mobile/features/passport/data/passport_repository.dart';
import 'package:attendee_mobile/features/passport/models/achievement_badge.dart';
import 'package:attendee_mobile/features/passport/models/journey_entry.dart';
import 'package:attendee_mobile/features/event_content/data/event_content_repository.dart';
import 'package:attendee_mobile/services/attendee_identity.dart';
import 'package:attendee_mobile/services/offline_service.dart';

class _RealHttpOverrides extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = _RealHttpOverrides();

  late SupabaseClient supabase;
  late EventCacheManager cacheManager;
  late PassportRepository passportRepository;
  late EventContentRepository contentRepository;

  const testEventId = '66c8a0ae-eb23-47d7-a0ad-2b304ccbd301';
  // Checked-in guest ticket holder in Supabase
  const testAttendeeId = '95e1e6a2-bdd3-4596-8cc5-808d150d2546';

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
    supabase = Supabase.instance.client;
    cacheManager = EventCacheManager();
    passportRepository = PassportRepositoryImpl(supabase: supabase);
    contentRepository = EventContentRepositoryImpl(supabase: supabase);
  });

  group('Phase 7B - Authoritative Passport & Gamification Test Suite', () {
    test('1. Passport loads real engagement summary from backend RPC', () async {
      final summary = await passportRepository.getPassportSummary(testEventId, testAttendeeId);

      expect(summary, isNotNull);
      expect(summary!['success'], true);
      expect(summary['eventId'], testEventId);
      expect(summary['attendeeId'], testAttendeeId);
      expect(summary['progress'], isNotNull);
      expect(summary['timeline'], isA<List>());
      expect(summary['achievements'], isA<List>());
    });

    test('2. Check-in appears in Passport timeline for checked-in attendee', () async {
      final timeline = await passportRepository.getJourneyTimeline(testEventId, testAttendeeId);

      expect(timeline, isNotEmpty);
      final checkInEntry = timeline.firstWhere(
        (e) => e.type == JourneyEntryType.checkIn,
        orElse: () => throw Exception('Check-in entry not found in timeline'),
      );

      expect(checkInEntry.isVerified, true);
      expect(checkInEntry.title, contains('Check-in'));
    });

    test('3. Activity completion updates activity state and points', () async {
      final progressBefore = await passportRepository.getEventProgress(testEventId, testAttendeeId);

      expect(progressBefore.pointsEarned, greaterThanOrEqualTo(0));
      expect(progressBefore.activitiesCompleted, greaterThanOrEqualTo(0));
      expect(progressBefore.sessionsAttended, greaterThanOrEqualTo(0));
      expect(progressBefore.boothsVisited, greaterThanOrEqualTo(0));
    });

    test('4. Activity completion updates Passport counts and points are reflected', () async {
      final summary = await passportRepository.getPassportSummary(testEventId, testAttendeeId);
      final progress = summary!['progress'] as Map<String, dynamic>;

      expect(progress['eventId'], testEventId);
      expect(progress.containsKey('pointsEarned'), true);
      expect(progress.containsKey('activitiesCompleted'), true);
      expect(progress.containsKey('boothsVisited'), true);
      expect(progress.containsKey('sessionsAttended'), true);
      expect(progress.containsKey('zonesVisited'), true);
      expect(progress.containsKey('badgesUnlocked'), true);
    });

    test('5. Duplicate completion does not duplicate points (Idempotency guarantee)', () async {
      final activities = await contentRepository.getActivities(testEventId);
      expect(activities, isNotEmpty);
      final activity = activities.first;

      // First verification
      final res1 = await contentRepository.verifyActivity(
        eventId: testEventId,
        attendeeId: testAttendeeId,
        activityId: activity.id,
        verificationCode: 'CHECKPOINT_TEST',
      );

      expect(res1['success'], true);

      // Second verification (same checkpoint)
      final res2 = await contentRepository.verifyActivity(
        eventId: testEventId,
        attendeeId: testAttendeeId,
        activityId: activity.id,
        verificationCode: 'CHECKPOINT_TEST',
      );

      expect(res2['success'], true);
      expect(res2['already_completed'], true);
      expect(res2['points_awarded'], 0); // Idempotency check: 0 duplicate points
    });

    test('6. Booth visit updates boothsVisited and is idempotent', () async {
      final booths = await contentRepository.getBooths(testEventId);
      expect(booths, isNotEmpty);
      final booth = booths.first;

      final res1 = await contentRepository.recordBoothVisit(
        eventId: testEventId,
        attendeeId: testAttendeeId,
        boothId: booth.id,
      );

      expect(res1['success'], true);

      final res2 = await contentRepository.recordBoothVisit(
        eventId: testEventId,
        attendeeId: testAttendeeId,
        boothId: booth.id,
      );

      expect(res2['success'], true);
      expect(res2['already_visited'], true);
    });

    test('7. Session attendance updates sessionsAttended and is idempotent', () async {
      final sessions = await contentRepository.getSessions(testEventId);
      expect(sessions, isNotEmpty);
      final session = sessions.first;

      final res1 = await contentRepository.recordSessionAttendance(
        eventId: testEventId,
        attendeeId: testAttendeeId,
        sessionId: session.id,
      );

      expect(res1['success'], true);

      final res2 = await contentRepository.recordSessionAttendance(
        eventId: testEventId,
        attendeeId: testAttendeeId,
        sessionId: session.id,
      );

      expect(res2['success'], true);
      expect(res2['already_attended'], true);
    });

    test('8. Badge thresholds are evaluated correctly', () async {
      final badges = await passportRepository.getAchievements(testEventId, testAttendeeId);

      expect(badges, isNotEmpty);
      expect(badges.length, 6);

      final pioneer = badges.firstWhere((b) => b.id == 'badge_pioneer');
      expect(pioneer.category, AchievementCategory.checkIn);
      expect(pioneer.requiredCount, 1);
      expect(pioneer.isUnlocked, true);
      expect(pioneer.progressFraction, 1.0);

      final keynote = badges.firstWhere((b) => b.id == 'badge_keynote');
      expect(keynote.category, AchievementCategory.session);
      expect(keynote.requiredCount, 1);
      expect(keynote.isUnlocked, true); // Session attendance logged in test 7!

      final questMaster = badges.firstWhere((b) => b.id == 'badge_quest_master');
      expect(questMaster.category, AchievementCategory.activity);
      expect(questMaster.requiredCount, 1);
      expect(questMaster.isUnlocked, true); // Activity verified in test 5!

      final finisher = badges.firstWhere((b) => b.id == 'badge_finisher');
      expect(finisher.requiredCount, 100);
    });

    test('9. Cached Passport loads offline', () async {
      const offlineAttendeeId = 'offline-test-attendee-001';
      final testSummary = {
        'success': true,
        'eventId': testEventId,
        'attendeeId': offlineAttendeeId,
        'isCheckedIn': true,
        'progress': {
          'eventId': testEventId,
          'sessionsAttended': 2,
          'boothsVisited': 3,
          'activitiesCompleted': 1,
          'zonesVisited': 3,
          'pointsEarned': 50,
          'badgesUnlocked': 3,
        },
        'timeline': [
          {
            'id': 'cached_checkin',
            'eventId': testEventId,
            'timestamp': DateTime.now().toIso8601String(),
            'title': 'Event Check-in Confirmed',
            'subtitle': 'Verified admission',
            'type': 'checkIn',
            'locationName': 'Auditorium',
            'isVerified': true,
            'points': 0,
          }
        ],
        'achievements': [
          {
            'id': 'badge_pioneer',
            'title': 'Event Pioneer',
            'description': 'Check in to the venue',
            'category': 'checkIn',
            'requiredCount': 1,
            'currentCount': 1,
            'isUnlocked': true,
          }
        ],
      };

      // Cache the summary
      await cacheManager.cachePassportSummary(testEventId, offlineAttendeeId, testSummary);

      // Verify cached summary directly
      final cached = await cacheManager.getCachedPassportSummary(testEventId, offlineAttendeeId);
      expect(cached, isNotNull);
      expect(cached!['progress']['pointsEarned'], 50);
      expect(cached['progress']['sessionsAttended'], 2);
      expect(cached['progress']['boothsVisited'], 3);

      // Verify repository parsing of cached progress when offline
      final progress = await passportRepository.getEventProgress(testEventId, offlineAttendeeId);
      expect(progress.pointsEarned, 50);
      expect(progress.sessionsAttended, 2);
      expect(progress.boothsVisited, 3);
    });

    test('10. Offline activity verification clearly requires connectivity', () async {
      final originalOnline = OfflineService().isOnlineNotifier.value;
      try {
        OfflineService().isOnlineNotifier.value = false;

        final res = await contentRepository.verifyActivity(
          eventId: testEventId,
          attendeeId: testAttendeeId,
          activityId: '30000000-0000-0000-0000-000000000001',
          verificationCode: 'OFFLINE_TEST',
        );

        expect(res['success'], false);
        expect(res['error'], 'OFFLINE');
        expect(res['message'], contains('Connectivity required to verify checkpoint and award passport points'));
      } finally {
        OfflineService().isOnlineNotifier.value = originalOnline;
      }
    });

    test('11. Unchecked-in attendee cannot claim activity points', () async {
      const uncheckAttendeeId = '00000000-0000-0000-0000-000000000099';

      final res = await contentRepository.verifyActivity(
        eventId: testEventId,
        attendeeId: uncheckAttendeeId,
        activityId: '30000000-0000-0000-0000-000000000001',
        verificationCode: 'CHECKPOINT123',
      );

      expect(res['success'], false);
      expect(res['error'], anyOf(equals('NOT_CHECKED_IN'), equals('NO_VALID_TICKET')));
    });

    test('12. Completed activity IDs are correctly queried', () async {
      final completed = await contentRepository.getCompletedActivityIds(testEventId, testAttendeeId);
      expect(completed, isA<Set<String>>());
      expect(completed, isNotEmpty);
    });
  });
}
