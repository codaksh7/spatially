import 'dart:convert';
import 'operational_message.dart';

export 'operational_message.dart' show OperationalPriority;

extension OperationalPriorityExt on OperationalPriority {
  String get label {
    switch (this) {
      case OperationalPriority.normal:
        return 'Normal';
      case OperationalPriority.important:
        return 'Important';
      case OperationalPriority.urgent:
        return 'Urgent';
    }
  }

  int get rank {
    switch (this) {
      case OperationalPriority.urgent:
        return 3;
      case OperationalPriority.important:
        return 2;
      case OperationalPriority.normal:
        return 1;
    }
  }
}

/// Categories of operational awareness events.
enum AwarenessCategory {
  crowd,
  incident,
  safety,
  assistance,
  team,
  shift,
  coverage,
  task,
  communication,
  system;

  String get label {
    switch (this) {
      case AwarenessCategory.crowd:
        return 'Crowd Density';
      case AwarenessCategory.incident:
        return 'Incident';
      case AwarenessCategory.safety:
        return 'Safety Alert';
      case AwarenessCategory.assistance:
        return 'Attendee Help';
      case AwarenessCategory.team:
        return 'Team Status';
      case AwarenessCategory.shift:
        return 'Shift Ops';
      case AwarenessCategory.coverage:
        return 'Relief / Coverage';
      case AwarenessCategory.task:
        return 'Supervisor Task';
      case AwarenessCategory.communication:
        return 'Operational Broadcast';
      case AwarenessCategory.system:
        return 'System & Scanner';
    }
  }

  static AwarenessCategory fromString(String val) {
    return AwarenessCategory.values.firstWhere(
      (e) => e.name.toLowerCase() == val.toLowerCase(),
      orElse: () => AwarenessCategory.system,
    );
  }
}

/// Relevance level to the current volunteer's operational context.
enum OperationalRelevance {
  myZone(100, 'My Zone'),
  myTeam(80, 'My Team'),
  currentShift(70, 'My Shift'),
  eventWideUrgent(90, 'Event-Wide Urgent'),
  eventWideImportant(60, 'Event-Wide Important'),
  unrelatedNormal(20, 'General Feed');

  final int score;
  final String label;
  const OperationalRelevance(this.score, this.label);

  static OperationalRelevance fromString(String val) {
    return OperationalRelevance.values.firstWhere(
      (e) => e.name.toLowerCase() == val.toLowerCase(),
      orElse: () => OperationalRelevance.unrelatedNormal,
    );
  }
}

/// Operational attention lifecycle states.
enum AttentionStatus {
  new_('new'),
  seen('seen'),
  acknowledged('acknowledged'),
  resolved('resolved');

  final String value;
  const AttentionStatus(this.value);

  static AttentionStatus fromString(String val) {
    if (val == 'new' || val == 'new_') return AttentionStatus.new_;
    return AttentionStatus.values.firstWhere(
      (e) => e.value.toLowerCase() == val.toLowerCase(),
      orElse: () => AttentionStatus.new_,
    );
  }
}

/// Normalized event awareness entity for Volunteer Block 2.5D.
class OperationalAwarenessItem {
  final String id;
  final String sourceId;
  final AwarenessCategory category;
  final OperationalPriority priority;
  final OperationalRelevance relevance;
  final AttentionStatus status;
  final String title;
  final String message;
  final DateTime timestamp;
  final String? zoneId;
  final String? zoneName;
  final String? zoneCode;
  final String? teamId;
  final String? teamName;
  final String? actionRoute;
  final Map<String, dynamic>? actionPayload;
  final bool isStale;
  final bool isCached;

  const OperationalAwarenessItem({
    required this.id,
    required this.sourceId,
    required this.category,
    required this.priority,
    required this.relevance,
    required this.status,
    required this.title,
    required this.message,
    required this.timestamp,
    this.zoneId,
    this.zoneName,
    this.zoneCode,
    this.teamId,
    this.teamName,
    this.actionRoute,
    this.actionPayload,
    this.isStale = false,
    this.isCached = false,
  });

  /// Stable key for haptic and attention deduplication.
  String get attentionKey => '${category.name}_${sourceId}_${priority.name}';

  /// True if item requires active volunteer attention.
  bool get requiresAttention =>
      priority != OperationalPriority.normal &&
      status != AttentionStatus.resolved;

  OperationalAwarenessItem copyWith({
    String? id,
    String? sourceId,
    AwarenessCategory? category,
    OperationalPriority? priority,
    OperationalRelevance? relevance,
    AttentionStatus? status,
    String? title,
    String? message,
    DateTime? timestamp,
    String? zoneId,
    String? zoneName,
    String? zoneCode,
    String? teamId,
    String? teamName,
    String? actionRoute,
    Map<String, dynamic>? actionPayload,
    bool? isStale,
    bool? isCached,
  }) {
    return OperationalAwarenessItem(
      id: id ?? this.id,
      sourceId: sourceId ?? this.sourceId,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      relevance: relevance ?? this.relevance,
      status: status ?? this.status,
      title: title ?? this.title,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      zoneId: zoneId ?? this.zoneId,
      zoneName: zoneName ?? this.zoneName,
      zoneCode: zoneCode ?? this.zoneCode,
      teamId: teamId ?? this.teamId,
      teamName: teamName ?? this.teamName,
      actionRoute: actionRoute ?? this.actionRoute,
      actionPayload: actionPayload ?? this.actionPayload,
      isStale: isStale ?? this.isStale,
      isCached: isCached ?? this.isCached,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'source_id': sourceId,
      'category': category.name,
      'priority': priority.name,
      'relevance': relevance.name,
      'status': status.value,
      'title': title,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'zone_id': zoneId,
      'zone_name': zoneName,
      'zone_code': zoneCode,
      'team_id': teamId,
      'team_name': teamName,
      'action_route': actionRoute,
      'action_payload': actionPayload != null ? jsonEncode(actionPayload) : null,
      'is_stale': isStale ? 1 : 0,
      'is_cached': isCached ? 1 : 0,
    };
  }

  factory OperationalAwarenessItem.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? payload;
    if (json['action_payload'] != null) {
      if (json['action_payload'] is Map) {
        payload = Map<String, dynamic>.from(json['action_payload'] as Map);
      } else if (json['action_payload'] is String && (json['action_payload'] as String).isNotEmpty) {
        try {
          payload = Map<String, dynamic>.from(jsonDecode(json['action_payload'] as String) as Map);
        } catch (_) {}
      }
    }

    return OperationalAwarenessItem(
      id: json['id'] as String,
      sourceId: json['source_id'] as String? ?? json['id'] as String,
      category: AwarenessCategory.fromString(json['category'] as String? ?? 'system'),
      priority: OperationalPriority.fromString(json['priority'] as String? ?? 'normal'),
      relevance: OperationalRelevance.fromString(json['relevance'] as String? ?? 'unrelatedNormal'),
      status: AttentionStatus.fromString(json['status'] as String? ?? 'new'),
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
      zoneId: json['zone_id'] as String?,
      zoneName: json['zone_name'] as String?,
      zoneCode: json['zone_code'] as String?,
      teamId: json['team_id'] as String?,
      teamName: json['team_name'] as String?,
      actionRoute: json['action_route'] as String?,
      actionPayload: payload,
      isStale: (json['is_stale'] == 1 || json['is_stale'] == true),
      isCached: (json['is_cached'] == 1 || json['is_cached'] == true),
    );
  }
}
