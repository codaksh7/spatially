import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../design_system/components/spatially_crowd_indicator.dart';
import 'venue_map_models.dart';

/// Centralized mock fixture providing realistic venue geometry,
/// matching the 6 real event zones from Supabase (701, 702, 706, 707, 711, 712).
class VenueMockData {
  static const String demoVenueName = 'Spatially Demo Venue';
  static const String demoFloorName = 'Main Floor';

  /// Initial demo user presence zone (honest simulation).
  static const String defaultPresenceZoneId = '712';
  static const String defaultPresenceZoneName = 'Room 712 • Foyer & Registration';

  /// Pre-configured zones for the main floor.
  static final List<MapZone> demoZones = [
    const MapZone(
      id: '701',
      roomNumber: 'Room 701',
      name: 'Auditorium',
      purpose: 'Keynote Stage & Major Presentations',
      bounds: MapBounds(left: 0.06, top: 0.30, width: 0.34, height: 0.40),
      entrancePoint: MapPoint(0.40, 0.50),
      crowdLevel: SpatiallyCrowdLevel.moderate,
      capacity: 250,
      poiIds: ['poi_stage_a'],
    ),
    const MapZone(
      id: '702',
      roomNumber: 'Room 702',
      name: 'Project Exhibition Hall A',
      purpose: 'Main Project Demos & Exhibits',
      bounds: MapBounds(left: 0.60, top: 0.50, width: 0.34, height: 0.26),
      entrancePoint: MapPoint(0.60, 0.62),
      crowdLevel: SpatiallyCrowdLevel.busy,
      capacity: 150,
      poiIds: ['poi_presentation_stage', 'poi_booth_1', 'poi_booth_2', 'poi_booth_3'],
    ),
    const MapZone(
      id: '706',
      roomNumber: 'Room 706',
      name: 'Project Exhibition Hall B',
      purpose: 'Interactive Showcase & Hardware Labs',
      bounds: MapBounds(left: 0.60, top: 0.20, width: 0.34, height: 0.26),
      entrancePoint: MapPoint(0.60, 0.34),
      crowdLevel: SpatiallyCrowdLevel.low,
      capacity: 120,
      poiIds: ['poi_booth_4', 'poi_booth_5', 'poi_booth_6'],
    ),
    const MapZone(
      id: '707',
      roomNumber: 'Room 707',
      name: 'Workshop & Labs',
      purpose: 'Hands-on Workshops & Tech Labs',
      bounds: MapBounds(left: 0.06, top: 0.08, width: 0.34, height: 0.18),
      entrancePoint: MapPoint(0.40, 0.18),
      crowdLevel: SpatiallyCrowdLevel.low,
      capacity: 60,
      poiIds: [],
    ),
    const MapZone(
      id: '711',
      roomNumber: 'Room 711',
      name: 'Seminar Room',
      purpose: 'Panel Discussions & Speaker Sessions',
      bounds: MapBounds(left: 0.42, top: 0.05, width: 0.16, height: 0.14),
      entrancePoint: MapPoint(0.50, 0.19),
      crowdLevel: SpatiallyCrowdLevel.moderate,
      capacity: 50,
      poiIds: [],
    ),
    const MapZone(
      id: '712',
      roomNumber: 'Room 712',
      name: 'Foyer & Registration',
      purpose: 'Central Check-in, Help & Gathering Hub',
      bounds: MapBounds(left: 0.22, top: 0.74, width: 0.56, height: 0.18),
      entrancePoint: MapPoint(0.50, 0.74),
      crowdLevel: SpatiallyCrowdLevel.low,
      capacity: 200,
      poiIds: ['poi_help_desk', 'poi_first_aid', 'poi_security_desk', 'poi_accessibility_desk'],
    ),
  ];

