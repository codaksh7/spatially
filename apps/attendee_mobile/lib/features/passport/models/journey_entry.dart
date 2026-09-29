import 'package:flutter/material.dart';
import '../../../design_system/design_system.dart';

/// Categories of verified timeline entries within an attendee's event journey.
enum JourneyEntryType {
  checkIn,
  sessionAttended,
  boothVisited,
  activityCompleted,
  zoneDiscovered,
  rewardUnlocked;

  IconData get icon {
    switch (this) {
      case JourneyEntryType.checkIn:
        return Icons.how_to_reg_rounded;
      case JourneyEntryType.sessionAttended:
        return Icons.campaign_rounded;
      case JourneyEntryType.boothVisited:
        return Icons.storefront_rounded;
      case JourneyEntryType.activityCompleted:
        return Icons.task_alt_rounded;
      case JourneyEntryType.zoneDiscovered:
        return Icons.explore_rounded;
      case JourneyEntryType.rewardUnlocked:
        return Icons.stars_rounded;
    }
  }

  Color get color {
    switch (this) {
      case JourneyEntryType.checkIn:
        return SpatiallyColors.success;
      case JourneyEntryType.sessionAttended:
        return SpatiallyColors.violet;
      case JourneyEntryType.boothVisited:
        return SpatiallyColors.spatialCyan;
      case JourneyEntryType.activityCompleted:
        return SpatiallyColors.warning;
      case JourneyEntryType.zoneDiscovered:
        return SpatiallyColors.info;
      case JourneyEntryType.rewardUnlocked:
        return SpatiallyColors.violet;
    }
  }

  String get label {
    switch (this) {
      case JourneyEntryType.checkIn:
        return 'CHECK-IN';
      case JourneyEntryType.sessionAttended:
        return 'SESSION';
      case JourneyEntryType.boothVisited:
        return 'BOOTH';
      case JourneyEntryType.activityCompleted:
        return 'QUEST';
      case JourneyEntryType.zoneDiscovered:
        return 'ZONE';
      case JourneyEntryType.rewardUnlocked:
        return 'REWARD';
    }
  }
}

/// A verified entry in the attendee's personal event journey timeline.
class JourneyEntry {
  final String id;
  final String eventId;
  final DateTime timestamp;
  final String title;
  final String subtitle;
  final JourneyEntryType type;
  final String? locationName;
  final String? zoneId;
  final String? poiId;
  final String? referenceId;
  final bool isVerified;

  const JourneyEntry({
    required this.id,
    required this.eventId,
    required this.timestamp,
    required this.title,
    required this.subtitle,
    required this.type,
    this.locationName,
    this.zoneId,
    this.poiId,
    this.referenceId,
    this.isVerified = true,
  });
}
