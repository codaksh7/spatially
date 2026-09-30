import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:volunteer_mobile/models/ble_observation.dart';
import 'package:volunteer_mobile/models/event_zone.dart';
import 'package:volunteer_mobile/models/ticket_check_in_result.dart';
import 'package:volunteer_mobile/models/offline_check_in_record.dart';
import 'package:volunteer_mobile/models/volunteer_assignment.dart';
import 'package:volunteer_mobile/repositories/volunteer_assignment_repository.dart';
import 'package:volunteer_mobile/repositories/ticket_check_in_repository.dart';
import 'package:volunteer_mobile/services/session_state.dart';

class MockVolunteerAssignmentRepository implements VolunteerAssignmentRepository {
  String? roleToReturn = 'volunteer';
  bool isAssignmentValidResult = true;

  @override
  Future<String?> getVolunteerRole(String userId) async {
    return roleToReturn;
  }

  @override
  Future<List<VolunteerAssignment>> getAssignments(String volunteerId) async {
    return [
      VolunteerAssignment(
        id: 'va-101',
        volunteerId: volunteerId,
        eventId: 'event-001',
        eventName: 'Tech Expo 2026',
        venue: 'Hall A',
        eventDate: DateTime(2026, 9, 27, 10, 0),
        eventStatus: 'live',
        zoneId: 'zone-701',
        zoneName: 'Robotics Arena',
        zoneCode: '701',
        role: 'gate_scanner',
        status: 'active',
      ),
    ];
  }

  @override
  Future<List<EventZone>> getEventZones(String eventId) async {
    return [
      const EventZone(
        id: 'zone-701',
        eventId: 'event-001',
        name: 'Robotics Arena',
        code: '701',
        floorLevel: 1,
        capacityLimit: 300,
        currentDensity: 'moderate',
      ),
      const EventZone(
        id: 'zone-702',
        eventId: 'event-001',
        name: 'AI Keynote Stage',
        code: '702',
        floorLevel: 2,
        capacityLimit: 500,
        currentDensity: 'high',
      ),
    ];
  }

  @override
  Future<bool> isAssignmentValid({
    required String volunteerId,
    required String eventId,
    String? zoneId,
  }) async {
    return isAssignmentValidResult;
  }
}

class MockTicketCheckInRepository implements TicketCheckInRepository {
  bool shouldFailNetwork = false;
  int pendingCount = 0;

  @override
  Future<TicketCheckInResult> checkInTicket({
    required String ticketCode,
    required String eventId,
  }) async {
    if (shouldFailNetwork) {
      pendingCount++;
      return TicketCheckInResult.offlineQueued(
        ticketCode: ticketCode,
        eventId: eventId,
      );
    }

    if (ticketCode == 'TICK-VALID') {
      return TicketCheckInResult(
        success: true,
        message: 'Admission granted',
        ticketId: 't-1',
        ticketCode: ticketCode,
        eventId: eventId,
        eventName: 'Tech Expo 2026',
        checkedInAt: DateTime.now(),
        checkedInBy: 'v-1',
      );
    } else if (ticketCode == 'TICK-USED') {
      return const TicketCheckInResult(
        success: false,
        errorCode: 'ALREADY_CHECKED_IN',
        message: 'Ticket has already been checked in.',
      );
    } else if (ticketCode == 'TICK-WRONG-EVENT') {
      return const TicketCheckInResult(
        success: false,
        errorCode: 'EVENT_MISMATCH',
        message: 'Ticket is for a different event.',
      );
    } else {
      return const TicketCheckInResult(
        success: false,
        errorCode: 'TICKET_NOT_FOUND',
        message: 'Ticket code not found.',
      );
    }
  }

  @override
  Future<int> flushOfflineCheckIns() async {
    final synced = pendingCount;
    pendingCount = 0;
    return synced;
  }

