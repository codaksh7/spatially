import 'dart:convert';

/// Priority levels for operational incidents.
enum IncidentPriority {
  normal,
  important,
  urgent;

  static IncidentPriority fromString(String value) {
    switch (value.toLowerCase().trim()) {
      case 'urgent':
        return IncidentPriority.urgent;
      case 'important':
        return IncidentPriority.important;
      default:
        return IncidentPriority.normal;
    }
  }

  String toDbString() => name;

  String get label {
    switch (this) {
      case IncidentPriority.urgent:
        return 'Urgent';
      case IncidentPriority.important:
        return 'Important';
      case IncidentPriority.normal:
        return 'Normal';
    }
  }
}

/// Categories for operational incidents.
enum IncidentCategory {
  crowd,
  safety,
  security,
  medical,
  infrastructure,
  equipment,
  accessibility,
  lostFound,
  attendeeAssistance,
  operational,
  other;

  static IncidentCategory fromString(String value) {
    switch (value.toLowerCase().trim()) {
      case 'crowd':
        return IncidentCategory.crowd;
      case 'safety':
        return IncidentCategory.safety;
      case 'security':
        return IncidentCategory.security;
      case 'medical':
        return IncidentCategory.medical;
      case 'infrastructure':
        return IncidentCategory.infrastructure;
      case 'equipment':
        return IncidentCategory.equipment;
      case 'accessibility':
        return IncidentCategory.accessibility;
      case 'lost_found':
        return IncidentCategory.lostFound;
      case 'attendee_assistance':
        return IncidentCategory.attendeeAssistance;
      case 'operational':
        return IncidentCategory.operational;
      default:
        return IncidentCategory.other;
    }
  }

  String toDbString() {
    switch (this) {
      case IncidentCategory.lostFound:
        return 'lost_found';
      case IncidentCategory.attendeeAssistance:
        return 'attendee_assistance';
      default:
        return name;
    }
  }

  String get label {
    switch (this) {
      case IncidentCategory.crowd:
        return 'Crowd Issue';
      case IncidentCategory.safety:
        return 'Safety Hazard';
      case IncidentCategory.security:
        return 'Security';
      case IncidentCategory.medical:
        return 'Medical Assist';
      case IncidentCategory.infrastructure:
        return 'Infrastructure';
      case IncidentCategory.equipment:
        return 'Equipment / Scanner';
      case IncidentCategory.accessibility:
        return 'Accessibility';
      case IncidentCategory.lostFound:
        return 'Lost & Found';
      case IncidentCategory.attendeeAssistance:
        return 'Attendee Assistance';
      case IncidentCategory.operational:
        return 'Operational / Help';
      case IncidentCategory.other:
        return 'Other';
    }
  }
}

/// Lifecycle status for operational incidents.
enum IncidentStatus {
  open,
  acknowledged,
  assigned,
  inProgress,
  resolved,
  closed,
  cancelled;

  static IncidentStatus fromString(String value) {
    switch (value.toLowerCase().trim()) {
      case 'acknowledged':
        return IncidentStatus.acknowledged;
      case 'assigned':
        return IncidentStatus.assigned;
      case 'in_progress':
        return IncidentStatus.inProgress;
      case 'resolved':
        return IncidentStatus.resolved;
      case 'closed':
        return IncidentStatus.closed;
      case 'cancelled':
        return IncidentStatus.cancelled;
      default:
        return IncidentStatus.open;
    }
  }

  String toDbString() {
    switch (this) {
      case IncidentStatus.inProgress:
        return 'in_progress';
      default:
        return name;
    }
  }

  String get label {
    switch (this) {
      case IncidentStatus.open:
        return 'Open';
      case IncidentStatus.acknowledged:
        return 'Acknowledged';
      case IncidentStatus.assigned:
        return 'Assigned';
      case IncidentStatus.inProgress:
        return 'In Progress';
      case IncidentStatus.resolved:
        return 'Resolved';
      case IncidentStatus.closed:
        return 'Closed';
      case IncidentStatus.cancelled:
        return 'Cancelled';
    }
  }
}

