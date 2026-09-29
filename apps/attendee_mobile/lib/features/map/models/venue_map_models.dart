import 'package:flutter/material.dart';
import '../../../design_system/components/spatially_crowd_indicator.dart';

/// Categories of points of interest on the Spatially Map.
enum PoiCategory {
  stages,
  booths,
  facilities,
  safety;

  static PoiCategory fromString(String? val) {
    if (val == null) return PoiCategory.facilities;
    final lower = val.toLowerCase().trim();
    if (lower.contains('stage')) return PoiCategory.stages;
    if (lower.contains('booth')) return PoiCategory.booths;
    if (lower.contains('safety') ||
        lower.contains('emergency') ||
        lower.contains('first_aid') ||
        lower.contains('security') ||
        lower.contains('exit') ||
        lower.contains('assembly')) {
      return PoiCategory.safety;
    }
    return PoiCategory.facilities;
  }

  String toJson() => name;
}

/// Normalized 2D coordinate inside the venue bounding box (0.0 to 1.0).
@immutable
class MapPoint {
  final double x;
  final double y;

  const MapPoint(this.x, this.y);

  MapPoint copyWith({double? x, double? y}) {
    return MapPoint(x ?? this.x, y ?? this.y);
  }

  Offset toOffset(Size canvasSize) {
    return Offset(x * canvasSize.width, y * canvasSize.height);
  }

  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
      };

  factory MapPoint.fromJson(dynamic json) {
    if (json is Map) {
      final xVal = (json['x'] as num?)?.toDouble() ?? 0.0;
      final yVal = (json['y'] as num?)?.toDouble() ?? 0.0;
      return MapPoint(xVal.clamp(0.0, 1.0), yVal.clamp(0.0, 1.0));
    }
    return const MapPoint(0.0, 0.0);
  }

  @override
  String toString() => 'MapPoint(${x.toStringAsFixed(2)}, ${y.toStringAsFixed(2)})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MapPoint &&
          runtimeType == other.runtimeType &&
          x == other.x &&
          y == other.y;

  @override
  int get hashCode => x.hashCode ^ y.hashCode;
}

/// Normalized bounding box for a venue room or zone (0.0 to 1.0).
@immutable
class MapBounds {
  final double left;
  final double top;
  final double width;
  final double height;