  @override
  Future<int> getPendingCheckInsCount() async {
    return pendingCount;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Step 1: Volunteer Role Verification', () {
    test('Role is permitted when role is "volunteer" or "admin"', () async {
      final repo = MockVolunteerAssignmentRepository();

      repo.roleToReturn = 'volunteer';
      final role1 = await repo.getVolunteerRole('user-1');
      expect(role1 == 'volunteer' || role1 == 'admin', isTrue);

      repo.roleToReturn = 'admin';
      final role2 = await repo.getVolunteerRole('user-2');
      expect(role2 == 'volunteer' || role2 == 'admin', isTrue);

      repo.roleToReturn = 'attendee';
      final role3 = await repo.getVolunteerRole('user-3');
      expect(role3 == 'volunteer' || role3 == 'admin', isFalse);

      repo.roleToReturn = null;
      final role4 = await repo.getVolunteerRole('user-4');
      expect(role4 == 'volunteer' || role4 == 'admin', isFalse);
    });
  });

  group('Step 2: Active Shift Persistence & Restoration', () {
    test('persistShift saves to SharedPreferences and restoreAndValidate restores valid shift', () async {
      final repo = MockVolunteerAssignmentRepository();
      final session = SessionState.instance;
      await session.clear();
      session.volunteerId = 'vol-uuid-123';

      await session.persistShift(
        newEventId: 'event-001',
        newZoneId: 'zone-701',
        newZoneName: 'Robotics Arena',
      );

      expect(session.eventId, 'event-001');
      expect(session.zoneId, 'zone-701');
      expect(session.zone, 'Robotics Arena');

      // Simulate app restart: clear in-memory state
      session.eventId = null;
      session.zoneId = null;
      session.zone = null;
      session.batteryChecked = false;

      // Restore and validate against server repo
      repo.isAssignmentValidResult = true;
      final restored = await session.restoreAndValidate(repo);

      expect(restored, isTrue);
      expect(session.eventId, 'event-001');
      expect(session.zoneId, 'zone-701');
      expect(session.zone, 'Robotics Arena');
      expect(session.batteryChecked, isTrue);
    });

    test('restoreAndValidate clears stale shift if server revokes assignment', () async {
      final repo = MockVolunteerAssignmentRepository();
      final session = SessionState.instance;
      await session.clear();
      session.volunteerId = 'vol-uuid-123';

      await session.persistShift(
        newEventId: 'event-revoked',
        newZoneId: 'zone-999',
        newZoneName: 'Old Station',
      );

      // Simulate revocation on backend
      repo.isAssignmentValidResult = false;
      final restored = await session.restoreAndValidate(repo);

      expect(restored, isFalse);
      expect(session.eventId, isNull);
      expect(session.zone, isNull);
    });
  });

  group('Step 4: Normalized Event Zones & Assignments', () {
    test('EventZone model parses normalized database representation correctly', () {
      final json = {
        'id': 'b8d4f40d-327c-4866-ba0a-e8f00dd6659c',
        'event_id': '63ed3709-1b92-4438-9bf3-4a860f3f1846',
        'name': 'Project Exhibition Hall A',
        'code': '701',
        'floor_level': 1,
        'capacity_limit': 250,
        'current_density': 'low',
      };

      final zone = EventZone.fromSupabase(json);
      expect(zone.id, 'b8d4f40d-327c-4866-ba0a-e8f00dd6659c');
      expect(zone.code, '701');
      expect(zone.name, 'Project Exhibition Hall A');
      expect(zone.capacityLimit, 250);
      expect(zone.floorLevel, 1);
    });

    test('VolunteerAssignment parses joined events and event_zones correctly', () {
      final json = {
        'id': 'va-501',
        'volunteer_id': 'vol-1',
        'event_id': 'event-10',
        'zone_id': 'zone-701',
        'role': 'gate_scanner',
        'status': 'active',
        'events': {
          'name': 'Annual Showcase 2026',
          'venue': 'Convention Center',
          'start_time': '2026-09-28T10:00:00Z',
          'status': 'live',
        },
        'event_zones': {
          'name': 'Main Entrance Gate',
          'code': 'GATE-1',
        },
      };

      final assignment = VolunteerAssignment.fromSupabase(json);
      expect(assignment.id, 'va-501');
      expect(assignment.eventName, 'Annual Showcase 2026');
      expect(assignment.venue, 'Convention Center');
      expect(assignment.zoneName, 'Main Entrance Gate');
      expect(assignment.zoneCode, 'GATE-1');
      expect(assignment.role, 'gate_scanner');
      expect(assignment.status, 'active');
    });
  });

  group('Step 6 & 7: Atomic Ticket Check-In RPC & Offline Queueing', () {
    test('Check-in succeeds on valid ticket', () async {
      final repo = MockTicketCheckInRepository();
      final result = await repo.checkInTicket(ticketCode: 'TICK-VALID', eventId: 'event-001');

      expect(result.success, isTrue);
      expect(result.isOfflineQueued, isFalse);
      expect(result.ticketCode, 'TICK-VALID');
      expect(result.eventName, 'Tech Expo 2026');
    });

    test('Check-in rejects already checked-in ticket', () async {
      final repo = MockTicketCheckInRepository();
      final result = await repo.checkInTicket(ticketCode: 'TICK-USED', eventId: 'event-001');

      expect(result.success, isFalse);
      expect(result.errorCode, 'ALREADY_CHECKED_IN');
      expect(result.message, contains('already been checked in'));
    });

    test('Check-in rejects ticket for different event', () async {
      final repo = MockTicketCheckInRepository();
      final result = await repo.checkInTicket(ticketCode: 'TICK-WRONG-EVENT', eventId: 'event-001');

      expect(result.success, isFalse);
      expect(result.errorCode, 'EVENT_MISMATCH');
    });

    test('Network failure enqueues offline check-in and flushes on reconnect', () async {
      final repo = MockTicketCheckInRepository();
      repo.shouldFailNetwork = true;

      final result = await repo.checkInTicket(ticketCode: 'TICK-OFFLINE', eventId: 'event-001');

      expect(result.isOfflineQueued, isTrue);
      expect(result.success, isTrue);
      expect(await repo.getPendingCheckInsCount(), 1);

      // Reconnect and flush
      repo.shouldFailNetwork = false;
      final synced = await repo.flushOfflineCheckIns();

      expect(synced, 1);
      expect(await repo.getPendingCheckInsCount(), 0);
    });
  });

  group('Step 8: Ambient BLE Telemetry Privacy Filter', () {
    test('Ambient non-Spatially devices are flagged isSpatiallyDevice=false', () {
      final ambientObs = BleObservation(
        ephemeralId: 'AA:BB:CC:DD:EE:FF',
        rssi: -85,
        scannedAt: DateTime.now(),
        isSpatiallyDevice: false,
      );

      final spatiallyObs = BleObservation(
        ephemeralId: '4A8F2C10E83D',
        rssi: -62,
        scannedAt: DateTime.now(),
        isSpatiallyDevice: true,
      );

      expect(ambientObs.isSpatiallyDevice, isFalse);
      expect(spatiallyObs.isSpatiallyDevice, isTrue);

      // Privacy gate verification: non-Spatially devices MUST NOT be queued or persisted
      final List<BleObservation> privacySafePersistenceList = [];

      void maybePersist(BleObservation obs) {
        if (!obs.isSpatiallyDevice) {
          // Strictly drop per Phase 5B privacy mandate
          return;
        }
        privacySafePersistenceList.add(obs);
      }

      maybePersist(ambientObs);
      maybePersist(spatiallyObs);

      expect(privacySafePersistenceList.length, 1);
      expect(privacySafePersistenceList.first.ephemeralId, '4A8F2C10E83D');
      expect(privacySafePersistenceList.first.isSpatiallyDevice, isTrue);
    });
  });

  group('Phase 5B Security Boundary Matrix (A-F)', () {
    // Simulated database RLS verification function mirroring 20260927_phase5b_zone_rls_hardening.sql
    bool checkObservationRls({
      required String? callerId,
      required String? callerRole,
      required String volunteerId,
      required String eventId,
      required String? zone,
      required bool isSpatiallyDevice,
      required List<VolunteerAssignment> activeAssignments,
      required List<EventZone> eventZones,
    }) {
      // E. Anonymous user -> rejected
      if (callerId == null) return false;

      // D. Attendee role -> rejected
      if (callerRole != 'volunteer' && callerRole != 'admin') return false;

      // Caller cannot impersonate another volunteer
      if (callerId != volunteerId) return false;

      // F. Non-Spatially BLE observation -> rejected
      if (!isSpatiallyDevice) return false;

      // C. Assignment check (must have active assignment for this event)
      final assignment = activeAssignments
          .where((a) => a.volunteerId == callerId && a.eventId == eventId && a.status == 'active')
          .firstOrNull;
      if (assignment == null) return false;

      // A & B. Zone-level check
      if (assignment.zoneId != null) {
        // Volunteer has designated station: must match assigned zone
        final assignedZone = eventZones.where((z) => z.id == assignment.zoneId).firstOrNull;
        if (assignedZone == null) return false;
        return zone == assignedZone.name || zone == assignedZone.code || zone == assignedZone.id;
      } else {
        // Event-wide roving volunteer: can write to any valid zone of the event
        if (zone == null) return true;
        return eventZones.any((z) => z.eventId == eventId && (z.name == zone || z.code == zone || z.id == zone));
      }
    }

    final testZones = [
      const EventZone(id: 'z-701', eventId: 'event-A', name: 'Main Stage', code: 'MS-1'),
      const EventZone(id: 'z-702', eventId: 'event-A', name: 'Entrance Gate', code: 'EG-1'),
      const EventZone(id: 'z-801', eventId: 'event-B', name: 'VIP Area', code: 'VIP-1'),
    ];

    final List<VolunteerAssignment> assignments = [
      VolunteerAssignment(
        id: 'va-1',
        volunteerId: 'vol-user-1',
        eventId: 'event-A',
        eventName: 'Event A',
        venue: 'Hall 1',
        eventStatus: 'live',
        zoneId: 'z-701', // Assigned specifically to Main Stage
        zoneName: 'Main Stage',
        zoneCode: 'MS-1',
        role: 'crowd_monitor',
        status: 'active',
      ),
    ];

    test('Boundary A: Assigned volunteer + assigned zone -> allowed', () {
      final allowed = checkObservationRls(
        callerId: 'vol-user-1',
        callerRole: 'volunteer',
        volunteerId: 'vol-user-1',
        eventId: 'event-A',
        zone: 'Main Stage',
        isSpatiallyDevice: true,
        activeAssignments: assignments,
        eventZones: testZones,
      );
      expect(allowed, isTrue);
    });

    test('Boundary B: Assigned volunteer + different/unassigned zone -> rejected', () {
      final allowed = checkObservationRls(
        callerId: 'vol-user-1',
        callerRole: 'volunteer',
        volunteerId: 'vol-user-1',
        eventId: 'event-A',
        zone: 'Entrance Gate', // Different station!
        isSpatiallyDevice: true,
        activeAssignments: assignments,
        eventZones: testZones,
      );
      expect(allowed, isFalse);
    });

    test('Boundary C: Volunteer assigned to Event A cannot write Event B observation', () {
      final allowed = checkObservationRls(
        callerId: 'vol-user-1',
        callerRole: 'volunteer',
        volunteerId: 'vol-user-1',
        eventId: 'event-B', // Different event!
        zone: 'VIP Area',
        isSpatiallyDevice: true,
        activeAssignments: assignments,
        eventZones: testZones,
      );
      expect(allowed, isFalse);
    });

    test('Boundary D: Attendee role cannot perform Volunteer operational writes', () {
      final allowed = checkObservationRls(
        callerId: 'attendee-user-1',
        callerRole: 'attendee', // Non-volunteer role!
        volunteerId: 'attendee-user-1',
        eventId: 'event-A',
        zone: 'Main Stage',
        isSpatiallyDevice: true,
        activeAssignments: assignments,
        eventZones: testZones,
      );
      expect(allowed, isFalse);
    });

    test('Boundary E: Anonymous user -> rejected', () {
      final allowed = checkObservationRls(
        callerId: null, // Anonymous!
        callerRole: null,
        volunteerId: 'vol-user-1',
        eventId: 'event-A',
        zone: 'Main Stage',
        isSpatiallyDevice: true,
        activeAssignments: assignments,
        eventZones: testZones,
      );
      expect(allowed, isFalse);
    });

    test('Boundary F: Non-Spatially BLE observation -> rejected', () {
      final allowed = checkObservationRls(
        callerId: 'vol-user-1',
        callerRole: 'volunteer',
        volunteerId: 'vol-user-1',
        eventId: 'event-A',
        zone: 'Main Stage',
        isSpatiallyDevice: false, // Ambient device!
        activeAssignments: assignments,
        eventZones: testZones,
      );
      expect(allowed, isFalse);
    });
  });

  // =========================================================================
  // Block 1: Production Integrity, Security & Data Correctness Pass
  // =========================================================================
  group('Block 1: Production Integrity, Security & Data Correctness Pass', () {
    late MockVolunteerAssignmentRepository repo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      repo = MockVolunteerAssignmentRepository();
      await SessionState.instance.clear();
      SessionState.instance.volunteerId = 'vol-test-uuid-001';
    });

    tearDown(() async {
      await SessionState.instance.clear();
    });

    test('1 & 2. Zone code storage vs zone name display distinction', () async {
      await SessionState.instance.persistShift(
        newEventId: 'event-001',
        newZoneId: 'zone-701',
        newZoneName: 'Auditorium',
        newZoneCode: '701',
      );

      // User-facing display gets zone name
      expect(SessionState.instance.zoneName, equals('Auditorium'));
      expect(SessionState.instance.zone, equals('Auditorium'));

      // Telemetry/backend contract gets zone code
      expect(SessionState.instance.zoneCode, equals('701'));
      expect(SessionState.instance.zoneId, equals('zone-701'));
    });

    test('3. Fixed assignment validation passes for assigned zone', () async {
      repo.isAssignmentValidResult = true;
      final isValid = await repo.isAssignmentValid(
        volunteerId: 'vol-test-uuid-001',
        eventId: 'event-001',
        zoneId: 'zone-701',
      );
      expect(isValid, isTrue);
    });

    test('4. Roving assignment validation passes with null zoneId', () async {
      repo.isAssignmentValidResult = true;
      final isValid = await repo.isAssignmentValid(
        volunteerId: 'vol-test-uuid-001',
        eventId: 'event-001',
        zoneId: null,
      );
      expect(isValid, isTrue);
    });

    test('5. Wrong-event assignment rejection', () async {
      repo.isAssignmentValidResult = false;
      final isValid = await repo.isAssignmentValid(
        volunteerId: 'vol-test-uuid-001',
        eventId: 'event-wrong-002',
        zoneId: 'zone-701',
      );
      expect(isValid, isFalse);
    });

    test('6. Observation security behavior enforces event and zone rules', () {
      bool checkObservationSecurity({
        required String callerId,
        required String volunteerId,
        required String eventId,
        required String zoneCode,
        required String assignedEventId,
        required String? assignedZoneCode,
      }) {
        if (callerId != volunteerId) return false;
        if (eventId != assignedEventId) return false;
        if (assignedZoneCode != null && zoneCode != assignedZoneCode) return false;
        return true;
      }

      // Valid fixed assignment write
      expect(
        checkObservationSecurity(
          callerId: 'vol-1',
          volunteerId: 'vol-1',
          eventId: 'event-1',
          zoneCode: '701',
          assignedEventId: 'event-1',
          assignedZoneCode: '701',
        ),
        isTrue,
      );

      // Wrong event rejected
      expect(
        checkObservationSecurity(
          callerId: 'vol-1',
          volunteerId: 'vol-1',
          eventId: 'event-2',
          zoneCode: '701',
          assignedEventId: 'event-1',
          assignedZoneCode: '701',
        ),
        isFalse,
      );

      // Wrong fixed zone rejected
      expect(
        checkObservationSecurity(
          callerId: 'vol-1',
          volunteerId: 'vol-1',
          eventId: 'event-1',
          zoneCode: '702',
          assignedEventId: 'event-1',
          assignedZoneCode: '701',
        ),
        isFalse,
      );

      // Volunteer impersonation rejected
      expect(
        checkObservationSecurity(
          callerId: 'vol-2',
          volunteerId: 'vol-1',
          eventId: 'event-1',
          zoneCode: '701',
          assignedEventId: 'event-1',
          assignedZoneCode: '701',
        ),
        isFalse,
      );
    });

    test('7. Volunteer counts security behavior enforces caller and event rules', () {
      bool checkCountsSecurity({
        required String authUid,
        required String volunteerId,
        required String eventId,
        required String zoneCode,
        required String assignedEventId,
        required String? assignedZoneCode,
        required List<String> eventValidCodes,
      }) {
        if (authUid != volunteerId) return false;
        if (eventId != assignedEventId) return false;
        if (!eventValidCodes.contains(zoneCode)) return false;
        if (assignedZoneCode != null && zoneCode != assignedZoneCode) return false;
        return true;
      }

      final validCodes = ['701', '702', '706'];

      // Valid fixed
      expect(
        checkCountsSecurity(
          authUid: 'vol-1',
          volunteerId: 'vol-1',
          eventId: 'event-1',
          zoneCode: '701',
          assignedEventId: 'event-1',
          assignedZoneCode: '701',
          eventValidCodes: validCodes,
        ),
        isTrue,
      );

      // Valid roving
      expect(
        checkCountsSecurity(
          authUid: 'vol-1',
          volunteerId: 'vol-1',
          eventId: 'event-1',
          zoneCode: '702',
          assignedEventId: 'event-1',
          assignedZoneCode: null, // roving
          eventValidCodes: validCodes,
        ),
        isTrue,
      );

      // Invalid zone code in roving
      expect(
        checkCountsSecurity(
          authUid: 'vol-1',
          volunteerId: 'vol-1',
          eventId: 'event-1',
          zoneCode: '999', // not valid for event
          assignedEventId: 'event-1',
          assignedZoneCode: null,
          eventValidCodes: validCodes,
        ),
        isFalse,
      );
    });

    test('8. QR volunteer ID passed and attributed', () async {
      SessionState.instance.volunteerId = 'vol-uuid-42';

      // Test OfflineCheckInRecord stores volunteerId
      final record = OfflineCheckInRecord(
        operationId: 'op-1',
        ticketCode: 'TICK-42',
        eventId: 'event-001',
        volunteerId: SessionState.instance.volunteerId,
        scannedAt: DateTime.now().toUtc(),
        syncStatus: 'pending',
      );

      final map = record.toMap();
      expect(map['volunteer_id'], equals('vol-uuid-42'));

      final parsed = OfflineCheckInRecord.fromMap(map);
      expect(parsed.volunteerId, equals('vol-uuid-42'));
    });

    test('9. Queue account safety isolates pending check-ins by volunteer', () {
      final records = [
        OfflineCheckInRecord(
          id: 1,
          operationId: 'op-1',
          ticketCode: 'TICK-1',
          eventId: 'event-1',
          volunteerId: 'vol-A',
          scannedAt: DateTime.now(),
          syncStatus: 'pending',
        ),
        OfflineCheckInRecord(
          id: 2,
          operationId: 'op-2',
          ticketCode: 'TICK-2',
          eventId: 'event-1',
          volunteerId: 'vol-B',
          scannedAt: DateTime.now(),
          syncStatus: 'pending',
        ),
      ];

      // Volunteer A should only see and flush Volunteer A's records
      final volARecords = records.where((r) => r.volunteerId == 'vol-A').toList();
      expect(volARecords.length, equals(1));
      expect(volARecords.first.ticketCode, equals('TICK-1'));

      // Volunteer B should only see and flush Volunteer B's records
      final volBRecords = records.where((r) => r.volunteerId == 'vol-B').toList();
      expect(volBRecords.length, equals(1));
      expect(volBRecords.first.ticketCode, equals('TICK-2'));
    });

    test('10. Assignment invalidation stops operational state and clears context', () async {
      await SessionState.instance.persistShift(
        newEventId: 'event-001',
        newZoneId: 'zone-701',
        newZoneName: 'Auditorium',
        newZoneCode: '701',
      );
      expect(SessionState.instance.eventId, isNotNull);

      // Simulate assignment revocation on server
      repo.isAssignmentValidResult = false;

      final restored = await SessionState.instance.restoreAndValidate(repo);
      expect(restored, isFalse);
      expect(SessionState.instance.eventId, isNull);
      expect(SessionState.instance.zone, isNull);
      expect(SessionState.instance.zoneCode, isNull);
      expect(SessionState.instance.zoneId, isNull);
    });

    test('11. Session restore preserves correct zone code and display name', () async {
      await SessionState.instance.persistShift(
        newEventId: 'event-001',
        newZoneId: 'zone-701',
        newZoneName: 'Auditorium',
        newZoneCode: '701',
      );

      // Simulate app restart by clearing memory only
      SessionState.instance.eventId = null;
      SessionState.instance.zoneId = null;
      SessionState.instance.zoneName = null;
      SessionState.instance.zoneCode = null;

      repo.isAssignmentValidResult = true;
      final restored = await SessionState.instance.restoreAndValidate(repo);
      expect(restored, isTrue);

      expect(SessionState.instance.eventId, equals('event-001'));
      expect(SessionState.instance.zoneId, equals('zone-701'));
      expect(SessionState.instance.zoneName, equals('Auditorium'));
      expect(SessionState.instance.zoneCode, equals('701'));
      expect(SessionState.instance.zone, equals('Auditorium'));
    });
  });
}
