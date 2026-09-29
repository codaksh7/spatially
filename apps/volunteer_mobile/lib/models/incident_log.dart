/// Represents an audit log entry for an operational incident.
class IncidentLog {
  final String id;
  final String incidentId;
  final String eventId;
  final String? actorId;
  final String actorName;
  final String action;
  final String? previousStatus;
  final String? newStatus;
  final String? notes;
  final DateTime createdAt;

  const IncidentLog({
    required this.id,
    required this.incidentId,
    required this.eventId,
    this.actorId,
    required this.actorName,
    required this.action,
    this.previousStatus,
    this.newStatus,
    this.notes,
    required this.createdAt,
  });

  factory IncidentLog.fromJson(Map<String, dynamic> json) {
    DateTime parseDt(dynamic val) {
      if (val == null) return DateTime.now();
      if (val is DateTime) return val;
      return DateTime.tryParse(val.toString()) ?? DateTime.now();
    }

    return IncidentLog(
      id: json['id'] as String? ?? '',
      incidentId: json['incident_id'] as String? ?? '',
      eventId: json['event_id'] as String? ?? '',
      actorId: json['actor_id'] as String?,
      actorName: json['actor_name'] as String? ?? 'Staff',
      action: json['action'] as String? ?? 'updated',
      previousStatus: json['previous_status'] as String?,
      newStatus: json['new_status'] as String?,
      notes: json['notes'] as String?,
      createdAt: parseDt(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'incident_id': incidentId,
      'event_id': eventId,
      'actor_id': actorId,
      'actor_name': actorName,
      'action': action,
      'previous_status': previousStatus,
      'new_status': newStatus,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