  /// Pre-configured POIs for the main floor.
  static final List<MapPoi> demoPois = [
    // Stages / Sessions
    const MapPoi(
      id: 'poi_stage_a',
      name: 'Stage A',
      category: PoiCategory.stages,
      point: MapPoint(0.18, 0.48),
      zoneId: '701',
      description: 'Keynote auditorium stage with AV & audio broadcast',
      icon: Icons.mic_external_on_rounded,
    ),
    const MapPoi(
      id: 'poi_presentation_stage',
      name: 'Presentation Stage',
      category: PoiCategory.stages,
      point: MapPoint(0.85, 0.65),
      zoneId: '702',
      description: 'Secondary demonstration stage for project pitches',
      icon: Icons.co_present_rounded,
    ),

    // Booths (1-6)
    const MapPoi(
      id: 'poi_booth_1',
      name: 'Booth 1',
      category: PoiCategory.booths,
      point: MapPoint(0.68, 0.56),
      zoneId: '702',
      description: 'AI & Spatial Perception Project Demo',
      icon: Icons.storefront_rounded,
    ),
    const MapPoi(
      id: 'poi_booth_2',
      name: 'Booth 2',
      category: PoiCategory.booths,
      point: MapPoint(0.78, 0.56),
      zoneId: '702',
      description: 'Smart Campus BLE Localization System',
      icon: Icons.storefront_rounded,
    ),
    const MapPoi(
      id: 'poi_booth_3',
      name: 'Booth 3',
      category: PoiCategory.booths,
      point: MapPoint(0.88, 0.56),
      zoneId: '702',
      description: 'Decentralized Ephemeral Attendee Verification',
      icon: Icons.storefront_rounded,
    ),
    const MapPoi(
      id: 'poi_booth_4',
      name: 'Booth 4',
      category: PoiCategory.booths,
      point: MapPoint(0.68, 0.28),
      zoneId: '706',
      description: 'Embedded Sensor Gateway & Mesh Hardware',
      icon: Icons.storefront_rounded,
    ),
    const MapPoi(
      id: 'poi_booth_5',
      name: 'Booth 5',
      category: PoiCategory.booths,
      point: MapPoint(0.78, 0.28),
      zoneId: '706',
      description: 'Autonomous Robotic Venue Guide',
      icon: Icons.storefront_rounded,
    ),
    const MapPoi(
      id: 'poi_booth_6',
      name: 'Booth 6',
      category: PoiCategory.booths,
      point: MapPoint(0.88, 0.28),
      zoneId: '706',
      description: 'Live Volunteer Crowd Analytics Station',
      icon: Icons.storefront_rounded,
    ),

    // Facilities
    const MapPoi(
      id: 'poi_restroom_east',
      name: 'Restroom East',
      category: PoiCategory.facilities,
      point: MapPoint(0.55, 0.32),
      zoneId: null,
      description: 'Restrooms & accessibility washroom (East Corridor)',
      icon: Icons.wc_rounded,
    ),
    const MapPoi(
      id: 'poi_restroom_west',
      name: 'Restroom West',
      category: PoiCategory.facilities,
      point: MapPoint(0.45, 0.32),
      zoneId: null,
      description: 'Restrooms & washrooms (West Corridor)',
      icon: Icons.wc_rounded,
    ),
    const MapPoi(
      id: 'poi_water_station',
      name: 'Water Station',
      category: PoiCategory.facilities,
      point: MapPoint(0.50, 0.48),
      zoneId: null,
      description: 'Filtered drinking water fountain & refill point',
      icon: Icons.water_drop_rounded,
    ),
    const MapPoi(
      id: 'poi_help_desk',
      name: 'Help Desk',
      category: PoiCategory.facilities,
      point: MapPoint(0.34, 0.82),
      zoneId: '712',
      description: 'Attendee registration, badge inquiries & lost property',
      icon: Icons.help_outline_rounded,
    ),

    // Safety Infrastructure
    const MapPoi(
      id: 'poi_first_aid',
      name: 'First Aid Desk',
      category: PoiCategory.safety,
      point: MapPoint(0.66, 0.82),
      zoneId: '712',
      description: 'Emergency medical supplies & certified campus responder',
      icon: Icons.medical_services_rounded,
    ),
    const MapPoi(
      id: 'poi_security_desk',
      name: 'Venue Security Desk',
      category: PoiCategory.safety,
      point: MapPoint(0.24, 0.82),
      zoneId: '712',
      description: 'Campus safety officers, incident reporting & key security personnel',
      icon: Icons.shield_rounded,
    ),
    const MapPoi(
      id: 'poi_accessibility_desk',
      name: 'Accessibility Support',
      category: PoiCategory.safety,
      point: MapPoint(0.46, 0.82),
      zoneId: '712',
      description: 'Wheelchair loan, elevator access & guided assistance',
      icon: Icons.accessible_rounded,
    ),
    const MapPoi(
      id: 'poi_exit_north',
      name: 'Emergency Exit North',
      category: PoiCategory.safety,
      point: MapPoint(0.50, 0.03),
      zoneId: null,
      description: 'Press-bar fire exit leading to North escape staircase',
      icon: Icons.exit_to_app_rounded,
    ),
    const MapPoi(
      id: 'poi_exit_south',
      name: 'Emergency Exit South',
      category: PoiCategory.safety,
      point: MapPoint(0.50, 0.96),
      zoneId: null,
      description: 'Main campus lobby stair & primary ground evacuation route',
      icon: Icons.exit_to_app_rounded,
    ),
  ];

