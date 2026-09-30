import '../models/spatially_session.dart';
import '../models/spatially_booth.dart';
import '../models/spatially_activity.dart';

/// Centralized local demo fixtures for Event Content (Sessions, Booths, Activities).
/// 
/// IMPORTANT PRODUCT NOTICE:
/// The Supabase backend currently does not provide `sessions`, `booths`, or `activities`
/// tables. These fixtures provide clean, realistic, event-scoped domain data that precisely
/// aligns with the existing venue geometry (Rooms 701, 702, 706, 707, 711, 712 and POIs).
/// 
/// When backend tables are provisioned in a future phase, [EventContentRepository] can
/// switch to live database queries with zero disruption to the attendee UI.
class EventContentMockData {
  /// Flag indicating that current event content is powered by demo fixtures.
  static const bool isDemoData = true;

  /// Generates demo sessions scoped to an [eventId].
  static List<SpatiallySession> getSessions(String eventId) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return [
      SpatiallySession(
        id: 'session_keynote_01',
        eventId: eventId,
        title: 'Spatial Intelligence & The Next Era of Physical Perception',
        description:
            'Opening keynote addressing non-invasive spatial computing, BLE mesh topologies, and real-time localized event analytics.',
        speaker: 'Dr. Elena Vance',
        speakerRole: 'Lead AI Researcher',
        speakerCompany: 'Spatially Labs',
        startTime: today.add(const Duration(hours: 9, minutes: 30)),
        endTime: today.add(const Duration(hours: 10, minutes: 45)),
        zoneId: '701',
        roomName: 'Room 701 • Auditorium',
        poiId: 'poi_stage_a',
        category: SessionCategory.keynote,
        status: SessionStatus.live,
        tags: const ['Keynote', 'Spatial AI', 'BLE Mesh', 'Privacy'],
      ),
      SpatiallySession(
        id: 'session_workshop_01',
        eventId: eventId,
        title: 'Hands-on BLE Mesh & Peripheral Infrastructure',
        description:
            'Deep dive workshop on low-energy Bluetooth advertising protocols, rotating cryptographic hashes, and mobile listener design.',
        speaker: 'Marcus Chen',
        speakerRole: 'Principal Systems Engineer',
        speakerCompany: 'BeaconGrid Networks',
        startTime: today.add(const Duration(hours: 11, minutes: 15)),
        endTime: today.add(const Duration(hours: 12, minutes: 45)),
        zoneId: '707',
        roomName: 'Room 707 • Workshop & Labs',
        poiId: null,
        category: SessionCategory.workshop,
        status: SessionStatus.upcoming,
        tags: const ['Workshop', 'Hardware', 'Bluetooth', 'Embedded'],
      ),
      SpatiallySession(
        id: 'session_presentation_01',
        eventId: eventId,
        title: 'Autonomous Spatial Wayfinding & Indoor Robotics',
        description:
            'A technical showcase demonstrating graph-based indoor pathfinding algorithms and dynamic barrier avoidance using micro-sensors.',
        speaker: 'Sarah Jenkins',
        speakerRole: 'Hardware Engineering Lead',
        speakerCompany: 'Horizon Automations',
        startTime: today.add(const Duration(hours: 13, minutes: 30)),
        endTime: today.add(const Duration(hours: 14, minutes: 15)),
        zoneId: '702',
        roomName: 'Room 702 • Exhibition Hall A',
        poiId: 'poi_presentation_stage',
        category: SessionCategory.presentation,
        status: SessionStatus.upcoming,
        tags: const ['Robotics', 'Wayfinding', 'Autonomous'],
      ),
      SpatiallySession(
        id: 'session_panel_01',
        eventId: eventId,
        title: 'The Privacy Frontier: Ephemeral IDs & Non-Invasive Sensing',
        description:
            'Industry panelists debate the ethics and engineering realities of preserving attendee anonymity while capturing aggregate venue intelligence.',
        speaker: 'Aiden Patel (Moderator)',
        speakerRole: 'Head of Product Security',
        speakerCompany: 'PrivacyFirst Alliance',
        startTime: today.add(const Duration(hours: 15, minutes: 00)),
        endTime: today.add(const Duration(hours: 16, minutes: 00)),
        zoneId: '711',
        roomName: 'Room 711 • Seminar Room',
        poiId: null,
        category: SessionCategory.panel,
        status: SessionStatus.upcoming,
        tags: const ['Panel', 'Security', 'Ethics', 'Zero-Knowledge'],
      ),
      SpatiallySession(
        id: 'session_lightning_01',
        eventId: eventId,
        title: 'Zero-Knowledge Ticketing Architectures in Practice',
        description:
            'A brisk 30-minute breakdown of asymmetric cryptographic signatures for instant attendee gate admittance without server bottlenecks.',
        speaker: 'Alex Thorne',
        speakerRole: 'Cryptography Architect',
        speakerCompany: 'Crypta Systems',
        startTime: today.add(const Duration(hours: 8, minutes: 30)),
        endTime: today.add(const Duration(hours: 9, minutes: 15)),
        zoneId: '701',
        roomName: 'Room 701 • Auditorium',
        poiId: 'poi_stage_a',
        category: SessionCategory.lightning,
        status: SessionStatus.completed,
        tags: const ['Lightning', 'Crypto', 'Ticketing'],
      ),
    ];
  }

  /// Generates demo booths scoped to an [eventId].
  static List<SpatiallyBooth> getBooths(String eventId) {
    return [
      SpatiallyBooth(
        id: 'booth_cortex_ai',
        eventId: eventId,
        name: 'Neural Perception Lab',
        companyOrOrg: 'Cortex AI',
        description:
            'Demonstrating live multi-angle human pose estimation, occupancy tracking, and real-time room density analytics on edge compute.',
        boothNumber: 'Booth 1',
        category: BoothCategory.ai,
        zoneId: '702',
        roomName: 'Room 702 • Exhibition Hall A',
        poiId: 'poi_booth_1',
        isOpen: true,
        tags: const ['Computer Vision', 'Edge AI', 'Occupancy'],
        highlightDemo: 'Live camera cluster with interactive crowd heatmap display.',
      ),
      SpatiallyBooth(
        id: 'booth_beacongrid',
        eventId: eventId,
        name: 'BeaconGrid Systems',
        companyOrOrg: 'MeshWave Networks',
        description:
            'Ultra-low power BLE beacon infrastructure engineered for massive convention centers, sporting arenas, and corporate campuses.',
        boothNumber: 'Booth 2',
        category: BoothCategory.hardware,
        zoneId: '702',
        roomName: 'Room 702 • Exhibition Hall A',
        poiId: 'poi_booth_2',
        isOpen: true,
        tags: const ['BLE 5.3', 'Hardware', 'Micro-power'],
        highlightDemo: 'Live sensor mesh deployment broadcasting simulated signals.',
      ),
      SpatiallyBooth(
        id: 'booth_identity_zero',
        eventId: eventId,
        name: 'IdentityZero Protocol',
        companyOrOrg: 'Crypta Systems',
        description:
            'Decentralized ephemeral identity protocol keeping physical presence disconnected from persistent personal identifiers.',
        boothNumber: 'Booth 3',
        category: BoothCategory.developerTools,
        zoneId: '702',
        roomName: 'Room 702 • Exhibition Hall A',
        poiId: 'poi_booth_3',
        isOpen: true,
        tags: const ['Cryptography', 'Privacy', 'ZK-Proofs'],
        highlightDemo: 'Test your phone with our zero-knowledge attendance validator.',
      ),
      SpatiallyBooth(
        id: 'booth_sensorgateway',
        eventId: eventId,
        name: 'SensorGateway Pro',
        companyOrOrg: 'EmbeddedForge',
        description:
            'Turnkey IoT gateways capturing temperature, decibels, humidity, and Bluetooth traffic with sub-second cloud ingestion.',
        boothNumber: 'Booth 4',
        category: BoothCategory.hardware,
        zoneId: '706',
        roomName: 'Room 706 • Exhibition Hall B',
        poiId: 'poi_booth_4',
        isOpen: true,
        tags: const ['IoT', 'Environmental Sensors', 'Industrial'],
        highlightDemo: 'Live environmental monitoring rack with real-time telemetry.',
      ),
      SpatiallyBooth(
        id: 'booth_pathfinder',
        eventId: eventId,
        name: 'PathFinder Autonomous Robot',
        companyOrOrg: 'Horizon Automations',
        description:
            'Interactive mobile guide robot designed to greet attendees, provide venue wayfinding, and inspect hall circulation.',
        boothNumber: 'Booth 5',
        category: BoothCategory.startup,
        zoneId: '706',
        roomName: 'Room 706 • Exhibition Hall B',
        poiId: 'poi_booth_5',
        isOpen: true,
        tags: const ['Robotics', 'Indoor Navigation', 'LiDAR'],
        highlightDemo: 'Interact with PathFinder unit roving throughout Hall B.',
      ),
      SpatiallyBooth(
        id: 'booth_crowdsense',
        eventId: eventId,
        name: 'Live CrowdSense Station',
        companyOrOrg: 'MetricsFlow Analytics',
        description:
            'Real-time volunteer observation synthesis dashboard converting physical staff counts into actionable crowd density flows.',
        boothNumber: 'Booth 6',
        category: BoothCategory.showcase,
        zoneId: '706',
        roomName: 'Room 706 • Exhibition Hall B',
        poiId: 'poi_booth_6',
        isOpen: true,
        tags: const ['Analytics', 'Volunteer Ops', 'Flow Control'],
        highlightDemo: 'Console stream showing active volunteer check-ins and zone loads.',
      ),
    ];
  }

  /// Generates demo engagement activities scoped to an [eventId].
  static List<SpatiallyActivity> getActivities(String eventId) {
    return [
      SpatiallyActivity(
        id: 'act_registration_checkin',
        eventId: eventId,
        title: 'Foyer Check-in & Badge Verification',
        description:
            'Confirm your arrival at the central registration hub in Room 712 to receive your event credentials.',
        type: ActivityType.checkpoint,
        zoneId: '712',
        locationName: 'Room 712 • Foyer & Registration',
        poiId: 'poi_help_desk',
        points: 50,
        reward: 'Pioneer Check-in Badge',
        verificationMethod: VerificationMethod.qrCheckpoint,
        status: ActivityStatus.available,
        instructions:
            'Locate the attendee registration desk in the main foyer and scan the welcome station QR code.',
      ),
      SpatiallyActivity(
        id: 'act_ai_booth_interaction',
        eventId: eventId,
        title: 'Interactive AI Perception Challenge',
        description:
            'Visit the Cortex AI booth in Exhibition Hall A and test their live pose detection camera rig.',
        type: ActivityType.challenge,
        zoneId: '702',
        locationName: 'Room 702 • Booth 1 (Cortex AI)',
        poiId: 'poi_booth_1',
        points: 75,
        reward: 'Neural Vision Stamp',
        verificationMethod: VerificationMethod.bleProximity,
        status: ActivityStatus.available,
        instructions:
            'Stand in front of the neural vision test array at Booth 1 with Bluetooth enabled to register presence.',
      ),
      SpatiallyActivity(
        id: 'act_robot_encounter',
        eventId: eventId,
        title: 'Autonomous Robot Wayfinding Quest',
        description:
            'Find the roaming PathFinder robot in Exhibition Hall B, inspect its digital display, and complete the quick wayfinding quiz.',
        type: ActivityType.quest,
        zoneId: '706',
        locationName: 'Room 706 • Booth 5 (PathFinder)',
        poiId: 'poi_booth_5',
        points: 100,
        reward: 'Robotics Navigator Pin',
        verificationMethod: VerificationMethod.qrCheckpoint,
        status: ActivityStatus.available,
        instructions:
            'Meet the robot in Hall B, scan the QR code displayed on its front touchscreen, and verify your wayfinding question.',
      ),
      SpatiallyActivity(
        id: 'act_keynote_attendance',
        eventId: eventId,
        title: 'Auditorium Keynote Attendance',
        description:
            'Join the live keynote presentation in the main auditorium to earn participation points.',
        type: ActivityType.quest,
        zoneId: '701',
        locationName: 'Room 701 • Auditorium',
        poiId: 'poi_stage_a',
        points: 50,
        reward: 'Keynote Attendee Ribbon',
        verificationMethod: VerificationMethod.zonePresence,
        status: ActivityStatus.available,
        instructions:
            'Be present inside Room 701 Auditorium during the session. Spatial zone presence logs attendance.',
      ),
    ];
  }
}
