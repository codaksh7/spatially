/// Typed domain model representing an event in the Spatially platform.
/// 
/// Maps directly to the Supabase `events` table with safe fallbacks and
/// helper predicates.
class SpatiallyEvent {
  final String id;
  final String name;
  final String venue;
  final DateTime eventDate;
  final String status; // 'live' | 'upcoming' | 'ended'
  final List<String> zones;
  final String description;
  final int capacity;
  final String organizerName;
  final String locationAddress;
  final String? startTime;
  final String? endTime;

  const SpatiallyEvent({
    required this.id,
    required this.name,
    this.venue = 'TBA',
    required this.eventDate,
    this.status = 'upcoming',
    this.zones = const [],
    this.description = '',
    this.capacity = 0,
    this.organizerName = '',
    this.locationAddress = '',
    this.startTime,
    this.endTime,
  });

  /// Creates a [SpatiallyEvent] from a Supabase row map.
  factory SpatiallyEvent.fromJson(Map<String, dynamic> json) {
    // Parse event date
    DateTime parsedDate;
    final rawDate = json['event_date'];
    if (rawDate is String) {
      parsedDate = DateTime.tryParse(rawDate)?.toLocal() ?? DateTime.now();
    } else if (rawDate is DateTime) {
      parsedDate = rawDate.toLocal();
    } else {
      parsedDate = DateTime.now();
    }

    // Parse zones array
    List<String> parsedZones = [];
    final rawZones = json['zones'];
    if (rawZones is List) {
      parsedZones = rawZones.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList();
    }

    // Parse capacity
    int parsedCapacity = 0;
    final rawCapacity = json['capacity'];
    if (rawCapacity is int) {
      parsedCapacity = rawCapacity;
    } else if (rawCapacity is String) {
      parsedCapacity = int.tryParse(rawCapacity) ?? 0;
    }

    return SpatiallyEvent(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unnamed Event',
      venue: json['venue']?.toString() ?? 'TBA',
      eventDate: parsedDate,
      status: (json['status']?.toString() ?? 'upcoming').toLowerCase(),
      zones: parsedZones,
      description: json['description']?.toString() ?? '',
      capacity: parsedCapacity,
      organizerName: json['organizer_name']?.toString() ?? '',
      locationAddress: json['location_address']?.toString() ?? '',
      startTime: json['start_time']?.toString(),
      endTime: json['end_time']?.toString(),
    );
  }

  /// Exports the event to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'venue': venue,
      'event_date': eventDate.toIso8601String(),
      'status': status,
      'zones': zones,
      'description': description,
      'capacity': capacity,
      'organizer_name': organizerName,
      'location_address': locationAddress,
      'start_time': startTime,
      'end_time': endTime,
    };
  }

  /// Whether the event is currently active / live.
  bool get isLive => status == 'live';

  /// Whether the event is upcoming.
  bool get isUpcoming => status == 'upcoming';

  /// Whether the event has concluded.
  bool get isEnded => status == 'ended';

  /// Returns location summary prioritizing locationAddress then venue.
  String get fullLocation {
    if (locationAddress.isNotEmpty && locationAddress != venue) {
      return '$venue, $locationAddress';
    }
    return venue;
  }
}
