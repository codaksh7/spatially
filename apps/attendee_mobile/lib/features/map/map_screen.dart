import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../design_system/spatially_colors.dart';
import '../../design_system/spatially_typography.dart';
import '../../design_system/spatially_spacing.dart';
import '../../design_system/components/spatially_app_bar.dart';
import '../../design_system/components/spatially_button.dart';
import '../../services/attendee_identity.dart';
import '../../services/offline_service.dart';
import '../explore/data/event_cache_manager.dart';
import '../explore/models/spatially_event.dart';
import '../profile/data/profile_repository.dart';
import 'data/supabase_venue_map_repository_impl.dart';
import 'data/venue_map_repository.dart';
import 'models/venue_map_models.dart';
import 'models/venue_mock_data.dart';
import 'widgets/map_canvas.dart';
import 'widgets/map_category_filters.dart';
import 'widgets/map_legend_status.dart';
import 'widgets/map_level_selector.dart';
import 'widgets/map_route_sheet.dart';
import 'widgets/map_search_bar.dart';
import 'widgets/map_zone_sheet.dart';

/// Spatially Attendee Map Destination Screen.
/// 
/// Production asynchronous, repository-backed spatial intelligence surface providing
/// multi-level venue visualization, real POI discovery, live Supabase Realtime
/// crowd telemetry, search, and deep-link resolution for Connect meeting points
/// and session/booth locations.
class MapScreen extends StatefulWidget {
  final SpatiallyEvent? initialEvent;
  final String? initialZoneId;
  final String? initialPoiId;
  final VenueMapRepository? repository;
  final bool? isRootTab;

