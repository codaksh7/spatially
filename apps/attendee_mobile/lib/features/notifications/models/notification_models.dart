import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../design_system/spatially_colors.dart';

/// Categories of attendee notifications.
///
/// Canonical Mapping from Supabase `event_notifications.category`:
/// - `schedule`    -> [NotificationCategory.session] ('Sessions')
/// - `engagement`  -> [NotificationCategory.activity] ('Activities')
/// - `networking`  -> [NotificationCategory.connect] ('Networking')
/// - `safety`      -> [NotificationCategory.safety] ('Safety & Venue')
/// - `crowd`       -> [NotificationCategory.crowd] ('Crowd Alerts')
/// - `general`     -> [NotificationCategory.event] ('Announcements')
/// - `urgent`      -> [NotificationCategory.safety] with [NotificationPriority.urgent]
enum NotificationCategory {
  session,
  activity,
  connect,
  safety,
  event,
  crowd,
  recommendation,
  system;

  String get label {
    switch (this) {
      case NotificationCategory.session:
        return 'Sessions';
      case NotificationCategory.activity:
        return 'Activities';
      case NotificationCategory.connect:
        return 'Networking';
      case NotificationCategory.safety:
        return 'Safety & Venue';
      case NotificationCategory.event:
        return 'Announcements';
      case NotificationCategory.crowd:
        return 'Crowd Alerts';
      case NotificationCategory.recommendation:
        return 'Recommendations';
      case NotificationCategory.system:
        return 'System';
    }
  }

  IconData get icon {
    switch (this) {
      case NotificationCategory.session:
        return Icons.alarm_rounded;
      case NotificationCategory.activity:
        return Icons.military_tech_rounded;
      case NotificationCategory.connect:
        return Icons.hub_outlined;
      case NotificationCategory.safety:
        return Icons.health_and_safety_outlined;
      case NotificationCategory.event:
        return Icons.campaign_rounded;
      case NotificationCategory.crowd:
        return Icons.groups_rounded;
      case NotificationCategory.recommendation:
        return Icons.lightbulb_outline_rounded;
      case NotificationCategory.system:
        return Icons.info_outline_rounded;
    }
  }

  Color get color {
    switch (this) {
      case NotificationCategory.session:
        return SpatiallyColors.violet;
      case NotificationCategory.activity:
        return SpatiallyColors.warning;
      case NotificationCategory.connect:
        return SpatiallyColors.spatialCyan;
      case NotificationCategory.safety:
        return SpatiallyColors.error;
      case NotificationCategory.event:
        return SpatiallyColors.info;
      case NotificationCategory.crowd:
        return const Color(0xFFF59E0B); // Amber
      case NotificationCategory.recommendation:
        return const Color(0xFF10B981); // Emerald
      case NotificationCategory.system:
        return Colors.grey;
    }
  }

  /// Canonical parser translating backend categories and client enum names.
  static NotificationCategory parseCategory(String? raw) {
    if (raw == null) return NotificationCategory.event;
    final lower = raw.trim().toLowerCase();
    switch (lower) {
      case 'schedule':
      case 'session':
      case 'sessions':
        return NotificationCategory.session;
      case 'engagement':
      case 'activity':
      case 'activities':
        return NotificationCategory.activity;
      case 'networking':
      case 'connect':
        return NotificationCategory.connect;
      case 'urgent':
      case 'safety':
        return NotificationCategory.safety;
      case 'crowd':
        return NotificationCategory.crowd;
      case 'general':
      case 'announcement':
      case 'announcements':
      case 'event':
        return NotificationCategory.event;
      case 'recommendation':
      case 'recommendations':
        return NotificationCategory.recommendation;
      case 'system':
        return NotificationCategory.system;
      default:
        for (final c in NotificationCategory.values) {
          if (c.name.toLowerCase() == lower) return c;
        }
        return NotificationCategory.event;
    }
  }

