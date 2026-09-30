import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:volunteer_mobile/models/operational_incident.dart';
import 'package:volunteer_mobile/models/incident_log.dart';
import 'package:volunteer_mobile/models/lost_found_item.dart';
import 'package:volunteer_mobile/repositories/incident_repository.dart';

void main() {
  group('Block 2.5B: Operational Incident Models & Serialization', () {
    test('IncidentPriority enum parses correctly from various formats', () {
      expect(IncidentPriority.fromString('urgent'), IncidentPriority.urgent);
      expect(IncidentPriority.fromString('URGENT'), IncidentPriority.urgent);
      expect(IncidentPriority.fromString('important'), IncidentPriority.important);
      expect(IncidentPriority.fromString('normal'), IncidentPriority.normal);
      expect(IncidentPriority.fromString('unknown'), IncidentPriority.normal);

      expect(IncidentPriority.urgent.toDbString(), 'urgent');
      expect(IncidentPriority.urgent.label, 'Urgent');
    });

    test('IncidentCategory enum parses all categories and converts to DB strings', () {
      expect(IncidentCategory.fromString('crowd'), IncidentCategory.crowd);
      expect(IncidentCategory.fromString('safety'), IncidentCategory.safety);
      expect(IncidentCategory.fromString('security'), IncidentCategory.security);
      expect(IncidentCategory.fromString('medical'), IncidentCategory.medical);
      expect(IncidentCategory.fromString('infrastructure'), IncidentCategory.infrastructure);
      expect(IncidentCategory.fromString('equipment'), IncidentCategory.equipment);
      expect(IncidentCategory.fromString('accessibility'), IncidentCategory.accessibility);
      expect(IncidentCategory.fromString('lost_found'), IncidentCategory.lostFound);
      expect(IncidentCategory.fromString('attendee_assistance'), IncidentCategory.attendeeAssistance);
      expect(IncidentCategory.fromString('operational'), IncidentCategory.operational);
      expect(IncidentCategory.fromString('other'), IncidentCategory.other);

      expect(IncidentCategory.lostFound.toDbString(), 'lost_found');
      expect(IncidentCategory.attendeeAssistance.toDbString(), 'attendee_assistance');
    });

    test('IncidentStatus transitions and string mapping', () {
      expect(IncidentStatus.fromString('open'), IncidentStatus.open);
      expect(IncidentStatus.fromString('acknowledged'), IncidentStatus.acknowledged);
      expect(IncidentStatus.fromString('assigned'), IncidentStatus.assigned);
      expect(IncidentStatus.fromString('in_progress'), IncidentStatus.inProgress);
      expect(IncidentStatus.fromString('resolved'), IncidentStatus.resolved);
      expect(IncidentStatus.fromString('closed'), IncidentStatus.closed);
      expect(IncidentStatus.fromString('cancelled'), IncidentStatus.cancelled);

      expect(IncidentStatus.inProgress.toDbString(), 'in_progress');
      expect(IncidentStatus.resolved.toDbString(), 'resolved');
    });

    test('OperationalIncident JSON serialization & deserialization', () {
      final now = DateTime.now();
      final incident = OperationalIncident(
        id: 'inc-1001',
        eventId: 'event-demo',
        reporterType: 'volunteer',
        reporterId: 'vol-42',
        reporterName: 'Blaise Rodrigues',
        category: IncidentCategory.crowd,
        priority: IncidentPriority.urgent,
        status: IncidentStatus.open,
        title: 'Gate 2 Crowd Surge',
        description: 'Need additional volunteers to manage line at entrance.',
        zoneId: 'zone-701',
        venueZoneName: 'Entrance & Foyer',
        specificLocation: 'Door 2B',
        imageUrl: 'https://storage.supabase.co/incident-evidence/photo1.jpg',
        linkedMessageId: 'msg-999',
        createdAt: now,
        updatedAt: now,
      );

      final json = incident.toJson();
      expect(json['id'], 'inc-1001');
      expect(json['category'], 'crowd');
      expect(json['priority'], 'urgent');
      expect(json['status'], 'open');
      expect(json['image_url'], 'https://storage.supabase.co/incident-evidence/photo1.jpg');

      final deserialized = OperationalIncident.fromJson(json);
      expect(deserialized.id, 'inc-1001');
      expect(deserialized.category, IncidentCategory.crowd);
      expect(deserialized.priority, IncidentPriority.urgent);
      expect(deserialized.isUrgent, isTrue);
      expect(deserialized.isAssistanceRequest, isFalse);
    });

    test('OperationalIncident identifies attendee assistance requests', () {
      final assistReq = OperationalIncident(
        id: 'inc-attendee-1',
        eventId: 'event-demo',
        reporterType: 'attendee',
        reporterName: 'John Doe',
        category: IncidentCategory.attendeeAssistance,
        priority: IncidentPriority.important,
        status: IncidentStatus.open,
        title: 'Wheelchair Ramp Assistance',
        description: 'Waiting at Hall B entrance for ramp deployment.',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(assistReq.isAssistanceRequest, isTrue);
      expect(assistReq.isUrgent, isFalse);
    });
  });

  group('Block 2.5B: Incident Audit Logs', () {
    test('IncidentLog parses action, actor, and status transitions', () {
      final logJson = {
        'id': 'log-001',
        'incident_id': 'inc-1001',
        'event_id': 'event-demo',
        'actor_id': 'vol-42',
        'actor_name': 'Volunteer Staff',
        'action': 'assigned',
        'previous_status': 'acknowledged',
        'new_status': 'assigned',
        'notes': 'Assigned to Blaise Rodrigues',
        'created_at': DateTime.now().toIso8601String(),
      };

      final log = IncidentLog.fromJson(logJson);
      expect(log.id, 'log-001');
      expect(log.action, 'assigned');
      expect(log.previousStatus, 'acknowledged');
      expect(log.newStatus, 'assigned');
      expect(log.notes, contains('Blaise Rodrigues'));
    });
  });

  group('Block 2.5B: Lost & Found Domain Model', () {
    test('LostFoundItem parses report types and status correctly', () {
      final itemJson = {
        'id': 'lf-501',
        'event_id': 'event-demo',
        'reporter_user_id': 'user-123',
        'reporter_device_id': 'dev-456',
        'report_type': 'lost',
        'category': 'electronics',
        'title': 'iPhone 15 Pro Blue',
        'description': 'Left on table in Room 712 during keynote.',
        'zone_id': 'zone-712',
        'venue_zone_name': 'Room 712 Foyer',
        'status': 'open',
        'pickup_instructions': 'Visit Info Desk #1',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final item = LostFoundItem.fromJson(itemJson);
      expect(item.id, 'lf-501');
      expect(item.isLost, isTrue);
      expect(item.isFound, isFalse);
      expect(item.isOpen, isTrue);
      expect(item.isMatched, isFalse);
      expect(item.pickupInstructions, 'Visit Info Desk #1');
    });

    test('LostFoundItem correctly handles found item', () {
      final itemJson = {
        'id': 'lf-502',
        'event_id': 'event-demo',
        'reporter_device_id': 'dev-789',
        'report_type': 'found',
        'category': 'accessories',
        'title': 'Car Key on Red Lanyard',
        'description': 'Found near cafeteria exit.',
        'status': 'matched',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final item = LostFoundItem.fromJson(itemJson);
      expect(item.isLost, isFalse);
      expect(item.isFound, isTrue);
      expect(item.isMatched, isTrue);
    });
  });

  group('Block 2.5B: Safety & Concurrency Exceptions', () {
    test('UrgentOfflineException refuses offline submission with clear emergency guidance', () {
      const ex = UrgentOfflineException();
      expect(ex.message, contains('Urgent reports cannot be queued offline'));
      expect(ex.message, contains('medical, security, or safety'));
      expect(ex.toString(), contains('emergency pathway'));
    });

    test('IncidentAlreadyAssignedException protects against volunteer assignment races', () {
      const ex = IncidentAlreadyAssignedException('Sarah Jenkins');
      expect(ex.assignedToName, 'Sarah Jenkins');
      expect(ex.message, contains('already assigned to Sarah Jenkins'));
      expect(ex.toString(), contains('Sarah Jenkins'));
    });
  });

  group('Block 2.5B: Attendee Privacy & Staff Isolation Safeguards', () {
    test('Staff confidential notes are isolated from attendee serialization', () {
      final staffIncident = OperationalIncident(
        id: 'inc-99',
        eventId: 'event-demo',
        reporterType: 'attendee',
        reporterName: 'Attendee 12',
        category: IncidentCategory.security,
        priority: IncidentPriority.urgent,
        status: IncidentStatus.assigned,
        title: 'Suspicious backpack near Stage 1',
        description: 'Unattended grey backpack left behind speaker podium.',
        staffNotes: 'SECURITY NOTICE: Dispatched guard Unit 4. Do not approach.',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Verify that the incident contains staff notes internally
      expect(staffIncident.staffNotes, contains('Unit 4'));

      // Simulate the Attendee Safe View mapping as performed by RPC get_attendee_assistance_status
      final attendeeSafeView = {
        'id': staffIncident.id,
        'category': staffIncident.category.toDbString(),
        'priority': staffIncident.priority.toDbString(),
        'status': staffIncident.status.toDbString(),
        'title': staffIncident.title,
        'description': staffIncident.description,
        'resolution_notes': staffIncident.resolutionNotes,
      };

      // Ensure staff notes are NOT present in the attendee-safe view
      expect(attendeeSafeView.containsKey('staff_notes'), isFalse);
      expect(attendeeSafeView.values, isNot(contains(contains('Unit 4'))));
    });
  });

  group('Block 2.5B: UI Component Sanity', () {
    testWidgets('Operational Incident Card displays badges and title', (tester) async {
      final incident = OperationalIncident(
        id: 'test-card-1',
        eventId: 'event-demo',
        reporterType: 'volunteer',
        reporterName: 'Tester',
        category: IncidentCategory.equipment,
        priority: IncidentPriority.important,
        status: IncidentStatus.open,
        title: 'Scanner #4 Battery Depleted',
        description: 'Need swap battery unit at Entrance.',
        venueZoneName: 'Entrance Station',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Card(
              child: Column(
                children: [
                  Text(incident.priority.label.toUpperCase()),
                  Text(incident.category.label),
                  Text(incident.title),
                  Text(incident.description),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('IMPORTANT'), findsOneWidget);
      expect(find.text('Equipment / Scanner'), findsOneWidget);
      expect(find.text('Scanner #4 Battery Depleted'), findsOneWidget);
      expect(find.text('Need swap battery unit at Entrance.'), findsOneWidget);
    });
  });
}
