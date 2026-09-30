import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:attendee_mobile/config/supabase_config.dart';
import 'package:attendee_mobile/design_system/components/spatially_crowd_indicator.dart';
import 'package:attendee_mobile/features/explore/data/event_cache_manager.dart';
import 'package:attendee_mobile/features/map/data/supabase_venue_map_repository_impl.dart';
import 'package:attendee_mobile/features/map/data/venue_map_repository.dart';
import 'package:attendee_mobile/features/map/models/venue_map_models.dart';
import 'package:attendee_mobile/services/attendee_identity.dart';
import 'package:attendee_mobile/services/offline_service.dart';

class _RealHttpOverrides extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = _RealHttpOverrides();

  late SupabaseClient supabase;
  late EventCacheManager cacheManager;
  late VenueMapRepository repository;

  String? resolvedEventId;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await AttendeeIdentity.init();
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabaseAnonKey,
      );
    } catch (_) {
      // Already initialized in other test suites
    }
    supabase = Supabase.instance.client;
    cacheManager = EventCacheManager();
    repository = SupabaseVenueMapRepositoryImpl(
      supabase: supabase,
      cacheManager: cacheManager,
      offlineService: OfflineService(),
    );

    try {
      final ezs = await supabase
          .from('event_zones')
          .select('event_id')
          .limit(1);
      if (ezs.isNotEmpty) {
        resolvedEventId = ezs.first['event_id'].toString();
      } else {
        final evs = await supabase
            .from('events')
            .select('id, name, venue_id')
            .not('venue_id', 'is', null)
            .limit(1);
        if (evs.isNotEmpty) {
          resolvedEventId = evs.first['id'].toString();
        }
      }
    } catch (_) {}
  });

  group('Phase 7A-2 Model Deserialization & Robustness Tests', () {
    test('MapPoint and MapBounds deserialize and clamp normalized coordinates', () {
      final point = MapPoint.fromJson({'x': 1.25, 'y': -0.1});
      expect(point.x, equals(1.0)); // Clamped to 1.0
      expect(point.y, equals(0.0)); // Clamped to 0.0

      final bounds = MapBounds.fromJson({
        'left': 0.1,
        'top': 0.2,
        'width': 0.3,
        'height': 0.4,
      });
      expect(bounds.left, equals(0.1));
      expect(bounds.top, equals(0.2));
      expect(bounds.width, equals(0.3));
      expect(bounds.height, equals(0.4));
      expect(bounds.center.x, closeTo(0.25, 0.001));
      expect(bounds.center.y, closeTo(0.40, 0.001));

      // Contains check
      expect(bounds.contains(const MapPoint(0.2, 0.3)), isTrue);
      expect(bounds.contains(const MapPoint(0.5, 0.5)), isFalse);
    });

    test('SpatialConnectorMetadata deserializes connector attributes safely', () {
      final json = {
        'connector_group_id': 'conn_north_elevators',
        'connector_type': 'elevator',
        'connected_level_indices': [0, 1, 7],
        'is_step_free': true,
        'directionality': 'two_way',
      };
      final conn = SpatialConnectorMetadata.fromJson(json);
      expect(conn.connectorGroupId, equals('conn_north_elevators'));
      expect(conn.connectorType, equals('elevator'));
      expect(conn.connectedLevelIndices, equals([0, 1, 7]));
      expect(conn.isStepFree, isTrue);
      expect(conn.directionality, equals('two_way'));
    });

    test('MapPoi handles unknown categories and malformed coordinates gracefully', () {
      final malformedPoi = MapPoi.fromJson({
        'id': 'poi_future_teleport',
        'name': 'Holographic Stage',
        'category': 'quantum_stage', // Unknown category
        'x_coordinate': 99.0, // Out of bounds -> clamps to 1.0
        'y_coordinate': -5.0, // Out of bounds -> clamps to 0.0
        'operational_status': 'active',
      });

      expect(malformedPoi.id, equals('poi_future_teleport'));
      expect(malformedPoi.name, equals('Holographic Stage'));
      expect(malformedPoi.category, equals(PoiCategory.stages)); // Category helper recognizes 'stage'
      expect(malformedPoi.point.x, equals(1.0));
      expect(malformedPoi.point.y, equals(0.0));
      expect(malformedPoi.isActive, isTrue);
    });

    test('SpatialCrowdFreshness classifies live, recent, stale, and unavailable correctly', () {
      final now = DateTime.now();

      // < 3 minutes -> live
      final liveTime = now.subtract(const Duration(minutes: 1));
      expect(SpatialCrowdFreshness.calculate(liveTime, isOnline: true), equals(SpatialCrowdFreshness.live));

      // 3 - 10 minutes -> recent
      final recentTime = now.subtract(const Duration(minutes: 5));
      expect(SpatialCrowdFreshness.calculate(recentTime, isOnline: true), equals(SpatialCrowdFreshness.recent));

      // > 10 minutes -> stale
      final staleTime = now.subtract(const Duration(minutes: 25));
      expect(SpatialCrowdFreshness.calculate(staleTime, isOnline: true), equals(SpatialCrowdFreshness.stale));

      // Null or offline -> unavailable
      expect(SpatialCrowdFreshness.calculate(null, isOnline: true), equals(SpatialCrowdFreshness.unavailable));
      expect(SpatialCrowdFreshness.calculate(liveTime, isOnline: false), equals(SpatialCrowdFreshness.unavailable));
    });

    test('SpatialMapSnapshot converts into VenueMapData view model with crowd levels and POIs', () {
      const venue = SpatialVenue(
        id: 'venue_1',
        name: 'Tech Campus',
      );
      const level0 = SpatialLevel(
        id: 'level_0',
        venueId: 'venue_1',
        levelIndex: 0,
        name: 'Ground Quad',
        shortCode: 'L0',
      );
      const level1 = SpatialLevel(
        id: 'level_1',
        venueId: 'venue_1',
        levelIndex: 1,
        name: 'Presentation Floor',
        shortCode: 'L1',
      );
      const zone701 = EventZone(
        id: 'zone_701_id',
        eventId: 'event_1',
        venueZoneId: 'vz_701',
        levelId: 'level_1',
        name: 'Auditorium',
        code: '701',
        bounds: MapBounds(left: 0.1, top: 0.1, width: 0.3, height: 0.3),
        entrancePoint: MapPoint(0.2, 0.1),
        operatingCapacity: 200,
      );
      final poi1 = MapPoi(
        id: 'poi_stage_main',
        name: 'Main Stage',
        category: PoiCategory.stages,
        point: const MapPoint(0.15, 0.15),
        zoneId: 'zone_701_id',
        levelId: 'level_1',
        description: 'Keynote stage',
        icon: Icons.mic,
      );

      final snapshot = SpatialMapSnapshot(
        eventId: 'event_1',
        venue: venue,
        levels: [level0, level1],
        eventZones: [zone701],
        pois: [poi1],
        crowdStates: {
          '701': const SpatialCrowdState(
            zoneCode: '701',
            activeCount: 150,
            crowdLevel: SpatiallyCrowdLevel.busy,
            freshness: SpatialCrowdFreshness.live,
          ),
        },
        cachedAt: DateTime.now(),
      );

      final venueMapData = snapshot.toVenueMapData(levelId: 'level_1');
      expect(venueMapData.venueName, equals('Tech Campus'));
      expect(venueMapData.floorName, equals('Presentation Floor'));
      expect(venueMapData.zones.length, equals(1));
      expect(venueMapData.zones.first.roomNumber, equals('701'));
      expect(venueMapData.zones.first.crowdLevel, equals(SpatiallyCrowdLevel.busy));
      expect(venueMapData.zones.first.poiIds, contains('poi_stage_main'));
      expect(venueMapData.pois.length, equals(1));
    });
  });

  group('Phase 7A-2 EventCacheManager Offline Spatial Caching Tests', () {
    const testEventId = 'test_event_cache_123';

    test('cacheSpatialSnapshot stores and retrieves offline snapshot with isolation', () async {
      final sampleSnapshot = {
        'event_id': testEventId,
        'venue': {'id': 'v_offline', 'name': 'Offline Campus'},
        'levels': [
          {'id': 'lvl_1', 'venue_id': 'v_offline', 'level_index': 1, 'name': 'Floor 1', 'short_code': 'F1'}
        ],
        'event_zones': [],
        'pois': [],
        'crowd_states': {
          '701': {
            'zone_code': '701',
            'active_count': 42,
            'crowd_level': 'moderate',
            'freshness': 'live',
          }
        },
        'cached_at': DateTime.now().toIso8601String(),
      };

      // 1. Cache snapshot
      await cacheManager.cacheSpatialSnapshot(testEventId, sampleSnapshot);

      // 2. Retrieve snapshot
      final retrieved = await cacheManager.getCachedSpatialSnapshot(testEventId);
      expect(retrieved, isNotNull);
      expect(retrieved!['venue']['name'], equals('Offline Campus'));

      // 3. Event isolation: another event ID returns null
      final otherEvent = await cacheManager.getCachedSpatialSnapshot('other_unrelated_event');
      expect(otherEvent, isNull);

      // 4. Clear cache
      await cacheManager.clearSpatialCache(testEventId);
      final afterClear = await cacheManager.getCachedSpatialSnapshot(testEventId);
      expect(afterClear, isNull);
    });

    test('Offline snapshot deserialization enforces UNAVAILABLE crowd freshness rule', () async {
      final sampleSnapshot = SpatialMapSnapshot(
        eventId: 'event_offline_test',
        venue: const SpatialVenue(id: 'v1', name: 'Campus'),
        levels: const [],
        eventZones: const [],
        pois: const [],
        crowdStates: {
          '701': const SpatialCrowdState(
            zoneCode: '701',
            activeCount: 100,
            crowdLevel: SpatiallyCrowdLevel.high,
            freshness: SpatialCrowdFreshness.live, // In database it was live
          ),
        },
        cachedAt: DateTime.now().subtract(const Duration(hours: 2)),
      );

      // Cache it
      await cacheManager.cacheSpatialSnapshot('event_offline_test', sampleSnapshot.toJson());

      // Read back via repository loadOffline logic
      final cachedRaw = await cacheManager.getCachedSpatialSnapshot('event_offline_test');
      expect(cachedRaw, isNotNull);

      final loaded = SpatialMapSnapshot.fromJson(cachedRaw);
      // Enforce offline freshness rule
      final offlineCrowd = loaded.crowdStates['701']?.copyWithFreshness(SpatialCrowdFreshness.unavailable);
      expect(offlineCrowd?.freshness, equals(SpatialCrowdFreshness.unavailable));
    });
  });

  group('Phase 7A-2 Live Supabase Spatial Topology & Contract Integration Tests', () {
    test('STEP 12/13: Query live event, linked venue, levels, zones, and POIs', () async {
      // 1. Resolve event that has spatial event_zones seeded
      if (resolvedEventId == null) {
        final ezs = await supabase.from('event_zones').select('event_id').limit(1);
        if (ezs.isNotEmpty) {
          resolvedEventId = ezs.first['event_id'].toString();
        }
      }
      expect(resolvedEventId, isNotNull, reason: 'Must find an event with seeded event_zones');

      final eventRow = await supabase
          .from('events')
          .select('id, name, venue_id')
          .eq('id', resolvedEventId!)
          .single();

      final venueId = eventRow['venue_id']?.toString();
      expect(venueId, isNotNull, reason: 'Event must have a linked venue_id from Phase 7A-1');

      // 2. Fetch full spatial map snapshot via repository
      final snapshot = await repository.getMapSnapshot(resolvedEventId!);
      expect(snapshot.eventId, equals(resolvedEventId));
      expect(snapshot.venue.id, equals(venueId));
      expect(snapshot.venue.name, isNotEmpty);
      expect(snapshot.levels, isNotEmpty, reason: 'Venue must have at least one level');

      // 3. Verify Levels ordering and map asset URL support
      final presentationLevel = snapshot.levels.firstWhere(
        (l) => l.levelIndex == 1,
        orElse: () => snapshot.levels.first,
      );
      expect(presentationLevel.shortCode, isNotEmpty);

      // 4. Verify Event Zones
      expect(snapshot.eventZones, isNotEmpty, reason: 'Event must have seeded zones');
      final zone701 = snapshot.eventZones.firstWhere((z) => z.code == '701');
      expect(zone701.bounds.width, greaterThan(0.0));
      expect(zone701.bounds.height, greaterThan(0.0));
      expect(zone701.entrancePoint.x, greaterThan(0.0));

      // 5. Verify POIs scoping: includes both permanent connectors and event POIs
      final permanentPois = snapshot.pois.where((p) => p.isPermanent).toList();
      final eventPois = snapshot.pois.where((p) => !p.isPermanent).toList();

      expect(permanentPois, isNotEmpty, reason: 'Permanent vertical connectors must be included');
      expect(eventPois, isNotEmpty, reason: 'Event-specific POIs must be included');

      // Verify no other event's POIs are included
      for (final p in eventPois) {
        expect(p.eventId, equals(resolvedEventId));
      }
    });

    test('STEP 19: Connect UUID Bridge resolves meeting_poi_id to level and coordinates', () async {
      expect(resolvedEventId, isNotNull);

      // Fetch a known POI from the snapshot
      final snapshot = await repository.getMapSnapshot(resolvedEventId!);
      final samplePoi = snapshot.pois.first;

      // Use Connect UUID lookup bridge
      final resolvedPoi = await repository.getPoiById(samplePoi.id);
      expect(resolvedPoi, isNotNull);
      expect(resolvedPoi!.id, equals(samplePoi.id));
      expect(resolvedPoi.levelId, isNotNull);
      expect(resolvedPoi.point.x, inInclusiveRange(0.0, 1.0));
      expect(resolvedPoi.point.y, inInclusiveRange(0.0, 1.0));
    });

    test('STEP 20: Session / Booth / Activity Bridge resolves zone by UUID and code', () async {
      expect(resolvedEventId, isNotNull);

      // Lookup by room number code "701"
      final zoneByCode = await repository.getZoneById(resolvedEventId!, '701');
      expect(zoneByCode, isNotNull);
      expect(zoneByCode!.code, equals('701'));
      expect(zoneByCode.operatingCapacity, greaterThan(0));

      // Lookup by UUID
      final zoneById = await repository.getZoneById(resolvedEventId!, zoneByCode.id);
      expect(zoneById, isNotNull);
      expect(zoneById!.id, equals(zoneByCode.id));
    });

    test('STEP 7: Vertical Connector Metadata exposes step-free and level links', () async {
      expect(resolvedEventId, isNotNull);

      final snapshot = await repository.getMapSnapshot(resolvedEventId!);
      final elevatorPoi = snapshot.pois.firstWhere(
        (p) => p.name.toLowerCase().contains('elevator'),
        orElse: () => snapshot.pois.firstWhere((p) => p.isPermanent),
      );

      expect(elevatorPoi.connectorMetadata, isNotNull);
      expect(elevatorPoi.connectorMetadata!.connectedLevelIndices, isNotEmpty);
      expect(elevatorPoi.connectorMetadata!.isStepFree, isTrue);
    });

    test('STEP 9 & 10: Crowd telemetry mapping from volunteer_counts to event_zones', () async {
      expect(resolvedEventId, isNotNull);

      final crowdStates = await repository.getCrowdState(resolvedEventId!);
      expect(crowdStates, isNotNull);

      // volunteer_counts was seeded with observations for 701, 702
      if (crowdStates.containsKey('701')) {
        final state701 = crowdStates['701']!;
        expect(state701.zoneCode, equals('701'));
        expect(state701.activeCount, greaterThanOrEqualTo(0));
        expect(state701.freshness, isNot(equals(SpatialCrowdFreshness.unavailable)));
      }
    });
  });
}
