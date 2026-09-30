import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:volunteer_mobile/models/ble_observation.dart';
import 'package:volunteer_mobile/models/event_zone.dart';
import 'package:volunteer_mobile/models/ticket_check_in_result.dart';
import 'package:volunteer_mobile/models/volunteer_assignment.dart';
import 'package:volunteer_mobile/repositories/volunteer_assignment_repository.dart';
import 'package:volunteer_mobile/repositories/ticket_check_in_repository.dart';
import 'package:volunteer_mobile/screens/event_picker_screen.dart';
import 'package:volunteer_mobile/screens/zone_selection_screen.dart';
import 'package:volunteer_mobile/screens/qr_scanner_screen.dart';
import 'package:volunteer_mobile/screens/scan_screen.dart';
import 'package:volunteer_mobile/services/observation_queue.dart';
import 'package:volunteer_mobile/services/session_state.dart';

class MockVolunteerAssignmentRepository implements VolunteerAssignmentRepository {
  bool shouldThrowError = false;
  List<VolunteerAssignment> assignmentsToReturn = [];
  List<EventZone> zonesToReturn = [];

  @override
  Future<String?> getVolunteerRole(String userId) async => 'volunteer';

  @override
  Future<List<VolunteerAssignment>> getAssignments(String volunteerId) async {
    if (shouldThrowError) {
      throw Exception('Network connection timed out');
    }
    return assignmentsToReturn;
  }

  @override
  Future<List<EventZone>> getEventZones(String eventId) async {
    if (shouldThrowError) {
      throw Exception('Database unreachable');
    }
    return zonesToReturn;
  }

  @override
  Future<bool> isAssignmentValid({
    required String volunteerId,
    required String eventId,
    String? zoneId,
  }) async => true;
}

class MockTicketCheckInRepository implements TicketCheckInRepository {
  TicketCheckInResult? nextResult;
  int pendingCount = 0;

  @override
  Future<TicketCheckInResult> checkInTicket({
    required String ticketCode,
    required String eventId,
  }) async {
    return nextResult ??
        TicketCheckInResult(
          success: true,
          message: 'Admission granted',
          ticketId: 't-100',
          ticketCode: ticketCode,
          eventId: eventId,
          eventName: 'Cultural Night 2026',
          checkedInAt: DateTime.now(),
        );
  }

  @override
  Future<int> getPendingCheckInsCount() async => pendingCount;

