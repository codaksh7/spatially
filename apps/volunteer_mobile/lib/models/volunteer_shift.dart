/// SPATIALLY — VOLUNTEER BLOCK 2.5C
/// Domain model for volunteer operational shifts.
library;

enum ShiftStatus {
  scheduled,
  active,
  onBreak,
  handoffPending,
  completed,
  cancelled;

  static ShiftStatus fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'active':
        return ShiftStatus.active;
      case 'on_break':
      case 'onbreak':
        return ShiftStatus.onBreak;
      case 'handoff_pending':
      case 'handoffpending':
        return ShiftStatus.handoffPending;
      case 'completed':
        return ShiftStatus.completed;
      case 'cancelled':
        return ShiftStatus.cancelled;
      case 'scheduled':
      default:
        return ShiftStatus.scheduled;
    }
  }

  String toDbString() {
    switch (this) {
      case ShiftStatus.scheduled:
        return 'scheduled';
      case ShiftStatus.active:
        return 'active';
      case ShiftStatus.onBreak:
        return 'on_break';
      case ShiftStatus.handoffPending:
        return 'handoff_pending';
      case ShiftStatus.completed:
        return 'completed';
      case ShiftStatus.cancelled:
        return 'cancelled';
    }
  }

  String get label {
    switch (this) {
      case ShiftStatus.scheduled:
        return 'Scheduled';
      case ShiftStatus.active:
        return 'Active';
      case ShiftStatus.onBreak:
        return 'On Break';
      case ShiftStatus.handoffPending:
        return 'Handoff Pending';
      case ShiftStatus.completed:
        return 'Completed';
      case ShiftStatus.cancelled:
        return 'Cancelled';
    }
  }
}

enum BreakState {
  none,
  requested,
  onBreak,
  completed;

  static BreakState fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'requested':
        return BreakState.requested;
      case 'on_break':
      case 'onbreak':
        return BreakState.onBreak;
      case 'completed':
        return BreakState.completed;
      case 'none':
      default:
        return BreakState.none;
    }
  }

  String toDbString() {
    switch (this) {
      case BreakState.none:
        return 'none';
      case BreakState.requested:
        return 'requested';
      case BreakState.onBreak:
        return 'on_break';
      case BreakState.completed:
        return 'completed';
    }
  }
}

class VolunteerShift {
  final String id;
  final String eventId;
  final String volunteerId;
  final String? volunteerName;
  final String? teamId;
  final String? teamName;
  final String? supervisorId;
  final String? supervisorName;
  final String? zoneId;
  final String? zoneName;
  final String shiftName;
  final DateTime scheduledStart;
  final DateTime scheduledEnd;
  final DateTime? actualStart;
  final DateTime? actualEnd;
  final ShiftStatus status;
  final BreakState breakState;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const VolunteerShift({
    required this.id,
    required this.eventId,
    required this.volunteerId,
    this.volunteerName,
    this.teamId,
    this.teamName,
    this.supervisorId,
    this.supervisorName,
    this.zoneId,
    this.zoneName,
    required this.shiftName,
    required this.scheduledStart,
    required this.scheduledEnd,
    this.actualStart,
    this.actualEnd,
    required this.status,
    required this.breakState,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isActive => status == ShiftStatus.active;
  bool get isOnBreak => status == ShiftStatus.onBreak;
  bool get isCompleted => status == ShiftStatus.completed;
  bool get isScheduled => status == ShiftStatus.scheduled;

  factory VolunteerShift.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      return DateTime.tryParse(val.toString())?.toLocal();
    }

    final teamObj = json['event_teams'] as Map<String, dynamic>?;
    final profileObj = json['profiles'] as Map<String, dynamic>?;

    return VolunteerShift(
      id: json['id'] as String? ?? '',
      eventId: json['event_id'] as String? ?? '',
      volunteerId: json['volunteer_id'] as String? ?? '',
      volunteerName: json['volunteer_name'] as String? ?? profileObj?['full_name'] as String?,
      teamId: json['team_id'] as String?,
      teamName: json['team_name'] as String? ?? teamObj?['name'] as String?,
      supervisorId: json['supervisor_id'] as String?,
      supervisorName: json['supervisor_name'] as String?,
      zoneId: json['zone_id'] as String?,
      zoneName: json['zone_name'] as String?,
      shiftName: json['shift_name'] as String? ?? 'Operational Shift',
      scheduledStart: parseDate(json['scheduled_start']) ?? DateTime.now(),
      scheduledEnd: parseDate(json['scheduled_end']) ?? DateTime.now().add(const Duration(hours: 4)),
      actualStart: parseDate(json['actual_start']),
      actualEnd: parseDate(json['actual_end']),
      status: ShiftStatus.fromString(json['status'] as String?),
      breakState: BreakState.fromString(json['break_state'] as String?),
      notes: json['notes'] as String?,
      createdAt: parseDate(json['created_at']) ?? DateTime.now(),
      updatedAt: parseDate(json['updated_at']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'event_id': eventId,
      'volunteer_id': volunteerId,
      'volunteer_name': volunteerName,
      'team_id': teamId,
      'team_name': teamName,
      'supervisor_id': supervisorId,
      'supervisor_name': supervisorName,
      'zone_id': zoneId,
      'zone_name': zoneName,
      'shift_name': shiftName,
      'scheduled_start': scheduledStart.toUtc().toIso8601String(),
      'scheduled_end': scheduledEnd.toUtc().toIso8601String(),
      'actual_start': actualStart?.toUtc().toIso8601String(),
      'actual_end': actualEnd?.toUtc().toIso8601String(),
      'status': status.toDbString(),
      'break_state': breakState.toDbString(),
      'notes': notes,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  VolunteerShift copyWith({
    ShiftStatus? status,
    BreakState? breakState,
    DateTime? actualStart,
    DateTime? actualEnd,
    String? notes,
  }) {
    return VolunteerShift(
      id: id,
      eventId: eventId,
      volunteerId: volunteerId,
      volunteerName: volunteerName,
      teamId: teamId,
      teamName: teamName,
      supervisorId: supervisorId,
      supervisorName: supervisorName,
      zoneId: zoneId,
      zoneName: zoneName,
      shiftName: shiftName,
      scheduledStart: scheduledStart,
      scheduledEnd: scheduledEnd,
      actualStart: actualStart ?? this.actualStart,
      actualEnd: actualEnd ?? this.actualEnd,
      status: status ?? this.status,
      breakState: breakState ?? this.breakState,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
