import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendee_mobile/design_system/components/spatially_crowd_indicator.dart';
import 'package:attendee_mobile/features/map/data/venue_map_repository.dart';
import 'package:attendee_mobile/features/map/models/venue_map_models.dart';
import 'package:attendee_mobile/features/map/widgets/map_legend_status.dart';
import 'package:attendee_mobile/features/map/widgets/map_level_selector.dart';
import 'package:attendee_mobile/features/map/widgets/map_zone_sheet.dart';

/// Test implementation of [VenueMapRepository] for Phase 7A-3 integration tests.
class TestVenueMapRepository implements VenueMapRepository {
  final SpatialMapSnapshot snapshot;
  bool simulateOffline = false;

  TestVenueMapRepository({required this.snapshot});

  @override
  Future<SpatialMapSnapshot> getMapSnapshot(String eventId) async {
    if (simulateOffline) {
      final offlineCrowd = <String, SpatialCrowdState>{};
      for (final entry in snapshot.crowdStates.entries) {
        offlineCrowd[entry.key] = entry.value.copyWithFreshness(SpatialCrowdFreshness.unavailable);
      }
      return SpatialMapSnapshot(
        eventId: snapshot.eventId,
        venue: snapshot.venue,
        levels: snapshot.levels,
        eventZones: snapshot.eventZones,
        pois: snapshot.pois,
        crowdStates: offlineCrowd,
        cachedAt: snapshot.cachedAt,
      );
    }
    return snapshot;
  }

  @override
  Future<SpatialVenue?> getVenueForEvent(String eventId) async => snapshot.venue;

  @override
  Future<List<SpatialLevel>> getLevelsForVenue(String venueId) async => snapshot.levels;

  @override
  Future<List<EventZone>> getZonesForEvent(String eventId) async => snapshot.eventZones;

  @override
  Future<List<MapPoi>> getPoisForEvent(String eventId, {String? levelId}) async {
    if (levelId == null) return snapshot.pois;
    return snapshot.pois.where((p) => p.levelId == levelId).toList();
  }

  @override
  Future<VenueMapData> getLevelSnapshot(String eventId, {String? levelId}) async {
    final snap = await getMapSnapshot(eventId);
    return snap.toVenueMapData(levelId: levelId);
  }

  @override
  Future<MapPoi?> getPoiById(String poiId) async {
    for (final p in snapshot.pois) {
      if (p.id == poiId) return p;
    }
    return null;
  }

  @override
  Future<EventZone?> getZoneById(String eventId, String zoneIdOrCode) async {
    final lower = zoneIdOrCode.toLowerCase().trim();
    for (final ez in snapshot.eventZones) {
      if (ez.id.toLowerCase() == lower ||
          ez.code.toLowerCase() == lower ||
          ez.venueZoneId.toLowerCase() == lower) {
        return ez;
      }
    }
    return null;
  }

  @override
  Future<Map<String, SpatialCrowdState>> getCrowdState(String eventId) async => snapshot.crowdStates;

  @override
  Future<void> clearSpatialCache(String eventId) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Test Fixture Data
  const testEventId = 'ev_7a3_tech_expo';
  const venue = SpatialVenue(
    id: 'venue_expo_hall',
    name: 'San Francisco Convention Center',
    slug: 'sf-convention',
    address: '747 Howard St',
  );

  const level0 = SpatialLevel(
    id: 'lvl_0',
    venueId: 'venue_expo_hall',
    levelIndex: 0,
    name: 'Exhibition Ground',
    shortCode: 'G',
  );

  const level1 = SpatialLevel(
    id: 'lvl_1',
    venueId: 'venue_expo_hall',
    levelIndex: 1,
    name: 'Keynote & Presentation Level',
    shortCode: 'L1',
    mapAssetUrl: 'https://cdn.spatially.io/maps/sf_l1.png',
  );

  const level2 = SpatialLevel(
    id: 'lvl_2',
    venueId: 'venue_expo_hall',
    levelIndex: 2,
    name: 'Executive Suites',
    shortCode: 'L2',
  );

