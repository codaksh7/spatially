import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/offline_service.dart';
import '../../explore/data/event_cache_manager.dart';
import '../models/venue_map_models.dart';
import 'venue_map_repository.dart';

/// Production Supabase-backed implementation of [VenueMapRepository].
///
/// Handles:
/// - Real PostgREST queries for venues, levels, zones, POIs, and crowd telemetry.
/// - Offline caching via [EventCacheManager] with automatic offline fallback.
/// - Event/venue scoping (event POIs + venue permanent POIs).
/// - Crowd telemetry freshness tracking (LIVE, RECENT, STALE, UNAVAILABLE).
/// - Legacy `volunteer_counts.zone` compatibility bridge to `event_zones.code`.
/// - Connect meeting_poi_id UUID resolution for deep-linking and meeting points.
/// - Session/booth/activity zone and POI resolution.
class SupabaseVenueMapRepositoryImpl implements VenueMapRepository {
  final SupabaseClient _supabase;
  final EventCacheManager _cacheManager;
  final OfflineService _offlineService;

  // In-memory cache for fast lookups during an active session
  final Map<String, SpatialMapSnapshot> _snapshotsMemory = {};
  final Map<String, MapPoi> _poiIndex = {};

  SupabaseVenueMapRepositoryImpl({
    SupabaseClient? supabase,
    EventCacheManager? cacheManager,
    OfflineService? offlineService,
  })  : _supabase = supabase ?? Supabase.instance.client,
        _cacheManager = cacheManager ?? EventCacheManager(),
        _offlineService = offlineService ?? OfflineService();

  @override
  Future<SpatialMapSnapshot> getMapSnapshot(String eventId) async {
    // 1. Try loading from memory cache if recently synced
    if (_snapshotsMemory.containsKey(eventId)) {
      final cachedSnapshot = _snapshotsMemory[eventId]!;
      // If we are online and cached snapshot is less than 60 seconds old, return memory cache
      if (_offlineService.isOnline &&
          DateTime.now().difference(cachedSnapshot.cachedAt).inSeconds < 60) {
        return cachedSnapshot;
      }
    }

    // 2. If online, attempt to fetch fresh spatial topology from Supabase
    if (_offlineService.isOnline) {
      try {
        final snapshot = await _fetchFromSupabase(eventId);
        _snapshotsMemory[eventId] = snapshot;
        _indexPois(snapshot.pois);

        // Persist to offline cache
        await _cacheManager.cacheSpatialSnapshot(eventId, snapshot.toJson());
        return snapshot;
      } catch (e, stack) {
        debugPrint('SupabaseVenueMapRepository: Failed to fetch live spatial topology: $e\n$stack');
        // Fallback to local cache on error
      }
    }

    // 3. Offline fallback from EventCacheManager
    return await _loadOfflineSnapshot(eventId);
  }

  /// Internal query orchestration against production Supabase tables.
  Future<SpatialMapSnapshot> _fetchFromSupabase(String eventId) async {
    // Step A: Resolve Event & its Venue ID
    final eventRow = await _supabase
        .from('events')
        .select('id, venue_id')
        .eq('id', eventId)
        .maybeSingle()
        .timeout(const Duration(seconds: 6));

    if (eventRow == null) {
      throw Exception('Event not found: $eventId');
    }

    final venueId = eventRow['venue_id']?.toString();
    if (venueId == null || venueId.isEmpty) {
      throw Exception('Event $eventId does not have a linked venue_id');
    }

    // Step B: Fetch Venue Details
    final venueRow = await _supabase
        .from('venues')
        .select()
        .eq('id', venueId)
        .maybeSingle()
        .timeout(const Duration(seconds: 6));

    if (venueRow == null) {
      throw Exception('Venue not found: $venueId');
    }
    final venue = SpatialVenue.fromJson(venueRow);

    // Step C: Fetch Venue Levels (ordered by display_order, level_index)
    final levelsResponse = await _supabase
        .from('venue_levels')
        .select()
        .eq('venue_id', venueId)
        .order('display_order', ascending: true)
        .order('level_index', ascending: true)
        .timeout(const Duration(seconds: 6));

    final levels = (levelsResponse as List)
        .map((row) => SpatialLevel.fromJson(row))
        .toList();

    // Step D: Fetch Event Zones joined with physical venue_zones for fallback geometry
    final eventZonesResponse = await _supabase
        .from('event_zones')
        .select('*, venue_zones(*)')
        .eq('event_id', eventId)
        .eq('is_published', true)
        .timeout(const Duration(seconds: 6));

    final eventZones = <EventZone>[];
    for (final raw in (eventZonesResponse as List)) {
      final row = Map<String, dynamic>.from(raw as Map);
      // Fallback geometry from venue_zones if event_zones bounds is missing
      if (row['bounds'] == null && row['venue_zones'] is Map) {
        final vz = row['venue_zones'] as Map;
        row['bounds'] = vz['bounds'];
        row['entrance_point'] ??= vz['entrance_point'];
        row['polygon'] ??= vz['polygon'];
      }
      eventZones.add(EventZone.fromJson(row));
    }

    // Step E: Fetch POIs (Event-specific POIs + Permanent Venue POIs)
    final eventPoisFuture = _supabase
        .from('venue_pois')
        .select()
        .eq('event_id', eventId)
        .eq('is_published', true)
        .timeout(const Duration(seconds: 6));

    final permanentPoisFuture = _supabase
        .from('venue_pois')
        .select()
        .eq('venue_id', venueId)
        .eq('is_permanent', true)
        .eq('is_published', true)
        .timeout(const Duration(seconds: 6));

    final poiResults = await Future.wait([eventPoisFuture, permanentPoisFuture]);
    final mergedPois = <String, MapPoi>{};

    for (final list in poiResults) {
      for (final raw in (list as List)) {
        final poi = MapPoi.fromJson(raw);
        if (poi.id.isNotEmpty) {
          mergedPois[poi.id] = poi;
        }
      }
    }
    final allPois = mergedPois.values.toList();

    // Step F: Fetch Live Crowd Telemetry from volunteer_counts
    final crowdTelemetry = await _fetchCrowdTelemetry(eventId, eventZones);

    return SpatialMapSnapshot(
      eventId: eventId,
      venue: venue,
      levels: levels,
      eventZones: eventZones,
      pois: allPois,
      crowdStates: crowdTelemetry,
      cachedAt: DateTime.now(),
    );
  }

