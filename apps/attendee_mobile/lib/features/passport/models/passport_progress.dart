/// Typed domain model representing an attendee's verified progress for an event.
/// 
/// Strictly distinguishes verified participation from available demo content.
/// Unverified metrics default to 0.
class PassportProgress {
  final String eventId;
  final int sessionsAttended;
  final int boothsVisited;
  final int activitiesCompleted;
  final int zonesVisited;
  final int pointsEarned;
  final int badgesUnlocked;

  const PassportProgress({
    required this.eventId,
    this.sessionsAttended = 0,
    this.boothsVisited = 0,
    this.activitiesCompleted = 0,
    this.zonesVisited = 0,
    this.pointsEarned = 0,
    this.badgesUnlocked = 0,
  });

  /// Factory creating an honest zero-progress state for an event.
  factory PassportProgress.zero(String eventId) {
    return PassportProgress(eventId: eventId);
  }

  /// Overall completion percentage indicator across event experiences.
  double get overallProgress {
    // Basic normalized score (e.g. out of 10 key milestones)
    final totalMilestones = sessionsAttended + boothsVisited + activitiesCompleted + zonesVisited;
    if (totalMilestones == 0) return 0.0;
    return (totalMilestones / 10).clamp(0.0, 1.0);
  }
}

/// Context for the current active or selected event in the Passport.
class PassportEventContext {
  final String eventId;
  final String eventName;
  final String venue;
  final DateTime eventDate;
  final String ticketStatus; // 'checked_in' | 'purchased' | 'none'
  final String? ticketCode;
  final bool isLive;

  const PassportEventContext({
    required this.eventId,
    required this.eventName,
    required this.venue,
    required this.eventDate,
    required this.ticketStatus,
    this.ticketCode,
    this.isLive = false,
  });

  /// Whether the attendee has physically checked in at the venue.
  bool get isCheckedIn => ticketStatus.toLowerCase() == 'checked_in';

  /// Whether the attendee holds an admission pass (purchased/registered).
  bool get isRegistered => ticketStatus.toLowerCase() == 'purchased' || isCheckedIn;
}