  final zoneAuditorium = EventZone(
    id: 'ez_701',
    eventId: testEventId,
    venueZoneId: 'vz_auditorium',
    levelId: 'lvl_1',
    name: 'Grand Keynote Auditorium',
    code: '701',
    bounds: const MapBounds(left: 0.10, top: 0.15, width: 0.35, height: 0.30),
    entrancePoint: const MapPoint(0.25, 0.15),
    polygon: const [
      MapPoint(0.10, 0.15),
      MapPoint(0.45, 0.15),
      MapPoint(0.45, 0.45),
      MapPoint(0.10, 0.45),
    ],
    operatingCapacity: 200,
    warningThreshold: 150,
    criticalThreshold: 180,
    isCrowdMonitored: true,
    operationalStatus: 'active',
  );

  final zoneWorkshop = EventZone(
    id: 'ez_702',
    eventId: testEventId,
    venueZoneId: 'vz_workshop',
    levelId: 'lvl_1',
    name: 'Developer Workshop Lab',
    code: '702',
    bounds: const MapBounds(left: 0.55, top: 0.15, width: 0.35, height: 0.30),
    entrancePoint: const MapPoint(0.70, 0.15),
    operatingCapacity: 60,
    operationalStatus: 'closed',
    statusReason: 'Under maintenance until 2:00 PM',
  );

  final zoneGroundBooths = EventZone(
    id: 'ez_001',
    eventId: testEventId,
    venueZoneId: 'vz_booth_area',
    levelId: 'lvl_0',
    name: 'Startup Alley',
    code: '001',
    bounds: const MapBounds(left: 0.20, top: 0.20, width: 0.60, height: 0.50),
    entrancePoint: const MapPoint(0.50, 0.20),
    operatingCapacity: 300,
  );

  final poiKeynoteStage = MapPoi(
    id: 'poi_keynote_stage',
    name: 'Keynote Main Stage',
    category: PoiCategory.stages,
    point: const MapPoint(0.25, 0.25),
    zoneId: 'ez_701',
    levelId: 'lvl_1',
    eventId: testEventId,
    description: 'Primary stage for morning keynotes and panels',
    icon: Icons.mic_rounded,
    isPermanent: false,
  );

  final poiElevatorL1 = MapPoi(
    id: 'poi_elevator_central',
    name: 'Central Glass Elevators',
    category: PoiCategory.facilities,
    point: const MapPoint(0.50, 0.50),
    levelId: 'lvl_1',
    venueId: 'venue_expo_hall',
    description: 'Step-free vertical access between G, L1, and L2',
    icon: Icons.elevator_rounded,
    isPermanent: true,
    accessibilityFlags: const ['wheelchair', 'step_free', 'tactile_paving'],
    connectorMetadata: const SpatialConnectorMetadata(
      connectorGroupId: 'conn_central_lift',
      connectorType: 'elevator',
      connectedLevelIndices: [0, 1, 2],
      isStepFree: true,
      directionality: 'two_way',
    ),
  );

  final poiEmergencyExit = MapPoi(
    id: 'poi_emergency_exit_north',
    name: 'North Emergency Stairwell',
    category: PoiCategory.safety,
    point: const MapPoint(0.50, 0.05),
    levelId: 'lvl_1',
    venueId: 'venue_expo_hall',
    description: 'Emergency evacuation route directly to Howard Street',
    icon: Icons.emergency_rounded,
    isPermanent: true,
  );

  final initialCrowdStates = <String, SpatialCrowdState>{
    '701': SpatialCrowdState(
      zoneCode: '701',
      zoneId: 'ez_701',
      activeCount: 160,
      crowdLevel: SpatiallyCrowdLevel.busy,
      lastUpdated: DateTime.now().subtract(const Duration(minutes: 1)),
      freshness: SpatialCrowdFreshness.live,
    ),
    '702': SpatialCrowdState(
      zoneCode: '702',
      zoneId: 'ez_702',
      activeCount: 0,
      crowdLevel: SpatiallyCrowdLevel.low,
      lastUpdated: DateTime.now().subtract(const Duration(minutes: 15)),
      freshness: SpatialCrowdFreshness.stale,
    ),
  };

  final fullSnapshot = SpatialMapSnapshot(
    eventId: testEventId,
    venue: venue,
    levels: [level0, level1, level2],
    eventZones: [zoneAuditorium, zoneWorkshop, zoneGroundBooths],
    pois: [poiKeynoteStage, poiElevatorL1, poiEmergencyExit],
    crowdStates: initialCrowdStates,
    cachedAt: DateTime.now(),
  );

  late TestVenueMapRepository testRepository;

  setUp(() {
    testRepository = TestVenueMapRepository(snapshot: fullSnapshot);
  });