  /// Queries `volunteer_counts` and maps legacy `zone` string to `event_zones.code`.
  Future<Map<String, SpatialCrowdState>> _fetchCrowdTelemetry(
    String eventId,
    List<EventZone> eventZones,
  ) async {
    final crowdMap = <String, SpatialCrowdState>{};

    try {
      final countsResponse = await _supabase
          .from('volunteer_counts')
          .select('zone, active_count, updated_at')
          .eq('event_id', eventId)
          .timeout(const Duration(seconds: 5));

      // Build code lookup for event zones
      final zoneByCode = <String, EventZone>{};
      for (final ez in eventZones) {
        zoneByCode[ez.code.toLowerCase().trim()] = ez;
      }

      for (final raw in countsResponse) {
        final zoneRaw = raw['zone']?.toString() ?? '';
        final cleanCode = zoneRaw.replaceAll(RegExp(r'[^0-9a-zA-Z]'), '').toLowerCase();
        final count = (raw['active_count'] as num?)?.toInt() ?? 0;
        final updatedAt = raw['updated_at'] != null
            ? DateTime.tryParse(raw['updated_at'].toString())
            : null;

        final matchedZone = zoneByCode[cleanCode] ??
            eventZones.cast<EventZone?>().firstWhere(
                  (z) => z != null && zoneRaw.contains(z.code),
                  orElse: () => null,
                );

        final freshness = SpatialCrowdFreshness.calculate(updatedAt, isOnline: true);
        final capacity = matchedZone?.operatingCapacity ?? 100;
        final crowdLevel = SpatialCrowdState.levelFromCount(count, capacity: capacity);

        final crowdState = SpatialCrowdState(
          zoneCode: matchedZone?.code ?? zoneRaw,
          zoneId: matchedZone?.id,
          activeCount: count,
          crowdLevel: crowdLevel,
          lastUpdated: updatedAt,
          freshness: freshness,
        );

        final key = matchedZone?.code ?? zoneRaw;
        // Keep the latest observation if multiple rows exist
        if (!crowdMap.containsKey(key) ||
            (updatedAt != null &&
                crowdMap[key]!.lastUpdated != null &&
                updatedAt.isAfter(crowdMap[key]!.lastUpdated!))) {
          crowdMap[key] = crowdState;
        }
      }
    } catch (e) {
      debugPrint('SupabaseVenueMapRepository: volunteer_counts query error: $e');
    }

    return crowdMap;
  }

