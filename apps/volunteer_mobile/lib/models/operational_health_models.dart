import 'operational_awareness_item.dart';

/// Deterministic operational health state of the event or a zone.
enum OperationalHealthState {
  healthy,
  attentionNeeded,
  operationalPressure,
  criticalAttention;

  String get label {
    switch (this) {
      case OperationalHealthState.healthy:
        return 'Healthy';
      case OperationalHealthState.attentionNeeded:
        return 'Attention Needed';
      case OperationalHealthState.operationalPressure:
        return 'Operational Pressure';
      case OperationalHealthState.criticalAttention:
        return 'Critical Attention';
    }
  }

  int get severityRank {
    switch (this) {
      case OperationalHealthState.healthy:
        return 0;
      case OperationalHealthState.attentionNeeded:
        return 1;
      case OperationalHealthState.operationalPressure:
        return 2;
      case OperationalHealthState.criticalAttention:
        return 3;
    }
  }
}

/// Operational health and capacity summary for a specific event zone.
class ZoneOperationalHealth {
  final String zoneId;
  final String zoneName;
  final int floorLevel;
  final int capacityLimit;
  final int operatingCapacity;
  final String currentDensity;
  final bool isMonitored;
  final int activeCount;
  final DateTime? countUpdatedAt;
  final int activeIncidents;
  final int pendingTasks;
  final int activeStaff;
  final bool coverageNeeded;

  const ZoneOperationalHealth({
    required this.zoneId,
    required this.zoneName,
    this.floorLevel = 1,
    this.capacityLimit = 200,
    this.operatingCapacity = 200,
    this.currentDensity = 'low',
    this.isMonitored = true,
    this.activeCount = 0,
    this.countUpdatedAt,
    this.activeIncidents = 0,
    this.pendingTasks = 0,
    this.activeStaff = 0,
    this.coverageNeeded = false,
  });

  int get effectiveCapacity => operatingCapacity > 0 ? operatingCapacity : (capacityLimit > 0 ? capacityLimit : 200);

  int get occupancyPercent {
    if (effectiveCapacity <= 0) return 0;
    return ((activeCount / effectiveCapacity) * 100).clamp(0, 200).round();
  }

  /// Canonical crowd condition matching Block 2 & 2.5D:
  /// <40% LOW, 40-79% MODERATE, 80-89% BUSY, >=90% NEAR CAPACITY
  String get crowdCondition {
    final pct = occupancyPercent;
    if (pct >= 90) return 'NEAR CAPACITY';
    if (pct >= 80) return 'BUSY';
    if (pct >= 40) return 'MODERATE';
    return 'LOW';
  }

  /// Canonical telemetry freshness: LIVE (<=60s), RECENT (<=180s), STALE (>180s), UNAVAILABLE (null)
  String get telemetryFreshness {
    if (countUpdatedAt == null) return 'UNAVAILABLE';
    final ageSeconds = DateTime.now().difference(countUpdatedAt!).inSeconds;
    if (ageSeconds <= 60) return 'LIVE';
    if (ageSeconds <= 180) return 'RECENT';
    return 'STALE';
  }

  /// Deterministic zone health classification
  OperationalHealthState get healthState {
    if (activeIncidents > 0 && (crowdCondition == 'NEAR CAPACITY' || occupancyPercent >= 90)) {
      return OperationalHealthState.criticalAttention;
    }
    if (crowdCondition == 'NEAR CAPACITY' || (activeIncidents >= 2) || (coverageNeeded && activeStaff == 0)) {
      return OperationalHealthState.operationalPressure;
    }
    if (crowdCondition == 'BUSY' || coverageNeeded || telemetryFreshness == 'STALE' || activeIncidents > 0) {
      return OperationalHealthState.attentionNeeded;
    }
    return OperationalHealthState.healthy;
  }