  /// Assembles the complete VenueMapData object.
  static VenueMapData getVenueData({Map<String, SpatiallyCrowdLevel>? zoneCrowdOverrides}) {
    List<MapZone> zones = demoZones;
    if (zoneCrowdOverrides != null && zoneCrowdOverrides.isNotEmpty) {
      zones = demoZones.map((z) {
        if (zoneCrowdOverrides.containsKey(z.id)) {
          return z.copyWith(crowdLevel: zoneCrowdOverrides[z.id]);
        }
        return z;
      }).toList();
    }

    return VenueMapData(
      venueName: demoVenueName,
      floorName: demoFloorName,
      zones: zones,
      pois: demoPois,
    );
  }

  /// Calculates a wayfinding route through the normalized corridor spine.
  static MapRoute calculateRoute({
    required MapPoint origin,
    required MapPoint destination,
    required String originLabel,
    required String destinationLabel,
    bool isAccessible = false,
  }) {
    final waypoints = <MapPoint>[origin];

    // Determine nearest corridor spine waypoint for origin
    final originSpineY = origin.y.clamp(0.20, 0.82);
    final originSpineX = isAccessible ? 0.46 : 0.50;
    waypoints.add(MapPoint(originSpineX, originSpineY));

    // If crossing the central elevator/ramp zone
    if (isAccessible) {
      waypoints.add(const MapPoint(0.46, 0.48)); // Elevator/ramp path
    } else {
      waypoints.add(const MapPoint(0.50, 0.48)); // Central direct spine
    }

    // Determine nearest corridor spine waypoint for destination
    final destSpineY = destination.y.clamp(0.20, 0.82);
    final destSpineX = isAccessible ? 0.46 : 0.50;
    waypoints.add(MapPoint(destSpineX, destSpineY));

    waypoints.add(destination);

    // Calculate approximate metric distance (scale: 1.0 normalized ~ 100 meters)
    double totalDistance = 0.0;
    for (int i = 0; i < waypoints.length - 1; i++) {
      final dx = (waypoints[i + 1].x - waypoints[i].x) * 90;
      final dy = (waypoints[i + 1].y - waypoints[i].y) * 110;
      totalDistance += math.sqrt(dx * dx + dy * dy);
    }
    final distanceMeters = totalDistance.clamp(15.0, 140.0);
    final minutes = (distanceMeters / 50.0).ceil(); // ~50m/min relaxed pace

    return MapRoute(
      originName: originLabel,
      destinationName: destinationLabel,
      waypoints: waypoints,
      distanceMeters: distanceMeters,
      estimatedMinutes: minutes,
      isAccessible: isAccessible,
      instructions: isAccessible
          ? 'Step-free route via West elevator corridor & entrance ramps.'
          : 'Direct central corridor route via Main Floor walkway.',
    );
  }
}
