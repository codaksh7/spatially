import 'package:flutter_test/flutter_test.dart';
import 'package:attendee_mobile/features/profile/models/user_profile.dart';
import 'package:attendee_mobile/features/explore/data/event_cache_manager.dart';
import 'package:attendee_mobile/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Phase 4C Auth & Identity Separation Tests', () {
    test('Default guest profile is unauthenticated and anonymous', () {
      const testDeviceId = '11111111-2222-3333-4444-555555555555';
      final guest = UserProfile.defaultGuest(testDeviceId);

      expect(guest.deviceId, testDeviceId);
      expect(guest.userId, isNull);
      expect(guest.isAuthenticated, isFalse);
      expect(guest.isAnonymous, isTrue);
      expect(guest.role, 'attendee');
      expect(guest.name, 'Attendee Guest');
      expect(guest.initials, 'AG');
    });

    test('Supabase profile deserializes correctly and enforces server role', () {
      const testDeviceId = '11111111-2222-3333-4444-555555555555';
      const testUserId = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';
      final dbRow = {
        'id': testUserId,
        'email': 'attendee@spatially.app',
        'full_name': 'Jane Doe',
        'role': 'attendee',
        'headline': 'AI Researcher',
        'bio': 'Exploring spatial presence.',
        'interests': ['AI & Machine Learning', 'Robotics & IoT'],
        'avatar_url': 'https://example.com/avatar.png',
        'created_at': '2026-09-27T10:00:00Z',
        'updated_at': '2026-09-27T12:00:00Z',
      };

      final profile = UserProfile.fromSupabaseProfile(
        dbRow,
        deviceId: testDeviceId,
        email: 'attendee@spatially.app',
      );

      expect(profile.userId, testUserId);
      expect(profile.deviceId, testDeviceId);
      expect(profile.isAuthenticated, isTrue);
      expect(profile.isAnonymous, isFalse);
      expect(profile.name, 'Jane Doe');
      expect(profile.email, 'attendee@spatially.app');
      expect(profile.role, 'attendee');
      expect(profile.headline, 'AI Researcher');
      expect(profile.bio, 'Exploring spatial presence.');
      expect(profile.interests.length, 2);
      expect(profile.initials, 'JD');
    });

    test('Identity separation: Device ID remains intact when authenticated', () {
      const deviceId = 'local-device-uuid-1234';
      const cloudUserId = 'cloud-user-uuid-9876';

      final guestProfile = UserProfile.defaultGuest(deviceId);
      expect(guestProfile.deviceId, deviceId);
      expect(guestProfile.userId, isNull);

      final authProfile = guestProfile.copyWith(
        userId: cloudUserId,
        email: 'user@example.com',
        isAnonymous: false,
      );

      // Cloud user ID and local device ID are strictly distinct
      expect(authProfile.userId, isNot(equals(authProfile.deviceId)));
      expect(authProfile.deviceId, deviceId);
      expect(authProfile.userId, cloudUserId);
    });

    test('ClaimTicketsResult deserializes RPC response correctly', () {
      final rpcPayload = {
        'success': true,
        'claimed_count': 2,
        'already_owned_count': 1,
        'conflict_count': 0,
        'claimed_ticket_ids': [
          't1111111-0000-0000-0000-000000000001',
          't2222222-0000-0000-0000-000000000002',
        ],
      };

      final result = ClaimTicketsResult.fromRpc(rpcPayload);
      expect(result.success, isTrue);
      expect(result.claimedCount, 2);
      expect(result.alreadyOwnedCount, 1);
      expect(result.conflictCount, 0);
      expect(result.claimedTicketIds.length, 2);
      expect(result.claimedTicketIds[0], 't1111111-0000-0000-0000-000000000001');
    });

    test('EventCacheManager partitions ticket storage by account to prevent data leaks', () async {
      final cacheManager = EventCacheManager();
      const userA = 'user-account-a';
      const userB = 'user-account-b';

      final ticketsA = [
        {'id': 'ticket-a1', 'ticket_code': 'CODE-A1', 'user_id': userA},
      ];
      final ticketsB = [
        {'id': 'ticket-b1', 'ticket_code': 'CODE-B1', 'user_id': userB},
      ];
      final guestTickets = [
        {'id': 'ticket-g1', 'ticket_code': 'CODE-GUEST', 'user_id': null},
      ];

      // Cache partitioned by account
      await cacheManager.cacheTickets(ticketsA, userId: userA);
      await cacheManager.cacheTickets(ticketsB, userId: userB);
      await cacheManager.cacheTickets(guestTickets, userId: null);

      // Account A only sees Account A's cached tickets
      final loadedA = await cacheManager.getCachedTickets(userId: userA);
      expect(loadedA.length, 1);
      expect(loadedA.first['ticket_code'], 'CODE-A1');

      // Account B only sees Account B's cached tickets
      final loadedB = await cacheManager.getCachedTickets(userId: userB);
      expect(loadedB.length, 1);
      expect(loadedB.first['ticket_code'], 'CODE-B1');

      // Guest only sees Guest's cached tickets
      final loadedGuest = await cacheManager.getCachedTickets(userId: null);
      expect(loadedGuest.length, 1);
      expect(loadedGuest.first['ticket_code'], 'CODE-GUEST');

      // Logout / clear Account A does not touch Account B or Guest
      await cacheManager.clearUserCache(userA);
      final emptyA = await cacheManager.getCachedTickets(userId: userA);
      expect(emptyA, isEmpty);

      final intactB = await cacheManager.getCachedTickets(userId: userB);
      expect(intactB.length, 1);
      expect(intactB.first['ticket_code'], 'CODE-B1');

      final intactGuest = await cacheManager.getCachedTickets(userId: null);
      expect(intactGuest.length, 1);
      expect(intactGuest.first['ticket_code'], 'CODE-GUEST');
    });
  });
}
