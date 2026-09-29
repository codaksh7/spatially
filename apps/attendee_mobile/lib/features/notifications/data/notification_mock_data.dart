import '../models/notification_models.dart';

/// Controlled demo notification fixtures for Spatially attendee testing.
/// 
/// Realistically grounded in the venue geometry and scheduled sessions.
/// Does NOT pretend to be real server push notifications or fake live AI.
class NotificationMockData {
  static const bool isDemo = true;

  static List<NotificationItem> getInitialNotifications({String? eventId}) {
    final now = DateTime.now();

    return [
      // 1. Session reminder (High priority, starting soon)
      NotificationItem(
        id: 'notif_session_01',
        eventId: eventId,
        title: 'Keynote starting in 15 minutes',
        body: '“Spatial Intelligence & The Next Era of Physical Perception” begins shortly in Room 701 Auditorium.',
        category: NotificationCategory.session,
        priority: NotificationPriority.high,
        timestamp: now.subtract(const Duration(minutes: 5)),
        isRead: false,
        action: NotificationAction(
          type: NotificationActionType.session,
          label: 'View Session',
          targetId: 'session_keynote_01',
          eventId: eventId,
          zoneId: '701',
          poiId: 'poi_stage_a',
        ),
      ),

      // 2. Authoritative Venue / Safety update (Urgent priority)
      NotificationItem(
        id: 'notif_safety_01',
        eventId: eventId,
        title: 'Venue Operational Notice: Hall A Access',
        body: 'West doors of Exhibition Hall A are temporarily staff-only for equipment staging. Please use the North entrance.',
        category: NotificationCategory.safety,
        priority: NotificationPriority.urgent,
        timestamp: now.subtract(const Duration(minutes: 25)),
        isRead: false,
        action: NotificationAction(
          type: NotificationActionType.safety,
          label: 'Safety & Exits',
          eventId: eventId,
          zoneId: '702',
        ),
      ),

      // 3. Connect / Networking notification (Normal priority)
      NotificationItem(
        id: 'notif_connect_01',
        eventId: eventId,
        title: 'New Connection Request',
        body: 'An attendee sharing your interest in “AI & Machine Learning” has sent you an event connection request.',
        category: NotificationCategory.connect,
        priority: NotificationPriority.normal,
        timestamp: now.subtract(const Duration(hours: 1, minutes: 10)),
        isRead: false,
        action: const NotificationAction(
          type: NotificationActionType.connect,
          label: 'Open Connect',
        ),
      ),

      // 4. Meeting point coordination (High priority)
      NotificationItem(
        id: 'notif_connect_meeting_01',
        eventId: eventId,
        title: 'Meeting Point Ready',
        body: 'Your agreed meeting point is at the Foyer Help Desk (Room 712). Tap to open wayfinding guidance.',
        category: NotificationCategory.connect,
        priority: NotificationPriority.high,
        timestamp: now.subtract(const Duration(hours: 2)),
        isRead: true,
        action: NotificationAction(
          type: NotificationActionType.map,
          label: 'Show on Map',
          zoneId: '712',
          poiId: 'poi_help_desk',
        ),
      ),

      // 5. Activity / Quest checkpoint (Normal priority)
      NotificationItem(
        id: 'notif_activity_01',
        eventId: eventId,
        title: 'Quest Available: Autonomous Robot Encounter',
        body: 'The roving PathFinder robot is now active in Exhibition Hall B. Meet the robot and scan its QR code for 100 points!',
        category: NotificationCategory.activity,
        priority: NotificationPriority.normal,
        timestamp: now.subtract(const Duration(hours: 3, minutes: 30)),
        isRead: true,
        action: NotificationAction(
          type: NotificationActionType.activity,
          label: 'View Quest',
          targetId: 'act_robot_encounter',
          eventId: eventId,
          zoneId: '706',
          poiId: 'poi_booth_5',
        ),
      ),

      // 6. Recommendation: Booth showcase (Normal priority)
      NotificationItem(
        id: 'notif_rec_01',
        eventId: eventId,
        title: 'Featured Booth: Neural Perception Lab',
        body: 'Cortex AI is hosting live computer vision demonstrations in Room 702. Stop by Booth 1 to explore their neural vision rig.',
        category: NotificationCategory.recommendation,
        priority: NotificationPriority.normal,
        timestamp: now.subtract(const Duration(hours: 5)),
        isRead: true,
        action: NotificationAction(
          type: NotificationActionType.booth,
          label: 'View Booth',
          targetId: 'booth_cortex_ai',
          eventId: eventId,
          zoneId: '702',
          poiId: 'poi_booth_1',
        ),
      ),

      // 7. General Event announcement (Normal priority)
      NotificationItem(
        id: 'notif_event_01',
        eventId: eventId,
        title: 'Welcome to Spatially Expo 2026',
        body: 'Check out the interactive schedule, discover booths across Halls A & B, and collect badges in your Spatial Passport.',
        category: NotificationCategory.event,
        priority: NotificationPriority.normal,
        timestamp: now.subtract(const Duration(days: 1)),
        isRead: true,
        action: NotificationAction(
          type: NotificationActionType.eventDetail,
          label: 'Event Overview',
          eventId: eventId,
        ),
      ),
    ];
  }
}
