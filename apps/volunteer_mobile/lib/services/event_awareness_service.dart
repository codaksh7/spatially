import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/operational_awareness_item.dart';
import 'session_state.dart';
import 'observation_queue.dart';
import 'haptic_attention_service.dart';

/// Summary metrics derived from the current operational awareness state.
class OperationalAwarenessSummary {
  final int activeIncidentsCount;
  final int busyZonesCount;
  final int pendingAssistanceCount;
  final int pendingTasksCount;
  final int coverageNeededCount;
  final int attentionRequiredCount;

  const OperationalAwarenessSummary({
    this.activeIncidentsCount = 0,
    this.busyZonesCount = 0,
    this.pendingAssistanceCount = 0,
    this.pendingTasksCount = 0,
    this.coverageNeededCount = 0,
    this.attentionRequiredCount = 0,
  });
}

/// Core service for Spatially Volunteer Block 2.5D: Event Awareness & Zone Operations.
///
/// Normalizes multi-source operational signals (crowd metrics, incidents, assistance,
/// coverage, supervisor tasks, broadcasts, system state) into a unified, deterministic
/// awareness model with pocket-friendly haptic attention, strict deduplication,
/// and honest offline caching.
class EventAwarenessService {
  EventAwarenessService._();
  static final EventAwarenessService _instance = EventAwarenessService._();
  static EventAwarenessService get instance => _instance;

  SupabaseClient? client;
  SupabaseClient get _supabase => client ?? Supabase.instance.client;
  RealtimeChannel? _realtimeChannel;

  final List<OperationalAwarenessItem> _items = [];
  final StreamController<List<OperationalAwarenessItem>> _itemsController =
      StreamController<List<OperationalAwarenessItem>>.broadcast();
  final StreamController<OperationalAwarenessSummary> _summaryController =
      StreamController<OperationalAwarenessSummary>.broadcast();

  String? _currentEventId;
  bool _isOffline = false;

  String? get currentEventId => _currentEventId;
  bool get isOffline => _isOffline;

  Stream<List<OperationalAwarenessItem>> get itemsStream => _itemsController.stream;
  Stream<OperationalAwarenessSummary> get summaryStream => _summaryController.stream;

  List<OperationalAwarenessItem> get allItems => List.unmodifiable(_items);

  /// Items that require immediate volunteer attention (unresolved Important & Urgent).
  List<OperationalAwarenessItem> get attentionRequiredItems {
    return _items.where((i) => i.requiresAttention).toList();
  }

  /// Calculates the current awareness summary metrics.
  OperationalAwarenessSummary get summary {
    int incidents = 0;
    int busyZones = 0;
    int assistance = 0;
    int tasks = 0;
    int coverage = 0;
    int attention = 0;

    for (final item in _items) {
      if (item.requiresAttention) {
        attention++;
      }
      if (item.status != AttentionStatus.resolved) {
        switch (item.category) {
          case AwarenessCategory.incident:
            incidents++;
            break;
          case AwarenessCategory.crowd:
            if (item.priority != OperationalPriority.normal) {
              busyZones++;
            }
            break;
          case AwarenessCategory.assistance:
            assistance++;
            break;
          case AwarenessCategory.task:
            tasks++;
            break;
          case AwarenessCategory.coverage:
            coverage++;
            break;
          default:
            break;
        }
      }
    }

    return OperationalAwarenessSummary(
      activeIncidentsCount: incidents,
      busyZonesCount: busyZones,
      pendingAssistanceCount: assistance,
      pendingTasksCount: tasks,
      coverageNeededCount: coverage,
      attentionRequiredCount: attention,
    );
  }

  // ---------------------------------------------------------------------------
  // Lifecycle & Initialization
  // ---------------------------------------------------------------------------

  /// Initializes awareness for an event, loading offline cache first then syncing live.
  Future<void> initialize({required String eventId, String? volunteerId}) async {
    _currentEventId = eventId;
    final vId = volunteerId ?? SessionState.instance.volunteerId ?? 'anonymous';

    // 1. Load cached items from SQLite first for instant display
    try {
      final cached = await ObservationQueue().getCachedAwarenessItems(
        eventId: eventId,
        volunteerId: vId,
      );
      if (cached.isNotEmpty) {
        _items.clear();
        _items.addAll(cached);
        _notifyListeners();
      }
    } catch (e) {
      debugPrint('EventAwarenessService: Error loading offline cache: $e');
    }

    // 2. Fetch live data from backend
    await refreshLiveAwareness(eventId: eventId);

    // 3. Subscribe to Realtime CDC stream
    subscribeRealtime(eventId: eventId);
  }

