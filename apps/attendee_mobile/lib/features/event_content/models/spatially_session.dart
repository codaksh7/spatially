import 'package:flutter/material.dart';

/// Categories of sessions in an event.
enum SessionCategory {
  keynote,
  workshop,
  presentation,
  panel,
  lightning,
  networking,
}

/// Dynamic or scheduled status of a session.
enum SessionStatus {
  upcoming,
  live,
  completed,
}

typedef SpatiallySessionStatus = SessionStatus;

/// Typed domain model representing a structured event session (talk, workshop, keynote, panel).
class SpatiallySession {
  final String id;
  final String eventId;
  final String title;
  final String description;
  final String speaker;
  final String? speakerRole;
  final String? speakerCompany;
  final DateTime startTime;
  final DateTime endTime;
  final String? zoneId; // e.g. "701"
  final String roomName; // e.g. "Room 701 • Auditorium"
  final String? poiId; // e.g. "poi_stage_a"
  final SessionCategory category;
  final bool isLiveOverride;
  final SessionStatus? _explicitStatus;
  final List<String> tags;

  const SpatiallySession({
    required this.id,
    required this.eventId,
    required this.title,
    required this.description,
    required this.speaker,
    this.speakerRole,
    this.speakerCompany,
    required this.startTime,
    required this.endTime,
    this.zoneId,
    required this.roomName,
    this.poiId,
    required this.category,
    SessionStatus? status,
    this.isLiveOverride = false,
    this.tags = const [],
  }) : _explicitStatus = status;

  /// Dynamic temporal status calculation.
  ///
  /// Precedence (Phase 7C Work Item A):
  /// 1. If is_live == true: LIVE (manual organizer override)
  /// 2. Otherwise:
  ///    if now < start_time: UPCOMING
  ///    else if now >= start_time AND now < end_time: LIVE
  ///    else if now >= end_time: COMPLETED
  SessionStatus calculateStatus([DateTime? referenceTime]) {
    if (isLiveOverride) return SessionStatus.live;
    if (referenceTime == null && _explicitStatus != null) return _explicitStatus;

    final now = referenceTime ?? DateTime.now();
    if (now.isBefore(startTime)) {
      return SessionStatus.upcoming;
    } else if (now.isBefore(endTime)) {
      return SessionStatus.live;
    } else {
      return SessionStatus.completed;
    }
  }

  SessionStatus get status => calculateStatus();

  bool get isLive => status == SessionStatus.live;
  bool get isUpcoming => status == SessionStatus.upcoming;
  bool get isCompleted => status == SessionStatus.completed;

  String get speakerName => speaker;
  String get location => roomName;
  int get durationMinutes => endTime.difference(startTime).inMinutes;

  String get formattedStartTime {
    final local = startTime.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String get categoryDisplayName {
    switch (category) {
      case SessionCategory.keynote:
        return 'Keynote';
      case SessionCategory.workshop:
        return 'Workshop';
      case SessionCategory.presentation:
        return 'Presentation';
      case SessionCategory.panel:
        return 'Panel Discussion';
      case SessionCategory.lightning:
        return 'Lightning Talk';
      case SessionCategory.networking:
        return 'Networking';
    }
  }

  IconData get categoryIcon {
    switch (category) {
      case SessionCategory.keynote:
        return Icons.campaign_rounded;
      case SessionCategory.workshop:
        return Icons.build_circle_rounded;
      case SessionCategory.presentation:
        return Icons.co_present_rounded;
      case SessionCategory.panel:
        return Icons.groups_rounded;
      case SessionCategory.lightning:
        return Icons.bolt_rounded;
      case SessionCategory.networking:
        return Icons.people_outline_rounded;
    }
  }

  String get formattedTimeRange {
    final startStr = _formatTime(startTime);
    final endStr = _formatTime(endTime);
    return '$startStr – $endStr';
  }

  static String _formatTime(DateTime dt) {
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final minuteStr = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minuteStr $period';
  }

  SpatiallySession copyWith({
    String? id,
    String? eventId,
    String? title,
    String? description,
    String? speaker,
    String? speakerRole,
    String? speakerCompany,
    DateTime? startTime,
    DateTime? endTime,
    String? zoneId,
    String? roomName,
    String? poiId,
    SessionCategory? category,
    SessionStatus? status,
    bool? isLiveOverride,
    List<String>? tags,
  }) {
    return SpatiallySession(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      title: title ?? this.title,
      description: description ?? this.description,
      speaker: speaker ?? this.speaker,
      speakerRole: speakerRole ?? this.speakerRole,
      speakerCompany: speakerCompany ?? this.speakerCompany,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      zoneId: zoneId ?? this.zoneId,
      roomName: roomName ?? this.roomName,
      poiId: poiId ?? this.poiId,
      category: category ?? this.category,
      status: status ?? _explicitStatus,
      isLiveOverride: isLiveOverride ?? this.isLiveOverride,
      tags: tags ?? this.tags,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'event_id': eventId,
      'title': title,
      'description': description,
      'speaker': speaker,
      'speaker_name': speaker,
      'speaker_role': speakerRole,
      'speaker_company': speakerCompany,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'zone_id': zoneId,
      'room_name': roomName,
      'stage_name': roomName,
      'poi_id': poiId,
      'category': category.name,
      'is_live': isLiveOverride,
      'status': status.name,
      'tags': tags,
    };
  }

  factory SpatiallySession.fromJson(Map<String, dynamic> json, {DateTime? referenceTime}) {
    final isLive = (json['is_live'] as bool?) ?? false;
    final startTime = DateTime.tryParse(json['start_time'] as String? ?? '')?.toLocal() ?? DateTime.now();
    final endTime = DateTime.tryParse(json['end_time'] as String? ?? '')?.toLocal() ??
        startTime.add(const Duration(hours: 1));

    return SpatiallySession(
      id: json['id']?.toString() ?? '',
      eventId: json['event_id']?.toString() ?? '',
      title: json['title'] as String? ?? 'Untitled Session',
      description: json['description'] as String? ?? '',
      speaker: json['speaker'] as String? ?? json['speaker_name'] as String? ?? 'Guest Speaker',
      speakerRole: json['speaker_role'] as String?,
      speakerCompany: json['speaker_company'] as String?,
      startTime: startTime,
      endTime: endTime,
      zoneId: json['zone_id']?.toString(),
      roomName: json['room_name'] as String? ?? json['stage_name'] as String? ?? 'Venue Stage',
      poiId: json['poi_id']?.toString(),
      category: SessionCategory.values.firstWhere(
        (c) => c.name.toLowerCase() == (json['category'] as String?)?.toLowerCase(),
        orElse: () => SessionCategory.presentation,
      ),
      isLiveOverride: isLive,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? const [],
    );
  }
}
