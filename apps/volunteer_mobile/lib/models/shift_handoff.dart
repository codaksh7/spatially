/// SPATIALLY — VOLUNTEER BLOCK 2.5C
/// Domain model for shift handoff briefings and responsibility transitions.
library;

enum HandoffStatus {
  pending,
  acknowledged,
  completed;

  static HandoffStatus fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'acknowledged':
        return HandoffStatus.acknowledged;
      case 'completed':
        return HandoffStatus.completed;
      case 'pending':
      default:
        return HandoffStatus.pending;
    }
  }

  String toDbString() {
    switch (this) {
      case HandoffStatus.pending:
        return 'pending';
      case HandoffStatus.acknowledged:
        return 'acknowledged';
      case HandoffStatus.completed:
        return 'completed';
    }
  }

  String get label {
    switch (this) {
      case HandoffStatus.pending:
        return 'Pending Acknowledgment';
      case HandoffStatus.acknowledged:
        return 'Acknowledged';
      case HandoffStatus.completed:
        return 'Completed';
    }
  }
}

class ShiftHandoff {
  final String id;
  final String eventId;
  final String shiftId;
  final String outgoingVolunteerId;
  final String outgoingVolunteerName;
  final String? incomingVolunteerId;
  final String? incomingVolunteerName;
  final String? zoneId;
  final String? zoneName;
  final String operationalSummary;
  final String? equipmentCondition;
  final String? attendeeNotes;
  final List<String> unresolvedIncidentIds;
  final List<String> pendingTaskIds;
  final HandoffStatus status;
  final DateTime? acknowledgedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ShiftHandoff({
    required this.id,
    required this.eventId,
    required this.shiftId,
    required this.outgoingVolunteerId,
    required this.outgoingVolunteerName,
    this.incomingVolunteerId,
    this.incomingVolunteerName,
    this.zoneId,
    this.zoneName,
    required this.operationalSummary,
    this.equipmentCondition,
    this.attendeeNotes,
    this.unresolvedIncidentIds = const [],
    this.pendingTaskIds = const [],
    required this.status,
    this.acknowledgedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isPending => status == HandoffStatus.pending;
  bool get isAcknowledged => status == HandoffStatus.acknowledged;

  ShiftHandoff copyWith({
    String? id,
    String? eventId,
    String? shiftId,
    String? outgoingVolunteerId,
    String? outgoingVolunteerName,
    String? incomingVolunteerId,
    String? incomingVolunteerName,
    String? zoneId,
    String? zoneName,
    String? operationalSummary,
    String? equipmentCondition,
    String? attendeeNotes,
    List<String>? unresolvedIncidentIds,
    List<String>? pendingTaskIds,
    HandoffStatus? status,
    DateTime? acknowledgedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ShiftHandoff(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      shiftId: shiftId ?? this.shiftId,
      outgoingVolunteerId: outgoingVolunteerId ?? this.outgoingVolunteerId,
      outgoingVolunteerName: outgoingVolunteerName ?? this.outgoingVolunteerName,
      incomingVolunteerId: incomingVolunteerId ?? this.incomingVolunteerId,
      incomingVolunteerName: incomingVolunteerName ?? this.incomingVolunteerName,
      zoneId: zoneId ?? this.zoneId,
      zoneName: zoneName ?? this.zoneName,
      operationalSummary: operationalSummary ?? this.operationalSummary,
      equipmentCondition: equipmentCondition ?? this.equipmentCondition,
      attendeeNotes: attendeeNotes ?? this.attendeeNotes,
      unresolvedIncidentIds: unresolvedIncidentIds ?? this.unresolvedIncidentIds,
      pendingTaskIds: pendingTaskIds ?? this.pendingTaskIds,
      status: status ?? this.status,
      acknowledgedAt: acknowledgedAt ?? this.acknowledgedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory ShiftHandoff.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      return DateTime.tryParse(val.toString())?.toLocal();
    }

    List<String> parseList(dynamic val) {
      if (val == null) return const [];
      if (val is List) {
        return val.map((e) => e.toString()).toList();
      }
      return const [];
    }

    return ShiftHandoff(
      id: json['id'] as String? ?? '',
      eventId: json['event_id'] as String? ?? '',
      shiftId: json['shift_id'] as String? ?? '',
      outgoingVolunteerId: json['outgoing_volunteer_id'] as String? ?? '',
      outgoingVolunteerName: json['outgoing_volunteer_name'] as String? ?? 'Volunteer',
      incomingVolunteerId: json['incoming_volunteer_id'] as String?,
      incomingVolunteerName: json['incoming_volunteer_name'] as String?,
      zoneId: json['zone_id'] as String?,
      zoneName: json['zone_name'] as String?,
      operationalSummary: json['operational_summary'] as String? ?? '',
      equipmentCondition: json['equipment_condition'] as String?,
      attendeeNotes: json['attendee_notes'] as String?,
      unresolvedIncidentIds: parseList(json['unresolved_incident_ids']),
      pendingTaskIds: parseList(json['pending_task_ids']),
      status: HandoffStatus.fromString(json['status'] as String?),
      acknowledgedAt: parseDate(json['acknowledged_at']),
      createdAt: parseDate(json['created_at']) ?? DateTime.now(),
      updatedAt: parseDate(json['updated_at']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'event_id': eventId,
      'shift_id': shiftId,
      'outgoing_volunteer_id': outgoingVolunteerId,
      'outgoing_volunteer_name': outgoingVolunteerName,
      'incoming_volunteer_id': incomingVolunteerId,
      'incoming_volunteer_name': incomingVolunteerName,
      'zone_id': zoneId,
      'zone_name': zoneName,
      'operational_summary': operationalSummary,
      'equipment_condition': equipmentCondition,
      'attendee_notes': attendeeNotes,
      'unresolved_incident_ids': unresolvedIncidentIds,
      'pending_task_ids': pendingTaskIds,
      'status': status.toDbString(),
      'acknowledged_at': acknowledgedAt?.toUtc().toIso8601String(),
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }
}