  const MapScreen({
    super.key,
    this.initialEvent,
    this.initialZoneId,
    this.initialPoiId,
    this.repository,
    this.isRootTab,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final TransformationController _transformationController = TransformationController();

  late VenueMapRepository _repository;
  SpatiallyEvent? _currentEvent;
  SpatialMapSnapshot? _snapshot;
  SpatialLevel? _selectedLevel;
  VenueMapData? _venueData;
  MapFilterType _activeFilter = MapFilterType.all;
  MapZone? _selectedZone;
  MapPoi? _selectedPoi;
  MapRoute? _activeRoute;
  bool _isAccessibleRoute = false;
  bool _isLoading = true;
  String? _errorMessage;

  // Supabase Realtime crowd telemetry state
  RealtimeChannel? _crowdChannel;
  String? _subscribedEventId;
  Map<String, SpatialCrowdState> _liveCrowdStates = {};

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? SupabaseVenueMapRepositoryImpl();
    _loadAccessibilityPreference();
    _resolveAndLoadMap();
  }

  @override
  void dispose() {
    _unsubscribeRealtimeCrowd();
    _transformationController.dispose();
    super.dispose();
  }

  Future<void> _loadAccessibilityPreference() async {
    try {
      final prefs = await ProfileRepositoryImpl().getPreferences();
      if (mounted && prefs.preferStepFreeRoutes) {
        setState(() {
          _isAccessibleRoute = true;
        });
      }
    } catch (_) {}
  }

  /// Resolves the active event context and initiates spatial snapshot loading.
  Future<void> _resolveAndLoadMap() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    if (widget.initialEvent != null) {
      _currentEvent = widget.initialEvent;
      await _loadMapSnapshot(_currentEvent!.id);
      return;
    }

    try {
      final isOnline = await OfflineService().checkConnectivity();
      if (!isOnline) {
        final cached = await EventCacheManager().getCachedPrimaryEvent();
        if (cached != null) {
          _currentEvent = SpatiallyEvent.fromJson(cached);
          await _loadMapSnapshot(_currentEvent!.id);
          return;
        }
      }

      final attendeeId = AttendeeIdentity.deviceId;
      SpatiallyEvent? resolvedEvent;

      // 1. Check if attendee has a ticket for a live/upcoming event
      if (attendeeId != null) {
        try {
          final ticketData = await Supabase.instance.client
              .from('tickets')
              .select('*, events(*)')
              .eq('attendee_id', attendeeId)
              .order('purchased_at', ascending: false)
              .timeout(const Duration(seconds: 4));

          if (ticketData.isNotEmpty) {
            for (final row in ticketData) {
              final evMap = row['events'];
              if (evMap is Map<String, dynamic>) {
                final ev = SpatiallyEvent.fromJson(evMap);
                if (ev.isLive) {
                  resolvedEvent = ev;
                  break;
                } else if (resolvedEvent == null && ev.isUpcoming) {
                  resolvedEvent = ev;
                }
              }
            }
          }
        } catch (_) {}
      }

      // 2. Fallback to any live event from database
      if (resolvedEvent == null) {
        try {
          final liveEvents = await Supabase.instance.client
              .from('events')
              .select()
              .eq('status', 'live')
              .limit(1)
              .timeout(const Duration(seconds: 4));

          if (liveEvents.isNotEmpty) {
            resolvedEvent = SpatiallyEvent.fromJson(Map<String, dynamic>.from(liveEvents.first));
          }
        } catch (_) {}
      }

      // 3. Fallback to upcoming events
      if (resolvedEvent == null) {
        try {
          final upcomingEvents = await Supabase.instance.client
              .from('events')
              .select()
              .eq('status', 'upcoming')
              .order('event_date', ascending: true)
              .limit(1)
              .timeout(const Duration(seconds: 4));

          if (upcomingEvents.isNotEmpty) {
            resolvedEvent = SpatiallyEvent.fromJson(Map<String, dynamic>.from(upcomingEvents.first));
          }
        } catch (_) {}
      }

      // 4. Fallback to cached primary event
      if (resolvedEvent == null) {
        final cached = await EventCacheManager().getCachedPrimaryEvent();
        if (cached != null) {
          resolvedEvent = SpatiallyEvent.fromJson(cached);
        }
      }

      _currentEvent = resolvedEvent;

      if (_currentEvent != null) {
        await _loadMapSnapshot(_currentEvent!.id);
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'No active or upcoming event found.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Unable to resolve event context: $e';
        });
      }
    }
  }

  /// Loads the real spatial snapshot from [VenueMapRepository].
  Future<void> _loadMapSnapshot(String eventId) async {
    try {
      final snapshot = await _repository.getMapSnapshot(eventId);

      if (snapshot.venue.id.isEmpty && snapshot.levels.isEmpty && snapshot.eventZones.isEmpty) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = OfflineService().isOnline
                ? 'Venue map layout is not yet published for this event.'
                : 'Map data is unavailable offline. Reconnect to download.';
          });
        }
        return;
      }

      _snapshot = snapshot;
      _liveCrowdStates = Map<String, SpatialCrowdState>.from(snapshot.crowdStates);

      // Determine initial level
      SpatialLevel? initialLvl;

      // Check if deep link POI or Zone defines a level
      if (widget.initialPoiId != null) {
        final poi = snapshot.pois.cast<MapPoi?>().firstWhere(
              (p) => p?.id == widget.initialPoiId,
              orElse: () => null,
            );
        if (poi != null && poi.levelId != null) {
          initialLvl = snapshot.levels.cast<SpatialLevel?>().firstWhere(
                (l) => l?.id == poi.levelId,
                orElse: () => null,
              );
        }
      }

      if (initialLvl == null && widget.initialZoneId != null) {
        final ez = snapshot.eventZones.cast<EventZone?>().firstWhere(
              (z) => z?.id == widget.initialZoneId || z?.code == widget.initialZoneId,
              orElse: () => null,
            );
        if (ez != null && ez.levelId.isNotEmpty) {
          initialLvl = snapshot.levels.cast<SpatialLevel?>().firstWhere(
                (l) => l?.id == ez.levelId,
                orElse: () => null,
              );
        }
      }

      // Fallback: Level index 1 (presentation) or first level
      initialLvl ??= snapshot.levels.cast<SpatialLevel?>().firstWhere(
            (lvl) => lvl?.levelIndex == 1,
            orElse: () => snapshot.levels.isNotEmpty ? snapshot.levels.first : null,
          );

      _selectedLevel = initialLvl;
      _venueData = _buildVenueMapData();

      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = null;
        });
      }

      // Subscribe to live crowd telemetry for this event
      _subscribeToRealtimeCrowd(eventId);

      // Resolve initial selection (POI or Zone)
      _checkInitialSelection();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load spatial map: $e';
        });
      }
    }
  }

  /// Assembles the current floor's [VenueMapData] using [_snapshot] and [_liveCrowdStates].
  VenueMapData _buildVenueMapData() {
    if (_snapshot == null) {
      return const VenueMapData(
        venueName: '',
        floorName: '',
        zones: [],
        pois: [],
      );
    }

    final currentSnapshot = SpatialMapSnapshot(
      eventId: _snapshot!.eventId,
      venue: _snapshot!.venue,
      levels: _snapshot!.levels,
      eventZones: _snapshot!.eventZones,
      pois: _snapshot!.pois,
      crowdStates: _liveCrowdStates,
      cachedAt: _snapshot!.cachedAt,
    );

    return currentSnapshot.toVenueMapData(levelId: _selectedLevel?.id);
  }

  /// Sets up a Supabase Realtime Postgres Changes subscription on `volunteer_counts`,
  /// strictly scoped to [eventId].
  void _subscribeToRealtimeCrowd(String eventId) {
    if (_subscribedEventId == eventId && _crowdChannel != null) {
      return;
    }

    _unsubscribeRealtimeCrowd();
    _subscribedEventId = eventId;

    if (!OfflineService().isOnline) return;

    try {
      _crowdChannel = Supabase.instance.client
          .channel('crowd_telemetry:$eventId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'volunteer_counts',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'event_id',
              value: eventId,
            ),
            callback: (payload) {
              _handleRealtimeCrowdPayload(payload);
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('MapScreen: Realtime crowd subscription error: $e');
    }
  }

  /// Cleanly unsubscribes from the current Realtime channel.
  void _unsubscribeRealtimeCrowd() {
    if (_crowdChannel != null) {
      try {
        _crowdChannel!.unsubscribe();
      } catch (_) {}
      _crowdChannel = null;
      _subscribedEventId = null;
    }
  }

  /// Processes realtime Postgres change payloads for `volunteer_counts`.
  ///
  /// Calculates freshness strictly from `updated_at` (Rule 12).
  /// Updates local state without refetching the entire static topology.
  void _handleRealtimeCrowdPayload(PostgresChangePayload payload) {
    try {
      final record = payload.newRecord;
      if (record.isEmpty) return;

      // Rule 21: Event isolation guard
      final eventId = record['event_id']?.toString();
      if (eventId != _currentEvent?.id) return;

      final zoneRaw = record['zone']?.toString() ?? '';
      final cleanCode = zoneRaw.replaceAll(RegExp(r'[^0-9a-zA-Z]'), '').toLowerCase();
      final count = (record['active_count'] as num?)?.toInt() ?? 0;
      final updatedAt = record['updated_at'] != null
          ? DateTime.tryParse(record['updated_at'].toString())
          : null;

      // Authoritative telemetry freshness calculation
      final freshness = SpatialCrowdFreshness.calculate(
        updatedAt,
        isOnline: OfflineService().isOnline,
      );

      // Match to event zone for capacity calculation
      EventZone? matchedZone;
      if (_snapshot != null) {
        for (final ez in _snapshot!.eventZones) {
          if (ez.code.toLowerCase().trim() == cleanCode ||
              ez.id.toLowerCase() == cleanCode ||
              zoneRaw.contains(ez.code)) {
            matchedZone = ez;
            break;
          }
        }
      }

      final capacity = matchedZone?.operatingCapacity ?? 100;
      final crowdLevel = SpatialCrowdState.levelFromCount(count, capacity: capacity);

      final updatedState = SpatialCrowdState(
        zoneCode: matchedZone?.code ?? zoneRaw,
        zoneId: matchedZone?.id,
        activeCount: count,
        crowdLevel: crowdLevel,
        lastUpdated: updatedAt,
        freshness: freshness,
      );

      final key = matchedZone?.code ?? zoneRaw;
      _liveCrowdStates[key] = updatedState;

      if (mounted) {
        setState(() {
          _venueData = _buildVenueMapData();
          // Keep selected zone reference synchronized if it was updated
          if (_selectedZone != null &&
              (_selectedZone!.roomNumber == key || _selectedZone!.id == updatedState.zoneId)) {
            _selectedZone = _venueData?.findZoneById(_selectedZone!.id);
          }
        });
      }
    } catch (e) {
      debugPrint('MapScreen: Error handling realtime crowd payload: $e');
    }
  }

  /// Handles initial deep-link context for Connect meeting points or Sessions/Booths.
  Future<void> _checkInitialSelection() async {
    if (widget.initialPoiId != null) {
      MapPoi? poi;
      if (_snapshot != null) {
        poi = _snapshot!.pois.cast<MapPoi?>().firstWhere(
              (p) => p?.id == widget.initialPoiId,
              orElse: () => null,
            );
      }
      poi ??= await _repository.getPoiById(widget.initialPoiId!);

      if (poi != null && mounted) {
        final resolvedPoi = poi;
        // Switch to the POI's level if different
        if (resolvedPoi.levelId != null && resolvedPoi.levelId != _selectedLevel?.id && _snapshot != null) {
          final targetLevel = _snapshot!.levels.cast<SpatialLevel?>().firstWhere(
                (lvl) => lvl?.id == resolvedPoi.levelId,
                orElse: () => null,
              );
          if (targetLevel != null) {
            _selectedLevel = targetLevel;
            _venueData = _buildVenueMapData();
          }
        }

        setState(() {
          _selectedPoi = resolvedPoi;
          _selectedZone = resolvedPoi.zoneId != null ? _venueData?.findZoneById(resolvedPoi.zoneId!) : null;
        });
        _centerMapOn(resolvedPoi.point);
        return;
      }
    }

    if (widget.initialZoneId != null && _currentEvent != null) {
      EventZone? ez;
      if (_snapshot != null) {
        ez = _snapshot!.eventZones.cast<EventZone?>().firstWhere(
              (z) => z?.id == widget.initialZoneId || z?.code == widget.initialZoneId,
              orElse: () => null,
            );
      }
      ez ??= await _repository.getZoneById(_currentEvent!.id, widget.initialZoneId!);

      if (ez != null && mounted) {
        // Switch to the Zone's level if different
        if (ez.levelId.isNotEmpty && ez.levelId != _selectedLevel?.id && _snapshot != null) {
          final targetLevel = _snapshot!.levels.cast<SpatialLevel?>().firstWhere(
                (lvl) => lvl?.id == ez!.levelId,
                orElse: () => null,
              );
          if (targetLevel != null) {
            _selectedLevel = targetLevel;
            _venueData = _buildVenueMapData();
          }
        }

        final zone = _venueData?.findZoneById(ez.id) ?? _venueData?.findZoneById(ez.code);
        if (zone != null) {
          setState(() {
            _selectedZone = zone;
          });
          _centerMapOn(zone.bounds.center);
        }
      }
    }
  }

  void _handleLevelSelected(SpatialLevel level) {
    if (_selectedLevel?.id == level.id) return;
    setState(() {
      _selectedLevel = level;
      _venueData = _buildVenueMapData();
      // Clear selection if not located on the newly selected level
      if (_selectedZone != null && _selectedZone!.levelId != level.id) {
        _selectedZone = null;
      }
      if (_selectedPoi != null && _selectedPoi!.levelId != level.id) {
        _selectedPoi = null;
      }
      _activeRoute = null;
    });
  }

  void _handleFilterChanged(MapFilterType filter) {
    setState(() {
      _activeFilter = filter;
      _selectedZone = null;
      _selectedPoi = null;
      _activeRoute = null;
    });
  }

  void _handleZoneTap(MapZone? zone) {
    setState(() {
      _selectedZone = zone;
      _selectedPoi = null;
      _activeRoute = null;
    });
  }

  void _handlePoiTap(MapPoi? poi) {
    setState(() {
      _selectedPoi = poi;
      _selectedZone = poi?.zoneId != null ? _venueData?.findZoneById(poi!.zoneId!) : null;
      _activeRoute = null;
    });
  }

  void _handleSearchResultSelected(MapSearchResult result) {
    setState(() {
      _selectedZone = result.zone;
      _selectedPoi = result.poi;
      _activeRoute = null;
    });

    final targetPoint = result.poi?.point ?? result.zone?.bounds.center;
    if (targetPoint != null) {
      _centerMapOn(targetPoint);
    }
  }

  void _centerMapOn(MapPoint point) {
    final matrix = Matrix4.identity();
    matrix.setTranslationRaw(
      (0.5 - point.x) * 200,
      (0.5 - point.y) * 200,
      0.0,
    );
    matrix.storage[0] = 1.3;
    matrix.storage[5] = 1.3;

    _transformationController.value = matrix;
  }

  void _resetMapView() {
    _transformationController.value = Matrix4.identity();
    setState(() {
      _selectedZone = null;
      _selectedPoi = null;
      _activeRoute = null;
    });
  }

  void _startNavigationToSelected() {
    if (_venueData == null) return;
    final targetPoint = _selectedPoi?.point ??
        _selectedZone?.entrancePoint ??
        _selectedZone?.bounds.center;
    if (targetPoint == null) return;

    final origin = _venueData!.zones.isNotEmpty
        ? _venueData!.zones.first.entrancePoint
        : const MapPoint(0.50, 0.90);
    final originLabel = _venueData!.zones.isNotEmpty
        ? _venueData!.zones.first.roomNumber
        : 'Main Entrance';
    final destinationName = _selectedPoi?.name ?? _selectedZone?.roomNumber ?? 'Destination';

    final route = VenueMockData.calculateRoute(
      origin: origin,
      destination: targetPoint,
      originLabel: originLabel,
      destinationLabel: destinationName,
      isAccessible: _isAccessibleRoute,
    );

    setState(() {
      _activeRoute = route;
    });
  }

  void _toggleAccessibility(bool accessible) {
    setState(() {
      _isAccessibleRoute = accessible;
    });
    if (_activeRoute != null) {
      _startNavigationToSelected();
    }
  }

  PoiCategory? _resolveActiveCategory() {
    switch (_activeFilter) {
      case MapFilterType.booths:
        return PoiCategory.booths;
      case MapFilterType.stages:
        return PoiCategory.stages;
      case MapFilterType.facilities:
        return PoiCategory.facilities;
      case MapFilterType.safety:
        return PoiCategory.safety;
      case MapFilterType.all:
      case MapFilterType.crowd:
        return null;
    }
  }

  /// Computes the aggregate crowd freshness indicator for the current floor.
  SpatialCrowdFreshness _resolveCurrentFloorCrowdFreshness() {
    if (!OfflineService().isOnline) {
      return SpatialCrowdFreshness.unavailable;
    }
    if (_venueData == null || _venueData!.zones.isEmpty) {
      return SpatialCrowdFreshness.unavailable;
    }

    bool hasLive = false;
    bool hasRecent = false;
    bool hasStale = false;

    for (final zone in _venueData!.zones) {
      switch (zone.crowdFreshness) {
        case SpatialCrowdFreshness.live:
          hasLive = true;
          break;
        case SpatialCrowdFreshness.recent:
          hasRecent = true;
          break;
        case SpatialCrowdFreshness.stale:
          hasStale = true;
          break;
        case SpatialCrowdFreshness.unavailable:
          break;
      }
    }

    if (hasLive) return SpatialCrowdFreshness.live;
    if (hasRecent) return SpatialCrowdFreshness.recent;
    if (hasStale) return SpatialCrowdFreshness.stale;
    return SpatialCrowdFreshness.unavailable;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark ? SpatiallyColors.darkBackground : SpatiallyColors.lightBackground;
    final textPrimary = isDark ? SpatiallyColors.darkTextPrimary : SpatiallyColors.lightTextPrimary;
    final textSecondary = isDark ? SpatiallyColors.darkTextSecondary : SpatiallyColors.lightTextSecondary;

    final title = _currentEvent?.name ?? 'Venue Map';
    final subtitle = _selectedLevel != null
        ? '${_selectedLevel!.name} • ${_snapshot?.venue.name ?? "Venue"}'
        : (_venueData != null && _venueData!.floorName.isNotEmpty
            ? '${_venueData!.floorName} • ${_venueData!.venueName}'
            : 'Floor Layout');
    final isRoot = widget.isRootTab ?? (widget.initialZoneId == null && widget.initialPoiId == null);
    final canPop = !isRoot && Navigator.canPop(context);

    // 1. Loading State
    if (_isLoading) {
      return Scaffold(
        backgroundColor: background,
        appBar: SpatiallyAppBar(
          title: title,
          automaticallyImplyLeading: canPop,
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(SpatiallyColors.spatialCyan),
                ),
              ),
              SpatiallySpacing.gapVerticalMd,
              Text(
                'Loading venue spatial topology...',
                style: SpatiallyTypography.caption(color: textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    // 2. Error / Offline Empty State
    if (_errorMessage != null && _venueData == null) {
      return Scaffold(
        backgroundColor: background,
        appBar: SpatiallyAppBar(
          title: title,
          automaticallyImplyLeading: canPop,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(SpatiallySpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  OfflineService().isOnline
                      ? Icons.map_outlined
                      : Icons.wifi_off_rounded,
                  size: 48,
                  color: SpatiallyColors.warning,
                ),
                SpatiallySpacing.gapVerticalMd,
                Text(
                  _errorMessage!,
                  style: SpatiallyTypography.body(color: textPrimary),
                  textAlign: TextAlign.center,
                ),
                SpatiallySpacing.gapVerticalLg,
                SpatiallyPrimaryButton(
                  label: 'Retry Connection',
                  icon: const Icon(Icons.refresh_rounded, size: 18, color: Colors.white),
                  onPressed: _resolveAndLoadMap,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final venueData = _venueData!;
    final floorCrowdFreshness = _resolveCurrentFloorCrowdFreshness();

    return Scaffold(
      backgroundColor: background,
      appBar: SpatiallyAppBar(
        titleWidget: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: SpatiallyTypography.sectionHeading(color: textPrimary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              subtitle,
              style: SpatiallyTypography.caption(color: textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        automaticallyImplyLeading: canPop,
        actions: [
          IconButton(
            icon: const Icon(Icons.center_focus_strong_rounded),
            color: textSecondary,
            tooltip: 'Fit Map View',
            onPressed: _resetMapView,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            color: textSecondary,
            tooltip: 'Sync Realtime Telemetry',
            onPressed: () {
              if (_currentEvent != null) {
                _loadMapSnapshot(_currentEvent!.id);
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. Interactive Map Canvas (Full viewport)
          Positioned.fill(
            child: MapCanvas(
              venueData: venueData,
              selectedCategory: _resolveActiveCategory(),
              showCrowdLayer: _activeFilter == MapFilterType.crowd,
              selectedZone: _selectedZone,
              selectedPoi: _selectedPoi,
              activeRoute: _activeRoute,
              transformationController: _transformationController,
              onZoneTap: _handleZoneTap,
              onPoiTap: _handlePoiTap,
            ),
          ),

          // 2. Floating Top Header Controls (Search + Category Filter Chips)
          Positioned(
            top: SpatiallySpacing.md,
            left: SpatiallySpacing.md,
            right: SpatiallySpacing.md,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Map Search Bar
                MapSearchBar(
                  venueData: venueData,
                  onResultSelected: _handleSearchResultSelected,
                  onClear: () {
                    setState(() {
                      _selectedZone = null;
                      _selectedPoi = null;
                    });
                  },
                ),

                SpatiallySpacing.gapVerticalSm,

                // Category Filter Pills
                MapCategoryFilters(
                  activeFilter: _activeFilter,
                  onFilterChanged: _handleFilterChanged,
                ),
              ],
            ),
          ),

          // 3. Multi-Level Floor Selector (Floats on right side if > 1 level)
          if (_snapshot != null && _snapshot!.levels.length > 1)
            Positioned(
              right: SpatiallySpacing.md,
              top: 135,
              child: MapLevelSelector(
                levels: _snapshot!.levels,
                selectedLevelId: _selectedLevel?.id,
                onLevelSelected: _handleLevelSelected,
              ),
            ),

          // 4. Floating Presence / Telemetry Legend Banner
          Positioned(
            bottom: (_selectedZone != null || _selectedPoi != null || _activeRoute != null)
                ? 210
                : (MediaQuery.of(context).padding.bottom + 16),
            left: SpatiallySpacing.md,
            right: SpatiallySpacing.md,
            child: Center(
              child: MapLegendStatus(
                floorName: _selectedLevel?.shortCode.isNotEmpty == true
                    ? '${_selectedLevel!.shortCode} • ${_selectedLevel!.name}'
                    : _selectedLevel?.name,
                isLiveCrowd: floorCrowdFreshness == SpatialCrowdFreshness.live,
                crowdFreshness: floorCrowdFreshness,
                isOffline: !OfflineService().isOnline,
                onResetView: _resetMapView,
              ),
            ),
          ),

          // 5. Floating Contextual Bottom Sheet (Zone / POI Details or Route Navigation)
          if (_activeRoute != null)
            Positioned(
              left: SpatiallySpacing.md,
              right: SpatiallySpacing.md,
              bottom: MediaQuery.of(context).padding.bottom + SpatiallySpacing.md,
              child: MapRouteSheet(
                route: _activeRoute!,
                isAccessible: _isAccessibleRoute,
                onAccessibilityToggled: _toggleAccessibility,
                onClose: () {
                  setState(() {
                    _activeRoute = null;
                  });
                },
              ),
            )
          else if (_selectedZone != null || _selectedPoi != null)
            Positioned(
              left: SpatiallySpacing.md,
              right: SpatiallySpacing.md,
              bottom: MediaQuery.of(context).padding.bottom + SpatiallySpacing.md,
              child: MapZoneSheet(
                zone: _selectedZone,
                poi: _selectedPoi,
                allPois: venueData.pois,
                isLiveCrowdData: floorCrowdFreshness == SpatialCrowdFreshness.live,
                isOffline: !OfflineService().isOnline,
                onNavigate: _startNavigationToSelected,
                onClose: () {
                  setState(() {
                    _selectedZone = null;
                    _selectedPoi = null;
                  });
                },
              ),
            ),
        ],
      ),
    );
  }
}
