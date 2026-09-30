import 'package:flutter/material.dart';

/// Categories of booths/exhibitors at an event.
enum BoothCategory {
  startup,
  ai,
  hardware,
  developerTools,
  showcase,
  community,
}

/// Typed domain model representing an exhibitor, project demonstration, or sponsor booth.
class SpatiallyBooth {
  final String id;
  final String eventId;
  final String name;
  final String companyOrOrg;
  final String description;
  final String boothNumber; // e.g. "Booth 1"
  final BoothCategory category;
  final String? zoneId; // e.g. "702"
  final String roomName; // e.g. "Room 702 • Exhibition Hall A"
  final String? poiId; // e.g. "poi_booth_1"
  final bool isOpen;
  final List<String> tags;
  final String? highlightDemo;

  const SpatiallyBooth({
    required this.id,
    required this.eventId,
    required this.name,
    required this.companyOrOrg,
    required this.description,
    required this.boothNumber,
    required this.category,
    this.zoneId,
    required this.roomName,
    this.poiId,
    this.isOpen = true,
    this.tags = const [],
    this.highlightDemo,
  });

  String get categoryDisplayName {
    switch (category) {
      case BoothCategory.startup:
        return 'Startup';
      case BoothCategory.ai:
        return 'AI & Machine Learning';
      case BoothCategory.hardware:
        return 'Hardware & IoT';
      case BoothCategory.developerTools:
        return 'Developer Tools';
      case BoothCategory.showcase:
        return 'Project Showcase';
      case BoothCategory.community:
        return 'Community & Open Source';
    }
  }

  IconData get categoryIcon {
    switch (category) {
      case BoothCategory.startup:
        return Icons.rocket_launch_rounded;
      case BoothCategory.ai:
        return Icons.psychology_rounded;
      case BoothCategory.hardware:
        return Icons.memory_rounded;
      case BoothCategory.developerTools:
        return Icons.code_rounded;
      case BoothCategory.showcase:
        return Icons.storefront_rounded;
      case BoothCategory.community:
        return Icons.public_rounded;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'event_id': eventId,
      'name': name,
      'company_or_org': companyOrOrg,
      'description': description,
      'booth_number': boothNumber,
      'category': category.name,
      'zone_id': zoneId,
      'room_name': roomName,
      'poi_id': poiId,
      'is_open': isOpen,
      'tags': tags,
      'highlight_demo': highlightDemo,
    };
  }

  factory SpatiallyBooth.fromJson(Map<String, dynamic> json) {
    return SpatiallyBooth(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      name: json['name'] as String? ?? 'Exhibitor Booth',
      companyOrOrg: json['company_or_org'] as String? ?? json['company_name'] as String? ?? 'Exhibitor',
      description: json['description'] as String? ?? '',
      boothNumber: json['booth_number'] as String? ?? 'Booth',
      category: BoothCategory.values.firstWhere(
        (c) => c.name.toLowerCase() == (json['category'] as String?)?.toLowerCase(),
        orElse: () => BoothCategory.showcase,
      ),
      zoneId: json['zone_id'] as String?,
      roomName: json['room_name'] as String? ?? 'Exhibition Area',
      poiId: json['poi_id'] as String?,
      isOpen: json['is_open'] as bool? ?? json['is_active'] as bool? ?? true,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? const [],
      highlightDemo: json['highlight_demo'] as String?,
    );
  }
}
