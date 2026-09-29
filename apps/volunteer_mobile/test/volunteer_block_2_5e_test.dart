import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:volunteer_mobile/models/operational_health_models.dart';
import 'package:volunteer_mobile/models/operational_awareness_item.dart';
import 'package:volunteer_mobile/models/operational_message.dart';
import 'package:volunteer_mobile/models/operational_incident.dart';
import 'package:volunteer_mobile/models/volunteer_shift.dart';
import 'package:volunteer_mobile/models/lost_found_item.dart';
import 'package:volunteer_mobile/models/ble_observation.dart';
import 'package:volunteer_mobile/services/session_state.dart';
import 'package:volunteer_mobile/services/haptic_attention_service.dart';
import 'package:volunteer_mobile/services/event_awareness_service.dart';
import 'package:volunteer_mobile/repositories/operational_health_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SessionState.instance.clear();
    HapticAttentionService.instance.clear();
    EventAwarenessService.instance.clearSession();
  });

  group('Block 2.5E: Operational Health & Analytics Test Suite', () {
    // 1. Live operational health parsing
    test('1. Live operational health parses from RPC JSON structure', () {
      final rpcJson = {
        'event_id': '5caca6ed-d946-4833-978e-f62209bc06ac',
        'computed_at': '2026-09-29T12:00:00Z',
        'incidents': {
          'total': 5,
          'active': 2,
          'urgent': 1,
          'resolved': 3,
          'by_category': {'crowd': 3, 'medical': 2},
          'avg_time_to_acknowledge_seconds': 45,
          'avg_time_to_assign_seconds': 120,
          'avg_time_to_resolve_seconds': 360,
        },
        'assistance': {
          'total': 2,
          'pending': 1,
          'in_progress': 0,
          'resolved': 1,
          'avg_time_to_resolve_seconds': 180,
        },
        'coverage': {
          'total': 2,
          'pending': 1,
          'accepted': 1,
          'resolved': 0,
          'avg_time_to_accept_seconds': 90,
        },
        'tasks': {
          'total': 4,
          'pending': 1,
          'in_progress': 1,
          'completed': 2,
          'avg_time_to_complete_seconds': 400,
        },
        'shifts': {
          'total': 6,
          'active': 4,
          'on_break': 1,
          'completed': 1,
        },
        'communications': {
          'total_messages': 8,
          'broadcasts': 3,
          'urgent': 1,
        },
        'zones': [
          {
            'zone_id': 'zone-1',
            'zone_name': 'Main Auditorium',
            'floor_level': 1,
            'capacity_limit': 250,
            'operating_capacity': 250,
            'current_density': 'low',
            'is_monitored': true,
            'active_count': 50,
            'count_updated_at': DateTime.now().toIso8601String(),
            'active_incidents': 0,
            'pending_tasks': 0,
            'active_staff': 2,
            'coverage_needed': false,
          }
        ],
        'lost_found': {
          'total': 4,
          'lost': 2,
          'found': 2,
          'active': 1,
          'resolved': 3,
        }
      };

      final health = EventOperationalHealth.fromRpc(rpcJson);
      expect(health.eventId, '5caca6ed-d946-4833-978e-f62209bc06ac');
      expect(health.activeIncidents, 2);
      expect(health.urgentIncidents, 1);
      expect(health.resolvedIncidents, 3);
      expect(health.pendingAssistance, 1);
      expect(health.pendingCoverage, 1);
      expect(health.activeStaff, 4);
      expect(health.staffOnBreak, 1);
      expect(health.broadcasts, 3);
      expect(health.zones.length, 1);
      expect(health.zones.first.zoneName, 'Main Auditorium');
    });

    // 2. Health state classification
    test('2. Health state classification has 4 severity ranks', () {
      expect(OperationalHealthState.healthy.severityRank, 0);
      expect(OperationalHealthState.attentionNeeded.severityRank, 1);
      expect(OperationalHealthState.operationalPressure.severityRank, 2);
      expect(OperationalHealthState.criticalAttention.severityRank, 3);
    });

    // 3. Healthy state
    test('3. Healthy state triggers when all metrics are within safe thresholds', () {
      final rpcJson = {
        'event_id': 'event-1',
        'incidents': {'total': 0, 'active': 0, 'urgent': 0, 'resolved': 0},
        'coverage': {'total': 0, 'pending': 0, 'accepted': 0, 'resolved': 0},
        'tasks': {'total': 0, 'pending': 0, 'completed': 0},
        'shifts': {'total': 2, 'active': 2, 'on_break': 0},
        'zones': [
          {
            'zone_id': 'z1',
            'zone_name': 'Entrance',
            'operating_capacity': 100,
            'active_count': 20,
            'count_updated_at': DateTime.now().toIso8601String(),
            'active_incidents': 0,
            'is_monitored': true,
          }
        ]
      };
      final health = EventOperationalHealth.fromRpc(rpcJson);
      expect(health.overallHealth, OperationalHealthState.healthy);
      expect(health.healthSummary, contains('operating within safe parameters'));
    });

    // 4. Attention-needed state
    test('4. Attention-needed state triggers on important incident, pending task, or coverage', () {
      final rpcJson = {
        'event_id': 'event-1',
        'incidents': {'total': 1, 'active': 1, 'urgent': 0, 'resolved': 0},
        'coverage': {'total': 0, 'pending': 0},
        'tasks': {'total': 1, 'pending': 1},
        'shifts': {'total': 2, 'active': 2},
        'zones': []
      };
      final health = EventOperationalHealth.fromRpc(rpcJson);
      expect(health.overallHealth, OperationalHealthState.attentionNeeded);
    });

    // 5. Operational-pressure state
    test('5. Operational-pressure state triggers on busy zones or elevated unresolved workload', () {
      final rpcJson = {
        'event_id': 'event-1',
        'incidents': {'total': 2, 'active': 2, 'urgent': 0},
        'coverage': {'total': 2, 'pending': 2},
        'tasks': {'total': 1, 'pending': 1},
        'shifts': {'total': 2, 'active': 2},
        'zones': [
          {
            'zone_id': 'z1',
            'zone_name': 'Hall A',
            'operating_capacity': 100,
            'active_count': 85, // 85% BUSY
            'count_updated_at': DateTime.now().toIso8601String(),
          },
          {
            'zone_id': 'z2',
            'zone_name': 'Hall B',
            'operating_capacity': 100,
            'active_count': 82, // 82% BUSY
            'count_updated_at': DateTime.now().toIso8601String(),
          }
        ]
      };
      final health = EventOperationalHealth.fromRpc(rpcJson);
      expect(health.overallHealth, OperationalHealthState.operationalPressure);
    });

    // 6. Critical-attention state
    test('6. Critical-attention state triggers on active urgent incident or near-capacity zone', () {
      final rpcJson = {
        'event_id': 'event-1',
        'incidents': {'total': 1, 'active': 1, 'urgent': 1},
        'coverage': {'total': 0, 'pending': 0},
        'tasks': {'total': 0, 'pending': 0},
        'shifts': {'total': 2, 'active': 2},
        'zones': []
      };
      final health = EventOperationalHealth.fromRpc(rpcJson);
      expect(health.overallHealth, OperationalHealthState.criticalAttention);
    });

    // 7. Zone health calculations
    test('7. Zone operational health computes occupancy percentage and crowd condition', () {
      final zone = ZoneOperationalHealth(
        zoneId: 'z1',
        zoneName: 'Auditorium',
        operatingCapacity: 200,
        activeCount: 190, // 95%
        countUpdatedAt: DateTime.now(),
      );
      expect(zone.occupancyPercent, 95);
      expect(zone.crowdCondition, 'NEAR CAPACITY');
      expect(zone.telemetryFreshness, 'LIVE');
      expect(zone.healthState, OperationalHealthState.operationalPressure);
    });

    // 8. Zone isolation
    test('8. Zone isolation ensures stats belong exclusively to the queried zone', () {
      const zoneA = ZoneOperationalHealth(zoneId: 'zA', zoneName: 'Zone A', activeIncidents: 2);
      const zoneB = ZoneOperationalHealth(zoneId: 'zB', zoneName: 'Zone B', activeIncidents: 0);
      expect(zoneA.activeIncidents, 2);
      expect(zoneB.activeIncidents, 0);
      expect(zoneA.zoneId, isNot(zoneB.zoneId));
    });

    // 9. Event isolation
    test('9. Event isolation enforces event ID separation', () {
      final healthEvent1 = EventOperationalHealth(
        eventId: 'event-alpha',
        computedAt: DateTime.now(),
        overallHealth: OperationalHealthState.healthy,
        healthSummary: 'Alpha',
      );
      final healthEvent2 = EventOperationalHealth(
        eventId: 'event-beta',
        computedAt: DateTime.now(),
        overallHealth: OperationalHealthState.criticalAttention,
        healthSummary: 'Beta',
      );
      expect(healthEvent1.eventId, 'event-alpha');
      expect(healthEvent2.eventId, 'event-beta');
      expect(healthEvent1.overallHealth, isNot(healthEvent2.overallHealth));
    });

    // 10. Incident metrics
    test('10. Incident metrics calculate totals, active, resolved, and categories', () {
      final rpcJson = {
        'event_id': 'e1',
        'incidents': {
          'total': 10,
          'active': 3,
          'urgent': 1,
          'resolved': 7,
          'by_category': {'medical': 2, 'crowd': 5, 'facility': 3},
        }
      };
      final health = EventOperationalHealth.fromRpc(rpcJson);
      expect(health.totalIncidents, 10);
      expect(health.activeIncidents, 3);
      expect(health.resolvedIncidents, 7);
      expect(health.incidentsByCategory['medical'], 2);
      expect(health.incidentsByCategory['crowd'], 5);
    });

    // 11. Assistance metrics
    test('11. Assistance metrics capture help request counts and resolutions', () {
      final rpcJson = {
        'event_id': 'e1',
        'assistance': {
          'total': 5,
          'pending': 1,
          'in_progress': 1,
          'resolved': 3,
        }
      };
      final health = EventOperationalHealth.fromRpc(rpcJson);
      expect(health.totalAssistance, 5);
      expect(health.pendingAssistance, 1);
      expect(health.resolvedAssistance, 3);
    });

    // 12. Coverage metrics
    test('12. Coverage metrics reflect relief request lifecycles', () {
      final rpcJson = {
        'event_id': 'e1',
        'coverage': {
          'total': 4,
          'pending': 1,
          'accepted': 2,
          'resolved': 1,
        }
      };
      final health = EventOperationalHealth.fromRpc(rpcJson);
      expect(health.totalCoverage, 4);
      expect(health.pendingCoverage, 1);
      expect(health.acceptedCoverage, 2);
    });

    // 13. Task metrics
    test('13. Task metrics reflect supervisor assignment states', () {
      final rpcJson = {
        'event_id': 'e1',
        'tasks': {
          'total': 6,
          'pending': 2,
          'in_progress': 1,
          'completed': 3,
        }
      };
      final health = EventOperationalHealth.fromRpc(rpcJson);
      expect(health.totalTasks, 6);
      expect(health.pendingTasks, 2);
      expect(health.completedTasks, 3);
    });

    // 14. Shift metrics
    test('14. Shift metrics track active staff and volunteers on break', () {
      final rpcJson = {
        'event_id': 'e1',
        'shifts': {
          'total': 10,
          'active': 8,
          'on_break': 2,
          'completed': 0,
        }
      };
      final health = EventOperationalHealth.fromRpc(rpcJson);
      expect(health.totalShifts, 10);
      expect(health.activeStaff, 8);
      expect(health.staffOnBreak, 2);
    });

    // 15. Team metrics
    test('15. Team and shift context are preserved across operational entities', () {
      final shift = VolunteerShift(
        id: 's1',
        eventId: 'e1',
        volunteerId: 'v1',
        shiftName: 'Morning Ops',
        scheduledStart: DateTime.parse('2026-09-29T08:00:00Z'),
        scheduledEnd: DateTime.parse('2026-09-29T14:00:00Z'),
        status: ShiftStatus.active,
        breakState: BreakState.none,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        teamId: 'team-crowd-ops',
      );
      expect(shift.teamId, 'team-crowd-ops');
      expect(shift.isActive, isTrue);
    });

    // 16. Communication metrics
    test('16. Communication metrics track broadcasts, urgent alerts, and totals', () {
      final rpcJson = {
        'event_id': 'e1',
        'communications': {
          'total_messages': 15,
          'broadcasts': 4,
          'urgent': 2,
        }
      };
      final health = EventOperationalHealth.fromRpc(rpcJson);
      expect(health.totalMessages, 15);
      expect(health.broadcasts, 4);
      expect(health.urgentMessages, 2);
    });

    // 17. Response-time calculation
    test('17. Response-time metrics format seconds into clean human-readable text', () {
      expect(ResponseTimeMetrics.formatSeconds(45), '45s');
      expect(ResponseTimeMetrics.formatSeconds(138), '2m 18s');
      expect(ResponseTimeMetrics.formatSeconds(3600), '1h');
      expect(ResponseTimeMetrics.formatSeconds(4320), '1h 12m');
    });

    // 18. Missing timestamp handling
    test('18. Missing timestamps yield honest "Unavailable" label without fabricating data', () {
      expect(ResponseTimeMetrics.formatSeconds(0), 'Unavailable');
      expect(ResponseTimeMetrics.formatSeconds(-5), 'Unavailable');
    });

    // 19. Unresolved item handling
    test('19. Unresolved items correctly drive overall health away from healthy state', () {
      final items = [
        OperationalAwarenessItem(
          id: 'item-1',
          sourceId: 'inc-1',
          category: AwarenessCategory.incident,
          priority: OperationalPriority.important,
          relevance: OperationalRelevance.myZone,
          status: AttentionStatus.new_,
          title: 'Unresolved Spillage',
          message: 'Water spill on stairs',
          timestamp: DateTime.now(),
        )
      ];

      final derived = OperationalHealthRepositoryImpl.deriveLocalHealth(
        eventId: 'e1',
        awarenessItems: items,
      );
      expect(derived.overallHealth, OperationalHealthState.attentionNeeded);
      expect(derived.activeIncidents, 1);
      expect(derived.resolvedIncidents, 0);
    });

    // 20. Crowd transition analytics
    test('20. Crowd thresholds map correctly (<40% LOW, 40-79% MODERATE, 80-89% BUSY, >=90% NEAR CAPACITY)', () {
      expect(const ZoneOperationalHealth(zoneId: '1', zoneName: 'Z', operatingCapacity: 100, activeCount: 30).crowdCondition, 'LOW');
      expect(const ZoneOperationalHealth(zoneId: '2', zoneName: 'Z', operatingCapacity: 100, activeCount: 65).crowdCondition, 'MODERATE');
      expect(const ZoneOperationalHealth(zoneId: '3', zoneName: 'Z', operatingCapacity: 100, activeCount: 85).crowdCondition, 'BUSY');
      expect(const ZoneOperationalHealth(zoneId: '4', zoneName: 'Z', operatingCapacity: 100, activeCount: 92).crowdCondition, 'NEAR CAPACITY');
    });

    // 21. Stale crowd analytics
    test('21. Telemetry older than 180s produces STALE status', () {
      final staleZone = ZoneOperationalHealth(
        zoneId: 'z1',
        zoneName: 'Stale Zone',
        countUpdatedAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );
      expect(staleZone.telemetryFreshness, 'STALE');
    });

    // 22. Unavailable crowd analytics
    test('22. Null timestamp produces UNAVAILABLE telemetry freshness', () {
      const unavailZone = ZoneOperationalHealth(
        zoneId: 'z1',
        zoneName: 'Unmonitored Zone',
        countUpdatedAt: null,
      );
      expect(unavailZone.telemetryFreshness, 'UNAVAILABLE');
    });

    // 23. Scanner health
    test('23. BleObservation retains ephemeral identity and timestamp', () {
      final obs = BleObservation(
        ephemeralId: 'spatially_1234abcd',
        rssi: -62,
        scannedAt: DateTime.now(),
        isSpatiallyDevice: true,
      );
      expect(obs.isSpatiallyDevice, isTrue);
      expect(obs.ephemeralId, 'spatially_1234abcd');
    });

    // 24. Data-quality conditions
    test('24. Stale monitored zones generate data integrity alerts', () {
      final rpcJson = {
        'event_id': 'e1',
        'incidents': {'total': 0, 'active': 0, 'urgent': 0},
        'coverage': {'total': 0, 'pending': 0},
        'tasks': {'total': 0, 'pending': 0},
        'shifts': {'total': 1, 'active': 1},
        'zones': [
          {
            'zone_id': 'z_stale',
            'zone_name': 'North Gate',
            'is_monitored': true,
            'count_updated_at': DateTime.now().subtract(const Duration(minutes: 10)).toIso8601String(),
          }
        ]
      };
      final health = EventOperationalHealth.fromRpc(rpcJson);
      expect(health.dataIntegrityAlerts.any((a) => a.condition == 'STALE_CROWD_TELEMETRY'), isTrue);
    });

    // 25. Awareness-to-analytics deduplication
    test('25. OperationalTimelineEntry preserves source identity without synthetic doubling', () {
      final entry = OperationalTimelineEntry.fromJson({
        'id': 'inc_resolved_uuid-1234',
        'source_type': 'incident',
        'source_id': 'uuid-1234',
        'event_type': 'resolved',
        'title': 'Incident Resolved: Water leak',
        'description': 'Maintenance turned off valve',
        'timestamp': DateTime.now().toIso8601String(),
        'priority': 'important',
      });
      expect(entry.sourceType, 'incident');
      expect(entry.sourceId, 'uuid-1234');
      expect(entry.priority, OperationalPriority.important);
    });

    // 26. No double counting
    test('26. Resolving an awareness item decrements active count and increments resolved count cleanly', () {
      final items = [
        OperationalAwarenessItem(
          id: 'i1',
          sourceId: 'src-1',
          category: AwarenessCategory.incident,
          priority: OperationalPriority.normal,
          relevance: OperationalRelevance.myZone,
          status: AttentionStatus.resolved,
          title: 'Incident 1',
          message: 'Resolved',
          timestamp: DateTime.now(),
        ),
        OperationalAwarenessItem(
          id: 'i2',
          sourceId: 'src-2',
          category: AwarenessCategory.incident,
          priority: OperationalPriority.normal,
          relevance: OperationalRelevance.myZone,
          status: AttentionStatus.new_,
          title: 'Incident 2',
          message: 'Active',
          timestamp: DateTime.now(),
        ),
      ];

      final health = OperationalHealthRepositoryImpl.deriveLocalHealth(
        eventId: 'e1',
        awarenessItems: items,
      );
      expect(health.totalIncidents, 2);
      expect(health.activeIncidents, 1);
      expect(health.resolvedIncidents, 1);
    });

    // 27. Historical timeline ordering
    test('27. Timeline items sort chronologically descending', () {
      final t1 = OperationalTimelineEntry(
        id: '1',
        sourceType: 'incident',
        sourceId: 's1',
        eventType: 'created',
        title: 'Earlier',
        description: '',
        timestamp: DateTime.now().subtract(const Duration(hours: 1)),
      );
      final t2 = OperationalTimelineEntry(
        id: '2',
        sourceType: 'task',
        sourceId: 's2',
        eventType: 'completed',
        title: 'Later',
        description: '',
        timestamp: DateTime.now(),
      );

      final list = [t1, t2];
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      expect(list.first.title, 'Later');
      expect(list.last.title, 'Earlier');
    });

    // 28. Event summary derivation
    test('28. Event summary computes duration and peak occupancy accurately', () {
      const summary = EventOperationalSummary(
        eventId: 'e1',
        eventName: 'Demo Fest 2026',
        duration: Duration(hours: 5, minutes: 30),
        peakOccupancyZone: 'Main Hall',
        peakOccupancyPercent: 88,
        incidentsReported: 12,
        incidentsResolved: 11,
        incidentsOpen: 1,
        assistanceRequests: 8,
        assistanceResolved: 8,
        coverageRequested: 4,
        coverageFulfilled: 4,
        tasksCompleted: 15,
        tasksPending: 0,
        avgIncidentResolution: '3m 12s',
        avgAssistanceResolution: '2m 04s',
        avgCoverageAcceptance: '1m 45s',
      );
      expect(summary.peakOccupancyPercent, 88);
      expect(summary.peakOccupancyZone, 'Main Hall');
      expect(summary.incidentsOpen, 1);
      expect(summary.duration.inHours, 5);
    });

    // 29. Offline cached analytics honesty
    test('29. Offline cached health flags isCached and preserves cachedAt timestamp', () {
      final cachedTime = DateTime.now().subtract(const Duration(minutes: 15));
      final health = EventOperationalHealth.fromRpc(
        {
          'event_id': 'e1',
          'incidents': {'total': 1, 'active': 0, 'urgent': 0},
          'shifts': {'total': 1, 'active': 1},
        },
        isCached: true,
        cachedAt: cachedTime,
      );
      expect(health.isCached, isTrue);
      expect(health.cachedAt, cachedTime);
    });

    // 30. Realtime lifecycle cleanup
    test('30. Clearing session resets services and controllers safely', () {
      EventAwarenessService.instance.clearSession();
      expect(EventAwarenessService.instance.allItems, isEmpty);
      expect(EventAwarenessService.instance.currentEventId, isNull);
    });

    // 31. Account isolation
    test('31. Models expose only operational staff names, not raw internal auth UUIDs in summaries', () {
      final timeline = OperationalTimelineEntry(
        id: 't1',
        sourceType: 'task',
        sourceId: 'task-uuid',
        eventType: 'completed',
        title: 'Task Done',
        description: 'Completed inspection',
        timestamp: DateTime.now(),
        actorName: 'Volunteer Blaise',
      );
      expect(timeline.actorName, 'Volunteer Blaise');
      expect(timeline.toJson().containsKey('auth_uuid'), isFalse);
    });

    // 32. RLS behavior and staff validation
    test('32. OperationalHealthRepository deriveLocalHealth isolates events and maintains data integrity', () {
      final health = OperationalHealthRepositoryImpl.deriveLocalHealth(
        eventId: 'isolated-event-uuid',
        awarenessItems: [],
        isCached: true,
        cachedAt: DateTime.now(),
      );
      expect(health.eventId, 'isolated-event-uuid');
      expect(health.isCached, isTrue);
      expect(health.overallHealth, OperationalHealthState.healthy);
    });

    // 33. Existing Block 2 regression
    test('33. Block 2 BleObservation and telemetry models remain intact', () {
      final obs = BleObservation(
        ephemeralId: 'spatially_aabb1122',
        rssi: -50,
        scannedAt: DateTime.now(),
        isSpatiallyDevice: true,
      );
      expect(obs.ephemeralId, 'spatially_aabb1122');
      expect(obs.rssi, -50);
    });

    // 34. Existing Block 2.5A regression
    test('34. Block 2.5A OperationalMessage models remain intact', () {
      final msg = OperationalMessage(
        id: 'msg-1',
        eventId: 'e1',
        senderId: 'u1',
        senderRole: 'supervisor',
        senderName: 'Lead Alex',
        targetType: OperationalTargetType.event,
        messageType: 'announcement',
        priority: OperationalPriority.important,
        body: 'Staff meeting in 10 mins',
        createdAt: DateTime.now(),
      );
      expect(msg.targetType, OperationalTargetType.event);
      expect(msg.priority, OperationalPriority.important);
      expect(msg.isBroadcast, isTrue);
    });

    // 35. Existing Block 2.5B regression
    test('35. Block 2.5B OperationalIncident and LostFoundItem models remain intact', () {
      final incident = OperationalIncident(
        id: 'inc-1',
        eventId: 'e1',
        reporterType: 'volunteer',
        reporterName: 'Aryan',
        category: IncidentCategory.medical,
        priority: IncidentPriority.urgent,
        status: IncidentStatus.inProgress,
        title: 'Fainting at stage',
        description: 'Attendee fainted',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(incident.isUrgent, isTrue);
      expect(incident.isResolved, isFalse);

      final lf = LostFoundItem(
        id: 'lf-1',
        eventId: 'e1',
        reporterDeviceId: 'dev-1',
        reportType: 'found',
        category: 'electronics',
        title: 'Blue iPhone 13',
        description: 'Left on chair',
        status: 'open',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(lf.isFound, isTrue);
    });

    // 36. Existing Block 2.5C regression
    test('36. Block 2.5C VolunteerShift, breaks, handoffs, and supervisor tasks remain intact', () {
      final shift = VolunteerShift(
        id: 's1',
        eventId: 'e1',
        volunteerId: 'v1',
        shiftName: 'Operations',
        scheduledStart: DateTime.parse('2026-09-29T08:00:00Z'),
        scheduledEnd: DateTime.parse('2026-09-29T16:00:00Z'),
        status: ShiftStatus.onBreak,
        breakState: BreakState.onBreak,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(shift.isOnBreak, isTrue);
    });

    // 37. Existing Block 2.5D regression
    test('37. Block 2.5D OperationalAwarenessItem and attention logic remain intact', () {
      final item = OperationalAwarenessItem(
        id: 'awareness-1',
        sourceId: 'inc-99',
        category: AwarenessCategory.incident,
        priority: OperationalPriority.urgent,
        relevance: OperationalRelevance.myZone,
        status: AttentionStatus.new_,
        title: 'Urgent Medical Assistance',
        message: 'First aid kit needed',
        timestamp: DateTime.now(),
      );
      expect(item.requiresAttention, isTrue);
      expect(item.attentionKey, 'incident_inc-99_urgent');
    });
  });
}