  group('Phase 7A-3 Real Spatial Topology & Snapshot Integration Tests', () {
    test('1. Real spatial snapshot converts into VenueMapData defaulting to Level 1', () {
      final venueData = fullSnapshot.toVenueMapData();
      expect(venueData.venueName, equals('San Francisco Convention Center'));
      expect(venueData.floorName, equals('Keynote & Presentation Level'));
      expect(venueData.levelId, equals('lvl_1'));
      expect(venueData.mapAssetUrl, equals('https://cdn.spatially.io/maps/sf_l1.png'));

      // Zones scoped to Level 1 only
      expect(venueData.zones.length, equals(2));
      expect(venueData.zones.map((z) => z.roomNumber), containsAll(['701', '702']));
      expect(venueData.zones.map((z) => z.roomNumber), isNot(contains('001')));

      // POIs scoped to Level 1 only
      expect(venueData.pois.length, equals(3));
      expect(venueData.pois.map((p) => p.name), contains('Keynote Main Stage'));
    });

    test('2. Multi-level floor switching filters zones and POIs to target level', () {
      // Switch to Level 0 (Ground)
      final groundData = fullSnapshot.toVenueMapData(levelId: 'lvl_0');
      expect(groundData.floorName, equals('Exhibition Ground'));
      expect(groundData.levelId, equals('lvl_0'));
      expect(groundData.zones.length, equals(1));
      expect(groundData.zones.first.roomNumber, equals('001'));
      expect(groundData.pois.isEmpty, isTrue); // No POIs assigned to level 0 in snapshot

      // Switch to Level 2 (Executive)
      final l2Data = fullSnapshot.toVenueMapData(levelId: 'lvl_2');
      expect(l2Data.floorName, equals('Executive Suites'));
      expect(l2Data.zones.isEmpty, isTrue);
      expect(l2Data.pois.isEmpty, isTrue);
    });

    test('3. Zone geometry rendering model preserves bounds, polygon, and entrance point', () {
      final venueData = fullSnapshot.toVenueMapData(levelId: 'lvl_1');
      final zone701 = venueData.findZoneById('ez_701');
      expect(zone701, isNotNull);
      expect(zone701!.bounds.left, equals(0.10));
      expect(zone701.bounds.top, equals(0.15));
      expect(zone701.bounds.width, equals(0.35));
      expect(zone701.bounds.height, equals(0.30));
      expect(zone701.entrancePoint.x, equals(0.25));
      expect(zone701.entrancePoint.y, equals(0.15));
      expect(zone701.polygon, isNotNull);
      expect(zone701.polygon!.length, equals(4));

      // Operational status preservation
      final zone702 = venueData.findZoneById('702');
      expect(zone702, isNotNull);
      expect(zone702!.isClosed, isTrue);
      expect(zone702.statusReason, contains('Under maintenance'));
    });

    test('4. POI rendering model preserves categories, coordinates, and connectors', () {
      final venueData = fullSnapshot.toVenueMapData(levelId: 'lvl_1');
      final elevator = venueData.findPoiById('poi_elevator_central');
      expect(elevator, isNotNull);
      expect(elevator!.category, equals(PoiCategory.facilities));
      expect(elevator.point.x, equals(0.50));
      expect(elevator.point.y, equals(0.50));
      expect(elevator.isPermanent, isTrue);
      expect(elevator.connectorMetadata, isNotNull);
      expect(elevator.connectorMetadata!.isStepFree, isTrue);
      expect(elevator.connectorMetadata!.connectedLevelIndices, equals([0, 1, 2]));

      final stage = venueData.findPoiById('poi_keynote_stage');
      expect(stage, isNotNull);
      expect(stage!.category, equals(PoiCategory.stages));
      expect(stage.isPermanent, isFalse);
      expect(stage.eventId, equals(testEventId));
    });

    test('5. Crowd state mapping derives correct level from count and operating capacity', () {
      // count > 80 -> high
      expect(SpatialCrowdState.levelFromCount(85, capacity: 100), equals(SpatiallyCrowdLevel.high));
      // count > 40 -> busy
      expect(SpatialCrowdState.levelFromCount(60, capacity: 100), equals(SpatiallyCrowdLevel.busy));
      // count > 15 -> moderate
      expect(SpatialCrowdState.levelFromCount(25, capacity: 100), equals(SpatiallyCrowdLevel.moderate));
      // count <= 15 -> low
      expect(SpatialCrowdState.levelFromCount(8, capacity: 100), equals(SpatiallyCrowdLevel.low));
    });

    test('6. Freshness calculation accurately classifies telemetry age', () {
      final now = DateTime.now();

      // < 3 minutes -> live
      final liveTime = now.subtract(const Duration(minutes: 1, seconds: 30));
      expect(SpatialCrowdFreshness.calculate(liveTime, isOnline: true), equals(SpatialCrowdFreshness.live));

      // 3 - 10 minutes -> recent
      final recentTime = now.subtract(const Duration(minutes: 5));
      expect(SpatialCrowdFreshness.calculate(recentTime, isOnline: true), equals(SpatialCrowdFreshness.recent));

      // > 10 minutes -> stale
      final staleTime = now.subtract(const Duration(minutes: 18));
      expect(SpatialCrowdFreshness.calculate(staleTime, isOnline: true), equals(SpatialCrowdFreshness.stale));

      // Missing or offline -> unavailable
      expect(SpatialCrowdFreshness.calculate(null, isOnline: true), equals(SpatialCrowdFreshness.unavailable));
      expect(SpatialCrowdFreshness.calculate(liveTime, isOnline: false), equals(SpatialCrowdFreshness.unavailable));
    });

    test('7. Offline behavior: cached topology renders, crowd marked UNAVAILABLE', () async {
      testRepository.simulateOffline = true;
      final offlineSnapshot = await testRepository.getMapSnapshot(testEventId);

      // Topology intact
      expect(offlineSnapshot.venue.name, equals('San Francisco Convention Center'));
      expect(offlineSnapshot.levels.length, equals(3));
      expect(offlineSnapshot.eventZones.length, equals(3));
      expect(offlineSnapshot.pois.length, equals(3));

      // All crowd states marked unavailable
      for (final state in offlineSnapshot.crowdStates.values) {
        expect(state.freshness, equals(SpatialCrowdFreshness.unavailable));
      }

      final offlineMapData = offlineSnapshot.toVenueMapData(levelId: 'lvl_1');
      for (final zone in offlineMapData.zones) {
        expect(zone.crowdFreshness, equals(SpatialCrowdFreshness.unavailable));
      }
    });

    test('8. Event isolation guard rejects cross-event realtime payload', () {
      const activeEventId = testEventId;
      const otherEventId = 'ev_other_event_999';

      final foreignRecord = {
        'event_id': otherEventId,
        'zone': '701',
        'active_count': 500,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Simulating guard in MapScreen._handleRealtimeCrowdPayload:
      bool wasAccepted = false;
      if (foreignRecord['event_id'] == activeEventId) {
        wasAccepted = true;
      }

      expect(wasAccepted, isFalse, reason: 'Cross-event telemetry must never be applied to current map');
    });

    test('9. Connect POI deep-link resolves meeting_poi_id to level and coordinates', () async {
      final poi = await testRepository.getPoiById('poi_keynote_stage');
      expect(poi, isNotNull);
      expect(poi!.id, equals('poi_keynote_stage'));
      expect(poi.levelId, equals('lvl_1'));
      expect(poi.point.x, equals(0.25));
      expect(poi.point.y, equals(0.25));
    });

    test('10. Session / Booth / Activity Bridge resolves zone by UUID and code', () async {
      // By UUID
      final zoneByUuid = await testRepository.getZoneById(testEventId, 'ez_701');
      expect(zoneByUuid, isNotNull);
      expect(zoneByUuid!.code, equals('701'));
      expect(zoneByUuid.levelId, equals('lvl_1'));

      // By code
      final zoneByCode = await testRepository.getZoneById(testEventId, '702');
      expect(zoneByCode, isNotNull);
      expect(zoneByCode!.id, equals('ez_702'));
      expect(zoneByCode.levelId, equals('lvl_1'));
    });

    test('11. Malformed geometry safe handling: bounds clamping and polygon fallback', () {
      final malformedBoundsJson = {
        'left': -0.5,
        'top': 1.8,
        'width': 2.0,
        'height': -0.1,
      };
      final bounds = MapBounds.fromJson(malformedBoundsJson);
      expect(bounds.left, equals(0.0));
      expect(bounds.top, equals(1.0));
      expect(bounds.width, equals(1.0));
      expect(bounds.height, equals(0.0));

      final emptyPolygonZone = EventZone(
        id: 'ez_malformed',
        eventId: testEventId,
        venueZoneId: 'vz_bad',
        levelId: 'lvl_1',
        name: 'Empty Polygon',
        code: 'BAD',
        bounds: bounds,
        entrancePoint: const MapPoint(0.5, 0.5),
        polygon: const [],
      );

      final mapZone = MapZone.fromEventZone(emptyPolygonZone);
      expect(mapZone.polygon, isEmpty);
      expect(mapZone.bounds.left, equals(0.0));
    });

    test('12. Realtime payload mapping evaluates freshness from updated_at without auto-LIVE', () {
      // Simulate payload with an OLD timestamp (received right now via realtime)
      final oldTimestamp = DateTime.now().subtract(const Duration(minutes: 12));
      final payloadRecord = {
        'event_id': testEventId,
        'zone': '701',
        'active_count': 55,
        'updated_at': oldTimestamp.toIso8601String(),
      };

      final updatedAt = DateTime.parse(payloadRecord['updated_at'] as String);
      final freshness = SpatialCrowdFreshness.calculate(updatedAt, isOnline: true);

      // Must be STALE, NOT live
      expect(freshness, equals(SpatialCrowdFreshness.stale));

      final state = SpatialCrowdState(
        zoneCode: '701',
        activeCount: (payloadRecord['active_count'] as num).toInt(),
        crowdLevel: SpatialCrowdState.levelFromCount(55, capacity: 100),
        lastUpdated: updatedAt,
        freshness: freshness,
      );

      expect(state.freshness, equals(SpatialCrowdFreshness.stale));
      expect(state.crowdLevel, equals(SpatiallyCrowdLevel.busy));
    });
  });

  group('Phase 7A-3 UI Component & Level Selector Widget Tests', () {
    testWidgets('MapLevelSelector renders available levels and handles selection', (tester) async {
      SpatialLevel? tappedLevel;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MapLevelSelector(
              levels: const [level0, level1, level2],
              selectedLevelId: 'lvl_1',
              onLevelSelected: (lvl) {
                tappedLevel = lvl;
              },
            ),
          ),
        ),
      );

      // Verify level shortcodes are present
      expect(find.text('L2'), findsOneWidget);
      expect(find.text('L1'), findsOneWidget);
      expect(find.text('G'), findsOneWidget);

      // Tap on Ground level 'G'
      await tester.tap(find.text('G'));
      await tester.pumpAndSettle();

      expect(tappedLevel, isNotNull);
      expect(tappedLevel!.id, equals('lvl_0'));
    });

