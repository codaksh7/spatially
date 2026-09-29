/// SPATIALLY — VOLUNTEER BLOCK 2.5A
/// Model representing a staff/volunteer directory entry for the active event.
/// Strictly privacy-preserving: contains NO emails, phone numbers, or private metadata.
library;

class VolunteerDirectoryEntry {
  final String volunteerId;
  final String fullName;
  final String role;
  final String staffType;
  final String? zoneId;
  final String? zoneName;
  final String? zoneCode;
  final bool isRoving;
  final String shiftStatus;

  const VolunteerDirectoryEntry({
    required this.volunteerId,
    required this.fullName,
    required this.role,
    required this.staffType,
    this.zoneId,
    this.zoneName,
    this.zoneCode,
    this.isRoving = false,
    this.shiftStatus = 'active',
  });

  bool get isOrganizerOrAdmin => staffType == 'organizer' || staffType == 'admin';

  String get assignmentLabel {
    if (isOrganizerOrAdmin) return 'Event Operations';
    if (isRoving) return 'Roving Shift (All Zones)';
    if (zoneName != null && zoneName!.isNotEmpty) {
      return zoneCode != null ? '$zoneName (Zone $zoneCode)' : zoneName!;
    }
    return 'Assigned Shift';
  }

  factory VolunteerDirectoryEntry.fromJson(Map<String, dynamic> json) {
    return VolunteerDirectoryEntry(
      volunteerId: (json['volunteer_id'] ?? json['id']) as String,
      fullName: json['full_name'] as String? ?? 'Staff Member',
      role: json['role'] as String? ?? 'staff',
      staffType: json['staff_type'] as String? ?? 'volunteer',
      zoneId: json['zone_id'] as String?,
      zoneName: json['zone_name'] as String?,
      zoneCode: json['zone_code'] as String?,
      isRoving: json['is_roving'] as bool? ?? false,
      shiftStatus: json['shift_status'] as String? ?? 'active',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'volunteer_id': volunteerId,
      'full_name': fullName,
      'role': role,
      'staff_type': staffType,
      'zone_id': zoneId,
      'zone_name': zoneName,
      'zone_code': zoneCode,
      'is_roving': isRoving,
      'shift_status': shiftStatus,
    };
  }
}
