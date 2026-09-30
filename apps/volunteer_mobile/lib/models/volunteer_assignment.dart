/// Domain model representing a volunteer's event and zone assignment.
class VolunteerAssignment {
  final String id;
  final String volunteerId;
  final String eventId;
  final String? zoneId;
  final String role;
  final String status;
  final DateTime? shiftStart;
  final DateTime? shiftEnd;
  final DateTime? assignedAt;

  // Joined event details
  final String eventName;
  final String venue;
  final DateTime? eventDate;
  final String eventStatus;

  // Joined zone details
  final String? zoneName;
  final String? zoneCode;
  final int? capacityLimit;

  const VolunteerAssignment({
    required this.id,
    required this.volunteerId,
    required this.eventId,
    this.zoneId,
    this.role = 'crowd_monitor',
    this.status = 'active',
    this.shiftStart,
    this.shiftEnd,
    this.assignedAt,
    required this.eventName,
    required this.venue,
    this.eventDate,
    required this.eventStatus,
    this.zoneName,
    this.zoneCode,
    this.capacityLimit,
  });

  factory VolunteerAssignment.fromSupabase(Map<String, dynamic> json) {
    final eventMap = json['events'] as Map<String, dynamic>?;
    final zoneMap = json['event_zones'] as Map<String, dynamic>?;

    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      return DateTime.tryParse(val.toString())?.toLocal();
    }

    return VolunteerAssignment(
      id: json['id'] as String? ?? '',
      volunteerId: json['volunteer_id'] as String? ?? '',
      eventId: json['event_id'] as String? ?? '',
      zoneId: json['zone_id'] as String?,
      role: json['role'] as String? ?? 'crowd_monitor',
      status: json['status'] as String? ?? 'active',
      shiftStart: parseDate(json['shift_start']),
      shiftEnd: parseDate(json['shift_end']),
      assignedAt: parseDate(json['assigned_at']),
      eventName: eventMap?['name'] as String? ?? 'Unknown Event',
      venue: eventMap?['venue'] as String? ?? 'TBA',
      eventDate: parseDate(eventMap?['event_date']),
      eventStatus: eventMap?['status'] as String? ?? 'upcoming',
      zoneName: zoneMap?['name'] as String?,
      zoneCode: zoneMap?['code'] as String?,
      capacityLimit: zoneMap?['capacity_limit'] as int?,
    );
  }

  bool get isRoving => zoneId == null;
}
