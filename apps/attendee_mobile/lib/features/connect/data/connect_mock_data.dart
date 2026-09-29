import '../models/connect_models.dart';

/// Curated demo fixture for event-scoped networking.
///
/// Strictly isolated behind the [ConnectRepository] boundary.
/// In future phases, these will be replaced with real-time Supabase Presence & Broadcast channels.
class ConnectMockData {
  static const List<MeetingPoint> availableMeetingPoints = [
    MeetingPoint(
      id: 'mp_foyer',
      title: 'Main Foyer & Registration',
      subtitle: 'Entrance lounge and registration desks',
      zoneId: '712',
      roomNumber: 'Room 712',
    ),
    MeetingPoint(
      id: 'mp_auditorium',
      title: 'Auditorium Entrance',
      subtitle: 'Keynote stage & main theater lobby',
      zoneId: '701',
      poiId: 'poi_stage_a',
      roomNumber: 'Room 701',
    ),
    MeetingPoint(
      id: 'mp_booth_1',
      title: 'Booth 1 • Spatially Analytics',
      subtitle: 'Project Exhibition Hall A center aisle',
      zoneId: '702',
      poiId: 'poi_booth_1',
      roomNumber: 'Room 702',
    ),
    MeetingPoint(
      id: 'mp_booth_3',
      title: 'Booth 3 • IoT Hardware Showcase',
      subtitle: 'Project Exhibition Hall A north corner',
      zoneId: '702',
      poiId: 'poi_booth_3',
      roomNumber: 'Room 702',
    ),
    MeetingPoint(
      id: 'mp_hall_b',
      title: 'Interactive Showcase Labs',
      subtitle: 'Project Exhibition Hall B entry door',
      zoneId: '706',
      poiId: 'poi_booth_4',
      roomNumber: 'Room 706',
    ),
    MeetingPoint(
      id: 'mp_workshops',
      title: 'Workshop & Tech Labs',
      subtitle: 'Hands-on developer workshop space',
      zoneId: '707',
      roomNumber: 'Room 707',
    ),
  ];

  static List<ConnectProfile> initialAttendees = [
    const ConnectProfile(
      id: 'demo_aarav_sharma',
      displayName: 'Aarav Sharma',
      headline: 'AI & Robotics Researcher',
      organization: 'Neuromorphic Lab',
      bio: 'Exploring edge vision models, real-time SLAM, and spatial robotics. Let us talk multimodal perception.',
      interests: ['AI & Machine Learning', 'Robotics & IoT'],
      locationNote: 'Near Auditorium (Room 701)',
      isReadyToChat: true,
      avatarInitials: 'AS',
    ),
    const ConnectProfile(
      id: 'demo_meera_patel',
      displayName: 'Meera Patel',
      headline: 'Lead Product Designer',
      organization: 'Studio Flow',
      bio: 'Designing human-centered spatial experiences. Passionate about accessible UI and tactile computing.',
      interests: ['UI/UX & Product Design', 'Mobile Engineering'],
      locationNote: 'Exhibition Hall A (Room 702)',
      isReadyToChat: true,
      avatarInitials: 'MP',
    ),
    const ConnectProfile(
      id: 'demo_rohan_mehta',
      displayName: 'Rohan Mehta',
      headline: 'Cloud & Infrastructure Architect',
      organization: 'ScaleCore Systems',
      bio: 'Zero-trust architecture, high-concurrency microservices, and distributed observability pipelines.',
      interests: ['Cloud & DevOps', 'Cybersecurity'],
      locationNote: 'Workshop & Labs (Room 707)',
      isReadyToChat: false,
      avatarInitials: 'RM',
    ),
    const ConnectProfile(
      id: 'demo_ananya_iyer',
      displayName: 'Ananya Iyer',
      headline: 'Data & ML Engineer',
      organization: 'Voxel Analytics',
      bio: 'Predictive crowd dynamics, graph neural networks, and event intelligence analytics.',
      interests: ['AI & Machine Learning', 'Data Science & Analytics'],
      locationNote: 'Exhibition Hall B (Room 706)',
      isReadyToChat: true,
      avatarInitials: 'AI',
    ),
    const ConnectProfile(
      id: 'demo_kabir_rao',
      displayName: 'Kabir Rao',
      headline: 'IoT & Embedded Systems Engineer',
      organization: 'PulseNodes',
      bio: 'BLE beacon networks, firmware optimization, and ultralow-power sensor nodes.',
      interests: ['Robotics & IoT', 'Mobile Engineering'],
      locationNote: 'Foyer & Registration (Room 712)',
      isReadyToChat: true,
      avatarInitials: 'KR',
    ),
  ];
}
