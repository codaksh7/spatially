import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/operational_health_models.dart';
import '../models/operational_awareness_item.dart';
import '../models/event_zone.dart';
import '../services/observation_queue.dart';

abstract class OperationalHealthRepository {
  Future<EventOperationalHealth> getOperationalHealth(String eventId, {bool forceRefresh = false});
  Future<List<OperationalTimelineEntry>> getOperationalTimeline(String eventId, {int limit = 50, bool forceRefresh = false});
  Future<EventOperationalSummary> getEventSummary(String eventId, String eventName, {DateTime? eventStartTime});
}

class OperationalHealthRepositoryImpl implements OperationalHealthRepository {
  final SupabaseClient? client;
  final ObservationQueue _queue;

  OperationalHealthRepositoryImpl({
    this.client,
    ObservationQueue? queue,
  }) : _queue = queue ?? ObservationQueue();

  SupabaseClient get _supabase => client ?? Supabase.instance.client;

  @override
  Future<EventOperationalHealth> getOperationalHealth(String eventId, {bool forceRefresh = false}) async {
    // 1. Try remote authoritative Supabase RPC
    try {
      final res = await _supabase.rpc(
        'get_event_operational_health',
        params: {'p_event_id': eventId},
      );

      if (res != null && res is Map) {
        final data = Map<String, dynamic>.from(res);
        // Persist to local cache for offline honesty
        await _queue.cacheOperationalHealth(eventId, jsonEncode(data));
        return EventOperationalHealth.fromRpc(data, isCached: false);
      }
    } catch (_) {
      // Remote call failed (offline, timeout, test env without live network)
    }

    // 2. Fall back to local SQLite cache
    final cached = await _queue.getCachedOperationalHealth(eventId);
    if (cached != null) {
      DateTime? cachedAt;
      if (cached['_cached_at'] != null) {
        cachedAt = DateTime.tryParse(cached['_cached_at'].toString());
      }
      return EventOperationalHealth.fromRpc(cached, isCached: true, cachedAt: cachedAt);
    }

    // 3. Fall back to empty/default operational state
    return EventOperationalHealth(
      eventId: eventId,
      computedAt: DateTime.now(),
      overallHealth: OperationalHealthState.healthy,
      healthSummary: 'No operational health data available.',
      isCached: true,
      cachedAt: DateTime.now(),
    );
  }

  @override
  Future<List<OperationalTimelineEntry>> getOperationalTimeline(String eventId, {int limit = 50, bool forceRefresh = false}) async {
    // 1. Try remote authoritative Supabase RPC
    try {
      final res = await _supabase.rpc(
        'get_event_operational_timeline',
        params: {
          'p_event_id': eventId,
          'p_limit': limit,
        },
      );

      if (res != null && res is List) {
        final list = <OperationalTimelineEntry>[];
        final rawMaps = <Map<String, dynamic>>[];
        for (final item in res) {
          if (item is Map) {
            final map = Map<String, dynamic>.from(item);
            rawMaps.add(map);
            list.add(OperationalTimelineEntry.fromJson(map));
          }
        }
        // Cache to SQLite
        await _queue.cacheOperationalTimeline(eventId, rawMaps);
        return list;
      }
    } catch (_) {}

    // 2. Fall back to local SQLite cache
    final cachedItems = await _queue.getCachedOperationalTimeline(eventId);
    if (cachedItems.isNotEmpty) {
      return cachedItems.map((m) => OperationalTimelineEntry.fromJson(m)).toList();
    }

    return [];
  }

  @override
  Future<EventOperationalSummary> getEventSummary(String eventId, String eventName, {DateTime? eventStartTime}) async {
    final health = await getOperationalHealth(eventId);
    
    // Determine peak occupancy zone
    String peakZone = 'None';
    int peakPct = 0;
    for (final z in health.zones) {
      if (z.occupancyPercent > peakPct) {
        peakPct = z.occupancyPercent;
        peakZone = z.zoneName;
      }
    }

    final now = DateTime.now();
    final start = eventStartTime ?? (now.subtract(const Duration(hours: 4)));
    final duration = now.difference(start);

    return EventOperationalSummary(
      eventId: eventId,
      eventName: eventName,
      duration: duration.isNegative ? Duration.zero : duration,
      peakOccupancyZone: peakZone,
      peakOccupancyPercent: peakPct,
      incidentsReported: health.totalIncidents,
      incidentsResolved: health.resolvedIncidents,
      incidentsOpen: health.activeIncidents,
      assistanceRequests: health.totalAssistance,
      assistanceResolved: health.resolvedAssistance,
      coverageRequested: health.totalCoverage,
      coverageFulfilled: health.acceptedCoverage,
      tasksCompleted: health.completedTasks,
      tasksPending: health.pendingTasks,
      avgIncidentResolution: ResponseTimeMetrics.formatSeconds(health.responseTimeMetrics.incidentAvgResolveSeconds),
      avgAssistanceResolution: ResponseTimeMetrics.formatSeconds(health.responseTimeMetrics.assistanceAvgResolveSeconds),
      avgCoverageAcceptance: ResponseTimeMetrics.formatSeconds(health.responseTimeMetrics.coverageAvgAcceptSeconds),
      isCached: health.isCached,
    );
  }

