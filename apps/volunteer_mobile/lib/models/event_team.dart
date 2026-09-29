/// SPATIALLY — VOLUNTEER BLOCK 2.5C
/// Domain model for event operational teams and team members.
library;

class TeamMember {
  final String id;
  final String teamId;
  final String volunteerId;
  final String fullName;
  final String role; // 'member', 'lead', 'supervisor'
  final String? shiftStatus; // 'active', 'on_break', 'scheduled', etc.
  final String? zoneName;
  final bool isOnBreak;

  const TeamMember({
    required this.id,
    required this.teamId,
    required this.volunteerId,
    required this.fullName,
    required this.role,
    this.shiftStatus,
    this.zoneName,
    this.isOnBreak = false,
  });

  bool get isLead => role == 'lead' || role == 'supervisor';

  factory TeamMember.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    final shift = json['volunteer_shifts'] as Map<String, dynamic>?;

    final shiftStatus = json['shift_status'] as String? ?? shift?['status'] as String?;
    final isOnBreak = shiftStatus == 'on_break' || json['is_on_break'] == true;

    return TeamMember(
      id: json['id'] as String? ?? '',
      teamId: json['team_id'] as String? ?? '',
      volunteerId: json['volunteer_id'] as String? ?? '',
      fullName: json['full_name'] as String? ?? profile?['full_name'] as String? ?? 'Team Member',
      role: json['role'] as String? ?? 'member',
      shiftStatus: shiftStatus,
      zoneName: json['zone_name'] as String? ?? shift?['zone_name'] as String?,
      isOnBreak: isOnBreak,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'team_id': teamId,
      'volunteer_id': volunteerId,
      'full_name': fullName,
      'role': role,
      'shift_status': shiftStatus,
      'zone_name': zoneName,
      'is_on_break': isOnBreak,
    };
  }
}

class EventTeam {
  final String id;
  final String eventId;
  final String name;
  final String? description;
  final String? leadId;
  final String? leadName;
  final String? zoneId;
  final String? zoneName;
  final int membersCount;
  final List<TeamMember> members;
  final DateTime createdAt;

  const EventTeam({
    required this.id,
    required this.eventId,
    required this.name,
    this.description,
    this.leadId,
    this.leadName,
    this.zoneId,
    this.zoneName,
    this.membersCount = 0,
    this.members = const [],
    required this.createdAt,
  });

  factory EventTeam.fromJson(Map<String, dynamic> json) {
    final leadProfile = json['profiles'] as Map<String, dynamic>?;
    final membersList = (json['event_team_members'] as List<dynamic>?)
            ?.map((m) => TeamMember.fromJson(m as Map<String, dynamic>))
            .toList() ??
        const [];

    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      return DateTime.tryParse(val.toString())?.toLocal();
    }

    return EventTeam(
      id: json['id'] as String? ?? '',
      eventId: json['event_id'] as String? ?? '',
      name: json['name'] as String? ?? 'Operations Team',
      description: json['description'] as String?,
      leadId: json['lead_id'] as String?,
      leadName: json['lead_name'] as String? ?? leadProfile?['full_name'] as String?,
      zoneId: json['zone_id'] as String?,
      zoneName: json['zone_name'] as String?,
      membersCount: json['members_count'] as int? ?? membersList.length,
      members: membersList,
      createdAt: parseDate(json['created_at']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'event_id': eventId,
      'name': name,
      'description': description,
      'lead_id': leadId,
      'lead_name': leadName,
      'zone_id': zoneId,
      'zone_name': zoneName,
      'members_count': membersCount,
      'members': members.map((m) => m.toJson()).toList(),
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }
}
