/// SPATIALLY — VOLUNTEER BLOCK 2.5C
/// Domain model for supervisor-assigned operational floor tasks.
library;

enum TaskPriority {
  normal,
  important,
  urgent;

  static TaskPriority fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'urgent':
        return TaskPriority.urgent;
      case 'important':
        return TaskPriority.important;
      case 'normal':
      default:
        return TaskPriority.normal;
    }
  }

  String toDbString() {
    switch (this) {
      case TaskPriority.normal:
        return 'normal';
      case TaskPriority.important:
        return 'important';
      case TaskPriority.urgent:
        return 'urgent';
    }
  }

  String get label {
    switch (this) {
      case TaskPriority.normal:
        return 'Normal';
      case TaskPriority.important:
        return 'Important';
      case TaskPriority.urgent:
        return 'Urgent';
    }
  }
}

enum TaskStatus {
  assigned,
  accepted,
  inProgress,
  completed,
  cancelled;

  static TaskStatus fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'accepted':
        return TaskStatus.accepted;
      case 'in_progress':
      case 'inprogress':
        return TaskStatus.inProgress;
      case 'completed':
        return TaskStatus.completed;
      case 'cancelled':
        return TaskStatus.cancelled;
      case 'assigned':
      default:
        return TaskStatus.assigned;
    }
  }

  String toDbString() {
    switch (this) {
      case TaskStatus.assigned:
        return 'assigned';
      case TaskStatus.accepted:
        return 'accepted';
      case TaskStatus.inProgress:
        return 'in_progress';
      case TaskStatus.completed:
        return 'completed';
      case TaskStatus.cancelled:
        return 'cancelled';
    }
  }

  String get label {
    switch (this) {
      case TaskStatus.assigned:
        return 'Assigned';
      case TaskStatus.accepted:
        return 'Accepted';
      case TaskStatus.inProgress:
        return 'In Progress';
      case TaskStatus.completed:
        return 'Completed';
      case TaskStatus.cancelled:
        return 'Cancelled';
    }
  }
}

class SupervisorTask {
  final String id;
  final String eventId;
  final String? teamId;
  final String? teamName;
  final String title;
  final String description;
  final String assignedToId;
  final String assignedToName;
  final String supervisorId;
  final String supervisorName;
  final String? zoneId;
  final String? zoneName;
  final TaskPriority priority;
  final TaskStatus status;
  final DateTime? dueTime;
  final DateTime? acceptedAt;
  final DateTime? completedAt;
  final String? completionNotes;
  final String? linkedIncidentId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SupervisorTask({
    required this.id,
    required this.eventId,
    this.teamId,
    this.teamName,
    required this.title,
    required this.description,
    required this.assignedToId,
    required this.assignedToName,
    required this.supervisorId,
    required this.supervisorName,
    this.zoneId,
    this.zoneName,
    required this.priority,
    required this.status,
    this.dueTime,
    this.acceptedAt,
    this.completedAt,
    this.completionNotes,
    this.linkedIncidentId,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isCompleted => status == TaskStatus.completed;
  bool get isAssigned => status == TaskStatus.assigned;
  bool get isPending => status == TaskStatus.assigned || status == TaskStatus.accepted;
  bool get isUrgent => priority == TaskPriority.urgent;
  bool get isActive => status == TaskStatus.assigned || status == TaskStatus.accepted || status == TaskStatus.inProgress;

  SupervisorTask copyWith({
    String? id,
    String? eventId,
    String? teamId,
    String? teamName,
    String? title,
    String? description,
    String? assignedToId,
    String? assignedToName,
    String? supervisorId,
    String? supervisorName,
    String? zoneId,
    String? zoneName,
    TaskPriority? priority,
    TaskStatus? status,
    DateTime? dueTime,
    DateTime? acceptedAt,
    DateTime? completedAt,
    String? completionNotes,
    String? linkedIncidentId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SupervisorTask(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      teamId: teamId ?? this.teamId,
      teamName: teamName ?? this.teamName,
      title: title ?? this.title,
      description: description ?? this.description,
      assignedToId: assignedToId ?? this.assignedToId,
      assignedToName: assignedToName ?? this.assignedToName,
      supervisorId: supervisorId ?? this.supervisorId,
      supervisorName: supervisorName ?? this.supervisorName,
      zoneId: zoneId ?? this.zoneId,
      zoneName: zoneName ?? this.zoneName,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      dueTime: dueTime ?? this.dueTime,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      completedAt: completedAt ?? this.completedAt,
      completionNotes: completionNotes ?? this.completionNotes,
      linkedIncidentId: linkedIncidentId ?? this.linkedIncidentId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory SupervisorTask.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      return DateTime.tryParse(val.toString())?.toLocal();
    }

    return SupervisorTask(
      id: json['id'] as String? ?? '',
      eventId: json['event_id'] as String? ?? '',
      teamId: json['team_id'] as String?,
      teamName: json['team_name'] as String?,
      title: json['title'] as String? ?? 'Operational Task',
      description: json['description'] as String? ?? '',
      assignedToId: json['assigned_to_id'] as String? ?? '',
      assignedToName: json['assigned_to_name'] as String? ?? 'Volunteer',
      supervisorId: json['supervisor_id'] as String? ?? '',
      supervisorName: json['supervisor_name'] as String? ?? 'Supervisor',
      zoneId: json['zone_id'] as String?,
      zoneName: json['zone_name'] as String?,
      priority: TaskPriority.fromString(json['priority'] as String?),
      status: TaskStatus.fromString(json['status'] as String?),
      dueTime: parseDate(json['due_time']),
      acceptedAt: parseDate(json['accepted_at']),
      completedAt: parseDate(json['completed_at']),
      completionNotes: json['completion_notes'] as String?,
      linkedIncidentId: json['linked_incident_id'] as String?,
      createdAt: parseDate(json['created_at']) ?? DateTime.now(),
      updatedAt: parseDate(json['updated_at']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'event_id': eventId,
      'team_id': teamId,
      'team_name': teamName,
      'title': title,
      'description': description,
      'assigned_to_id': assignedToId,
      'assigned_to_name': assignedToName,
      'supervisor_id': supervisorId,
      'supervisor_name': supervisorName,
      'zone_id': zoneId,
      'zone_name': zoneName,
      'priority': priority.toDbString(),
      'status': status.toDbString(),
      'due_time': dueTime?.toUtc().toIso8601String(),
      'accepted_at': acceptedAt?.toUtc().toIso8601String(),
      'completed_at': completedAt?.toUtc().toIso8601String(),
      'completion_notes': completionNotes,
      'linked_incident_id': linkedIncidentId,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }
}