  factory ZoneOperationalHealth.fromJson(Map<String, dynamic> json) {
    return ZoneOperationalHealth(
      zoneId: json['zone_id']?.toString() ?? '',
      zoneName: json['zone_name']?.toString() ?? 'Unknown Zone',
      floorLevel: (json['floor_level'] as num?)?.toInt() ?? 1,
      capacityLimit: (json['capacity_limit'] as num?)?.toInt() ?? 200,
      operatingCapacity: (json['operating_capacity'] as num?)?.toInt() ?? 200,
      currentDensity: json['current_density']?.toString() ?? 'low',
      isMonitored: json['is_monitored'] as bool? ?? true,
      activeCount: (json['active_count'] as num?)?.toInt() ?? 0,
      countUpdatedAt: json['count_updated_at'] != null ? DateTime.tryParse(json['count_updated_at'].toString()) : null,
      activeIncidents: (json['active_incidents'] as num?)?.toInt() ?? 0,
      pendingTasks: (json['pending_tasks'] as num?)?.toInt() ?? 0,
      activeStaff: (json['active_staff'] as num?)?.toInt() ?? 0,
      coverageNeeded: json['coverage_needed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'zone_id': zoneId,
    'zone_name': zoneName,
    'floor_level': floorLevel,
    'capacity_limit': capacityLimit,
    'operating_capacity': operatingCapacity,
    'current_density': currentDensity,
    'is_monitored': isMonitored,
    'active_count': activeCount,
    'count_updated_at': countUpdatedAt?.toIso8601String(),
    'active_incidents': activeIncidents,
    'pending_tasks': pendingTasks,
    'active_staff': activeStaff,
    'coverage_needed': coverageNeeded,
  };
}

/// Operational response & resolution latency metrics.
class ResponseTimeMetrics {
  final int incidentAvgAcknowledgeSeconds;
  final int incidentAvgAssignSeconds;
  final int incidentAvgResolveSeconds;
  final int assistanceAvgResolveSeconds;
  final int coverageAvgAcceptSeconds;
  final int taskAvgCompleteSeconds;

  const ResponseTimeMetrics({
    this.incidentAvgAcknowledgeSeconds = 0,
    this.incidentAvgAssignSeconds = 0,
    this.incidentAvgResolveSeconds = 0,
    this.assistanceAvgResolveSeconds = 0,
    this.coverageAvgAcceptSeconds = 0,
    this.taskAvgCompleteSeconds = 0,
  });

  static String formatSeconds(int seconds) {
    if (seconds <= 0) return 'Unavailable';
    if (seconds < 60) return '${seconds}s';
    final minutes = seconds ~/ 60;
    final remainingSecs = seconds % 60;
    if (minutes < 60) {
      return remainingSecs > 0 ? '${minutes}m ${remainingSecs}s' : '${minutes}m';
    }
    final hours = minutes ~/ 60;
    final remainingMins = minutes % 60;
    return remainingMins > 0 ? '${hours}h ${remainingMins}m' : '${hours}h';
  }

  factory ResponseTimeMetrics.fromJson(Map<String, dynamic> json) {
    return ResponseTimeMetrics(
      incidentAvgAcknowledgeSeconds: (json['incident_avg_acknowledge_seconds'] as num?)?.toInt() ?? 0,
      incidentAvgAssignSeconds: (json['incident_avg_assign_seconds'] as num?)?.toInt() ?? 0,
      incidentAvgResolveSeconds: (json['incident_avg_resolve_seconds'] as num?)?.toInt() ?? 0,
      assistanceAvgResolveSeconds: (json['assistance_avg_resolve_seconds'] as num?)?.toInt() ?? 0,
      coverageAvgAcceptSeconds: (json['coverage_avg_accept_seconds'] as num?)?.toInt() ?? 0,
      taskAvgCompleteSeconds: (json['task_avg_complete_seconds'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'incident_avg_acknowledge_seconds': incidentAvgAcknowledgeSeconds,
    'incident_avg_assign_seconds': incidentAvgAssignSeconds,
    'incident_avg_resolve_seconds': incidentAvgResolveSeconds,
    'assistance_avg_resolve_seconds': assistanceAvgResolveSeconds,
    'coverage_avg_accept_seconds': coverageAvgAcceptSeconds,
    'task_avg_complete_seconds': taskAvgCompleteSeconds,
  };
}

/// Operational timeline milestone entry.
class OperationalTimelineEntry {
  final String id;
  final String sourceType; // 'incident', 'assistance', 'coverage', 'task', 'shift', 'communication', 'crowd', 'system'
  final String sourceId;
  final String eventType; // 'created', 'acknowledged', 'assigned', 'accepted', 'completed', 'resolved', 'started', 'broadcast'
  final String title;
  final String description;
  final DateTime timestamp;
  final String? zoneId;
  final String? zoneName;
  final String? actorName;
  final OperationalPriority priority;
  final String? actionRoute;
  final Map<String, dynamic>? actionPayload;

  const OperationalTimelineEntry({
    required this.id,
    required this.sourceType,
    required this.sourceId,
    required this.eventType,
    required this.title,
    required this.description,
    required this.timestamp,
    this.zoneId,
    this.zoneName,
    this.actorName,
    this.priority = OperationalPriority.normal,
    this.actionRoute,
    this.actionPayload,
  });

  factory OperationalTimelineEntry.fromJson(Map<String, dynamic> json) {
    OperationalPriority pri = OperationalPriority.normal;
    final priStr = json['priority']?.toString().toLowerCase();
    if (priStr == 'urgent') pri = OperationalPriority.urgent;
    if (priStr == 'important') pri = OperationalPriority.important;

    DateTime ts = DateTime.now();
    if (json['timestamp'] != null) {
      ts = DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now();
    }

    return OperationalTimelineEntry(
      id: json['id']?.toString() ?? '',
      sourceType: json['source_type']?.toString() ?? 'general',
      sourceId: json['source_id']?.toString() ?? '',
      eventType: json['event_type']?.toString() ?? 'event',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      timestamp: ts,
      zoneId: json['zone_id']?.toString(),
      zoneName: json['zone_name']?.toString(),
      actorName: json['actor_name']?.toString(),
      priority: pri,
      actionRoute: json['action_route']?.toString(),
      actionPayload: json['action_payload'] is Map ? Map<String, dynamic>.from(json['action_payload'] as Map) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'source_type': sourceType,
    'source_id': sourceId,
    'event_type': eventType,
    'title': title,
    'description': description,
    'timestamp': timestamp.toIso8601String(),
    'zone_id': zoneId,
    'zone_name': zoneName,
    'actor_name': actorName,
    'priority': priority.name,
    'action_route': actionRoute,
    'action_payload': actionPayload,
  };
}

/// Operational integrity and data quality issue indicator.
class DataIntegrityAlert {
  final String id;
  final String condition;
  final String severity; // 'info', 'warning', 'critical'
  final String message;
  final String? suggestedAction;

  const DataIntegrityAlert({
    required this.id,
    required this.condition,
    required this.severity,
    required this.message,
    this.suggestedAction,
  });
}

/// Complete aggregated operational health for the event.
class EventOperationalHealth {
  final String eventId;
  final DateTime computedAt;
  final OperationalHealthState overallHealth;
  final String healthSummary;
  final int totalIncidents;
  final int activeIncidents;
  final int urgentIncidents;
  final int resolvedIncidents;
  final Map<String, int> incidentsByCategory;
  final int totalAssistance;
  final int pendingAssistance;
  final int resolvedAssistance;
  final int totalCoverage;
  final int pendingCoverage;
  final int acceptedCoverage;
  final int totalTasks;
  final int pendingTasks;
  final int completedTasks;
  final int totalShifts;
  final int activeStaff;
  final int staffOnBreak;
  final int totalMessages;
  final int urgentMessages;
  final int broadcasts;
  final int lostFoundTotal;
  final int lostFoundActive;
  final List<ZoneOperationalHealth> zones;
  final ResponseTimeMetrics responseTimeMetrics;
  final List<DataIntegrityAlert> dataIntegrityAlerts;
  final bool isCached;
  final DateTime? cachedAt;

  const EventOperationalHealth({
    required this.eventId,
    required this.computedAt,
    required this.overallHealth,
    required this.healthSummary,
    this.totalIncidents = 0,
    this.activeIncidents = 0,
    this.urgentIncidents = 0,
    this.resolvedIncidents = 0,
    this.incidentsByCategory = const {},
    this.totalAssistance = 0,
    this.pendingAssistance = 0,
    this.resolvedAssistance = 0,
    this.totalCoverage = 0,
    this.pendingCoverage = 0,
    this.acceptedCoverage = 0,
    this.totalTasks = 0,
    this.pendingTasks = 0,
    this.completedTasks = 0,
    this.totalShifts = 0,
    this.activeStaff = 0,
    this.staffOnBreak = 0,
    this.totalMessages = 0,
    this.urgentMessages = 0,
    this.broadcasts = 0,
    this.lostFoundTotal = 0,
    this.lostFoundActive = 0,
    this.zones = const [],
    this.responseTimeMetrics = const ResponseTimeMetrics(),
    this.dataIntegrityAlerts = const [],
    this.isCached = false,
    this.cachedAt,
  });

  /// Factory constructor parsing the authoritative Supabase RPC JSON output
  factory EventOperationalHealth.fromRpc(Map<String, dynamic> json, {bool isCached = false, DateTime? cachedAt}) {
    final eventId = json['event_id']?.toString() ?? '';
    final computedAt = json['computed_at'] != null 
        ? DateTime.tryParse(json['computed_at'].toString()) ?? DateTime.now() 
        : DateTime.now();

    final inc = json['incidents'] is Map ? json['incidents'] as Map<String, dynamic> : <String, dynamic>{};
    final ast = json['assistance'] is Map ? json['assistance'] as Map<String, dynamic> : <String, dynamic>{};
    final cov = json['coverage'] is Map ? json['coverage'] as Map<String, dynamic> : <String, dynamic>{};
    final tsk = json['tasks'] is Map ? json['tasks'] as Map<String, dynamic> : <String, dynamic>{};
    final shf = json['shifts'] is Map ? json['shifts'] as Map<String, dynamic> : <String, dynamic>{};
    final msg = json['communications'] is Map ? json['communications'] as Map<String, dynamic> : <String, dynamic>{};
    final lf = json['lost_found'] is Map ? json['lost_found'] as Map<String, dynamic> : <String, dynamic>{};

    final zonesList = <ZoneOperationalHealth>[];
    if (json['zones'] is List) {
      for (final item in json['zones'] as List) {
        if (item is Map) {
          zonesList.add(ZoneOperationalHealth.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    final catMap = <String, int>{};
    if (inc['by_category'] is Map) {
      (inc['by_category'] as Map).forEach((k, v) {
        catMap[k.toString()] = (v as num?)?.toInt() ?? 0;
      });
    }

    final respMetrics = ResponseTimeMetrics(
      incidentAvgAcknowledgeSeconds: (inc['avg_time_to_acknowledge_seconds'] as num?)?.toInt() ?? 0,
      incidentAvgAssignSeconds: (inc['avg_time_to_assign_seconds'] as num?)?.toInt() ?? 0,
      incidentAvgResolveSeconds: (inc['avg_time_to_resolve_seconds'] as num?)?.toInt() ?? 0,
      assistanceAvgResolveSeconds: (ast['avg_time_to_resolve_seconds'] as num?)?.toInt() ?? 0,
      coverageAvgAcceptSeconds: (cov['avg_time_to_accept_seconds'] as num?)?.toInt() ?? 0,
      taskAvgCompleteSeconds: (tsk['avg_time_to_complete_seconds'] as num?)?.toInt() ?? 0,
    );

    final activeIncidents = (inc['active'] as num?)?.toInt() ?? 0;
    final urgentIncidents = (inc['urgent'] as num?)?.toInt() ?? 0;
    final pendingCoverage = (cov['pending'] as num?)?.toInt() ?? 0;
    final pendingTasks = (tsk['pending'] as num?)?.toInt() ?? 0;
    final activeStaff = (shf['active'] as num?)?.toInt() ?? 0;

    // Detect data integrity conditions
    final alerts = <DataIntegrityAlert>[];
    int nearCapacityCount = 0;
    int busyCount = 0;
    int staleTelemetryCount = 0;

    for (final z in zonesList) {
      if (z.crowdCondition == 'NEAR CAPACITY') nearCapacityCount++;
      if (z.crowdCondition == 'BUSY') busyCount++;
      if (z.isMonitored && z.telemetryFreshness == 'STALE') {
        staleTelemetryCount++;
        alerts.add(DataIntegrityAlert(
          id: 'stale_crowd_${z.zoneId}',
          condition: 'STALE_CROWD_TELEMETRY',
          severity: 'warning',
          message: 'Crowd telemetry for ${z.zoneName} has not updated in over 3 minutes.',
          suggestedAction: 'Verify volunteer BLE scanner is active in zone.',
        ));
      }
    }

    if (urgentIncidents > 0) {
      alerts.add(DataIntegrityAlert(
        id: 'urgent_incidents_active',
        condition: 'URGENT_INCIDENT_ACTIVE',
        severity: 'critical',
        message: '$urgentIncidents urgent operational incident(s) require immediate response.',
        suggestedAction: 'Deploy crowd control or medical volunteers to location.',
      ));
    }

    if (pendingCoverage > 0 && activeStaff <= pendingCoverage) {
      alerts.add(DataIntegrityAlert(
        id: 'staffing_deficit',
        condition: 'STAFFING_DEFICIT',
        severity: 'warning',
        message: '$pendingCoverage relief request(s) pending with limited standby staff.',
        suggestedAction: 'Notify supervisor to reallocate roving staff.',
      ));
    }

    // Determine authoritative health state
    OperationalHealthState overallHealth;
    String healthSummary;

    if (urgentIncidents > 0 || nearCapacityCount > 0) {
      overallHealth = OperationalHealthState.criticalAttention;
      healthSummary = urgentIncidents > 0 
          ? '$urgentIncidents urgent incident(s) requiring immediate intervention'
          : '$nearCapacityCount zone(s) near critical operating capacity';
    } else if (busyCount >= 2 || (activeIncidents + pendingCoverage) >= 3) {
      overallHealth = OperationalHealthState.operationalPressure;
      healthSummary = 'Elevated operational load across venue zones';
    } else if (activeIncidents > 0 || pendingCoverage > 0 || staleTelemetryCount > 0 || pendingTasks > 0) {
      overallHealth = OperationalHealthState.attentionNeeded;
      healthSummary = 'Action items pending volunteer or supervisor attention';
    } else {
      overallHealth = OperationalHealthState.healthy;
      healthSummary = 'All venue zones operating within safe parameters';
    }

    return EventOperationalHealth(
      eventId: eventId,
      computedAt: computedAt,
      overallHealth: overallHealth,
      healthSummary: healthSummary,
      totalIncidents: (inc['total'] as num?)?.toInt() ?? 0,
      activeIncidents: activeIncidents,
      urgentIncidents: urgentIncidents,
      resolvedIncidents: (inc['resolved'] as num?)?.toInt() ?? 0,
      incidentsByCategory: catMap,
      totalAssistance: (ast['total'] as num?)?.toInt() ?? 0,
      pendingAssistance: (ast['pending'] as num?)?.toInt() ?? 0,
      resolvedAssistance: (ast['resolved'] as num?)?.toInt() ?? 0,
      totalCoverage: (cov['total'] as num?)?.toInt() ?? 0,
      pendingCoverage: pendingCoverage,
      acceptedCoverage: (cov['accepted'] as num?)?.toInt() ?? 0,
      totalTasks: (tsk['total'] as num?)?.toInt() ?? 0,
      pendingTasks: pendingTasks,
      completedTasks: (tsk['completed'] as num?)?.toInt() ?? 0,
      totalShifts: (shf['total'] as num?)?.toInt() ?? 0,
      activeStaff: activeStaff,
      staffOnBreak: (shf['on_break'] as num?)?.toInt() ?? 0,
      totalMessages: (msg['total_messages'] as num?)?.toInt() ?? 0,
      urgentMessages: (msg['urgent'] as num?)?.toInt() ?? 0,
      broadcasts: (msg['broadcasts'] as num?)?.toInt() ?? 0,
      lostFoundTotal: (lf['total'] as num?)?.toInt() ?? 0,
      lostFoundActive: (lf['active'] as num?)?.toInt() ?? 0,
      zones: zonesList,
      responseTimeMetrics: respMetrics,
      dataIntegrityAlerts: alerts,
      isCached: isCached,
      cachedAt: cachedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'event_id': eventId,
    'computed_at': computedAt.toIso8601String(),
    'overall_health': overallHealth.name,
    'health_summary': healthSummary,
    'total_incidents': totalIncidents,
    'active_incidents': activeIncidents,
    'urgent_incidents': urgentIncidents,
    'resolved_incidents': resolvedIncidents,
    'incidents_by_category': incidentsByCategory,
    'total_assistance': totalAssistance,
    'pending_assistance': pendingAssistance,
    'resolved_assistance': resolvedAssistance,
    'total_coverage': totalCoverage,
    'pending_coverage': pendingCoverage,
    'accepted_coverage': acceptedCoverage,
    'total_tasks': totalTasks,
    'pending_tasks': pendingTasks,
    'completed_tasks': completedTasks,
    'total_shifts': totalShifts,
    'active_staff': activeStaff,
    'staff_on_break': staffOnBreak,
    'total_messages': totalMessages,
    'urgent_messages': urgentMessages,
    'broadcasts': broadcasts,
    'lost_found_total': lostFoundTotal,
    'lost_found_active': lostFoundActive,
    'zones': zones.map((z) => z.toJson()).toList(),
    'response_time_metrics': responseTimeMetrics.toJson(),
    'is_cached': isCached,
    'cached_at': cachedAt?.toIso8601String(),
  };
}

/// Comprehensive high-level operational summary of an event.
class EventOperationalSummary {
  final String eventId;
  final String eventName;
  final Duration duration;
  final String peakOccupancyZone;
  final int peakOccupancyPercent;
  final int incidentsReported;
  final int incidentsResolved;
  final int incidentsOpen;
  final int assistanceRequests;
  final int assistanceResolved;
  final int coverageRequested;
  final int coverageFulfilled;
  final int tasksCompleted;
  final int tasksPending;
  final String avgIncidentResolution;
  final String avgAssistanceResolution;
  final String avgCoverageAcceptance;
  final bool isCached;

  const EventOperationalSummary({
    required this.eventId,
    required this.eventName,
    required this.duration,
    required this.peakOccupancyZone,
    required this.peakOccupancyPercent,
    required this.incidentsReported,
    required this.incidentsResolved,
    required this.incidentsOpen,
    required this.assistanceRequests,
    required this.assistanceResolved,
    required this.coverageRequested,
    required this.coverageFulfilled,
    required this.tasksCompleted,
    required this.tasksPending,
    required this.avgIncidentResolution,
    required this.avgAssistanceResolution,
    required this.avgCoverageAcceptance,
    this.isCached = false,
  });
}
