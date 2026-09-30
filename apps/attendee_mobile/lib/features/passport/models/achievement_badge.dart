import 'package:flutter/material.dart';

/// Categories of event achievements.
enum AchievementCategory {
  checkIn,
  session,
  booth,
  activity,
  exploration;

  String get displayName {
    switch (this) {
      case AchievementCategory.checkIn:
        return 'Check-in';
      case AchievementCategory.session:
        return 'Sessions';
      case AchievementCategory.booth:
        return 'Exhibition';
      case AchievementCategory.activity:
        return 'Quests';
      case AchievementCategory.exploration:
        return 'Exploration';
    }
  }
}

/// An achievement badge definition for the event passport.
/// 
/// Shows locked or unlocked status based strictly on verified participation.
class AchievementBadge {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final AchievementCategory category;
  final int requiredCount;
  final int currentCount;
  final bool isUnlocked;
  final DateTime? unlockedAt;

  const AchievementBadge({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.category,
    required this.requiredCount,
    this.currentCount = 0,
    this.isUnlocked = false,
    this.unlockedAt,
  });

  /// Progress fraction towards unlocking this badge (0.0 to 1.0).
  double get progressFraction {
    if (requiredCount <= 0) return isUnlocked ? 1.0 : 0.0;
    return (currentCount / requiredCount).clamp(0.0, 1.0);
  }
}
