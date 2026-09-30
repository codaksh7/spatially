/// Represents an item in the Lost & Found operational system.
class LostFoundItem {
  final String id;
  final String eventId;
  final String? reporterUserId;
  final String reporterDeviceId;
  final String reportType; // 'lost' | 'found'
  final String category;
  final String title;
  final String description;
  final String? zoneId;
  final String? venueZoneName;
  final String? specificLocation;
  final String? imageUrl;
  final String status; // 'open', 'matched', 'returned', 'expired', 'closed'
  final String? pickupInstructions;
  final DateTime createdAt;
  final DateTime updatedAt;

  const LostFoundItem({
    required this.id,
    required this.eventId,
    this.reporterUserId,
    required this.reporterDeviceId,
    required this.reportType,
    required this.category,
    required this.title,
    required this.description,
    this.zoneId,
    this.venueZoneName,
    this.specificLocation,
    this.imageUrl,
    required this.status,
    this.pickupInstructions,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isLost => reportType.toLowerCase() == 'lost';
  bool get isFound => reportType.toLowerCase() == 'found';
  bool get isOpen => status.toLowerCase() == 'open';
  bool get isMatched => status.toLowerCase() == 'matched';
  bool get isReturned => status.toLowerCase() == 'returned';

  factory LostFoundItem.fromJson(Map<String, dynamic> json) {
    DateTime parseDt(dynamic val) {
      if (val == null) return DateTime.now();
      if (val is DateTime) return val;
      return DateTime.tryParse(val.toString()) ?? DateTime.now();
    }

    return LostFoundItem(
      id: json['id'] as String? ?? '',
      eventId: json['event_id'] as String? ?? '',
      reporterUserId: json['reporter_user_id'] as String?,
      reporterDeviceId: json['reporter_device_id'] as String? ?? '',
      reportType: json['report_type'] as String? ?? 'lost',
      category: json['category'] as String? ?? 'general',
      title: json['title'] as String? ?? 'Item',
      description: json['description'] as String? ?? '',
      zoneId: json['zone_id'] as String?,
      venueZoneName: json['venue_zone_name'] as String?,
      specificLocation: json['specific_location'] as String?,
      imageUrl: json['image_url'] as String?,
      status: json['status'] as String? ?? 'open',
      pickupInstructions: json['pickup_instructions'] as String?,
      createdAt: parseDt(json['created_at']),
      updatedAt: parseDt(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'event_id': eventId,
      'reporter_user_id': reporterUserId,
      'reporter_device_id': reporterDeviceId,
      'report_type': reportType,
      'category': category,
      'title': title,
      'description': description,
      'zone_id': zoneId,
      'venue_zone_name': venueZoneName,
      'specific_location': specificLocation,
      'image_url': imageUrl,
      'status': status,
      'pickup_instructions': pickupInstructions,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  LostFoundItem copyWith({
    String? id,
    String? eventId,
    String? reporterUserId,
    String? reporterDeviceId,
    String? reportType,
    String? category,
    String? title,
    String? description,
    String? zoneId,
    String? venueZoneName,
    String? specificLocation,
    String? imageUrl,
    String? status,
    String? pickupInstructions,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LostFoundItem(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      reporterUserId: reporterUserId ?? this.reporterUserId,
      reporterDeviceId: reporterDeviceId ?? this.reporterDeviceId,
      reportType: reportType ?? this.reportType,
      category: category ?? this.category,
      title: title ?? this.title,
      description: description ?? this.description,
      zoneId: zoneId ?? this.zoneId,
      venueZoneName: venueZoneName ?? this.venueZoneName,
      specificLocation: specificLocation ?? this.specificLocation,
      imageUrl: imageUrl ?? this.imageUrl,
      status: status ?? this.status,
      pickupInstructions: pickupInstructions ?? this.pickupInstructions,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