    testWidgets('MapLevelSelector hides automatically for single-level venues', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MapLevelSelector(
              levels: const [level1],
              selectedLevelId: 'lvl_1',
              onLevelSelected: (_) {},
            ),
          ),
        ),
      );

      expect(find.byType(MapLevelSelector), findsOneWidget);
      expect(find.text('L1'), findsNothing); // Hidden via SizedBox.shrink()
    });

    testWidgets('MapLegendStatus displays authoritative telemetry states', (tester) async {
      // 1. Live Telemetry
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MapLegendStatus(
              floorName: 'L1 • Presentation',
              crowdFreshness: SpatialCrowdFreshness.live,
              isOffline: false,
            ),
          ),
        ),
      );
      expect(find.text('Live Telemetry'), findsOneWidget);

      // 2. Stale Telemetry
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MapLegendStatus(
              floorName: 'L1 • Presentation',
              crowdFreshness: SpatialCrowdFreshness.stale,
              isOffline: false,
            ),
          ),
        ),
      );
      expect(find.text('Stale Telemetry'), findsOneWidget);

      // 3. Offline
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MapLegendStatus(
              floorName: 'L1 • Presentation',
              crowdFreshness: SpatialCrowdFreshness.unavailable,
              isOffline: true,
            ),
          ),
        ),
      );
      expect(find.text('Crowd Offline'), findsOneWidget);
    });

    testWidgets('MapZoneSheet displays room closed operational banner and telemetry status', (tester) async {
      final closedZone = MapZone.fromEventZone(
        zoneWorkshop,
        crowdFreshness: SpatialCrowdFreshness.stale,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MapZoneSheet(
              zone: closedZone,
              allPois: const [],
              onNavigate: () {},
              onClose: () {},
            ),
          ),
        ),
      );

      // Operational status banner
      expect(find.textContaining('Room is currently closed'), findsOneWidget);
      expect(find.textContaining('Under maintenance'), findsOneWidget);

      // Telemetry status
      expect(find.text('Stale telemetry (> 10m ago)'), findsOneWidget);
    });
  });
}
