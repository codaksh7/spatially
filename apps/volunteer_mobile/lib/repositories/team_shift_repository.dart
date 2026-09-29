/// SPATIALLY — VOLUNTEER BLOCK 2.5C
/// Repository managing operational shifts, break lifecycle, relief/coverage,
/// team membership, supervisor tasks, and shift handoffs.
library;

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/volunteer_shift.dart';
import '../models/event_team.dart';
import '../models/supervisor_task.dart';
import '../models/coverage_request.dart';
import '../models/shift_handoff.dart';
import '../services/observation_queue.dart';
import '../services/session_state.dart';

class TeamShiftRepository {
  static final TeamShiftRepository instance = TeamShiftRepository._internal();
  factory TeamShiftRepository() => instance;
  TeamShiftRepository._internal();

  RealtimeChannel? _shiftsChannel;
  RealtimeChannel? _tasksChannel;
  RealtimeChannel? _coverageChannel;
  RealtimeChannel? _handoffsChannel;

  Future<bool> _isOnline() async {
    final results = await Connectivity().checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  // ---------------------------------------------------------------------------
  // 1. Shift Operations
  // ---------------------------------------------------------------------------

  Future<List<VolunteerShift>> fetchMyShifts({
    required String eventId,
    bool forceRefresh = false,
  }) async {
    final volunteerId = SessionState.instance.volunteerId;
    if (volunteerId == null) return [];

    final isOnline = await _isOnline();
    if (!isOnline && !forceRefresh) {
      final cached = await ObservationQueue().getCachedVolunteerShifts(
        eventId: eventId,
        volunteerId: volunteerId,
      );
      if (cached.isNotEmpty) {
        return cached.map((j) => VolunteerShift.fromJson(j)).toList();
      }
    }

    try {
      final client = Supabase.instance.client;
      final response = await client
          .from('volunteer_shifts')
          .select('*, event_teams(*)')
          .eq('event_id', eventId)
          .eq('volunteer_id', volunteerId)
          .order('scheduled_start', ascending: true);

      final list = (response as List<dynamic>)
          .map((item) => VolunteerShift.fromJson(item as Map<String, dynamic>))
          .toList();

      // Cache locally
      await ObservationQueue().cacheVolunteerShifts(
        eventId: eventId,
        volunteerId: volunteerId,
        shifts: list.map((s) => s.toJson()).toList(),
      );

      return list;
    } catch (e) {
      print('TeamShiftRepository: Error fetching shifts online, loading cache: $e');
      final cached = await ObservationQueue().getCachedVolunteerShifts(
        eventId: eventId,
        volunteerId: volunteerId,
      );
      return cached.map((j) => VolunteerShift.fromJson(j)).toList();
    }
  }

  Future<VolunteerShift?> fetchActiveShift({
    required String eventId,
    bool forceRefresh = false,
  }) async {
    final shifts = await fetchMyShifts(eventId: eventId, forceRefresh: forceRefresh);
    if (shifts.isEmpty) return null;

    // Prefer active or onBreak shift, else next scheduled
    for (final s in shifts) {
      if (s.status == ShiftStatus.active ||
          s.status == ShiftStatus.onBreak ||
          s.status == ShiftStatus.handoffPending) {
        return s;
      }
    }
    for (final s in shifts) {
      if (s.status == ShiftStatus.scheduled) return s;
    }
    return shifts.first;
  }

  Future<VolunteerShift> startShift(String shiftId) async {
    final isOnline = await _isOnline();
    if (!isOnline) {
      throw Exception('Starting a shift requires active network connectivity for authorization.');
    }

    final client = Supabase.instance.client;
    final res = await client.rpc('start_volunteer_shift', params: {
      'p_shift_id': shiftId,
    });

    if (res is Map<String, dynamic> && res['success'] == true) {
      final shiftData = res['shift'] as Map<String, dynamic>?;
      if (shiftData != null) {
        return VolunteerShift.fromJson(shiftData);
      }
      final updated = await client.from('volunteer_shifts').select().eq('id', shiftId).single();
      return VolunteerShift.fromJson(updated);
    }
    throw Exception(res['message'] ?? 'Failed to start shift');
  }

  Future<Map<String, dynamic>> endShift(String shiftId, {String? notes}) async {
    final isOnline = await _isOnline();
    if (!isOnline) {
      throw Exception('Ending a shift requires active network connectivity for verification.');
    }

    final client = Supabase.instance.client;
    final res = await client.rpc('end_volunteer_shift', params: {
      'p_shift_id': shiftId,
      'p_notes': notes,
    });

    if (res is Map<String, dynamic> && res['success'] == true) {
      return res;
    }
    throw Exception(res['message'] ?? 'Failed to end shift');
  }

  // ---------------------------------------------------------------------------
  // 2. Break Management
  // ---------------------------------------------------------------------------

  Future<void> startBreak(
    String shiftId, {
    DateTime? expectedReturn,
    String? reason,
  }) async {
    final isOnline = await _isOnline();
    if (!isOnline) {
      throw Exception('Network connectivity required to report starting a break.');
    }

    final client = Supabase.instance.client;
    final res = await client.rpc('start_shift_break', params: {
      'p_shift_id': shiftId,
      'p_expected_return': expectedReturn?.toUtc().toIso8601String(),
      'p_reason': reason ?? 'Standard Break',
    });

    if (res is Map<String, dynamic> && res['success'] == true) {
      return;
    }
    throw Exception(res['message'] ?? 'Failed to start break');
  }

  Future<void> endBreak(String shiftId) async {
    final isOnline = await _isOnline();
    if (!isOnline) {
      throw Exception('Network connectivity required to report returning from break.');
    }

    final client = Supabase.instance.client;
    final res = await client.rpc('end_shift_break', params: {
      'p_shift_id': shiftId,
    });

    if (res is Map<String, dynamic> && res['success'] == true) {
      return;
    }
    throw Exception(res['message'] ?? 'Failed to end break');
  }

  // ---------------------------------------------------------------------------
  // 3. Relief / Coverage Requests
  // ---------------------------------------------------------------------------

  Future<String> requestCoverage({
    required String eventId,
    required String shiftId,
    required CoverageReason reason,
    String? notes,
    String priority = 'normal',
  }) async {
    final isOnline = await _isOnline();
    if (!isOnline) {
      throw Exception('Network connectivity required to submit coverage request.');
    }

    final client = Supabase.instance.client;
    final res = await client.rpc('request_shift_coverage', params: {
      'p_event_id': eventId,
      'p_shift_id': shiftId,
      'p_reason': reason.toDbString(),
      'p_notes': notes,
      'p_priority': priority,
    });

    if (res is Map<String, dynamic> && res['success'] == true) {
      return res['request_id'] as String;
    }
    throw Exception(res['message'] ?? 'Failed to request coverage');
  }

  Future<void> acceptCoverage(String requestId) async {
    final isOnline = await _isOnline();
    if (!isOnline) {
      throw Exception('Network connectivity required to claim coverage.');
    }

    final client = Supabase.instance.client;
    final res = await client.rpc('accept_shift_coverage', params: {
      'p_request_id': requestId,
    });

    if (res is Map<String, dynamic> && res['success'] == true) {
      return;
    }
    if (res is Map<String, dynamic> && res['error'] == 'ALREADY_CLAIMED') {
      final name = res['covering_volunteer_name'] ?? 'another volunteer';
      throw Exception('This coverage request was already claimed by $name.');
    }
    throw Exception(res['message'] ?? 'Failed to accept coverage request');
  }

  Future<List<CoverageRequest>> fetchCoverageRequests({
    required String eventId,
    bool forceRefresh = false,
  }) async {
    final isOnline = await _isOnline();
    if (!isOnline && !forceRefresh) {
      final cached = await ObservationQueue().getCachedCoverageRequests(eventId: eventId);
      return cached.map((j) => CoverageRequest.fromJson(j)).toList();
    }

    try {
      final client = Supabase.instance.client;
      final response = await client
          .from('coverage_requests')
          .select()
          .eq('event_id', eventId)
          .order('created_at', ascending: false);

      final list = (response as List<dynamic>)
          .map((item) => CoverageRequest.fromJson(item as Map<String, dynamic>))
          .toList();

      await ObservationQueue().cacheCoverageRequests(
        eventId: eventId,
        requests: list.map((r) => r.toJson()).toList(),
      );

      return list;
    } catch (e) {
      final cached = await ObservationQueue().getCachedCoverageRequests(eventId: eventId);
      return cached.map((j) => CoverageRequest.fromJson(j)).toList();
    }
  }

  // ---------------------------------------------------------------------------
  // 4. Team Operations
  // ---------------------------------------------------------------------------

  Future<List<EventTeam>> fetchTeams({
    required String eventId,
    bool forceRefresh = false,
  }) async {
    final isOnline = await _isOnline();
    if (!isOnline && !forceRefresh) {
      final cached = await ObservationQueue().getCachedEventTeams(eventId: eventId);
      return cached.map((j) => EventTeam.fromJson(j)).toList();
    }

    try {
      final client = Supabase.instance.client;
      final response = await client
          .from('event_teams')
          .select('*, event_team_members(*, profiles(*))')
          .eq('event_id', eventId)
          .order('name', ascending: true);

      final list = (response as List<dynamic>)
          .map((item) => EventTeam.fromJson(item as Map<String, dynamic>))
          .toList();

      await ObservationQueue().cacheEventTeams(
        eventId: eventId,
        teams: list.map((t) => t.toJson()).toList(),
      );

      return list;
    } catch (e) {
      final cached = await ObservationQueue().getCachedEventTeams(eventId: eventId);
      return cached.map((j) => EventTeam.fromJson(j)).toList();
    }
  }

  // ---------------------------------------------------------------------------
  // 5. Supervisor Tasks
  // ---------------------------------------------------------------------------

  Future<List<SupervisorTask>> fetchTasks({
    required String eventId,
    String? assignedToId,
    bool forceRefresh = false,
  }) async {
    final isOnline = await _isOnline();
    if (!isOnline && !forceRefresh) {
      final cached = await ObservationQueue().getCachedSupervisorTasks(
        eventId: eventId,
        assignedToId: assignedToId,
      );
      return cached.map((j) => SupervisorTask.fromJson(j)).toList();
    }

    try {
      final client = Supabase.instance.client;
      var query = client
          .from('supervisor_tasks')
          .select()
          .eq('event_id', eventId);

      if (assignedToId != null) {
        query = query.eq('assigned_to_id', assignedToId);
      }

      final response = await query.order('created_at', ascending: false);

      final list = (response as List<dynamic>)
          .map((item) => SupervisorTask.fromJson(item as Map<String, dynamic>))
          .toList();

      await ObservationQueue().cacheSupervisorTasks(
        eventId: eventId,
        tasks: list.map((t) => t.toJson()).toList(),
      );

      return list;
    } catch (e) {
      final cached = await ObservationQueue().getCachedSupervisorTasks(
        eventId: eventId,
        assignedToId: assignedToId,
      );
      return cached.map((j) => SupervisorTask.fromJson(j)).toList();
    }
  }

  Future<String> createTask({
    required String eventId,
    required String title,
    required String description,
    required String assignedToId,
    String? teamId,
    String? zoneId,
    TaskPriority priority = TaskPriority.normal,
    DateTime? dueTime,
    String? linkedIncidentId,
  }) async {
    final isOnline = await _isOnline();
    if (!isOnline) {
      throw Exception('Assigning tasks requires active network connectivity.');
    }

    final client = Supabase.instance.client;
    final res = await client.rpc('create_supervisor_task', params: {
      'p_event_id': eventId,
      'p_title': title,
      'p_description': description,
      'p_assigned_to_id': assignedToId,
      'p_team_id': teamId,
      'p_zone_id': zoneId,
      'p_priority': priority.toDbString(),
      'p_due_time': dueTime?.toUtc().toIso8601String(),
      'p_linked_incident_id': linkedIncidentId,
    });

    if (res is Map<String, dynamic> && res['success'] == true) {
      return res['task_id'] as String;
    }
    throw Exception(res['message'] ?? 'Failed to create task');
  }

  Future<void> updateTaskStatus(
    String taskId,
    TaskStatus status, {
    String? completionNotes,
  }) async {
    final isOnline = await _isOnline();
    if (!isOnline) {
      throw Exception('Updating task status requires active network connectivity.');
    }

    final client = Supabase.instance.client;
    final res = await client.rpc('update_task_status', params: {
      'p_task_id': taskId,
      'p_status': status.toDbString(),
      'p_completion_notes': completionNotes,
    });

    if (res is Map<String, dynamic> && res['success'] == true) {
      return;
    }
    throw Exception(res['message'] ?? 'Failed to update task status');
  }

  // ---------------------------------------------------------------------------
  // 6. Shift Handoffs
  // ---------------------------------------------------------------------------

  Future<String> createHandoff({
    required String shiftId,
    required String operationalSummary,
    String? incomingVolunteerId,
    String? equipmentCondition,
    String? attendeeNotes,
    List<String> unresolvedIncidentIds = const [],
    List<String> pendingTaskIds = const [],
  }) async {
    final isOnline = await _isOnline();
    if (!isOnline) {
      throw Exception('Submitting handoff requires active network connectivity.');
    }

    final client = Supabase.instance.client;
    final res = await client.rpc('create_shift_handoff', params: {
      'p_shift_id': shiftId,
      'p_summary': operationalSummary,
      'p_incoming_volunteer_id': incomingVolunteerId,
      'p_equipment_condition': equipmentCondition,
      'p_attendee_notes': attendeeNotes,
      'p_incident_ids': unresolvedIncidentIds,
      'p_task_ids': pendingTaskIds,
    });

    if (res is Map<String, dynamic> && res['success'] == true) {
      return res['handoff_id'] as String;
    }
    throw Exception(res['message'] ?? 'Failed to submit shift handoff');
  }

  Future<void> acknowledgeHandoff(String handoffId) async {
    final isOnline = await _isOnline();
    if (!isOnline) {
      throw Exception('Acknowledging handoff requires active network connectivity.');
    }

    final client = Supabase.instance.client;
    final res = await client.rpc('acknowledge_shift_handoff', params: {
      'p_handoff_id': handoffId,
    });

    if (res is Map<String, dynamic> && res['success'] == true) {
      return;
    }
    throw Exception(res['message'] ?? 'Failed to acknowledge handoff');
  }

  Future<List<ShiftHandoff>> fetchHandoffs({
    required String eventId,
    bool forceRefresh = false,
  }) async {
    final isOnline = await _isOnline();
    if (!isOnline && !forceRefresh) {
      final cached = await ObservationQueue().getCachedShiftHandoffs(eventId: eventId);
      return cached.map((j) => ShiftHandoff.fromJson(j)).toList();
    }

    try {
      final client = Supabase.instance.client;
      final response = await client
          .from('shift_handoffs')
          .select()
          .eq('event_id', eventId)
          .order('created_at', ascending: false);

      final list = (response as List<dynamic>)
          .map((item) => ShiftHandoff.fromJson(item as Map<String, dynamic>))
          .toList();

      await ObservationQueue().cacheShiftHandoffs(
        eventId: eventId,
        handoffs: list.map((h) => h.toJson()).toList(),
      );

      return list;
    } catch (e) {
      final cached = await ObservationQueue().getCachedShiftHandoffs(eventId: eventId);
      return cached.map((j) => ShiftHandoff.fromJson(j)).toList();
    }
  }

  // ---------------------------------------------------------------------------
  // 7. Supabase Realtime Lifecycle
  // ---------------------------------------------------------------------------

  void subscribeRealtime({
    required String eventId,
    required void Function() onDataChanged,
  }) {
    unsubscribeRealtime();

    final client = Supabase.instance.client;

    _shiftsChannel = client
        .channel('public:volunteer_shifts:event:$eventId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'volunteer_shifts',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'event_id',
            value: eventId,
          ),
          callback: (payload) {
            print('TeamShiftRepository: Realtime shift update received: ${payload.eventType}');
            onDataChanged();
          },
        )
        .subscribe();

    _tasksChannel = client
        .channel('public:supervisor_tasks:event:$eventId')
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
            print('TeamShiftRepository: Realtime task update received: ${payload.eventType}');
            onDataChanged();
          },
        )
        .subscribe();

    _coverageChannel = client
        .channel('public:coverage_requests:event:$eventId')
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
            print('TeamShiftRepository: Realtime coverage update received: ${payload.eventType}');
            onDataChanged();
          },
        )
        .subscribe();

    _handoffsChannel = client
        .channel('public:shift_handoffs:event:$eventId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'shift_handoffs',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'event_id',
            value: eventId,
          ),
          callback: (payload) {
            print('TeamShiftRepository: Realtime handoff update received: ${payload.eventType}');
            onDataChanged();
          },
        )
        .subscribe();
  }

  void unsubscribeRealtime() {
    if (_shiftsChannel != null) {
      Supabase.instance.client.removeChannel(_shiftsChannel!);
      _shiftsChannel = null;
    }
    if (_tasksChannel != null) {
      Supabase.instance.client.removeChannel(_tasksChannel!);
      _tasksChannel = null;
    }
    if (_coverageChannel != null) {
      Supabase.instance.client.removeChannel(_coverageChannel!);
      _coverageChannel = null;
    }
    if (_handoffsChannel != null) {
      Supabase.instance.client.removeChannel(_handoffsChannel!);
      _handoffsChannel = null;
    }
  }
}
