/// SPATIALLY — VOLUNTEER BLOCK 2.5C
/// Domain model for shift relief and station coverage requests.
library;

enum CoverageReason {
  breakTime,
  incident,
  equipment,
  overflow,
  personal,
  other;

  static CoverageReason fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'incident':
        return CoverageReason.incident;
      case 'equipment':
        return CoverageReason.equipment;
      case 'overflow':
        return CoverageReason.overflow;
      case 'personal':
        return CoverageReason.personal;
      case 'other':
        return CoverageReason.other;
      case 'break':
      default:
        return CoverageReason.breakTime;
    }
  }

  String toDbString() {
    switch (this) {
      case CoverageReason.breakTime:
        return 'break';
      case CoverageReason.incident:
        return 'incident';
      case CoverageReason.equipment:
        return 'equipment';
      case CoverageReason.overflow:
        return 'overflow';
      case CoverageReason.personal:
        return 'personal';
      case CoverageReason.other:
        return 'other';
    }
  }

  String get label {
    switch (this) {
      case CoverageReason.breakTime:
        return 'Meal / Rest Break';
      case CoverageReason.incident:
        return 'Handling Incident';
      case CoverageReason.equipment:
        return 'Scanner / Device Issue';
      case CoverageReason.overflow:
        return 'Queue / Crowd Overflow';
      case CoverageReason.personal:
        return 'Personal Emergency';
      case CoverageReason.other:
        return 'Other Operations';
    }
  }
}

enum CoverageStatus {
  requested,
  accepted,
  declined,
  cancelled,
  completed;

  static CoverageStatus fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'accepted':
        return CoverageStatus.accepted;
      case 'declined':
        return CoverageStatus.declined;
      case 'cancelled':
        return CoverageStatus.cancelled;
      case 'completed':
        return CoverageStatus.completed;
      case 'requested':
      default:
        return CoverageStatus.requested;
    }
  }

  String toDbString() {
    switch (this) {
      case CoverageStatus.requested:
        return 'requested';
      case CoverageStatus.accepted:
        return 'accepted';
      case CoverageStatus.declined:
        return 'declined';
      case CoverageStatus.cancelled:
        return 'cancelled';
      case CoverageStatus.completed:
        return 'completed';
    }
  }

  String get label {
    switch (this) {
      case CoverageStatus.requested:
        return 'Coverage Requested';
      case CoverageStatus.accepted:
        return 'Accepted / Covered';
      case CoverageStatus.declined:
        return 'Declined';
      case CoverageStatus.cancelled:
        return 'Cancelled';
      case CoverageStatus.completed:
        return 'Completed';
    }
  }
}

class CoverageRequest {
  final String id;
  final String eventId;
  final String? shiftId;
  final String requesterId;
  final String requesterName;
  final String? teamId;
  final String? teamName;
  final String? zoneId;
  final String? zoneName;
  final CoverageReason reason;
  final String? notes;
  final String priority;
  final CoverageStatus status;
  final String? coveringVolunteerId;
  final String? coveringVolunteerName;
  final DateTime? acceptedAt;
  final DateTime? resolvedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CoverageRequest({
    required this.id,
    required this.eventId,
    this.shiftId,
    required this.requesterId,
    required this.requesterName,
    this.teamId,
    this.teamName,
    this.zoneId,
    this.zoneName,
    required this.reason,
    this.notes,
    required this.priority,
    required this.status,
    this.coveringVolunteerId,
    this.coveringVolunteerName,
    this.acceptedAt,
    this.resolvedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isPending => status == CoverageStatus.requested;
  bool get isAccepted => status == CoverageStatus.accepted;

  CoverageRequest copyWith({
    String? id,
    String? eventId,
    String? shiftId,
    String? requesterId,
    String? requesterName,
    String? teamId,
    String? teamName,
    String? zoneId,
    String? zoneName,
    CoverageReason? reason,
    String? notes,
    String? priority,
    CoverageStatus? status,
    String? coveringVolunteerId,
    String? coveringVolunteerName,
    DateTime? acceptedAt,
    DateTime? resolvedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CoverageRequest(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      shiftId: shiftId ?? this.shiftId,
      requesterId: requesterId ?? this.requesterId,
      requesterName: requesterName ?? this.requesterName,
      teamId: teamId ?? this.teamId,
      teamName: teamName ?? this.teamName,
      zoneId: zoneId ?? this.zoneId,
      zoneName: zoneName ?? this.zoneName,
      reason: reason ?? this.reason,
      notes: notes ?? this.notes,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      coveringVolunteerId: coveringVolunteerId ?? this.coveringVolunteerId,
      coveringVolunteerName: coveringVolunteerName ?? this.coveringVolunteerName,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory CoverageRequest.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      return DateTime.tryParse(val.toString())?.toLocal();
    }

    return CoverageRequest(
      id: json['id'] as String? ?? '',
      eventId: json['event_id'] as String? ?? '',
      shiftId: json['shift_id'] as String?,
      requesterId: json['requester_id'] as String? ?? '',
      requesterName: json['requester_name'] as String? ?? 'Volunteer',
      teamId: json['team_id'] as String?,
      teamName: json['team_name'] as String?,
      zoneId: json['zone_id'] as String?,
      zoneName: json['zone_name'] as String?,
      reason: CoverageReason.fromString(json['reason'] as String?),
      notes: json['notes'] as String?,
      priority: json['priority'] as String? ?? 'normal',
      status: CoverageStatus.fromString(json['status'] as String?),
      coveringVolunteerId: json['covering_volunteer_id'] as String?,
      coveringVolunteerName: json['covering_volunteer_name'] as String?,
      acceptedAt: parseDate(json['accepted_at']),
      resolvedAt: parseDate(json['resolved_at']),
      createdAt: parseDate(json['created_at']) ?? DateTime.now(),
      updatedAt: parseDate(json['updated_at']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'event_id': eventId,
      'shift_id': shiftId,
      'requester_id': requesterId,
      'requester_name': requesterName,
      'team_id': teamId,
      'team_name': teamName,
      'zone_id': zoneId,
      'zone_name': zoneName,
      'reason': reason.toDbString(),
      'notes': notes,
      'priority': priority,
      'status': status.toDbString(),
      'covering_volunteer_id': coveringVolunteerId,
      'covering_volunteer_name': coveringVolunteerName,
      'accepted_at': acceptedAt?.toUtc().toIso8601String(),
      'resolved_at': resolvedAt?.toUtc().toIso8601String(),
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }
}