/// Represents an operational incident or assistance request.
class OperationalIncident {
  final String id;
  final String eventId;
  final String reporterType;
  final String? reporterId;
  final String reporterName;
  final String? reporterDeviceId;
  final IncidentCategory category;
  final IncidentPriority priority;
  final IncidentStatus status;
  final String title;
  final String description;
  final String? zoneId;
  final String? venueZoneName;
  final String? venuePoiId;
  final String? specificLocation;
  final String? assignedToId;
  final String? assignedToName;
  final DateTime? assignedAt;
  final DateTime? acknowledgedAt;
  final DateTime? resolvedAt;
  final DateTime? closedAt;
  final String? resolutionNotes;
  final String? staffNotes;
  final String? imageUrl;
  final String? linkedMessageId;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isOfflineQueued;

  const OperationalIncident({
    required this.id,
    required this.eventId,
    required this.reporterType,
    this.reporterId,
    required this.reporterName,
    this.reporterDeviceId,
    required this.category,
    required this.priority,
    required this.status,
    required this.title,
    required this.description,
    this.zoneId,
    this.venueZoneName,
    this.venuePoiId,
    this.specificLocation,
    this.assignedToId,
    this.assignedToName,
    this.assignedAt,
    this.acknowledgedAt,
    this.resolvedAt,
    this.closedAt,
    this.resolutionNotes,
    this.staffNotes,
    this.imageUrl,
    this.linkedMessageId,
    this.metadata,
    required this.createdAt,
    required this.updatedAt,
    this.isOfflineQueued = false,
  });

  bool get isAssistanceRequest =>
      reporterType == 'attendee' || category == IncidentCategory.attendeeAssistance;

  bool get isUrgent => priority == IncidentPriority.urgent;

  bool get isResolved =>
      status == IncidentStatus.resolved || status == IncidentStatus.closed;

  bool get isAssignedToMe {
    return false; // Checked against current user id dynamically in repository / UI
  }

