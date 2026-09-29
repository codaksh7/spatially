import '../models/venue_map_models.dart';

/// Clean repository contract for spatial venue map topology, multi-level structures,
/// POIs, and crowd observations.
///
/// Decouples the UI and MapCanvas from raw Supabase queries and offline persistence.
abstract class VenueMapRepository {
  /// Fetches the complete multi-level spatial snapshot for [eventId],
  /// combining venue, levels, event zones, POIs, and crowd states.
  /// When online, refreshes the local cache; when offline, returns cached data.
  Future<SpatialMapSnapshot> getMapSnapshot(String eventId);

  /// Resolves the venue details for [eventId].
  Future<SpatialVenue?> getVenueForEvent(String eventId);

  /// Retrieves all levels/floors for [venueId], ordered by display_order / level_index.
  Future<List<SpatialLevel>> getLevelsForVenue(String venueId);

  /// Retrieves all event zones for [eventId].
  Future<List<EventZone>> getZonesForEvent(String eventId);

  /// Retrieves all visible POIs for [eventId]
  /// (both permanent venue POIs and event-specific POIs, optionally filtered by [levelId]).
  Future<List<MapPoi>> getPoisForEvent(String eventId, {String? levelId});

  /// Retrieves a specific level snapshot formatted as [VenueMapData] ready for UI rendering.
  Future<VenueMapData> getLevelSnapshot(String eventId, {String? levelId});

  /// Resolves a single POI by UUID (Connect UUID bridge & deep-linking).
  /// Works for both permanent venue POIs and event-specific POIs.
  Future<MapPoi?> getPoiById(String poiId);

  /// Resolves a single zone by UUID or zone code (e.g. "701").
  Future<EventZone?> getZoneById(String eventId, String zoneIdOrCode);

  /// Retrieves crowd telemetry for [eventId], mapped to event zone codes,
  /// with explicit freshness indication.
  Future<Map<String, SpatialCrowdState>> getCrowdState(String eventId);

  /// Clears the cached spatial snapshot for [eventId].
  Future<void> clearSpatialCache(String eventId);
}