  const MapBounds({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  Rect toRect(Size canvasSize) {
    return Rect.fromLTWH(
      left * canvasSize.width,
      top * canvasSize.height,
      width * canvasSize.width,
      height * canvasSize.height,
    );
  }

  bool contains(MapPoint point) {
    return point.x >= left &&
        point.x <= (left + width) &&
        point.y >= top &&
        point.y <= (top + height);
  }

  MapPoint get center => MapPoint(left + width / 2, top + height / 2);

  Map<String, dynamic> toJson() => {
        'left': left,
        'top': top,
        'width': width,
        'height': height,
      };

  factory MapBounds.fromJson(dynamic json) {
    if (json is Map) {
      return MapBounds(
        left: ((json['left'] as num?)?.toDouble() ?? 0.0).clamp(0.0, 1.0),
        top: ((json['top'] as num?)?.toDouble() ?? 0.0).clamp(0.0, 1.0),
        width: ((json['width'] as num?)?.toDouble() ?? 0.0).clamp(0.0, 1.0),
        height: ((json['height'] as num?)?.toDouble() ?? 0.0).clamp(0.0, 1.0),
      );
    }
    return const MapBounds(left: 0, top: 0, width: 0, height: 0);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MapBounds &&
          runtimeType == other.runtimeType &&
          left == other.left &&
          top == other.top &&
          width == other.width &&
          height == other.height;

  @override
  int get hashCode =>
      left.hashCode ^ top.hashCode ^ width.hashCode ^ height.hashCode;
}

/// Metadata for vertical multi-level connectors (elevators, stairs, ramps).
@immutable
class SpatialConnectorMetadata {
  final String? connectorGroupId;
  final String connectorType;
  final List<int> connectedLevelIndices;
  final bool isStepFree;
  final String directionality;

  const SpatialConnectorMetadata({
    this.connectorGroupId,
    this.connectorType = 'elevator',
    this.connectedLevelIndices = const [],
    this.isStepFree = true,
    this.directionality = 'two_way',
  });

  Map<String, dynamic> toJson() => {
        'connector_group_id': connectorGroupId,
        'connector_type': connectorType,
        'connected_level_indices': connectedLevelIndices,
        'is_step_free': isStepFree,
        'directionality': directionality,
      };

  factory SpatialConnectorMetadata.fromJson(dynamic json) {
    if (json is Map) {
      final indicesRaw = json['connected_level_indices'];
      final List<int> indices = [];
      if (indicesRaw is List) {
        for (final item in indicesRaw) {
          if (item is num) indices.add(item.toInt());
        }
      }
      return SpatialConnectorMetadata(
        connectorGroupId: json['connector_group_id']?.toString(),
        connectorType: json['connector_type']?.toString() ?? 'elevator',
        connectedLevelIndices: indices,
        isStepFree: json['is_step_free'] as bool? ?? true,
        directionality: json['directionality']?.toString() ?? 'two_way',
      );
    }
    return const SpatialConnectorMetadata();
  }
}

/// Point of Interest (booth, stage, restroom, emergency exit, connector, etc.).
@immutable
class MapPoi {
  final String id;
  final String name;
  final PoiCategory category;
  final String categoryRaw;
  final MapPoint point;
  final String? zoneId;
  final String? levelId;
  final String? venueId;
  final String? eventId;
  final String description;
  final IconData icon;
  final bool isPermanent;
  final List<String> accessibilityFlags;
  final String operationalStatus;
  final bool isPublished;
  final Map<String, dynamic>? metadata;
  final SpatialConnectorMetadata? connectorMetadata;

  const MapPoi({
    required this.id,
    required this.name,
    required this.category,
    this.categoryRaw = '',
    required this.point,
    this.zoneId,
    this.levelId,
    this.venueId,
    this.eventId,
    required this.description,
    required this.icon,
    this.isPermanent = false,
    this.accessibilityFlags = const [],
    this.operationalStatus = 'active',
    this.isPublished = true,
    this.metadata,
    this.connectorMetadata,
  });

  bool get isActive => operationalStatus.toLowerCase() == 'active';
  bool get isClosed => operationalStatus.toLowerCase() == 'closed';
  bool get isRestricted => operationalStatus.toLowerCase() == 'restricted';
  bool get isBlocked => operationalStatus.toLowerCase() == 'blocked';

  static IconData resolveIcon(String category, [Map<String, dynamic>? metadata]) {
    final catLower = category.toLowerCase().trim();
    if (catLower.contains('stage')) return Icons.mic_external_on_rounded;
    if (catLower.contains('booth')) return Icons.storefront_rounded;
    if (catLower.contains('restroom') || catLower.contains('wc')) return Icons.wc_rounded;
    if (catLower.contains('food') || catLower.contains('cafe')) return Icons.restaurant_rounded;
    if (catLower.contains('elevator')) return Icons.elevator_rounded;
    if (catLower.contains('stairs')) return Icons.stairs_rounded;
    if (catLower.contains('emergency') || catLower.contains('exit')) return Icons.emergency_rounded;
    if (catLower.contains('first_aid') || catLower.contains('health')) return Icons.local_hospital_rounded;
    if (catLower.contains('security')) return Icons.security_rounded;
    if (catLower.contains('assembly')) return Icons.groups_rounded;
    if (catLower.contains('facility')) return Icons.info_outline_rounded;
    if (catLower.contains('activity') || catLower.contains('quest')) return Icons.flag_rounded;

    if (metadata != null && metadata.containsKey('connector_type')) {
      final connType = metadata['connector_type']?.toString().toLowerCase();
      if (connType == 'stairs') return Icons.stairs_rounded;
      if (connType == 'elevator') return Icons.elevator_rounded;
    }

    return Icons.place_rounded;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category.name,
        'category_raw': categoryRaw,
        'point': point.toJson(),
        'zone_id': zoneId,
        'level_id': levelId,
        'venue_id': venueId,
        'event_id': eventId,
        'description': description,
        'icon_code': icon.codePoint,
        'icon_font_family': icon.fontFamily,
        'is_permanent': isPermanent,
        'accessibility_flags': accessibilityFlags,
        'operational_status': operationalStatus,
        'is_published': isPublished,
        'metadata': metadata,
        'connector_metadata': connectorMetadata?.toJson(),
      };

  factory MapPoi.fromJson(dynamic json) {
    if (json is! Map) {
      return const MapPoi(
        id: '',
        name: '',
        category: PoiCategory.facilities,
        point: MapPoint(0, 0),
        description: '',
        icon: Icons.place_rounded,
      );
    }

    final catRaw = (json['category'] ?? json['category_raw'])?.toString() ?? 'other';
    final parsedCategory = PoiCategory.fromString(catRaw);

    MapPoint parsedPoint;
    if (json.containsKey('x_coordinate') && json.containsKey('y_coordinate')) {
      final x = (json['x_coordinate'] as num?)?.toDouble() ?? 0.0;
      final y = (json['y_coordinate'] as num?)?.toDouble() ?? 0.0;
      parsedPoint = MapPoint(x.clamp(0.0, 1.0), y.clamp(0.0, 1.0));
    } else if (json['point'] != null) {
      parsedPoint = MapPoint.fromJson(json['point']);
    } else {
      parsedPoint = const MapPoint(0, 0);
    }

    final metadataMap = json['metadata'] is Map
        ? Map<String, dynamic>.from(json['metadata'] as Map)
        : null;

    SpatialConnectorMetadata? connector;
    if (json['connector_metadata'] != null) {
      connector = SpatialConnectorMetadata.fromJson(json['connector_metadata']);
    } else if (metadataMap != null &&
        (metadataMap.containsKey('connector_type') || metadataMap.containsKey('connector_group_id'))) {
      connector = SpatialConnectorMetadata.fromJson(metadataMap);
    }

    final flagsRaw = json['accessibility_flags'];
    final List<String> flags = [];
    if (flagsRaw is List) {
      for (final f in flagsRaw) {
        if (f != null) flags.add(f.toString());
      }
    }

    final icon = resolveIcon(catRaw, metadataMap);

    return MapPoi(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      category: parsedCategory,
      categoryRaw: catRaw,
      point: parsedPoint,
      zoneId: json['zone_id']?.toString(),
      levelId: json['level_id']?.toString(),
      venueId: json['venue_id']?.toString(),
      eventId: json['event_id']?.toString(),
      description: json['description']?.toString() ?? '',
      icon: icon,
      isPermanent: json['is_permanent'] as bool? ?? false,
      accessibilityFlags: flags,
      operationalStatus: json['operational_status']?.toString() ?? 'active',
      isPublished: json['is_published'] as bool? ?? true,
      metadata: metadataMap,
      connectorMetadata: connector,
    );
  }
}

/// Physical Venue Zone (physical room layout in `venue_zones`).
@immutable
class SpatialZone {
  final String id;
  final String venueId;
  final String levelId;
  final String name;
  final String code;
  final MapBounds bounds;
  final MapPoint? entrancePoint;
  final List<MapPoint>? polygon;
  final int defaultCapacity;
  final String zoneType;
  final bool isReservable;
  final Map<String, dynamic>? metadata;

  const SpatialZone({
    required this.id,
    required this.venueId,
    required this.levelId,
    required this.name,
    required this.code,
    required this.bounds,
    this.entrancePoint,
    this.polygon,
    this.defaultCapacity = 100,
    this.zoneType = 'room',
    this.isReservable = true,
    this.metadata,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'venue_id': venueId,
        'level_id': levelId,
        'name': name,
        'code': code,
        'bounds': bounds.toJson(),
        'entrance_point': entrancePoint?.toJson(),
        'polygon': polygon?.map((p) => p.toJson()).toList(),
        'default_capacity': defaultCapacity,
        'zone_type': zoneType,
        'is_reservable': isReservable,
        'metadata': metadata,
      };

  factory SpatialZone.fromJson(dynamic json) {
    if (json is! Map) {
      return const SpatialZone(
        id: '',
        venueId: '',
        levelId: '',
        name: '',
        code: '',
        bounds: MapBounds(left: 0, top: 0, width: 0, height: 0),
      );
    }

    List<MapPoint>? parsedPolygon;
    if (json['polygon'] is List) {
      parsedPolygon = (json['polygon'] as List)
          .map((item) => MapPoint.fromJson(item))
          .toList();
    }

    return SpatialZone(
      id: json['id']?.toString() ?? '',
      venueId: json['venue_id']?.toString() ?? '',
      levelId: json['level_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      bounds: MapBounds.fromJson(json['bounds']),
      entrancePoint: json['entrance_point'] != null
          ? MapPoint.fromJson(json['entrance_point'])
          : null,
      polygon: parsedPolygon,
      defaultCapacity: (json['default_capacity'] as num?)?.toInt() ?? 100,
      zoneType: json['zone_type']?.toString() ?? 'room',
      isReservable: json['is_reservable'] as bool? ?? true,
      metadata: json['metadata'] is Map
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : null,
    );
  }
}

/// Event Zone (event-specific usage overlay in `event_zones`).
@immutable
class EventZone {
  final String id;
  final String eventId;
  final String venueZoneId;
  final String levelId;
  final String name;
  final String code;
  final MapBounds bounds;
  final MapPoint entrancePoint;
  final List<MapPoint>? polygon;
  final int operatingCapacity;
  final int warningThreshold;
  final int criticalThreshold;
  final bool isCrowdMonitored;
  final String operationalStatus;
  final String? statusReason;
  final bool isPublished;
  final Map<String, dynamic>? metadata;

  const EventZone({
    required this.id,
    required this.eventId,
    required this.venueZoneId,
    required this.levelId,
    required this.name,
    required this.code,
    required this.bounds,
    required this.entrancePoint,
    this.polygon,
    this.operatingCapacity = 100,
    this.warningThreshold = 75,
    this.criticalThreshold = 90,
    this.isCrowdMonitored = true,
    this.operationalStatus = 'active',
    this.statusReason,
    this.isPublished = true,
    this.metadata,
  });

  bool get isActive => operationalStatus.toLowerCase() == 'active';
  bool get isClosed => operationalStatus.toLowerCase() == 'closed';
  bool get isRestricted => operationalStatus.toLowerCase() == 'restricted';
  bool get isBlocked => operationalStatus.toLowerCase() == 'blocked';

  Map<String, dynamic> toJson() => {
        'id': id,
        'event_id': eventId,
        'venue_zone_id': venueZoneId,
        'level_id': levelId,
        'name': name,
        'code': code,
        'bounds': bounds.toJson(),
        'entrance_point': entrancePoint.toJson(),
        'polygon': polygon?.map((p) => p.toJson()).toList(),
        'operating_capacity': operatingCapacity,
        'warning_threshold': warningThreshold,
        'critical_threshold': criticalThreshold,
        'is_crowd_monitored': isCrowdMonitored,
        'operational_status': operationalStatus,
        'status_reason': statusReason,
        'is_published': isPublished,
        'metadata': metadata,
      };

  factory EventZone.fromJson(dynamic json) {
    if (json is! Map) {
      return const EventZone(
        id: '',
        eventId: '',
        venueZoneId: '',
        levelId: '',
        name: '',
        code: '',
        bounds: MapBounds(left: 0, top: 0, width: 0, height: 0),
        entrancePoint: MapPoint(0, 0),
      );
    }

    List<MapPoint>? parsedPolygon;
    if (json['polygon'] is List) {
      parsedPolygon = (json['polygon'] as List)
          .map((item) => MapPoint.fromJson(item))
          .toList();
    }

    final cap = (json['operating_capacity'] as num?)?.toInt() ?? 100;

    return EventZone(
      id: json['id']?.toString() ?? '',
      eventId: json['event_id']?.toString() ?? '',
      venueZoneId: json['venue_zone_id']?.toString() ?? '',
      levelId: json['level_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      bounds: MapBounds.fromJson(json['bounds']),
      entrancePoint: MapPoint.fromJson(json['entrance_point']),
      polygon: parsedPolygon,
      operatingCapacity: cap,
      warningThreshold: (json['warning_threshold'] as num?)?.toInt() ?? ((cap * 0.75).round()),
      criticalThreshold: (json['critical_threshold'] as num?)?.toInt() ?? ((cap * 0.90).round()),
      isCrowdMonitored: json['is_crowd_monitored'] as bool? ?? true,
      operationalStatus: json['operational_status']?.toString() ?? 'active',
      statusReason: json['status_reason']?.toString(),
      isPublished: json['is_published'] as bool? ?? true,
      metadata: json['metadata'] is Map
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : null,
    );
  }
}

/// Spatial room or zone on a venue floor with backward compatibility for Attendee UI.
@immutable
class MapZone {
  final String id; // Matches Supabase events.zones string (e.g. "701" or UUID)
  final String roomNumber;
  final String name;
  final String purpose;
  final MapBounds bounds;
  final MapPoint entrancePoint;
  final SpatiallyCrowdLevel crowdLevel;
  final SpatialCrowdFreshness crowdFreshness;
  final int capacity;
  final List<String> poiIds;

  // Real backend topological fields
  final String? levelId;
  final String? venueZoneId;
  final int operatingCapacity;
  final int warningThreshold;
  final int criticalThreshold;
  final bool isCrowdMonitored;
  final String operationalStatus;
  final String? statusReason;
  final bool isPublished;
  final List<MapPoint>? polygon;
  final Map<String, dynamic>? metadata;

  const MapZone({
    required this.id,
    required this.roomNumber,
    required this.name,
    required this.purpose,
    required this.bounds,
    required this.entrancePoint,
    this.crowdLevel = SpatiallyCrowdLevel.low,
    this.crowdFreshness = SpatialCrowdFreshness.unavailable,
    this.capacity = 100,
    this.poiIds = const [],
    this.levelId,
    this.venueZoneId,
    this.operatingCapacity = 100,
    this.warningThreshold = 75,
    this.criticalThreshold = 90,
    this.isCrowdMonitored = true,
    this.operationalStatus = 'active',
    this.statusReason,
    this.isPublished = true,
    this.polygon,
    this.metadata,
  });

  bool get isActive => operationalStatus.toLowerCase() == 'active';
  bool get isClosed => operationalStatus.toLowerCase() == 'closed';
  bool get isRestricted => operationalStatus.toLowerCase() == 'restricted';
  bool get isBlocked => operationalStatus.toLowerCase() == 'blocked';

  MapZone copyWith({
    String? id,
    String? roomNumber,
    String? name,
    String? purpose,
    MapBounds? bounds,
    MapPoint? entrancePoint,
    SpatiallyCrowdLevel? crowdLevel,
    SpatialCrowdFreshness? crowdFreshness,
    int? capacity,
    List<String>? poiIds,
    String? levelId,
    String? venueZoneId,
    int? operatingCapacity,
    int? warningThreshold,
    int? criticalThreshold,
    bool? isCrowdMonitored,
    String? operationalStatus,
    String? statusReason,
    bool? isPublished,
    List<MapPoint>? polygon,
    Map<String, dynamic>? metadata,
  }) {
    return MapZone(
      id: id ?? this.id,
      roomNumber: roomNumber ?? this.roomNumber,
      name: name ?? this.name,
      purpose: purpose ?? this.purpose,
      bounds: bounds ?? this.bounds,
      entrancePoint: entrancePoint ?? this.entrancePoint,
      crowdLevel: crowdLevel ?? this.crowdLevel,
      crowdFreshness: crowdFreshness ?? this.crowdFreshness,
      capacity: capacity ?? this.capacity,
      poiIds: poiIds ?? this.poiIds,
      levelId: levelId ?? this.levelId,
      venueZoneId: venueZoneId ?? this.venueZoneId,
      operatingCapacity: operatingCapacity ?? this.operatingCapacity,
      warningThreshold: warningThreshold ?? this.warningThreshold,
      criticalThreshold: criticalThreshold ?? this.criticalThreshold,
      isCrowdMonitored: isCrowdMonitored ?? this.isCrowdMonitored,
      operationalStatus: operationalStatus ?? this.operationalStatus,
      statusReason: statusReason ?? this.statusReason,
      isPublished: isPublished ?? this.isPublished,
      polygon: polygon ?? this.polygon,
      metadata: metadata ?? this.metadata,
    );
  }

  factory MapZone.fromEventZone(
    EventZone ez, {
    SpatiallyCrowdLevel crowdLevel = SpatiallyCrowdLevel.low,
    SpatialCrowdFreshness crowdFreshness = SpatialCrowdFreshness.unavailable,
    List<String> poiIds = const [],
    String? purpose,
  }) {
    return MapZone(
      id: ez.id,
      roomNumber: ez.code,
      name: ez.name,
      purpose: purpose ?? ez.metadata?['purpose']?.toString() ?? 'Event Zone',
      bounds: ez.bounds,
      entrancePoint: ez.entrancePoint,
      crowdLevel: crowdLevel,
      crowdFreshness: crowdFreshness,
      capacity: ez.operatingCapacity,
      poiIds: poiIds,
      levelId: ez.levelId,
      venueZoneId: ez.venueZoneId,
      operatingCapacity: ez.operatingCapacity,
      warningThreshold: ez.warningThreshold,
      criticalThreshold: ez.criticalThreshold,
      isCrowdMonitored: ez.isCrowdMonitored,
      operationalStatus: ez.operationalStatus,
      statusReason: ez.statusReason,
      isPublished: ez.isPublished,
      polygon: ez.polygon,
      metadata: ez.metadata,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'room_number': roomNumber,
        'name': name,
        'purpose': purpose,
        'bounds': bounds.toJson(),
        'entrance_point': entrancePoint.toJson(),
        'crowd_level': crowdLevel.name,
        'crowd_freshness': crowdFreshness.name,
        'capacity': capacity,
        'poi_ids': poiIds,
        'level_id': levelId,
        'venue_zone_id': venueZoneId,
        'operating_capacity': operatingCapacity,
        'warning_threshold': warningThreshold,
        'critical_threshold': criticalThreshold,
        'is_crowd_monitored': isCrowdMonitored,
        'operational_status': operationalStatus,
        'status_reason': statusReason,
        'is_published': isPublished,
        'polygon': polygon?.map((p) => p.toJson()).toList(),
        'metadata': metadata,
      };

  factory MapZone.fromJson(dynamic json) {
    if (json is! Map) {
      return const MapZone(
        id: '',
        roomNumber: '',
        name: '',
        purpose: '',
        bounds: MapBounds(left: 0, top: 0, width: 0, height: 0),
        entrancePoint: MapPoint(0, 0),
      );
    }

    final crowdStr = json['crowd_level']?.toString() ?? 'low';
    final crowd = SpatiallyCrowdLevel.values.firstWhere(
      (c) => c.name == crowdStr,
      orElse: () => SpatiallyCrowdLevel.low,
    );

    final freshStr = json['crowd_freshness']?.toString() ?? 'unavailable';
    final freshness = SpatialCrowdFreshness.values.firstWhere(
      (f) => f.name == freshStr,
      orElse: () => SpatialCrowdFreshness.unavailable,
    );

    final poiIdsRaw = json['poi_ids'];
    final List<String> pois = [];
    if (poiIdsRaw is List) {
      for (final p in poiIdsRaw) {
        if (p != null) pois.add(p.toString());
      }
    }

    List<MapPoint>? poly;
    if (json['polygon'] is List) {
      poly = (json['polygon'] as List)
          .map((item) => MapPoint.fromJson(item))
          .toList();
    }

    final cap = (json['capacity'] ?? json['operating_capacity'] as num?)?.toInt() ?? 100;

    return MapZone(
      id: json['id']?.toString() ?? '',
      roomNumber: json['room_number']?.toString() ?? json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      purpose: json['purpose']?.toString() ?? 'Event Zone',
      bounds: MapBounds.fromJson(json['bounds']),
      entrancePoint: MapPoint.fromJson(json['entrance_point']),
      crowdLevel: crowd,
      crowdFreshness: freshness,
      capacity: cap,
      poiIds: pois,
      levelId: json['level_id']?.toString(),
      venueZoneId: json['venue_zone_id']?.toString(),
      operatingCapacity: (json['operating_capacity'] as num?)?.toInt() ?? cap,
      warningThreshold: (json['warning_threshold'] as num?)?.toInt() ?? ((cap * 0.75).round()),
      criticalThreshold: (json['critical_threshold'] as num?)?.toInt() ?? ((cap * 0.90).round()),
      isCrowdMonitored: json['is_crowd_monitored'] as bool? ?? true,
      operationalStatus: json['operational_status']?.toString() ?? 'active',
      statusReason: json['status_reason']?.toString(),
      isPublished: json['is_published'] as bool? ?? true,
      polygon: poly,
      metadata: json['metadata'] is Map
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : null,
    );
  }
}

/// Wayfinding route preview between two locations on the map.
@immutable
class MapRoute {
  final String originName;
  final String destinationName;
  final List<MapPoint> waypoints;
  final double distanceMeters;
  final int estimatedMinutes;
  final bool isAccessible;
  final String instructions;

  const MapRoute({
    required this.originName,
    required this.destinationName,
    required this.waypoints,
    required this.distanceMeters,
    required this.estimatedMinutes,
    this.isAccessible = false,
    this.instructions = '',
  });

  Map<String, dynamic> toJson() => {
        'origin_name': originName,
        'destination_name': destinationName,
        'waypoints': waypoints.map((w) => w.toJson()).toList(),
        'distance_meters': distanceMeters,
        'estimated_minutes': estimatedMinutes,
        'is_accessible': isAccessible,
        'instructions': instructions,
      };

  factory MapRoute.fromJson(dynamic json) {
    if (json is! Map) {
      return const MapRoute(
        originName: '',
        destinationName: '',
        waypoints: [],
        distanceMeters: 0,
        estimatedMinutes: 0,
      );
    }

    final wpRaw = json['waypoints'];
    final List<MapPoint> wp = [];
    if (wpRaw is List) {
      for (final item in wpRaw) {
        wp.add(MapPoint.fromJson(item));
      }
    }

    return MapRoute(
      originName: json['origin_name']?.toString() ?? '',
      destinationName: json['destination_name']?.toString() ?? '',
      waypoints: wp,
      distanceMeters: (json['distance_meters'] as num?)?.toDouble() ?? 0.0,
      estimatedMinutes: (json['estimated_minutes'] as num?)?.toInt() ?? 0,
      isAccessible: json['is_accessible'] as bool? ?? false,
      instructions: json['instructions']?.toString() ?? '',
    );
  }
}

/// Domain model for a Physical Venue.
@immutable
class SpatialVenue {
  final String id;
  final String name;
  final String? slug;
  final String? venueType;
  final String? address;
  final String? timezone;
  final Map<String, dynamic>? metadata;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const SpatialVenue({
    required this.id,
    required this.name,
    this.slug,
    this.venueType,
    this.address,
    this.timezone,
    this.metadata,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'slug': slug,
        'venue_type': venueType,
        'address': address,
        'timezone': timezone,
        'metadata': metadata,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  factory SpatialVenue.fromJson(dynamic json) {
    if (json is! Map) {
      return const SpatialVenue(id: '', name: '');
    }
    return SpatialVenue(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      slug: json['slug']?.toString(),
      venueType: json['venue_type']?.toString(),
      address: json['address']?.toString(),
      timezone: json['timezone']?.toString(),
      metadata: json['metadata'] is Map
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }
}

/// Domain model for a Venue Level / Floor.
@immutable
class SpatialLevel {
  final String id;
  final String venueId;
  final int levelIndex;
  final String name;
  final String shortCode;
  final String levelType;
  final String? mapAssetUrl;
  final double aspectRatio;
  final int displayOrder;
  final bool isPublished;
  final Map<String, dynamic>? metadata;

  const SpatialLevel({
    required this.id,
    required this.venueId,
    required this.levelIndex,
    required this.name,
    required this.shortCode,
    this.levelType = 'presentation_complex',
    this.mapAssetUrl,
    this.aspectRatio = 1.0,
    this.displayOrder = 0,
    this.isPublished = true,
    this.metadata,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'venue_id': venueId,
        'level_index': levelIndex,
        'name': name,
        'short_code': shortCode,
        'level_type': levelType,
        'map_asset_url': mapAssetUrl,
        'aspect_ratio': aspectRatio,
        'display_order': displayOrder,
        'is_published': isPublished,
        'metadata': metadata,
      };

  factory SpatialLevel.fromJson(dynamic json) {
    if (json is! Map) {
      return const SpatialLevel(
        id: '',
        venueId: '',
        levelIndex: 0,
        name: '',
        shortCode: '',
      );
    }
    return SpatialLevel(
      id: json['id']?.toString() ?? '',
      venueId: json['venue_id']?.toString() ?? '',
      levelIndex: (json['level_index'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      shortCode: json['short_code']?.toString() ?? '',
      levelType: json['level_type']?.toString() ?? 'floor',
      mapAssetUrl: json['map_asset_url']?.toString(),
      aspectRatio: (json['aspect_ratio'] as num?)?.toDouble() ?? 1.0,
      displayOrder: (json['display_order'] as num?)?.toInt() ?? 0,
      isPublished: json['is_published'] as bool? ?? true,
      metadata: json['metadata'] is Map
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : null,
    );
  }
}

/// Crowd freshness classification states.
enum SpatialCrowdFreshness {
  live, // Updated < 3 minutes ago
  recent, // Updated 3 - 10 minutes ago
  stale, // Updated > 10 minutes ago
  unavailable; // Offline without recent timestamp or no telemetry

  static SpatialCrowdFreshness calculate(DateTime? timestamp, {bool isOnline = true}) {
    if (timestamp == null || !isOnline) return SpatialCrowdFreshness.unavailable;
    final age = DateTime.now().difference(timestamp);
    if (age.isNegative) return SpatialCrowdFreshness.live;
    if (age.inMinutes < 3) return SpatialCrowdFreshness.live;
    if (age.inMinutes < 10) return SpatialCrowdFreshness.recent;
    return SpatialCrowdFreshness.stale;
  }
}

/// Realtime or cached Crowd Observation State for a zone.
@immutable
class SpatialCrowdState {
  final String zoneCode;
  final String? zoneId;
  final int activeCount;
  final SpatiallyCrowdLevel crowdLevel;
  final DateTime? lastUpdated;
  final SpatialCrowdFreshness freshness;

  const SpatialCrowdState({
    required this.zoneCode,
    this.zoneId,
    required this.activeCount,
    required this.crowdLevel,
    this.lastUpdated,
    this.freshness = SpatialCrowdFreshness.live,
  });

  static SpatiallyCrowdLevel levelFromCount(int count, {int capacity = 100}) {
    final ratio = capacity > 0 ? (count / capacity) : 0.0;
    if (ratio > 0.85 || count > 80) return SpatiallyCrowdLevel.high;
    if (ratio > 0.50 || count > 40) return SpatiallyCrowdLevel.busy;
    if (ratio > 0.20 || count > 15) return SpatiallyCrowdLevel.moderate;
    return SpatiallyCrowdLevel.low;
  }

  SpatialCrowdState copyWithFreshness(SpatialCrowdFreshness newFreshness) {
    return SpatialCrowdState(
      zoneCode: zoneCode,
      zoneId: zoneId,
      activeCount: activeCount,
      crowdLevel: crowdLevel,
      lastUpdated: lastUpdated,
      freshness: newFreshness,
    );
  }

  Map<String, dynamic> toJson() => {
        'zone_code': zoneCode,
        'zone_id': zoneId,
        'active_count': activeCount,
        'crowd_level': crowdLevel.name,
        'last_updated': lastUpdated?.toIso8601String(),
        'freshness': freshness.name,
      };

  factory SpatialCrowdState.fromJson(dynamic json) {
    if (json is! Map) {
      return const SpatialCrowdState(
        zoneCode: '',
        activeCount: 0,
        crowdLevel: SpatiallyCrowdLevel.low,
        freshness: SpatialCrowdFreshness.unavailable,
      );
    }

    final levelStr = json['crowd_level']?.toString() ?? 'low';
    final level = SpatiallyCrowdLevel.values.firstWhere(
      (l) => l.name == levelStr,
      orElse: () => SpatiallyCrowdLevel.low,
    );

    final freshStr = json['freshness']?.toString() ?? 'unavailable';
    final fresh = SpatialCrowdFreshness.values.firstWhere(
      (f) => f.name == freshStr,
      orElse: () => SpatialCrowdFreshness.unavailable,
    );

    return SpatialCrowdState(
      zoneCode: json['zone_code']?.toString() ?? '',
      zoneId: json['zone_id']?.toString(),
      activeCount: (json['active_count'] as num?)?.toInt() ?? 0,
      crowdLevel: level,
      lastUpdated: json['last_updated'] != null
          ? DateTime.tryParse(json['last_updated'].toString())
          : null,
      freshness: fresh,
    );
  }
}

/// Normalized venue floor data model (UI View Model).
@immutable
class VenueMapData {
  final String venueName;
  final String floorName;
  final List<MapZone> zones;
  final List<MapPoi> pois;
  final String? levelId;
  final String? mapAssetUrl;

  const VenueMapData({
    required this.venueName,
    required this.floorName,
    required this.zones,
    required this.pois,
    this.levelId,
    this.mapAssetUrl,
  });

  MapZone? findZoneById(String id) {
    for (final zone in zones) {
      if (zone.id == id || zone.roomNumber == id || zone.roomNumber.contains(id)) {
        return zone;
      }
    }
    return null;
  }

  MapPoi? findPoiById(String id) {
    for (final poi in pois) {
      if (poi.id == id) return poi;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'venue_name': venueName,
        'floor_name': floorName,
        'zones': zones.map((z) => z.toJson()).toList(),
        'pois': pois.map((p) => p.toJson()).toList(),
        'level_id': levelId,
        'map_asset_url': mapAssetUrl,
      };

  factory VenueMapData.fromJson(dynamic json) {
    if (json is! Map) {
      return const VenueMapData(
        venueName: '',
        floorName: '',
        zones: [],
        pois: [],
      );
    }

    final zonesRaw = json['zones'];
    final List<MapZone> zList = [];
    if (zonesRaw is List) {
      for (final item in zonesRaw) {
        zList.add(MapZone.fromJson(item));
      }
    }

    final poisRaw = json['pois'];
    final List<MapPoi> pList = [];
    if (poisRaw is List) {
      for (final item in poisRaw) {
        pList.add(MapPoi.fromJson(item));
      }
    }

    return VenueMapData(
      venueName: json['venue_name']?.toString() ?? '',
      floorName: json['floor_name']?.toString() ?? '',
      zones: zList,
      pois: pList,
      levelId: json['level_id']?.toString(),
      mapAssetUrl: json['map_asset_url']?.toString(),
    );
  }
}

/// Complete Spatial Snapshot for an event, containing venue hierarchy,
/// levels, zones, POIs, and crowd telemetry.
@immutable
class SpatialMapSnapshot {
  final String eventId;
  final SpatialVenue venue;
  final List<SpatialLevel> levels;
  final List<EventZone> eventZones;
  final List<MapPoi> pois;
  final Map<String, SpatialCrowdState> crowdStates; // Key: zone code (e.g. "701")
  final DateTime cachedAt;

  const SpatialMapSnapshot({
    required this.eventId,
    required this.venue,
    required this.levels,
    required this.eventZones,
    required this.pois,
    this.crowdStates = const {},
    required this.cachedAt,
  });

  /// Converts this multi-level snapshot into a [VenueMapData] ready for UI rendering
  /// for a specific [levelId] (defaults to lowest or presentation floor).
  VenueMapData toVenueMapData({String? levelId}) {
    // 1. Resolve level
    SpatialLevel? targetLevel;
    if (levelId != null) {
      targetLevel = levels.cast<SpatialLevel?>().firstWhere(
            (lvl) => lvl?.id == levelId,
            orElse: () => null,
          );
    }
    // Fallback to level with level_index == 1 or first available
    targetLevel ??= levels.cast<SpatialLevel?>().firstWhere(
          (lvl) => lvl?.levelIndex == 1,
          orElse: () => levels.isNotEmpty ? levels.first : null,
        );

    final resolvedLevelId = targetLevel?.id;
    final floorName = targetLevel?.name ?? 'Venue Floor';

    // 2. Filter event zones for this level
    final zonesForLevel = eventZones.where((ez) {
      if (resolvedLevelId == null) return true;
      return ez.levelId == resolvedLevelId;
    }).toList();

    // 3. Filter POIs for this level
    final poisForLevel = pois.where((p) {
      if (resolvedLevelId == null) return true;
      return p.levelId == resolvedLevelId;
    }).toList();

    // 4. Map into MapZone with live/cached crowd level & freshness
    final mappedZones = zonesForLevel.map((ez) {
      final crowd = crowdStates[ez.code];
      final crowdLevel = crowd != null ? crowd.crowdLevel : SpatiallyCrowdLevel.low;
      final freshness = crowd != null ? crowd.freshness : SpatialCrowdFreshness.unavailable;
      final zonePoiIds = poisForLevel
          .where((p) => p.zoneId == ez.id || p.zoneId == ez.venueZoneId)
          .map((p) => p.id)
          .toList();

      return MapZone.fromEventZone(
        ez,
        crowdLevel: crowdLevel,
        crowdFreshness: freshness,
        poiIds: zonePoiIds,
      );
    }).toList();

    return VenueMapData(
      venueName: venue.name,
      floorName: floorName,
      zones: mappedZones,
      pois: poisForLevel,
      levelId: resolvedLevelId,
      mapAssetUrl: targetLevel?.mapAssetUrl,
    );
  }

  Map<String, dynamic> toJson() => {
        'event_id': eventId,
        'venue': venue.toJson(),
        'levels': levels.map((l) => l.toJson()).toList(),
        'event_zones': eventZones.map((z) => z.toJson()).toList(),
        'pois': pois.map((p) => p.toJson()).toList(),
        'crowd_states': crowdStates.map((k, v) => MapEntry(k, v.toJson())),
        'cached_at': cachedAt.toIso8601String(),
      };

  factory SpatialMapSnapshot.fromJson(dynamic json) {
    if (json is! Map) {
      return SpatialMapSnapshot(
        eventId: '',
        venue: const SpatialVenue(id: '', name: ''),
        levels: const [],
        eventZones: const [],
        pois: const [],
        cachedAt: DateTime.now(),
      );
    }

    final venue = SpatialVenue.fromJson(json['venue']);

    final levelsRaw = json['levels'];
    final List<SpatialLevel> lvls = [];
    if (levelsRaw is List) {
      for (final item in levelsRaw) {
        lvls.add(SpatialLevel.fromJson(item));
      }
    }

    final zonesRaw = json['event_zones'];
    final List<EventZone> ezs = [];
    if (zonesRaw is List) {
      for (final item in zonesRaw) {
        ezs.add(EventZone.fromJson(item));
      }
    }

    final poisRaw = json['pois'];
    final List<MapPoi> ps = [];
    if (poisRaw is List) {
      for (final item in poisRaw) {
        ps.add(MapPoi.fromJson(item));
      }
    }

    final crowdRaw = json['crowd_states'];
    final Map<String, SpatialCrowdState> crowds = {};
    if (crowdRaw is Map) {
      for (final entry in crowdRaw.entries) {
        crowds[entry.key.toString()] = SpatialCrowdState.fromJson(entry.value);
      }
    }

    return SpatialMapSnapshot(
      eventId: json['event_id']?.toString() ?? '',
      venue: venue,
      levels: lvls,
      eventZones: ezs,
      pois: ps,
      crowdStates: crowds,
      cachedAt: json['cached_at'] != null
          ? (DateTime.tryParse(json['cached_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }
}