  /// Derives priority from explicit priority column or 'urgent' category.
  static NotificationPriority parsePriority(String? category, String? priority) {
    if (category?.trim().toLowerCase() == 'urgent') {
      return NotificationPriority.urgent;
    }
    if (priority == null) return NotificationPriority.normal;
    final p = priority.trim().toLowerCase();
    switch (p) {
      case 'urgent':
        return NotificationPriority.urgent;
      case 'high':
        return NotificationPriority.high;
      case 'low':
        return NotificationPriority.low;
      case 'normal':
      default:
        return NotificationPriority.normal;
    }
  }
}

/// Urgency / priority level of the notification.
enum NotificationPriority {
  low,
  normal,
  high,
  urgent;

  bool get isHighOrUrgent => this == NotificationPriority.high || this == NotificationPriority.urgent;
}

/// Target destination for contextual deep linking.
enum NotificationActionType {
  none,
  session,
  activity,
  booth,
  map,
  connect,
  safety,
  eventDetail;

  String get defaultLabel {
    switch (this) {
      case NotificationActionType.session:
        return 'View Session';
      case NotificationActionType.activity:
        return 'View Activity';
      case NotificationActionType.booth:
        return 'View Booth';
      case NotificationActionType.map:
        return 'View on Map';
      case NotificationActionType.connect:
        return 'Open Connect';
      case NotificationActionType.safety:
        return 'Safety Info';
      case NotificationActionType.eventDetail:
        return 'Event Details';
      case NotificationActionType.none:
        return 'View';
    }
  }
}

/// Contextual action attached to a notification.
class NotificationAction {
  final NotificationActionType type;
  final String? label;
  final String? targetId;
  final String? eventId;
  final String? zoneId;
  final String? poiId;

  const NotificationAction({
    required this.type,
    this.label,
    this.targetId,
    this.eventId,
    this.zoneId,
    this.poiId,
  });

  String get displayLabel => label ?? type.defaultLabel;

  Map<String, dynamic> toMap() => {
        'type': type.name,
        'label': label,
        'targetId': targetId,
        'eventId': eventId,
        'zoneId': zoneId,
        'poiId': poiId,
      };

  factory NotificationAction.fromMap(Map<String, dynamic> map) {
    NotificationActionType parseType(String? val) {
      if (val == null) return NotificationActionType.none;
      for (final t in NotificationActionType.values) {
        if (t.name == val) return t;
      }
      return NotificationActionType.none;
    }

    return NotificationAction(
      type: parseType(map['type'] as String?),
      label: map['label'] as String?,
      targetId: map['targetId'] as String?,
      eventId: map['eventId'] as String?,
      zoneId: map['zoneId'] as String?,
      poiId: map['poiId'] as String?,
    );
  }

  /// Parses action route string from database column `action_route`.
  /// Formats supported:
  /// - `session:<id>`
  /// - `booth:<id>`
  /// - `activity:<id>`
  /// - `map:<zoneId>` or `map:<zoneId>:<poiId>`
  /// - `connect`
  /// - `safety`
  /// - `event`
  factory NotificationAction.fromRoute(String? route, {String? eventId}) {
    if (route == null || route.trim().isEmpty) {
      return const NotificationAction(type: NotificationActionType.none);
    }

    final trimmed = route.trim();
    final parts = trimmed.split(':');
    final scheme = parts[0].toLowerCase();
    final param1 = parts.length > 1 ? parts[1] : null;
    final param2 = parts.length > 2 ? parts[2] : null;

    switch (scheme) {
      case 'session':
        return NotificationAction(
          type: NotificationActionType.session,
          targetId: param1,
          eventId: eventId,
        );
      case 'booth':
        return NotificationAction(
          type: NotificationActionType.booth,
          targetId: param1,
          eventId: eventId,
        );
      case 'activity':
        return NotificationAction(
          type: NotificationActionType.activity,
          targetId: param1,
          eventId: eventId,
        );
      case 'map':
        return NotificationAction(
          type: NotificationActionType.map,
          eventId: eventId,
          zoneId: param1,
          poiId: param2,
        );
      case 'connect':
        return NotificationAction(
          type: NotificationActionType.connect,
          eventId: eventId,
        );
      case 'safety':
        return NotificationAction(
          type: NotificationActionType.safety,
          eventId: eventId,
        );
      case 'event':
      case 'announcement':
        return NotificationAction(
          type: NotificationActionType.eventDetail,
          eventId: param1 ?? eventId,
        );
      default:
        return NotificationAction(
          type: NotificationActionType.eventDetail,
          eventId: eventId,
          label: 'View Announcement',
        );
    }
  }
}