  /// Loads cached spatial topology from [EventCacheManager] and enforces offline crowd freshness rules.
  Future<SpatialMapSnapshot> _loadOfflineSnapshot(String eventId) async {
    final cachedData = await _cacheManager.getCachedSpatialSnapshot(eventId);
    if (cachedData != null) {
      final snapshot = SpatialMapSnapshot.fromJson(cachedData);

      // STEP 10 & 17: In offline mode, NEVER render crowd data as LIVE.
      final offlineCrowdStates = <String, SpatialCrowdState>{};
      for (final entry in snapshot.crowdStates.entries) {
        offlineCrowdStates[entry.key] = entry.value.copyWithFreshness(
          SpatialCrowdFreshness.unavailable,
        );
      }

      final offlineSnapshot = SpatialMapSnapshot(
        eventId: snapshot.eventId,
        venue: snapshot.venue,
        levels: snapshot.levels,
        eventZones: snapshot.eventZones,
        pois: snapshot.pois,
        crowdStates: offlineCrowdStates,
        cachedAt: snapshot.cachedAt,
      );

      _snapshotsMemory[eventId] = offlineSnapshot;
      _indexPois(offlineSnapshot.pois);
      return offlineSnapshot;
    }

    // Honest empty state when no cache is available
    return SpatialMapSnapshot(
      eventId: eventId,
      venue: const SpatialVenue(
        id: '',
        name: 'Offline Map Unavailable',
      ),
      levels: const [],
      eventZones: const [],
      pois: const [],
      crowdStates: const {},
      cachedAt: DateTime.now(),
    );
  }

  void _indexPois(List<MapPoi> pois) {
    for (final p in pois) {
      if (p.id.isNotEmpty) {
        _poiIndex[p.id] = p;
      }
    }
  }

  @override
  Future<SpatialVenue?> getVenueForEvent(String eventId) async {
    final snapshot = await getMapSnapshot(eventId);
    return snapshot.venue.id.isNotEmpty ? snapshot.venue : null;
  }

  @override
  Future<List<SpatialLevel>> getLevelsForVenue(String venueId) async {
    // Check if venue is in current memory snapshots
    for (final snap in _snapshotsMemory.values) {
      if (snap.venue.id == venueId && snap.levels.isNotEmpty) {
        return snap.levels;
      }
    }

    // Direct query if not in snapshot
    if (_offlineService.isOnline) {
      try {
        final rows = await _supabase
            .from('venue_levels')
            .select()
            .eq('venue_id', venueId)
            .order('display_order', ascending: true)
            .order('level_index', ascending: true)
            .timeout(const Duration(seconds: 5));

        return (rows as List).map((r) => SpatialLevel.fromJson(r)).toList();
      } catch (_) {}
    }

    return [];
  }

  @override
  Future<List<EventZone>> getZonesForEvent(String eventId) async {
    final snapshot = await getMapSnapshot(eventId);
    return snapshot.eventZones;
  }

  @override
  Future<List<MapPoi>> getPoisForEvent(String eventId, {String? levelId}) async {
    final snapshot = await getMapSnapshot(eventId);
    if (levelId == null) return snapshot.pois;
    return snapshot.pois.where((p) => p.levelId == levelId).toList();
  }

  @override
  Future<VenueMapData> getLevelSnapshot(String eventId, {String? levelId}) async {
    final snapshot = await getMapSnapshot(eventId);
    return snapshot.toVenueMapData(levelId: levelId);
  }

  @override
  Future<MapPoi?> getPoiById(String poiId) async {
    // 1. Check memory index
    if (_poiIndex.containsKey(poiId)) {
      return _poiIndex[poiId];
    }

    // 2. Check existing memory snapshots
    for (final snap in _snapshotsMemory.values) {
      for (final p in snap.pois) {
        if (p.id == poiId) {
          _poiIndex[poiId] = p;
          return p;
        }
      }
    }

    // 3. Fallback to Supabase direct query (works for both permanent and event POIs)
    if (_offlineService.isOnline) {
      try {
        final row = await _supabase
            .from('venue_pois')
            .select()
            .eq('id', poiId)
            .maybeSingle()
            .timeout(const Duration(seconds: 5));

        if (row != null) {
          final poi = MapPoi.fromJson(row);
          _poiIndex[poi.id] = poi;
          return poi;
        }
      } catch (e) {
        debugPrint('SupabaseVenueMapRepository: getPoiById error: $e');
      }
    }

    return null;
  }

  @override
  Future<EventZone?> getZoneById(String eventId, String zoneIdOrCode) async {
    final snapshot = await getMapSnapshot(eventId);
    final target = zoneIdOrCode.toLowerCase().trim();

    for (final ez in snapshot.eventZones) {
      if (ez.id.toLowerCase() == target ||
          ez.code.toLowerCase() == target ||
          ez.venueZoneId.toLowerCase() == target) {
        return ez;
      }
    }
    return null;
  }

  @override
  Future<Map<String, SpatialCrowdState>> getCrowdState(String eventId) async {
    final snapshot = await getMapSnapshot(eventId);
    return snapshot.crowdStates;
  }

  @override
  Future<void> clearSpatialCache(String eventId) async {
    _snapshotsMemory.remove(eventId);
    await _cacheManager.clearSpatialCache(eventId);
  }
}
