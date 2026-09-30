/// Domain model representing a normalized event zone from public.event_zones.
class EventZone {
  final String id;
  final String eventId;
  final String name;
  final String code;
  final int floorLevel;
  final int capacityLimit;
  final String currentDensity;

  const EventZone({
    required this.id,
    required this.eventId,
    required this.name,
    required this.code,
    this.floorLevel = 1,
    this.capacityLimit = 200,
    this.currentDensity = 'low',
  });

  factory EventZone.fromSupabase(Map<String, dynamic> json) {
    return EventZone(
      id: json['id'] as String? ?? '',
      eventId: json['event_id'] as String? ?? '',
      name: json['name'] as String? ?? 'General Zone',
      code: json['code'] as String? ?? '',
      floorLevel: json['floor_level'] as int? ?? 1,
      capacityLimit: json['capacity_limit'] as int? ?? 200,
      currentDensity: json['current_density'] as String? ?? 'low',
    );
  }
}