/// Primary notification domain model for attendees.
/// 
/// Privacy: Contains zero persistent attendee UUIDs, BLE mac/rotating IDs,
/// or raw telemetry.
class NotificationItem {
  final String id;
  final String? eventId;
  final String title;
  final String body;
  final NotificationCategory category;
  final NotificationPriority priority;
  final DateTime timestamp;
  final bool isRead;
  final NotificationAction action;
  final Map<String, dynamic>? metadata;
  final DateTime? expiresAt;

  const NotificationItem({
    required this.id,
    this.eventId,
    required this.title,
    required this.body,
    required this.category,
    this.priority = NotificationPriority.normal,
    required this.timestamp,
    this.isRead = false,
    this.action = const NotificationAction(type: NotificationActionType.none),
    this.metadata,
    this.expiresAt,
  });

  NotificationItem copyWith({
    String? id,
    String? eventId,
    String? title,
    String? body,
    NotificationCategory? category,
    NotificationPriority? priority,
    DateTime? timestamp,
    bool? isRead,
    NotificationAction? action,
    Map<String, dynamic>? metadata,
    DateTime? expiresAt,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      title: title ?? this.title,
      body: body ?? this.body,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      action: action ?? this.action,
      metadata: metadata ?? this.metadata,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'eventId': eventId,
        'title': title,
        'body': body,
        'category': category.name,
        'priority': priority.name,
        'timestamp': timestamp.toIso8601String(),
        'isRead': isRead,
        'action': action.toMap(),
        'metadata': metadata,
        'expiresAt': expiresAt?.toIso8601String(),
      };

  factory NotificationItem.fromMap(Map<String, dynamic> map) {
    final rawCat = map['category']?.toString();
    final rawPriority = map['priority']?.toString();
    final category = NotificationCategory.parseCategory(rawCat);
    final priority = NotificationCategory.parsePriority(rawCat, rawPriority);

    // Support both event_id (DB) and eventId (model map)
    final eventId = (map['eventId'] ?? map['event_id'])?.toString();

    // Action resolution
    NotificationAction action;
    if (map['action'] != null) {
      action = NotificationAction.fromMap(Map<String, dynamic>.from(map['action'] as Map));
    } else if (map['action_route'] != null) {
      action = NotificationAction.fromRoute(map['action_route']?.toString(), eventId: eventId);
    } else {
      action = const NotificationAction(type: NotificationActionType.none);
    }

    // Timestamp resolution
    final tsStr = (map['timestamp'] ?? map['created_at'])?.toString();
    final timestamp = tsStr != null ? (DateTime.tryParse(tsStr)?.toLocal() ?? DateTime.now()) : DateTime.now();

    // Expiry resolution
    final expStr = (map['expiresAt'] ?? map['expires_at'])?.toString();
    final expiresAt = expStr != null ? DateTime.tryParse(expStr)?.toLocal() : null;

    return NotificationItem(
      id: (map['id'] ?? '').toString(),
      eventId: eventId,
      title: (map['title'] ?? 'Notice').toString(),
      body: (map['body'] ?? '').toString(),
      category: category,
      priority: priority,
      timestamp: timestamp,
      isRead: map['isRead'] as bool? ?? false,
      action: action,
      metadata: map['metadata'] != null ? Map<String, dynamic>.from(map['metadata'] as Map) : null,
      expiresAt: expiresAt,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory NotificationItem.fromJson(String source) =>
      NotificationItem.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