  /// Pure deterministic helper to derive operational health directly from a list of
  /// [OperationalAwarenessItem] and [EventZone] instances. Ideal for unit tests,
  /// offline live updates, and client-side reactive derivation.
  static EventOperationalHealth deriveLocalHealth({
    required String eventId,
    required List<OperationalAwarenessItem> awarenessItems,
    List<EventZone> zones = const [],
    bool isCached = false,
    DateTime? cachedAt,
  }) {
    int incidents = 0;
    int activeIncidents = 0;
    int urgentIncidents = 0;
    int resolvedIncidents = 0;
    final catMap = <String, int>{};

    int assistance = 0;
    int pendingAssistance = 0;
    int resolvedAssistance = 0;

    int coverage = 0;
    int pendingCoverage = 0;
    int acceptedCoverage = 0;

    int tasks = 0;
    int pendingTasks = 0;
    int completedTasks = 0;

    int urgentMessages = 0;
    int broadcasts = 0;

    for (final item in awarenessItems) {
      final isResolved = item.status == AttentionStatus.resolved;
      switch (item.category) {
        case AwarenessCategory.incident:
          incidents++;
          if (isResolved) {
            resolvedIncidents++;
          } else {
            activeIncidents++;
            if (item.priority == OperationalPriority.urgent) {
              urgentIncidents++;
            }
          }
          break;
        case AwarenessCategory.assistance:
          assistance++;
          if (isResolved) {
            resolvedAssistance++;
          } else {
            pendingAssistance++;
          }
          break;
        case AwarenessCategory.coverage:
          coverage++;
          if (isResolved) {
            acceptedCoverage++;
          } else {
            pendingCoverage++;
          }
          break;
        case AwarenessCategory.task:
          tasks++;
          if (isResolved) {
            completedTasks++;
          } else {
            pendingTasks++;
          }
          break;
        case AwarenessCategory.communication:
          if (item.priority == OperationalPriority.urgent) urgentMessages++;
          broadcasts++;
          break;
        default:
          break;
      }
    }

    final zoneHealths = <ZoneOperationalHealth>[];
    for (final z in zones) {
      final zoneIncidents = awarenessItems.where((i) => 
        i.category == AwarenessCategory.incident && 
        i.zoneName == z.name && 
        i.status != AttentionStatus.resolved
      ).length;
      final zoneTasks = awarenessItems.where((i) => 
        i.category == AwarenessCategory.task && 
        i.zoneName == z.name && 
        i.status != AttentionStatus.resolved
      ).length;
      final zoneCoverage = awarenessItems.any((i) => 
        i.category == AwarenessCategory.coverage && 
        i.zoneName == z.name && 
        i.status != AttentionStatus.resolved
      );

      zoneHealths.add(ZoneOperationalHealth(
        zoneId: z.id,
        zoneName: z.name,
        floorLevel: z.floorLevel,
        capacityLimit: z.capacityLimit,
        operatingCapacity: z.capacityLimit,
        currentDensity: z.currentDensity,
        isMonitored: true,
        activeIncidents: zoneIncidents,
        pendingTasks: zoneTasks,
        coverageNeeded: zoneCoverage,
      ));
    }

    OperationalHealthState overallHealth;
    String healthSummary;

    if (urgentIncidents > 0) {
      overallHealth = OperationalHealthState.criticalAttention;
      healthSummary = '$urgentIncidents urgent incident(s) requiring immediate intervention';
    } else if (activeIncidents >= 3 || pendingCoverage >= 2) {
      overallHealth = OperationalHealthState.operationalPressure;
      healthSummary = 'Elevated operational load across venue zones';
    } else if (activeIncidents > 0 || pendingCoverage > 0 || pendingTasks > 0) {
      overallHealth = OperationalHealthState.attentionNeeded;
      healthSummary = 'Action items pending volunteer or supervisor attention';
    } else {
      overallHealth = OperationalHealthState.healthy;
      healthSummary = 'All venue zones operating within safe parameters';
    }

    return EventOperationalHealth(
      eventId: eventId,
      computedAt: DateTime.now(),
      overallHealth: overallHealth,
      healthSummary: healthSummary,
      totalIncidents: incidents,
      activeIncidents: activeIncidents,
      urgentIncidents: urgentIncidents,
      resolvedIncidents: resolvedIncidents,
      incidentsByCategory: catMap,
      totalAssistance: assistance,
      pendingAssistance: pendingAssistance,
      resolvedAssistance: resolvedAssistance,
      totalCoverage: coverage,
      pendingCoverage: pendingCoverage,
      acceptedCoverage: acceptedCoverage,
      totalTasks: tasks,
      pendingTasks: pendingTasks,
      completedTasks: completedTasks,
      totalShifts: 1,
      activeStaff: 1,
      totalMessages: broadcasts,
      urgentMessages: urgentMessages,
      broadcasts: broadcasts,
      zones: zoneHealths,
      isCached: isCached,
      cachedAt: cachedAt,
    );
  }
}
