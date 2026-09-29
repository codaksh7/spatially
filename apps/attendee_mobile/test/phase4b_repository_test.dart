import 'package:flutter_test/flutter_test.dart';
import 'package:attendee_mobile/features/event_content/models/spatially_session.dart';
import 'package:attendee_mobile/features/event_content/models/spatially_booth.dart';
import 'package:attendee_mobile/features/event_content/models/spatially_activity.dart';

void main() {
  group('Phase 4B Backend Schema Deserialization Tests', () {
    test('SpatiallySession deserializes database columns correctly', () {
      final dbRow = {
        'id': '10000000-0000-0000-0000-000000000001',
        'event_id': '63ed3709-1b92-4438-9bf3-4a860f3f1846',
        'zone_id': '43d6540f-8993-4b46-89e7-236cf0dd8740',
        'poi_id': null,
        'title': 'Spatial Intelligence Keynote',
        'description': 'Opening talk on physical perception.',
        'speaker_name': 'Dr. Elena Vance',
        'speaker_role': 'Lead AI Researcher',
        'stage_name': 'Room 701 • Auditorium',
        'start_time': '2026-09-27T10:00:00Z',
        'end_time': '2026-09-27T11:00:00Z',
        'tags': ['Keynote', 'Spatial AI'],
        'is_live': true,
      };

      final session = SpatiallySession.fromJson(dbRow);
      expect(session.id, '10000000-0000-0000-0000-000000000001');
      expect(session.speaker, 'Dr. Elena Vance');
      expect(session.roomName, 'Room 701 • Auditorium');
      expect(session.isLive, true);
      expect(session.tags.length, 2);
    });

    test('SpatiallyBooth deserializes database columns correctly', () {
      final dbRow = {
        'id': '20000000-0000-0000-0000-000000000001',
        'event_id': '63ed3709-1b92-4438-9bf3-4a860f3f1846',
        'zone_id': '693ae34b-6a13-4835-8b77-af3a108c6212',
        'poi_id': null,
        'name': 'Spatially Labs Interactive Experience',
        'company_name': 'Spatially Labs',
        'booth_number': 'B-101',
        'description': 'Live BLE demo',
        'category': 'ai',
        'is_active': true,
      };

      final booth = SpatiallyBooth.fromJson(dbRow);
      expect(booth.id, '20000000-0000-0000-0000-000000000001');
      expect(booth.companyOrOrg, 'Spatially Labs');
      expect(booth.category, BoothCategory.ai);
      expect(booth.isOpen, true);
    });

    test('SpatiallyActivity deserializes database columns correctly', () {
      final dbRow = {
        'id': '30000000-0000-0000-0000-000000000001',
        'event_id': '63ed3709-1b92-4438-9bf3-4a860f3f1846',
        'zone_id': '693ae34b-6a13-4835-8b77-af3a108c6212',
        'poi_id': null,
        'title': 'Beacon Scavenger Hunt',
        'description': 'Find checkpoints',
        'activity_type': 'quest',
        'points_reward': 50,
        'is_active': true,
      };

      final activity = SpatiallyActivity.fromJson(dbRow);
      expect(activity.id, '30000000-0000-0000-0000-000000000001');
      expect(activity.type, ActivityType.quest);
      expect(activity.points, 50);
    });
  });
}
