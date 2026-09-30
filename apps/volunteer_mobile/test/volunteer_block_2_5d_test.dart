import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:volunteer_mobile/models/operational_awareness_item.dart';
import 'package:volunteer_mobile/models/operational_message.dart';
import 'package:volunteer_mobile/models/operational_incident.dart';
import 'package:volunteer_mobile/models/volunteer_shift.dart';
import 'package:volunteer_mobile/models/ble_observation.dart';
import 'package:volunteer_mobile/services/session_state.dart';
import 'package:volunteer_mobile/services/haptic_attention_service.dart';
import 'package:volunteer_mobile/services/event_awareness_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SessionState.instance.clear();
    HapticAttentionService.instance.clear();
    EventAwarenessService.instance.clearSession();
  });

  group('Block 2.5D: Event Awareness & Zone Operations Test Suite', () {
    // 1. operational event classification
    test('1. Operational event classification maps canonical categories correctly', () {
      expect(AwarenessCategory.fromString('crowd'), AwarenessCategory.crowd);
      expect(AwarenessCategory.fromString('incident'), AwarenessCategory.incident);
      expect(AwarenessCategory.fromString('safety'), AwarenessCategory.safety);
      expect(AwarenessCategory.fromString('assistance'), AwarenessCategory.assistance);
      expect(AwarenessCategory.fromString('team'), AwarenessCategory.team);
      expect(AwarenessCategory.fromString('shift'), AwarenessCategory.shift);
      expect(AwarenessCategory.fromString('coverage'), AwarenessCategory.coverage);
      expect(AwarenessCategory.fromString('task'), AwarenessCategory.task);
      expect(AwarenessCategory.fromString('communication'), AwarenessCategory.communication);
      expect(AwarenessCategory.fromString('system'), AwarenessCategory.system);
      expect(AwarenessCategory.fromString('unknown_val'), AwarenessCategory.system);
    });

    // 2. priority handling
    test('2. Priority handling ranks urgent > important > normal correctly', () {
      expect(OperationalPriority.urgent.rank, greaterThan(OperationalPriority.important.rank));
      expect(OperationalPriority.important.rank, greaterThan(OperationalPriority.normal.rank));
      expect(OperationalPriority.urgent.label, 'Urgent');
      expect(OperationalPriority.important.label, 'Important');
      expect(OperationalPriority.normal.label, 'Normal');
    });

    // 3. relevance to current zone
    test('3. Relevance to current zone assigns highest score (myZone)', () {
      SessionState.instance.zoneId = 'zone-main-gate-uuid';
      SessionState.instance.zoneCode = '701';

      final service = EventAwarenessService.instance;
      final relevanceById = service.determineRelevance(
        zoneId: 'zone-main-gate-uuid',
        priority: OperationalPriority.normal,
      );
      expect(relevanceById, OperationalRelevance.myZone);
      expect(relevanceById.score, 100);

      final relevanceByCode = service.determineRelevance(
        zoneCode: '701',
        priority: OperationalPriority.normal,
      );
      expect(relevanceByCode, OperationalRelevance.myZone);
    });

    // 4. team relevance
    test('4. Team relevance assigns high score (myTeam) for squad events', () {
      SessionState.instance.zoneId = 'zone-other-uuid';
      SessionState.instance.teamId = 'team-crowd-ops-uuid';

      final service = EventAwarenessService.instance;
      final relevance = service.determineRelevance(
        zoneId: 'zone-other-uuid2',
        teamId: 'team-crowd-ops-uuid',
        priority: OperationalPriority.normal,
      );
      expect(relevance, OperationalRelevance.myTeam);
      expect(relevance.score, 80);
    });

    // 5. event-wide urgent relevance
    test('5. Event-wide urgent relevance prioritizes urgent items regardless of zone', () {
      SessionState.instance.zoneId = 'zone-auditorium';
      SessionState.instance.teamId = 'team-stage-ops';

      final service = EventAwarenessService.instance;
      final relevance = service.determineRelevance(
        zoneId: 'zone-distant-gate',
        teamId: 'team-medical',
        priority: OperationalPriority.urgent,
      );
      expect(relevance, OperationalRelevance.eventWideUrgent);
      expect(relevance.score, 90);
    });

    // 6. notification deduplication
    test('6. Stable attentionKey prevents duplicate notifications', () {
      final item1 = OperationalAwarenessItem(
        id: 'inc_101',
        sourceId: 'incident-101',
        category: AwarenessCategory.incident,
        priority: OperationalPriority.urgent,
        relevance: OperationalRelevance.eventWideUrgent,
        status: AttentionStatus.new_,
        title: 'Congestion at Main Gate',
        message: 'Severe bottleneck',
        timestamp: DateTime.now(),
      );

      final item2 = item1.copyWith(message: 'Severe bottleneck updated');
      expect(item1.attentionKey, item2.attentionKey);
      expect(item1.attentionKey, 'incident_incident-101_urgent');
    });

    // 7. haptic deduplication
    test('7. Haptic deduplication triggers once and ignores replayed keys', () async {
      final haptic = HapticAttentionService.instance;
      int triggerCount = 0;
      haptic.onAttentionTriggered = (key, prio, pat) => triggerCount++;

      final first = await haptic.triggerAttention(
        itemKey: 'test_item_1',
        priority: OperationalPriority.important,
        isNew: true,
      );
      expect(first, isTrue);
      expect(triggerCount, 1);
      expect(haptic.hasHandled('test_item_1'), isTrue);

      final second = await haptic.triggerAttention(
        itemKey: 'test_item_1',
        priority: OperationalPriority.important,
        isNew: true,
      );
      expect(second, isFalse);
      expect(triggerCount, 1); // No second vibration
    });

    // 8. important haptic behavior
    test('8. Important haptic behavior executes short double-pulse pattern', () async {
      final haptic = HapticAttentionService.instance;
      List<int>? triggeredPattern;
      OperationalPriority? triggeredPriority;

      haptic.onAttentionTriggered = (key, prio, pat) {
        triggeredPriority = prio;
        triggeredPattern = pat;
      };

      await haptic.triggerAttention(
        itemKey: 'item_important_1',
        priority: OperationalPriority.important,
        isNew: true,
      );

      expect(triggeredPriority, OperationalPriority.important);
      expect(triggeredPattern, HapticAttentionService.importantPattern);
      expect(triggeredPattern, [0, 90, 100, 90]);
    });

    // 9. urgent haptic behavior
    test('9. Urgent haptic behavior executes distinct burst pattern', () async {
      final haptic = HapticAttentionService.instance;
      List<int>? triggeredPattern;
      OperationalPriority? triggeredPriority;

      haptic.onAttentionTriggered = (key, prio, pat) {
        triggeredPriority = prio;
        triggeredPattern = pat;
      };

      await haptic.triggerAttention(
        itemKey: 'item_urgent_1',
        priority: OperationalPriority.urgent,
        isNew: true,
      );

      expect(triggeredPriority, OperationalPriority.urgent);
      expect(triggeredPattern, HapticAttentionService.urgentPattern);
      expect(triggeredPattern!.length, 12);
    });

    // 10. no haptic for normal events
    test('10. Normal events never trigger haptic attention', () async {
      final haptic = HapticAttentionService.instance;
      int triggerCount = 0;
      haptic.onAttentionTriggered = (key, priority, pattern) => triggerCount++;

      final result = await haptic.triggerAttention(
        itemKey: 'item_normal_1',
        priority: OperationalPriority.normal,
        isNew: true,
      );

      expect(result, isFalse);
      expect(triggerCount, 0);
    });

    // 11. notification deep links
    test('11. Notification deep links map to canonical operational routes', () {
      final service = EventAwarenessService.instance;

      final incidentItem = service.normalizeIncident({
        'id': 'inc-99',
        'title': 'Power Glitch',
        'description': 'Stage 1 glitch',
        'priority': 'important',
        'status': 'open',
        'category': 'equipment',
        'created_at': DateTime.now().toIso8601String(),
      });
      expect(incidentItem.actionRoute, 'incident_detail');
      expect(incidentItem.actionPayload?['incidentId'], 'inc-99');

      final taskItem = service.normalizeTask({
        'id': 'task-55',
        'title': 'Restock water',
        'description': 'Water station 2',
        'priority': 'normal',
        'status': 'assigned',
        'created_at': DateTime.now().toIso8601String(),
      });
      expect(taskItem.actionRoute, 'supervisor_tasks');
      expect(taskItem.actionPayload?['taskId'], 'task-55');

      final coverageItem = service.normalizeCoverage({
        'id': 'cov-77',
        'reason': 'break',
        'priority': 'important',
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });
      expect(coverageItem.actionRoute, 'team_overview');
      expect(coverageItem.actionPayload?['requestId'], 'cov-77');
    });

    // 12. crowd threshold transitions
    test('12. Crowd threshold transitions categorize Busy (80%) and Near Capacity (90%)', () {
      final service = EventAwarenessService.instance;

      // 75% -> Below 80% returns null (routine noise omitted)
      final moderate = service.normalizeCrowdCount(
        zoneCode: '701',
        zoneName: 'Main Hall',
        zoneId: 'z-701',
        activeCount: 75,
        capacity: 100,
        updatedAt: DateTime.now(),
      );
      expect(moderate, isNull);

      // 85% -> Busy (OperationalPriority.important)
      final busy = service.normalizeCrowdCount(
        zoneCode: '701',
        zoneName: 'Main Hall',
        zoneId: 'z-701',
        activeCount: 85,
        capacity: 100,
        updatedAt: DateTime.now(),
      );
      expect(busy, isNotNull);
      expect(busy!.priority, OperationalPriority.important);
      expect(busy.title, contains('85% Density'));

      // 95% -> Near Capacity (OperationalPriority.urgent)
      final nearCap = service.normalizeCrowdCount(
        zoneCode: '701',
        zoneName: 'Main Hall',
        zoneId: 'z-701',
        activeCount: 95,
        capacity: 100,
        updatedAt: DateTime.now(),
      );
      expect(nearCap, isNotNull);
      expect(nearCap!.priority, OperationalPriority.urgent);
      expect(nearCap.title, contains('95% Density'));
    });

    // 13. stale crowd handling
    test('13. Stale crowd observation flags isStale = true when age > 45s', () {
      final service = EventAwarenessService.instance;
      final staleTime = DateTime.now().subtract(const Duration(seconds: 60));

      final staleItem = service.normalizeCrowdCount(
        zoneCode: '702',
        zoneName: 'Gate B',
        zoneId: 'z-702',
        activeCount: 88,
        capacity: 100,
        updatedAt: staleTime,
      );

      expect(staleItem, isNotNull);
      expect(staleItem!.isStale, isTrue);
    });

    // 14. unavailable crowd handling
    test('14. Unavailable or unrated crowd capacity is handled gracefully', () {
      final service = EventAwarenessService.instance;

      final zeroCap = service.normalizeCrowdCount(
        zoneCode: '703',
        zoneName: 'Corridor',
        zoneId: 'z-703',
        activeCount: 40,
        capacity: 0,
        updatedAt: DateTime.now(),
      );
      expect(zeroCap, isNull);
    });

    // 15. incident awareness
    test('15. Open operational incident normalizes into incident awareness entity', () {
      final service = EventAwarenessService.instance;
      final item = service.normalizeIncident({
        'id': 'inc-gate-1',
        'title': 'Gate Turnstile Jammed',
        'description': 'Scanner #4 offline',
        'category': 'equipment',
        'priority': 'urgent',
        'status': 'open',
        'created_at': DateTime.now().toIso8601String(),
      });

      expect(item.category, AwarenessCategory.incident);
      expect(item.priority, OperationalPriority.urgent);
      expect(item.requiresAttention, isTrue);
      expect(item.status, AttentionStatus.new_);
    });

    // 16. attendee assistance awareness
    test('16. Attendee help request maps to AwarenessCategory.assistance', () {
      final service = EventAwarenessService.instance;
      final item = service.normalizeIncident({
        'id': 'ast-1',
        'title': 'Wheelchair Assistance Needed',
        'description': 'Attendee at Ramp 2',
        'category': 'accessibility',
        'priority': 'important',
        'status': 'open',
        'created_at': DateTime.now().toIso8601String(),
      });

      expect(item.category, AwarenessCategory.assistance);
      expect(item.priority, OperationalPriority.important);
    });

    // 17. coverage awareness
    test('17. Pending coverage request maps to AwarenessCategory.coverage', () {
      final service = EventAwarenessService.instance;
      final item = service.normalizeCoverage({
        'id': 'cov-88',
        'reason': 'break',
        'notes': 'Need 15min break',
        'priority': 'important',
        'status': 'pending',
        'zone_name': 'Entrance',
        'created_at': DateTime.now().toIso8601String(),
      });

      expect(item.category, AwarenessCategory.coverage);
      expect(item.priority, OperationalPriority.important);
      expect(item.requiresAttention, isTrue);
    });

    // 18. supervisor task awareness
    test('18. Supervisor task maps to AwarenessCategory.task with correct status', () {
      final service = EventAwarenessService.instance;
      final item = service.normalizeTask({
        'id': 'st-1',
        'title': 'Deploy barricades',
        'description': 'Move queue stanchions',
        'priority': 'urgent',
        'status': 'assigned',
        'created_at': DateTime.now().toIso8601String(),
      });

      expect(item.category, AwarenessCategory.task);
      expect(item.priority, OperationalPriority.urgent);
      expect(item.requiresAttention, isTrue);
    });

    // 19. shift awareness
    test('19. Shift turnover pending produces important awareness item', () {
      final service = EventAwarenessService.instance;
      final item = service.normalizeShift({
        'id': 'sh-1',
        'shift_name': 'Morning Shift',
        'status': 'handoff_pending',
        'break_state': 'none',
        'volunteer_name': 'Aryan',
        'team_name': 'Crowd Ops',
        'updated_at': DateTime.now().toIso8601String(),
      });

      expect(item, isNotNull);
      expect(item!.category, AwarenessCategory.shift);
      expect(item.priority, OperationalPriority.important);
      expect(item.title, contains('Shift Turnover Pending'));
    });

    // 20. device/system awareness
    test('20. System conditions create actionable awareness alerts', () {
      final service = EventAwarenessService.instance;
      service.recordSystemAlert(
        key: 'bt_off',
        title: 'Bluetooth Disabled',
        message: 'Scanner paused',
        priority: OperationalPriority.important,
      );

      final items = service.allItems;
      expect(items.any((i) => i.category == AwarenessCategory.system), isTrue);
      final sysItem = items.firstWhere((i) => i.category == AwarenessCategory.system);
      expect(sysItem.title, 'Bluetooth Disabled');
      expect(sysItem.requiresAttention, isTrue);
    });

    // 21. offline honesty
    test('21. Cached items have isCached = true and suppress haptic vibration', () async {
      final haptic = HapticAttentionService.instance;
      int triggerCount = 0;
      haptic.onAttentionTriggered = (key, priority, pattern) => triggerCount++;

      final cachedItem = OperationalAwarenessItem(
        id: 'cached_inc_1',
        sourceId: 'inc-1',
        category: AwarenessCategory.incident,
        priority: OperationalPriority.urgent,
        relevance: OperationalRelevance.myZone,
        status: AttentionStatus.new_,
        title: 'Cached Incident',
        message: 'Loaded from SQLite',
        timestamp: DateTime.now(),
        isCached: true,
      );

      final service = EventAwarenessService.instance;
      await service.ingestAwarenessItem(cachedItem, isNew: false);

      expect(service.allItems.first.isCached, isTrue);
      expect(triggerCount, 0); // Suppressed by offline honesty
    });

    // 22. Realtime lifecycle
    test('22. clearSession resets items and handled attention keys', () {
      final service = EventAwarenessService.instance;
      service.recordSystemAlert(
        key: 'test_alert',
        title: 'Alert',
        message: 'Msg',
      );
      expect(service.allItems, isNotEmpty);

      service.clearSession();
      expect(service.allItems, isEmpty);
      expect(HapticAttentionService.instance.hasHandled('system_test_alert_important'), isFalse);
    });

    // 23. account isolation
    test('23. Account isolation correctly matches assignedVolunteerId', () {
      SessionState.instance.volunteerId = 'volunteer-aryan-uuid';

      final service = EventAwarenessService.instance;
      final assignedToMe = service.determineRelevance(
        assignedVolunteerId: 'volunteer-aryan-uuid',
        priority: OperationalPriority.normal,
      );
      expect(assignedToMe, OperationalRelevance.myZone);

      final assignedToOther = service.determineRelevance(
        assignedVolunteerId: 'volunteer-other-uuid',
        priority: OperationalPriority.normal,
      );
      expect(assignedToOther, OperationalRelevance.unrelatedNormal);
    });

    // 24. event isolation
    test('24. JSON serialization preserves event isolation fields and attention state', () {
      final item = OperationalAwarenessItem(
        id: 'item_100',
        sourceId: 'src_100',
        category: AwarenessCategory.crowd,
        priority: OperationalPriority.important,
        relevance: OperationalRelevance.myZone,
        status: AttentionStatus.seen,
        title: 'Crowd Dense',
        message: 'Zone 701 is busy',
        timestamp: DateTime.parse('2026-09-29T12:00:00Z'),
        zoneId: 'z-701',
        zoneName: 'Main Stage',
        zoneCode: '701',
        teamId: 't-1',
        teamName: 'Crowd Team',
        actionRoute: 'scanner',
        isStale: false,
        isCached: true,
      );

      final json = item.toJson();
      final reconstituted = OperationalAwarenessItem.fromJson(json);

      expect(reconstituted.id, item.id);
      expect(reconstituted.sourceId, item.sourceId);
      expect(reconstituted.category, item.category);
      expect(reconstituted.priority, item.priority);
      expect(reconstituted.status, AttentionStatus.seen);
      expect(reconstituted.isCached, isTrue);
      expect(reconstituted.zoneCode, '701');
    });

    // 25. existing Block 2 regression
    test('25. Block 2 BleObservation analytical schema remains regression-free', () {
      final obs = BleObservation(
        ephemeralId: 'abc12345',
        rssi: -65,
        scannedAt: DateTime.now(),
        isSpatiallyDevice: true,
      );
      expect(obs.isSpatiallyDevice, isTrue);
      expect(obs.rssi, -65);
    });

    // 26. existing Block 2.5A regression
    test('26. Block 2.5A OperationalMessage models remain regression-free', () {
      final msg = OperationalMessage(
        id: 'msg-1',
        eventId: 'evt-1',
        senderId: 'v-1',
        senderName: 'Coordinator',
        senderRole: 'admin',
        targetType: OperationalTargetType.event,
        messageType: 'broadcast',
        priority: OperationalPriority.urgent,
        body: 'Severe weather alert',
        requiresAcknowledgment: true,
        createdAt: DateTime.now(),
      );
      expect(msg.isUrgent, isTrue);
      expect(msg.priority, OperationalPriority.urgent);
    });

    // 27. existing Block 2.5B regression
    test('27. Block 2.5B OperationalIncident and isResolved helper remain intact', () {
      final incident = OperationalIncident(
        id: 'inc-1',
        eventId: 'evt-1',
        reporterType: 'volunteer',
        reporterName: 'Aryan',
        category: IncidentCategory.safety,
        priority: IncidentPriority.urgent,
        status: IncidentStatus.resolved,
        title: 'Spill',
        description: 'Cleaned',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(incident.isResolved, isTrue);
    });

    // 28. existing Block 2.5C regression
    test('28. Block 2.5C VolunteerShift and break state remain intact', () {
      final shift = VolunteerShift(
        id: 'sh-1',
        eventId: 'evt-1',
        volunteerId: 'v-1',
        shiftName: 'Morning Shift',
        scheduledStart: DateTime.now(),
        scheduledEnd: DateTime.now().add(const Duration(hours: 6)),
        status: ShiftStatus.onBreak,
        breakState: BreakState.onBreak,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(shift.isOnBreak, isTrue);
      expect(shift.status.label, 'On Break');
    });
  });
}
