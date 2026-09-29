import 'package:flutter/material.dart';

/// Categories of emergency or venue assistance.
enum SafetyCategory {
  medical,
  security,
  emergencyExit,
  helpDesk,
  accessibility,
  generalInfo,
}

/// Status of assistance or venue safety resource.
enum ResourceAvailability {
  available,
  busy,
  standby,
  evacuationOnly,
}

/// Official authoritative venue safety or emergency resource.
class SafetyResource {
  final String id;
  final String title;
  final String subtitle;
  final SafetyCategory category;
  final String zoneId;
  final String zoneName;
  final String poiId;
  final IconData icon;
  final ResourceAvailability availability;
  final String guidance;
  final String? contactChannel;

  const SafetyResource({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.category,
    required this.zoneId,
    required this.zoneName,
    required this.poiId,
    required this.icon,
    this.availability = ResourceAvailability.available,
    required this.guidance,
    this.contactChannel,
  });
}

/// Controlled venue emergency contact directory entry (demo labeled).
class EmergencyContact {
  final String id;
  final String title;
  final String role;
  final String location;
  final String channel;
  final bool isDemonstrationOnly;
  final String operationalHours;

  const EmergencyContact({
    required this.id,
    required this.title,
    required this.role,
    required this.location,
    required this.channel,
    this.isDemonstrationOnly = true,
    required this.operationalHours,
  });
}

/// Type of report in Lost & Found.
enum LostFoundType {
  lost,
  found;

  String get label => this == LostFoundType.lost ? 'Lost Item' : 'Found Item';
}

/// Standardized categories for Lost & Found items.
enum LostFoundCategory {
  phone,
  wallet,
  idCard,
  bag,
  clothing,
  electronics,
  keys,
  other;

  String get label {
    switch (this) {
      case LostFoundCategory.phone:
        return 'Phone & Device';
      case LostFoundCategory.wallet:
        return 'Wallet & Money';
      case LostFoundCategory.idCard:
        return 'ID, Badge & Cards';
      case LostFoundCategory.bag:
        return 'Bag & Backpack';
      case LostFoundCategory.clothing:
        return 'Clothing & Jacket';
      case LostFoundCategory.electronics:
        return 'Laptops & Chargers';
      case LostFoundCategory.keys:
        return 'Keys';
      case LostFoundCategory.other:
        return 'Other Item';
    }
  }

  IconData get icon {
    switch (this) {
      case LostFoundCategory.phone:
        return Icons.smartphone_rounded;
      case LostFoundCategory.wallet:
        return Icons.account_balance_wallet_rounded;
      case LostFoundCategory.idCard:
        return Icons.badge_rounded;
      case LostFoundCategory.bag:
        return Icons.backpack_rounded;
      case LostFoundCategory.clothing:
        return Icons.checkroom_rounded;
      case LostFoundCategory.electronics:
        return Icons.laptop_mac_rounded;
      case LostFoundCategory.keys:
        return Icons.vpn_key_rounded;
      case LostFoundCategory.other:
        return Icons.inventory_2_rounded;
    }
  }
}

/// Lifecycle status for a Lost & Found item.
enum LostFoundStatus {
  pendingSync,
  submitted,
  underReview,
  matched,
  resolved,
  expired;

  String get label {
    switch (this) {
      case LostFoundStatus.pendingSync:
        return 'Pending Sync (Offline Draft)';
      case LostFoundStatus.submitted:
        return 'Report Submitted';
      case LostFoundStatus.underReview:
        return 'Under Staff Review';
      case LostFoundStatus.matched:
        return 'Potential Match';
      case LostFoundStatus.resolved:
        return 'Claimed / Resolved';
      case LostFoundStatus.expired:
        return 'Archived';
    }
  }

  Color get color {
    switch (this) {
      case LostFoundStatus.pendingSync:
        return const Color(0xFFF59E0B); // Amber / Warning
      case LostFoundStatus.submitted:
        return const Color(0xFF6366F1); // Indigo
      case LostFoundStatus.underReview:
        return const Color(0xFFF59E0B); // Amber
      case LostFoundStatus.matched:
        return const Color(0xFF10B981); // Emerald
      case LostFoundStatus.resolved:
        return const Color(0xFF6B7280); // Gray
      case LostFoundStatus.expired:
        return const Color(0xFF9CA3AF); // Light gray
    }
  }
}

/// Attendee-facing Lost & Found report model.
class LostFoundReport {
  final String id;
  final String eventId;
  final LostFoundType type;
  final LostFoundCategory category;
  final String title;
  final String description;
  final String venueZoneId;
  final String venueZoneName;
  final String? specificLocation;
  final String? imagePlaceholderName;
  final LostFoundStatus status;
  final DateTime createdAt;
  final bool isCurrentUser;
  final String? pickupInstructions;

  const LostFoundReport({
    required this.id,
    required this.eventId,
    required this.type,
    required this.category,
    required this.title,
    required this.description,
    required this.venueZoneId,
    required this.venueZoneName,
    this.specificLocation,
    this.imagePlaceholderName,
    this.status = LostFoundStatus.submitted,
    required this.createdAt,
    this.isCurrentUser = false,
    this.pickupInstructions,
  });

  LostFoundReport copyWith({
    String? id,
    String? eventId,
    LostFoundType? type,
    LostFoundCategory? category,
    String? title,
    String? description,
    String? venueZoneId,
    String? venueZoneName,
    String? specificLocation,
    String? imagePlaceholderName,
    LostFoundStatus? status,
    DateTime? createdAt,
    bool? isCurrentUser,
    String? pickupInstructions,
  }) {
    return LostFoundReport(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      type: type ?? this.type,
      category: category ?? this.category,
      title: title ?? this.title,
      description: description ?? this.description,
      venueZoneId: venueZoneId ?? this.venueZoneId,
      venueZoneName: venueZoneName ?? this.venueZoneName,
      specificLocation: specificLocation ?? this.specificLocation,
      imagePlaceholderName: imagePlaceholderName ?? this.imagePlaceholderName,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      isCurrentUser: isCurrentUser ?? this.isCurrentUser,
      pickupInstructions: pickupInstructions ?? this.pickupInstructions,
    );
  }
}