  /// Refreshes all awareness domains from live tables.
  Future<void> refreshLiveAwareness({required String eventId}) async {
    try {
      final List<OperationalAwarenessItem> liveItems = [];

      // A. Incidents & Assistance
      final incidentItems = await _fetchIncidentAwareness(eventId);
      liveItems.addAll(incidentItems);

      // B. Supervisor Tasks
      final taskItems = await _fetchTaskAwareness(eventId);
      liveItems.addAll(taskItems);

      // C. Relief / Coverage Requests
      final coverageItems = await _fetchCoverageAwareness(eventId);
      liveItems.addAll(coverageItems);

      // D. Active Shifts & Breaks
      final shiftItems = await _fetchShiftAwareness(eventId);
      liveItems.addAll(shiftItems);

      // E. Broadcast & Urgent Communications
      final commItems = await _fetchCommunicationAwareness(eventId);
      liveItems.addAll(commItems);

      // F. Crowd Capacity & Busy Zones
      final crowdItems = await _fetchCrowdAwareness(eventId);
      liveItems.addAll(crowdItems);

      // Merge into local collection and sort by timestamp DESC
      _items.clear();
      _items.addAll(liveItems);
      _items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      _isOffline = false;

      // Cache to SQLite for offline resilience
      final vId = SessionState.instance.volunteerId ?? 'anonymous';
      await ObservationQueue().cacheAwarenessItems(
        eventId: eventId,
        volunteerId: vId,
        items: _items,
      );

      _notifyListeners();
    } catch (e) {
      debugPrint('EventAwarenessService: Live refresh failed (device may be offline): $e');
      _isOffline = true;
      // Mark current memory items as cached
      for (int i = 0; i < _items.length; i++) {
        _items[i] = _items[i].copyWith(isCached: true);
      }
      _notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Data Domain Ingestion & Normalization
  // ---------------------------------------------------------------------------

  Future<List<OperationalAwarenessItem>> _fetchIncidentAwareness(String eventId) async {
    try {
      final res = await _supabase
          .from('operational_incidents')
          .select()
          .eq('event_id', eventId)
          .neq('status', 'closed')
          .order('created_at', ascending: false)
          .limit(20);

      final List<OperationalAwarenessItem> items = [];
      for (final r in (res as List)) {
        final item = normalizeIncident(r as Map<String, dynamic>);
        items.add(item);
      }
      return items;
    } catch (_) {
      return [];
    }
  }

  Future<List<OperationalAwarenessItem>> _fetchTaskAwareness(String eventId) async {
    try {
      final res = await _supabase
          .from('supervisor_tasks')
          .select()
          .eq('event_id', eventId)
          .neq('status', 'completed')
          .neq('status', 'cancelled')
          .order('created_at', ascending: false)
          .limit(15);

      final List<OperationalAwarenessItem> items = [];
      for (final r in (res as List)) {
        final item = normalizeTask(r as Map<String, dynamic>);
        items.add(item);
      }
      return items;
    } catch (_) {
      return [];
    }
  }

  Future<List<OperationalAwarenessItem>> _fetchCoverageAwareness(String eventId) async {
    try {
      final res = await _supabase
          .from('coverage_requests')
          .select()
          .eq('event_id', eventId)
          .eq('status', 'pending')
          .order('created_at', ascending: false)
          .limit(10);

      final List<OperationalAwarenessItem> items = [];
      for (final r in (res as List)) {
        final item = normalizeCoverage(r as Map<String, dynamic>);
        items.add(item);
      }
      return items;
    } catch (_) {
      return [];
    }
  }

  Future<List<OperationalAwarenessItem>> _fetchShiftAwareness(String eventId) async {
    try {
      final res = await _supabase
          .from('volunteer_shifts')
          .select()
          .eq('event_id', eventId)
          .inFilter('status', ['active', 'on_break', 'handoff_pending'])
          .order('updated_at', ascending: false)
          .limit(10);

      final List<OperationalAwarenessItem> items = [];
      for (final r in (res as List)) {
        final item = normalizeShift(r as Map<String, dynamic>);
        if (item != null) items.add(item);
      }
      return items;
    } catch (_) {
      return [];
    }
  }

  Future<List<OperationalAwarenessItem>> _fetchCommunicationAwareness(String eventId) async {
    try {
      final res = await _supabase
          .from('operational_messages')
          .select()
          .eq('event_id', eventId)
          .inFilter('priority', ['important', 'urgent'])
          .order('created_at', ascending: false)
          .limit(10);

      final List<OperationalAwarenessItem> items = [];
      for (final r in (res as List)) {
        final item = normalizeMessage(r as Map<String, dynamic>);
        items.add(item);
      }
      return items;
    } catch (_) {
      return [];
    }
  }

  Future<List<OperationalAwarenessItem>> _fetchCrowdAwareness(String eventId) async {
    try {
      final res = await _supabase
          .from('volunteer_counts')
          .select()
          .eq('event_id', eventId);

      // Also get event_zones for capacity comparison
      final zonesRes = await _supabase
          .from('event_zones')
          .select('id, venue_zone_id, operating_capacity, venue_zones(code, name)')
          .eq('event_id', eventId);

      final Map<String, Map<String, dynamic>> zoneMeta = {};
      for (final z in (zonesRes as List)) {
        final vz = z['venue_zones'] as Map<String, dynamic>?;
        final code = vz?['code']?.toString() ?? '';
        final name = vz?['name']?.toString() ?? 'Zone $code';
        final cap = z['operating_capacity'] as int? ?? 100;
        zoneMeta[code] = {'id': z['id'], 'name': name, 'capacity': cap};
      }

      final List<OperationalAwarenessItem> items = [];
      for (final r in (res as List)) {
        final zoneCode = r['zone'] as String? ?? '';
        final activeCount = r['active_count'] as int? ?? 0;
        final updatedAt = DateTime.tryParse(r['updated_at'] as String? ?? '') ?? DateTime.now();
        final meta = zoneMeta[zoneCode];
        final capacity = meta?['capacity'] as int? ?? 100;
        final zoneName = meta?['name'] as String? ?? 'Zone $zoneCode';
        final zoneId = meta?['id'] as String?;

        final item = normalizeCrowdCount(
          zoneCode: zoneCode,
          zoneName: zoneName,
          zoneId: zoneId,
          activeCount: activeCount,
          capacity: capacity,
          updatedAt: updatedAt,
        );
        if (item != null) items.add(item);
      }
      return items;
    } catch (_) {
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Normalization Helpers & Deterministic Relevance
  // ---------------------------------------------------------------------------

  OperationalAwarenessItem normalizeIncident(Map<String, dynamic> r) {
    final id = r['id'] as String;
    final title = r['title'] as String? ?? 'Operational Incident';
    final desc = r['description'] as String? ?? '';
    final categoryStr = r['category'] as String? ?? 'general';
    final priorityStr = r['priority'] as String? ?? 'normal';
    final statusStr = r['status'] as String? ?? 'open';
    final zoneId = r['zone_id'] as String?;
    final zoneName = r['venue_zone_name'] as String? ?? r['specific_location'] as String?;
    final createdAt = DateTime.tryParse(r['created_at'] as String? ?? '') ?? DateTime.now();

    final priority = OperationalPriority.fromString(priorityStr);
    final category = (categoryStr == 'attendee_help' || categoryStr == 'medical' || categoryStr == 'accessibility')
        ? AwarenessCategory.assistance
        : (categoryStr == 'safety' ? AwarenessCategory.safety : AwarenessCategory.incident);

    final relevance = determineRelevance(
      zoneId: zoneId,
      priority: priority,
    );

    final status = statusStr == 'resolved' || statusStr == 'closed'
        ? AttentionStatus.resolved
        : (statusStr == 'in_progress' ? AttentionStatus.acknowledged : AttentionStatus.new_);

    return OperationalAwarenessItem(
      id: 'incident_$id',
      sourceId: id,
      category: category,
      priority: priority,
      relevance: relevance,
      status: status,
      title: title,
      message: desc,
      timestamp: createdAt,
      zoneId: zoneId,
      zoneName: zoneName,
      actionRoute: 'incident_detail',
      actionPayload: {'incidentId': id},
    );
  }

  OperationalAwarenessItem normalizeTask(Map<String, dynamic> r) {
    final id = r['id'] as String;
    final title = r['title'] as String? ?? 'Operational Task';
    final desc = r['description'] as String? ?? '';
    final priorityStr = r['priority'] as String? ?? 'normal';
    final statusStr = r['status'] as String? ?? 'assigned';
    final zoneId = r['zone_id'] as String?;
    final zoneName = r['zone_name'] as String?;
    final teamId = r['team_id'] as String?;
    final teamName = r['team_name'] as String?;
    final assignedToId = r['assigned_to_id'] as String?;
    final createdAt = DateTime.tryParse(r['created_at'] as String? ?? '') ?? DateTime.now();

    final priority = OperationalPriority.fromString(priorityStr);
    final relevance = determineRelevance(
      zoneId: zoneId,
      teamId: teamId,
      assignedVolunteerId: assignedToId,
      priority: priority,
    );

    final status = statusStr == 'completed'
        ? AttentionStatus.resolved
        : (statusStr == 'in_progress' || statusStr == 'accepted'
            ? AttentionStatus.acknowledged
            : AttentionStatus.new_);

    return OperationalAwarenessItem(
      id: 'task_$id',
      sourceId: id,
      category: AwarenessCategory.task,
      priority: priority,
      relevance: relevance,
      status: status,
      title: title,
      message: desc,
      timestamp: createdAt,
      zoneId: zoneId,
      zoneName: zoneName,
      teamId: teamId,
      teamName: teamName,
      actionRoute: 'supervisor_tasks',
      actionPayload: {'taskId': id},
    );
  }

  OperationalAwarenessItem normalizeCoverage(Map<String, dynamic> r) {
    final id = r['id'] as String;
    final reason = r['reason'] as String? ?? 'Relief Required';
    final notes = r['notes'] as String? ?? 'Volunteer requires station relief';
    final priorityStr = r['priority'] as String? ?? 'normal';
    final statusStr = r['status'] as String? ?? 'pending';
    final zoneId = r['zone_id'] as String?;
    final zoneName = r['zone_name'] as String?;
    final teamId = r['team_id'] as String?;
    final teamName = r['team_name'] as String?;
    final createdAt = DateTime.tryParse(r['created_at'] as String? ?? '') ?? DateTime.now();

    final priority = OperationalPriority.fromString(priorityStr);
    final relevance = determineRelevance(
      zoneId: zoneId,
      teamId: teamId,
      priority: priority,
    );

    final status = statusStr == 'accepted' || statusStr == 'resolved'
        ? AttentionStatus.resolved
        : AttentionStatus.new_;

    return OperationalAwarenessItem(
      id: 'coverage_$id',
      sourceId: id,
      category: AwarenessCategory.coverage,
      priority: priority,
      relevance: relevance,
      status: status,
      title: 'Coverage: $reason',
      message: zoneName != null ? '$notes ($zoneName)' : notes,
      timestamp: createdAt,
      zoneId: zoneId,
      zoneName: zoneName,
      teamId: teamId,
      teamName: teamName,
      actionRoute: 'team_overview',
      actionPayload: {'requestId': id},
    );
  }

  OperationalAwarenessItem? normalizeShift(Map<String, dynamic> r) {
    final id = r['id'] as String;
    final shiftName = r['shift_name'] as String? ?? 'Operational Shift';
    final statusStr = r['status'] as String? ?? 'scheduled';
    final breakState = r['break_state'] as String? ?? 'none';
    final volunteerName = r['volunteer_name'] as String? ?? 'Staff';
    final teamId = r['team_id'] as String?;
    final teamName = r['team_name'] as String?;
    final zoneId = r['zone_id'] as String?;
    final zoneName = r['zone_name'] as String?;
    final updatedAt = DateTime.tryParse(r['updated_at'] as String? ?? '') ?? DateTime.now();

    // Only surface notable state changes (on break, handoff pending)
    if (breakState != 'on_break' && statusStr != 'handoff_pending') {
      return null;
    }

    final priority = statusStr == 'handoff_pending'
        ? OperationalPriority.important
        : OperationalPriority.normal;

    final relevance = determineRelevance(
      zoneId: zoneId,
      teamId: teamId,
      priority: priority,
    );

    final title = statusStr == 'handoff_pending'
        ? 'Shift Turnover Pending: $shiftName'
        : '$volunteerName is on break';
    final message = statusStr == 'handoff_pending'
        ? 'Shift handoff briefing ready for incoming volunteer'
        : 'Team $teamName temporary coverage may be required';

    return OperationalAwarenessItem(
      id: 'shift_${id}_$breakState',
      sourceId: id,
      category: AwarenessCategory.shift,
      priority: priority,
      relevance: relevance,
      status: AttentionStatus.new_,
      title: title,
      message: message,
      timestamp: updatedAt,
      zoneId: zoneId,
      zoneName: zoneName,
      teamId: teamId,
      teamName: teamName,
      actionRoute: 'shift_overview',
      actionPayload: {'shiftId': id},
    );
  }

  OperationalAwarenessItem normalizeMessage(Map<String, dynamic> r) {
    final id = r['id'] as String;
    final senderName = r['sender_name'] as String? ?? 'Operations';
    final senderRole = r['sender_role'] as String? ?? 'Staff';
    final priorityStr = r['priority'] as String? ?? 'normal';
    final body = r['body'] as String? ?? '';
    final createdAt = DateTime.tryParse(r['created_at'] as String? ?? '') ?? DateTime.now();

    final priority = OperationalPriority.fromString(priorityStr);
    final relevance = priority == OperationalPriority.urgent
        ? OperationalRelevance.eventWideUrgent
        : OperationalRelevance.eventWideImportant;

    return OperationalAwarenessItem(
      id: 'msg_$id',
      sourceId: id,
      category: AwarenessCategory.communication,
      priority: priority,
      relevance: relevance,
      status: AttentionStatus.new_,
      title: 'Broadcast ($senderRole $senderName)',
      message: body,
      timestamp: createdAt,
      actionRoute: 'communications',
      actionPayload: {'messageId': id},
    );
  }

  OperationalAwarenessItem? normalizeCrowdCount({
    required String zoneCode,
    required String zoneName,
    required String? zoneId,
    required int activeCount,
    required int capacity,
    required DateTime updatedAt,
  }) {
    if (capacity <= 0) return null;

    final ratio = activeCount / capacity;
    final percent = (ratio * 100).round();
    final isStale = DateTime.now().difference(updatedAt).inSeconds > 45;

    // Only surface notable thresholds (>=80% Busy, >=90% Near Capacity)
    if (ratio < 0.80) return null;

    final isNearCap = ratio >= 0.90;
    final priority = isNearCap ? OperationalPriority.urgent : OperationalPriority.important;

    final relevance = determineRelevance(
      zoneId: zoneId,
      zoneCode: zoneCode,
      priority: priority,
    );

    return OperationalAwarenessItem(
      id: 'crowd_${zoneCode}_${isNearCap ? 'cap' : 'busy'}',
      sourceId: zoneCode,
      category: AwarenessCategory.crowd,
      priority: priority,
      relevance: relevance,
      status: AttentionStatus.new_,
      title: '$zoneName: $percent% Density',
      message: isNearCap
          ? 'Near maximum capacity ($activeCount / $capacity). Flow control advised.'
          : 'High crowd volume ($activeCount / $capacity). Queue monitor advised.',
      timestamp: updatedAt,
      zoneId: zoneId,
      zoneName: zoneName,
      zoneCode: zoneCode,
      isStale: isStale,
      actionRoute: 'scanner',
    );
  }

  /// System-level awareness (e.g. Bluetooth turned off or scanner stopped).
  void recordSystemAlert({
    required String key,
    required String title,
    required String message,
    OperationalPriority priority = OperationalPriority.important,
  }) {
    final item = OperationalAwarenessItem(
      id: 'sys_$key',
      sourceId: key,
      category: AwarenessCategory.system,
      priority: priority,
      relevance: OperationalRelevance.myZone,
      status: AttentionStatus.new_,
      title: title,
      message: message,
      timestamp: DateTime.now(),
      actionRoute: 'scanner',
    );

    ingestAwarenessItem(item);
  }

  /// Ingests a single item into the active awareness stream and triggers haptics if appropriate.
  Future<void> ingestAwarenessItem(OperationalAwarenessItem item, {bool isNew = true}) async {
    // Avoid exact duplicate IDs in active list
    final idx = _items.indexWhere((i) => i.id == item.id);
    if (idx >= 0) {
      _items[idx] = item;
    } else {
      _items.insert(0, item);
    }

    _notifyListeners();

    // Trigger haptic attention for actionable items
    if (item.requiresAttention && isNew && !item.isCached) {
      await HapticAttentionService.instance.triggerAttention(
        itemKey: item.attentionKey,
        priority: item.priority,
        isNew: true,
      );
    }
  }

  /// Deterministic relevance calculation matching the volunteer's current session state.
  OperationalRelevance determineRelevance({
    String? zoneId,
    String? zoneCode,
    String? teamId,
    String? assignedVolunteerId,
    required OperationalPriority priority,
  }) {
    final myZoneId = SessionState.instance.zoneId;
    final myZoneCode = SessionState.instance.zoneCode;
    final myTeamId = SessionState.instance.teamId;
    final myVolunteerId = SessionState.instance.volunteerId;

    // 1. Direct assignment to this volunteer
    if (assignedVolunteerId != null && assignedVolunteerId == myVolunteerId) {
      return OperationalRelevance.myZone;
    }

    // 2. Zone match (highest operational relevance)
    if (zoneId != null && myZoneId != null && zoneId == myZoneId) {
      return OperationalRelevance.myZone;
    }
    if (zoneCode != null && myZoneCode != null && zoneCode == myZoneCode) {
      return OperationalRelevance.myZone;
    }

    // 3. Team match (high relevance)
    if (teamId != null && myTeamId != null && teamId == myTeamId) {
      return OperationalRelevance.myTeam;
    }

    // 4. Event-wide urgency hierarchy
    if (priority == OperationalPriority.urgent) {
      return OperationalRelevance.eventWideUrgent;
    }
    if (priority == OperationalPriority.important) {
      return OperationalRelevance.eventWideImportant;
    }

    return OperationalRelevance.unrelatedNormal;
  }

  // ---------------------------------------------------------------------------
  // Attention Lifecycle Actions
  // ---------------------------------------------------------------------------

  void markAttentionSeen(String itemId) {
    final idx = _items.indexWhere((i) => i.id == itemId);
    if (idx >= 0) {
      final cur = _items[idx];
      if (cur.status == AttentionStatus.new_) {
        _items[idx] = cur.copyWith(status: AttentionStatus.seen);
        HapticAttentionService.instance.markHandled(cur.attentionKey);
        _notifyListeners();
      }
    }
  }

  void acknowledgeAttention(String itemId) {
    final idx = _items.indexWhere((i) => i.id == itemId);
    if (idx >= 0) {
      final cur = _items[idx];
      _items[idx] = cur.copyWith(status: AttentionStatus.acknowledged);
      HapticAttentionService.instance.markHandled(cur.attentionKey);
      _notifyListeners();
    }
  }

  void resolveAttention(String itemId) {
    final idx = _items.indexWhere((i) => i.id == itemId);
    if (idx >= 0) {
      final cur = _items[idx];
      _items[idx] = cur.copyWith(status: AttentionStatus.resolved);
      HapticAttentionService.instance.markHandled(cur.attentionKey);
      _notifyListeners();
    }
  }

  void markAllSeen() {
    for (int i = 0; i < _items.length; i++) {
      if (_items[i].status == AttentionStatus.new_) {
        _items[i] = _items[i].copyWith(status: AttentionStatus.seen);
        HapticAttentionService.instance.markHandled(_items[i].attentionKey);
      }
    }
    _notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Realtime Subscriptions
  // ---------------------------------------------------------------------------

  void subscribeRealtime({required String eventId}) {
    if (_realtimeChannel != null) {
      _realtimeChannel!.unsubscribe();
      _realtimeChannel = null;
    }

    try {
      _realtimeChannel = _supabase
          .channel('volunteer_awareness_$eventId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'operational_incidents',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'event_id',
              value: eventId,
            ),
            callback: (payload) {
              final rec = payload.newRecord;
              if (rec.isNotEmpty) {
                final item = normalizeIncident(rec);
                ingestAwarenessItem(item, isNew: payload.eventType == PostgresChangeEvent.insert);
              }
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'supervisor_tasks',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'event_id',
              value: eventId,
            ),
            callback: (payload) {
              final rec = payload.newRecord;
              if (rec.isNotEmpty) {
                final item = normalizeTask(rec);
                ingestAwarenessItem(item, isNew: payload.eventType == PostgresChangeEvent.insert);
              }
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'coverage_requests',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'event_id',
              value: eventId,
            ),
            callback: (payload) {
              final rec = payload.newRecord;
              if (rec.isNotEmpty) {
                final item = normalizeCoverage(rec);
                ingestAwarenessItem(item, isNew: payload.eventType == PostgresChangeEvent.insert);
              }
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('EventAwarenessService: Error setting up Realtime: $e');
    }
  }

  void _notifyListeners() {
    if (!_itemsController.isClosed) {
      _itemsController.add(List.unmodifiable(_items));
    }
    if (!_summaryController.isClosed) {
      _summaryController.add(summary);
    }
  }

  // ---------------------------------------------------------------------------
  // Teardown
  // ---------------------------------------------------------------------------

  void clearSession() {
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = null;
    _items.clear();
    _currentEventId = null;
    HapticAttentionService.instance.clear();
    _notifyListeners();
  }

  void dispose() {
    clearSession();
    _itemsController.close();
    _summaryController.close();
  }
}
