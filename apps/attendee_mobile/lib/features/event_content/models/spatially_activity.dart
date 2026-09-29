import 'package:flutter/material.dart';

/// Categories of engagement activities and quests at an event.
enum ActivityType {
  quest,
  challenge,
  checkpoint,
  workshopTask,
  trivia,
  sponsorTask,
}

/// Verification mechanism required to complete the activity.
enum VerificationMethod {
  qrCheckpoint,
  bleProximity,
  zonePresence,
  manualCheckin,
}

/// Attendee's progress state on this activity.
enum ActivityStatus {
  available,
  inProgress,
  completed,
  locked,
}

/// Typed domain model representing an interactive event activity, quest, or checkpoint challenge.
class SpatiallyActivity {
  final String id;
  final String eventId;
  final String title;
  final String description;
  final ActivityType type;
  final String? zoneId; // e.g. "712"
  final String locationName; // e.g. "Room 712 • Foyer & Registration"
  final String? poiId; // e.g. "poi_help_desk"
  final int points;
  final String? reward;
  final VerificationMethod verificationMethod;
  final ActivityStatus status;
  final String instructions;

  const SpatiallyActivity({
    required this.id,
    required this.eventId,
    required this.title,
    required this.description,
    required this.type,
    this.zoneId,
    required this.locationName,
    this.poiId,
    required this.points,
    this.reward,
    required this.verificationMethod,
    this.status = ActivityStatus.available,
    required this.instructions,
  });

  bool get isCompleted => status == ActivityStatus.completed;

  String get typeDisplayName {
    switch (type) {
      case ActivityType.quest:
        return 'Quest';
      case ActivityType.challenge:
        return 'Challenge';
      case ActivityType.checkpoint:
        return 'Checkpoint Stamp';
      case ActivityType.workshopTask:
        return 'Workshop Lab';
      case ActivityType.trivia:
        return 'Trivia & Quiz';
      case ActivityType.sponsorTask:
        return 'Partner Challenge';
    }
  }

  IconData get typeIcon {
    switch (type) {
      case ActivityType.quest:
        return Icons.explore_rounded;
      case ActivityType.challenge:
        return Icons.emoji_events_rounded;
      case ActivityType.checkpoint:
        return Icons.where_to_vote_rounded;
      case ActivityType.workshopTask:
        return Icons.terminal_rounded;
      case ActivityType.trivia:
        return Icons.quiz_rounded;
      case ActivityType.sponsorTask:
        return Icons.verified_rounded;
    }
  }

  String get verificationDisplayName {
    switch (verificationMethod) {
      case VerificationMethod.qrCheckpoint:
        return 'Scan QR at Checkpoint';
      case VerificationMethod.bleProximity:
        return 'BLE Proximity Beacon';
      case VerificationMethod.zonePresence:
        return 'Spatial Zone Presence';
      case VerificationMethod.manualCheckin:
        return 'Volunteer Verification';
    }
  }

  IconData get verificationIcon {
    switch (verificationMethod) {
      case VerificationMethod.qrCheckpoint:
        return Icons.qr_code_scanner_rounded;
      case VerificationMethod.bleProximity:
        return Icons.bluetooth_searching_rounded;
      case VerificationMethod.zonePresence:
        return Icons.sensors_rounded;
      case VerificationMethod.manualCheckin:
        return Icons.badge_rounded;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'event_id': eventId,
      'title': title,
      'description': description,
      'type': type.name,
      'zone_id': zoneId,
      'location_name': locationName,
      'poi_id': poiId,
      'points': points,
      'reward': reward,
      'verification_method': verificationMethod.name,
      'status': status.name,
      'instructions': instructions,
    };
  }

  factory SpatiallyActivity.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String? ?? json['activity_type'] as String?;
    return SpatiallyActivity(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      title: json['title'] as String? ?? 'Interactive Challenge',
      description: json['description'] as String? ?? '',
      type: ActivityType.values.firstWhere(
        (t) => t.name.toLowerCase() == typeStr?.toLowerCase(),
        orElse: () => ActivityType.challenge,
      ),
      zoneId: json['zone_id'] as String?,
      locationName: json['location_name'] as String? ?? 'Event Venue',
      poiId: json['poi_id'] as String?,
      points: (json['points'] as num?)?.toInt() ?? (json['points_reward'] as num?)?.toInt() ?? 25,
      reward: json['reward'] as String? ?? '${json['points_reward'] ?? 25} Points',
      verificationMethod: VerificationMethod.values.firstWhere(
        (v) => v.name.toLowerCase() == (json['verification_method'] as String?)?.toLowerCase(),
        orElse: () => VerificationMethod.qrCheckpoint,
      ),
      status: ActivityStatus.values.firstWhere(
        (s) => s.name.toLowerCase() == (json['status'] as String?)?.toLowerCase(),
        orElse: () => ActivityStatus.available,
      ),
      instructions: json['instructions'] as String? ?? 'Follow on-site checkpoint cues to complete.',
    );
  }
}
