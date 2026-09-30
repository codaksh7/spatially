/// SPATIALLY — VOLUNTEER BLOCK 2.5A
/// Operational Message Data Models and Priority / Lifecycle Enums.
library;

enum OperationalPriority {
  normal,
  important,
  urgent;

  static OperationalPriority fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'urgent':
        return OperationalPriority.urgent;
      case 'important':
        return OperationalPriority.important;
      default:
        return OperationalPriority.normal;
    }
  }

  String get value => name;
}

enum OperationalTargetType {
  event,
  zone,
  volunteer,
  organizer;

  static OperationalTargetType fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'zone':
        return OperationalTargetType.zone;
      case 'volunteer':
        return OperationalTargetType.volunteer;
      case 'organizer':
        return OperationalTargetType.organizer;
      default:
        return OperationalTargetType.event;
    }
  }

  String get value => name;
}

enum MessageLifecycleStatus {
  queued,
  sent,
  delivered,
  read,
  acknowledged,
  failed;

  static MessageLifecycleStatus fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'queued':
        return MessageLifecycleStatus.queued;
      case 'delivered':
        return MessageLifecycleStatus.delivered;
      case 'read':
        return MessageLifecycleStatus.read;
      case 'acknowledged':
        return MessageLifecycleStatus.acknowledged;
      case 'failed':
        return MessageLifecycleStatus.failed;
      default:
        return MessageLifecycleStatus.sent;
    }
  }
}

class OperationalMessage {
  final String id;
  final String eventId;
  final String senderId;
  final String senderRole;
  final String senderName;
  final OperationalTargetType targetType;
  final String? targetId;
  final String? zoneId;
  final String messageType;
  final OperationalPriority priority;
  final String body;
  final bool requiresAcknowledgment;
  final DateTime createdAt;
  final DateTime? expiresAt;

  // Recipient / receipt tracking
  final MessageLifecycleStatus receiptStatus;
  final DateTime? acknowledgedAt;
  final DateTime? readAt;

  // Local sync state
  final bool isLocalQueued;

  const OperationalMessage({
    required this.id,
    required this.eventId,
    required this.senderId,
    required this.senderRole,
    required this.senderName,
    required this.targetType,
    this.targetId,
    this.zoneId,
    required this.messageType,
    required this.priority,
    required this.body,
    this.requiresAcknowledgment = false,
    required this.createdAt,
    this.expiresAt,
    this.receiptStatus = MessageLifecycleStatus.sent,
    this.acknowledgedAt,
    this.readAt,
    this.isLocalQueued = false,
  });

  bool get isUrgent => priority == OperationalPriority.urgent;
  bool get isImportant => priority == OperationalPriority.important;
  bool get isBroadcast => targetType == OperationalTargetType.event || targetType == OperationalTargetType.zone;
  bool get isDirect => targetType == OperationalTargetType.volunteer;
  bool get isOrganizerChannel => targetType == OperationalTargetType.organizer;
  bool get isFromOrganizer => senderRole == 'organizer' || senderRole == 'admin';
  bool get isAcknowledged => acknowledgedAt != null || receiptStatus == MessageLifecycleStatus.acknowledged;
  bool get isRead => readAt != null || receiptStatus == MessageLifecycleStatus.read || isAcknowledged;

  factory OperationalMessage.fromJson(Map<String, dynamic> json, {String? currentUserId}) {
    // Parse receipt if joined
    MessageLifecycleStatus status = MessageLifecycleStatus.sent;
    DateTime? ackAt;
    DateTime? rdAt;

    if (json['receipts'] != null && json['receipts'] is List && (json['receipts'] as List).isNotEmpty) {
      final receiptsList = json['receipts'] as List;
      dynamic myReceipt;
      for (final r in receiptsList) {
        if (r is Map && r['recipient_id'] == currentUserId) {
          myReceipt = r;
          break;
        }
      }
      myReceipt ??= receiptsList.first;
      if (myReceipt is Map) {
        status = MessageLifecycleStatus.fromString(myReceipt['status'] as String?);
        if (myReceipt['acknowledged_at'] != null) {
          ackAt = DateTime.tryParse(myReceipt['acknowledged_at'] as String);
        }
        if (myReceipt['read_at'] != null) {
          rdAt = DateTime.tryParse(myReceipt['read_at'] as String);
        }
      }
    } else if (json['receipt_status'] != null) {
      status = MessageLifecycleStatus.fromString(json['receipt_status'] as String?);
      if (json['acknowledged_at'] != null) {
        ackAt = DateTime.tryParse(json['acknowledged_at'] as String);
      }
      if (json['read_at'] != null) {
        rdAt = DateTime.tryParse(json['read_at'] as String);
      }
    }

    return OperationalMessage(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      senderId: json['sender_id'] as String,
      senderRole: json['sender_role'] as String? ?? 'volunteer',
      senderName: json['sender_name'] as String? ?? 'Staff',
      targetType: OperationalTargetType.fromString(json['target_type'] as String?),
      targetId: json['target_id'] as String?,
      zoneId: json['zone_id'] as String?,
      messageType: json['message_type'] as String? ?? 'operational',
      priority: OperationalPriority.fromString(json['priority'] as String?),
      body: json['body'] as String? ?? '',
      requiresAcknowledgment: json['requires_acknowledgment'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'] as String)
          : null,
      receiptStatus: status,
      acknowledgedAt: ackAt,
      readAt: rdAt,
      isLocalQueued: json['is_local_queued'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'event_id': eventId,
      'sender_id': senderId,
      'sender_role': senderRole,
      'sender_name': senderName,
      'target_type': targetType.value,
      'target_id': targetId,
      'zone_id': zoneId,
      'message_type': messageType,
      'priority': priority.value,
      'body': body,
      'requires_acknowledgment': requiresAcknowledgment,
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
      'receipt_status': receiptStatus.name,
      'acknowledged_at': acknowledgedAt?.toIso8601String(),
      'read_at': readAt?.toIso8601String(),
      'is_local_queued': isLocalQueued,
    };
  }

  OperationalMessage copyWith({
    String? id,
    String? eventId,
    String? senderId,
    String? senderRole,
    String? senderName,
    OperationalTargetType? targetType,
    String? targetId,
    String? zoneId,
    String? messageType,
    OperationalPriority? priority,
    String? body,
    bool? requiresAcknowledgment,
    DateTime? createdAt,
    DateTime? expiresAt,
    MessageLifecycleStatus? receiptStatus,
    DateTime? acknowledgedAt,
    DateTime? readAt,
    bool? isLocalQueued,
  }) {
    return OperationalMessage(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      senderId: senderId ?? this.senderId,
      senderRole: senderRole ?? this.senderRole,
      senderName: senderName ?? this.senderName,
      targetType: targetType ?? this.targetType,
      targetId: targetId ?? this.targetId,
      zoneId: zoneId ?? this.zoneId,
      messageType: messageType ?? this.messageType,
      priority: priority ?? this.priority,
      body: body ?? this.body,
      requiresAcknowledgment: requiresAcknowledgment ?? this.requiresAcknowledgment,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      receiptStatus: receiptStatus ?? this.receiptStatus,
      acknowledgedAt: acknowledgedAt ?? this.acknowledgedAt,
      readAt: readAt ?? this.readAt,
      isLocalQueued: isLocalQueued ?? this.isLocalQueued,
    );
  }
}