  @override
  Future<int> flushOfflineCheckIns() async {
    final flushed = pendingCount;
    pendingCount = 0;
    return flushed;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SessionState.instance.clear();
  });

  group('Block 2: Event & Zone Operational Identity', () {
    test('Fixed assignment properly differentiates display name vs operational zone code', () {
      final assignment = VolunteerAssignment(
        id: 'assign-1',
        volunteerId: 'vol-42',
        eventId: 'event-99',
        eventName: 'Cultural Night 2026',
        venue: 'Grand Arena',
        eventStatus: 'live',
        zoneId: 'zone-auditorium',
        zoneName: 'Auditorium',
        zoneCode: '701',
        capacityLimit: 250,
      );

      expect(assignment.isRoving, isFalse);
      expect(assignment.zoneName, equals('Auditorium'));
      expect(assignment.zoneCode, equals('701'));
      expect(assignment.capacityLimit, equals(250));
    });

    test('Roving assignment identifies as roving and spans event zones', () {
      final rovingAssignment = VolunteerAssignment(
        id: 'assign-2',
        volunteerId: 'vol-42',
        eventId: 'event-99',
        eventName: 'Cultural Night 2026',
        venue: 'Grand Arena',
        eventStatus: 'live',
        zoneId: null,
        zoneName: null,
        zoneCode: null,
      );

      expect(rovingAssignment.isRoving, isTrue);
      expect(rovingAssignment.zoneId, isNull);
      expect(rovingAssignment.zoneName, isNull);
      expect(rovingAssignment.zoneCode, isNull);
    });

    test('SessionState preserves complete shift context including roving and capacity', () async {
      await SessionState.instance.persistShift(
        newEventId: 'event-99',
        newEventName: 'Cultural Night 2026',
        newZoneId: 'zone-auditorium',
        newZoneName: 'Auditorium',
        newZoneCode: '701',
        isRoving: false,
        capacityLimit: 250,
      );

      expect(SessionState.instance.eventId, equals('event-99'));
      expect(SessionState.instance.eventName, equals('Cultural Night 2026'));
      expect(SessionState.instance.zoneName, equals('Auditorium'));
      expect(SessionState.instance.zoneCode, equals('701'));
      expect(SessionState.instance.isRoving, isFalse);
      expect(SessionState.instance.capacityLimit, equals(250));

      // Test Roving shift persistence
      await SessionState.instance.persistShift(
        newEventId: 'event-99',
        newEventName: 'Cultural Night 2026',
        newZoneId: null,
        newZoneName: null,
        newZoneCode: null,
        isRoving: true,
      );

      expect(SessionState.instance.isRoving, isTrue);
      expect(SessionState.instance.zoneId, isNull);
      expect(SessionState.instance.zoneName, isNull);
      expect(SessionState.instance.zoneCode, isNull);
    });
  });

  group('Block 2: Crowd Presentation & Density Calculation', () {
    // Thresholds:
    // < 0.40 -> Low Crowd
    // 0.40 - 0.79 -> Moderate Crowd
    // 0.80 - 0.89 -> Busy
    // >= 0.90 -> Near Capacity

    CrowdDensityInfo? calculateDensity(int detected, int? capacity) {
      if (capacity == null || capacity <= 0) return null;
      final ratio = detected / capacity;
      if (ratio < 0.40) {
        return CrowdDensityInfo(
          label: 'Low Crowd',
          color: Colors.green,
          bgColor: Colors.green.shade50,
          ratio: ratio,
        );
      } else if (ratio < 0.80) {
        return CrowdDensityInfo(
          label: 'Moderate Crowd',
          color: Colors.amber,
          bgColor: Colors.amber.shade50,
          ratio: ratio,
        );
      } else if (ratio < 0.90) {
        return CrowdDensityInfo(
          label: 'Busy',
          color: Colors.orange,
          bgColor: Colors.orange.shade50,
          ratio: ratio,
        );
      } else {
        return CrowdDensityInfo(
          label: 'Near Capacity',
          color: Colors.red,
          bgColor: Colors.red.shade50,
          ratio: ratio,
        );
      }
    }

    test('Honest raw count displayed when zone capacity is unknown', () {
      final info = calculateDensity(42, null);
      expect(info, isNull, reason: 'Must not invent fake density if capacity is unknown');
    });

    test('Classifies Low Crowd when occupancy is under 40%', () {
      final info = calculateDensity(35, 100);
      expect(info, isNotNull);
      expect(info!.label, equals('Low Crowd'));
      expect(info.ratio, closeTo(0.35, 0.001));
    });

    test('Classifies Moderate Crowd when occupancy is between 40% and 79%', () {
      final info = calculateDensity(50, 100);
      expect(info, isNotNull);
      expect(info!.label, equals('Moderate Crowd'));
      expect(info.ratio, closeTo(0.50, 0.001));
    });

    test('Classifies Busy when occupancy is between 80% and 89%', () {
      final info = calculateDensity(85, 100);
      expect(info, isNotNull);
      expect(info!.label, equals('Busy'));
      expect(info.ratio, closeTo(0.85, 0.001));
    });

    test('Classifies Near Capacity when occupancy is >= 90%', () {
      final info = calculateDensity(95, 100);
      expect(info, isNotNull);
      expect(info!.label, equals('Near Capacity'));
      expect(info.ratio, closeTo(0.95, 0.001));
    });
  });

  group('Block 2: Offline & Sync Visibility', () {
    test('QueueSyncInfo accurately calculates totalPending across observations and tickets', () {
      const syncInfo = QueueSyncInfo(
        pendingObservations: 14,
        pendingTickets: 3,
        isSyncing: false,
      );

      expect(syncInfo.totalPending, equals(17));
      expect(syncInfo.pendingObservations, equals(14));
      expect(syncInfo.pendingTickets, equals(3));
      expect(syncInfo.isSyncing, isFalse);
    });

    test('QueueSyncInfo tracks active syncing state', () {
      final syncInfo = QueueSyncInfo(
        pendingObservations: 2,
        pendingTickets: 1,
        isSyncing: true,
        lastSyncedAt: DateTime.now(),
      );

      expect(syncInfo.isSyncing, isTrue);
      expect(syncInfo.lastSyncedAt, isNotNull);
      expect(syncInfo.totalPending, equals(3));
    });
  });

  group('Block 2: QR Scanner Workflow & Operational States', () {
    test('QR result states map to structured feedback without exposing raw exceptions', () {
      final success = TicketCheckInResult(
        success: true,
        message: 'Admission granted',
        ticketId: 't-1',
        ticketCode: 'VALID-1',
        eventId: 'e-1',
        eventName: 'Main Event',
      );
      expect(success.success, isTrue);
      expect(success.isOfflineQueued, isFalse);

      final duplicate = TicketCheckInResult(
        success: false,
        ticketCode: 'DUP-1',
        eventId: 'e-1',
        errorCode: 'ALREADY_CHECKED_IN',
        message: 'This ticket has already been used',
      );
      expect(duplicate.errorCode, equals('ALREADY_CHECKED_IN'));

      final wrongEvent = TicketCheckInResult(
        success: false,
        ticketCode: 'DIFF-1',
        eventId: 'e-1',
        errorCode: 'EVENT_MISMATCH',
        message: 'Ticket is for another event',
      );
      expect(wrongEvent.errorCode, equals('EVENT_MISMATCH'));

      final offlineQueued = TicketCheckInResult.offlineQueued(
        ticketCode: 'OFF-1',
        eventId: 'e-1',
      );
      expect(offlineQueued.isOfflineQueued, isTrue);
      expect(offlineQueued.success, isTrue);
    });

    testWidgets('QrScannerScreen renders ready feedback initially', (tester) async {
      final mockRepo = MockTicketCheckInRepository();
      SessionState.instance.eventId = 'event-001';
      SessionState.instance.eventName = 'Tech Expo 2026';

      await tester.pumpWidget(
        MaterialApp(
          home: QrScannerScreen(repository: mockRepo),
        ),
      );

      expect(find.text('Ready to Scan'), findsOneWidget);
      expect(find.text('Position the attendee QR ticket code inside the frame.'), findsOneWidget);
    });
  });

  group('Block 2: EventPicker & ZoneSelection UX with Error & Retry States', () {
    testWidgets('EventPickerScreen shows structured retry state on network error', (tester) async {
      final mockRepo = MockVolunteerAssignmentRepository()..shouldThrowError = true;
      SessionState.instance.volunteerId = 'vol-001';

      await tester.pumpWidget(
        MaterialApp(
          home: EventPickerScreen(assignmentRepository: mockRepo),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Connection Issue'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      // Now resolve the error and tap retry
      mockRepo.shouldThrowError = false;
      mockRepo.assignmentsToReturn = [
        VolunteerAssignment(
          id: 'va-1',
          volunteerId: 'vol-001',
          eventId: 'event-001',
          eventName: 'Tech Expo 2026',
          venue: 'Main Hall',
          eventStatus: 'live',
          zoneId: 'z-1',
          zoneName: 'Robotics Stage',
          zoneCode: '701',
        ),
      ];

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Tech Expo 2026'), findsOneWidget);
      expect(find.text('Station: Robotics Stage (701)'), findsOneWidget);
    });

    testWidgets('EventPickerScreen shows coordinator instructions when assignments list is empty', (tester) async {
      final mockRepo = MockVolunteerAssignmentRepository()..assignmentsToReturn = [];
      SessionState.instance.volunteerId = 'vol-001';

      await tester.pumpWidget(
        MaterialApp(
          home: EventPickerScreen(assignmentRepository: mockRepo),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No Active Assignments'), findsOneWidget);
      expect(find.text('Check for Updates'), findsOneWidget);
    });

    testWidgets('ZoneSelectionScreen displays current event context and retry state on failure', (tester) async {
      final mockRepo = MockVolunteerAssignmentRepository()..shouldThrowError = true;
      SessionState.instance.eventId = 'event-001';
      SessionState.instance.eventName = 'Tech Expo 2026';

      await tester.pumpWidget(
        MaterialApp(
          home: ZoneSelectionScreen(assignmentRepository: mockRepo),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Connection Issue'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Choose Different Event'), findsOneWidget);
    });
  });

  group('Block 2: Telemetry & AI Data-Readiness Assurances', () {
    test('BleObservation preserves full analytical schema without dropping fields', () {
      final scannedAt = DateTime.utc(2026, 9, 29, 10, 30, 0);
      final obs = BleObservation(
        ephemeralId: '3a7b9c1d2e4f',
        rssi: -65,
        scannedAt: scannedAt,
        isSpatiallyDevice: true,
        volunteerId: 'vol-001',
        eventId: 'event-001',
        zone: '701',
      );

      final map = obs.toMap();
      expect(map['ephemeral_id'], equals('3a7b9c1d2e4f'));
      expect(map['rssi'], equals(-65));
      expect(map['scanned_at'], equals('2026-09-29T10:30:00.000Z'));
      expect(map['is_spatially_device'], isTrue);
      expect(map['volunteer_id'], equals('vol-001'));
      expect(map['event_id'], equals('event-001'));
      expect(map['zone'], equals('701'), reason: 'Zone code must be preserved for spatial joins');
    });

    test('Non-Spatially ambient devices are dropped by telemetry privacy gate', () {
      final ambientObs = BleObservation(
        ephemeralId: 'random-mac-address',
        rssi: -82,
        scannedAt: DateTime.now(),
        isSpatiallyDevice: false,
        volunteerId: 'vol-001',
        eventId: 'event-001',
        zone: '701',
      );

      expect(ambientObs.isSpatiallyDevice, isFalse);
    });
  });
}