  factory OperationalIncident.fromJson(Map<String, dynamic> json, {bool isOfflineQueued = false}) {
    DateTime parseDt(dynamic val, [DateTime? fallback]) {
      if (val == null) return fallback ?? DateTime.now();
      if (val is DateTime) return val;
      return DateTime.tryParse(val.toString()) ?? fallback ?? DateTime.now();
    }

    DateTime? parseNullableDt(dynamic val) {
      if (val == null) return null;
      if (val is DateTime) return val;
      return DateTime.tryParse(val.toString());
    }

    Map<String, dynamic>? parseMetadata(dynamic val) {
      if (val == null) return null;
      if (val is Map<String, dynamic>) return val;
      if (val is String) {
        try {
          return jsonDecode(val) as Map<String, dynamic>;
        } catch (_) {
          return null;
        }
      }
      return null;
    }

    return OperationalIncident(
      id: json['id'] as String? ?? '',
      eventId: json['event_id'] as String? ?? '',
      reporterType: json['reporter_type'] as String? ?? 'volunteer',
      reporterId: json['reporter_id'] as String?,
      reporterName: json['reporter_name'] as String? ?? 'Staff Member',
      reporterDeviceId: json['reporter_device_id'] as String?,
      category: IncidentCategory.fromString(json['category'] as String? ?? 'other'),
      priority: IncidentPriority.fromString(json['priority'] as String? ?? 'normal'),
      status: IncidentStatus.fromString(json['status'] as String? ?? 'open'),
      title: json['title'] as String? ?? 'Incident',
      description: json['description'] as String? ?? '',
      zoneId: json['zone_id'] as String?,
      venueZoneName: json['venue_zone_name'] as String?,
      venuePoiId: json['venue_poi_id'] as String?,
      specificLocation: json['specific_location'] as String?,
      assignedToId: json['assigned_to_id'] as String?,
      assignedToName: json['assigned_to_name'] as String?,
      assignedAt: parseNullableDt(json['assigned_at']),
      acknowledgedAt: parseNullableDt(json['acknowledged_at']),
      resolvedAt: parseNullableDt(json['resolved_at']),
      closedAt: parseNullableDt(json['closed_at']),
      resolutionNotes: json['resolution_notes'] as String?,
      staffNotes: json['staff_notes'] as String?,
      imageUrl: json['image_url'] as String?,
      linkedMessageId: json['linked_message_id'] as String?,
      metadata: parseMetadata(json['metadata']),
      createdAt: parseDt(json['created_at']),
      updatedAt: parseDt(json['updated_at']),
      isOfflineQueued: isOfflineQueued,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'event_id': eventId,
      'reporter_type': reporterType,
      'reporter_id': reporterId,
      'reporter_name': reporterName,
      'reporter_device_id': reporterDeviceId,
      'category': category.toDbString(),
      'priority': priority.toDbString(),
      'status': status.toDbString(),
      'title': title,
      'description': description,
      'zone_id': zoneId,
      'venue_zone_name': venueZoneName,
      'venue_poi_id': venuePoiId,
      'specific_location': specificLocation,
      'assigned_to_id': assignedToId,
      'assigned_to_name': assignedToName,
      'assigned_at': assignedAt?.toIso8601String(),
      'acknowledged_at': acknowledgedAt?.toIso8601String(),
      'resolved_at': resolvedAt?.toIso8601String(),
      'closed_at': closedAt?.toIso8601String(),
      'resolution_notes': resolutionNotes,
      'staff_notes': staffNotes,
      'image_url': imageUrl,
      'linked_message_id': linkedMessageId,
      'metadata': metadata,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  OperationalIncident copyWith({
    String? id,
    String? eventId,
    String? reporterType,
    String? reporterId,
    String? reporterName,
    String? reporterDeviceId,
    IncidentCategory? category,
    IncidentPriority? priority,
    IncidentStatus? status,
    String? title,
    String? description,
    String? zoneId,
    String? venueZoneName,
    String? venuePoiId,
    String? specificLocation,
    String? assignedToId,
    String? assignedToName,
    DateTime? assignedAt,
    DateTime? acknowledgedAt,
    DateTime? resolvedAt,
    DateTime? closedAt,
    String? resolutionNotes,
    String? staffNotes,
    String? imageUrl,
    String? linkedMessageId,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isOfflineQueued,
  }) {
    return OperationalIncident(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      reporterType: reporterType ?? this.reporterType,
      reporterId: reporterId ?? this.reporterId,
      reporterName: reporterName ?? this.reporterName,
      reporterDeviceId: reporterDeviceId ?? this.reporterDeviceId,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      title: title ?? this.title,
      description: description ?? this.description,
      zoneId: zoneId ?? this.zoneId,
      venueZoneName: venueZoneName ?? this.venueZoneName,
      venuePoiId: venuePoiId ?? this.venuePoiId,
      specificLocation: specificLocation ?? this.specificLocation,
      assignedToId: assignedToId ?? this.assignedToId,
      assignedToName: assignedToName ?? this.assignedToName,
      assignedAt: assignedAt ?? this.assignedAt,
      acknowledgedAt: acknowledgedAt ?? this.acknowledgedAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      closedAt: closedAt ?? this.closedAt,
      resolutionNotes: resolutionNotes ?? this.resolutionNotes,
      staffNotes: staffNotes ?? this.staffNotes,
      imageUrl: imageUrl ?? this.imageUrl,
      linkedMessageId: linkedMessageId ?? this.linkedMessageId,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isOfflineQueued: isOfflineQueued ?? this.isOfflineQueued,
    );
  }
}
