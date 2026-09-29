import 'dart:convert';

/// Represents an attendee's personal profile and spatial identity.
/// 
/// Strictly separates personal identity from event participation records (owned by Passport).
/// Supports both:
/// 1. Guest mode ([userId] == null, [isAnonymous] == true): backed by local SharedPreferences.
/// 2. Authenticated mode ([userId] != null, [isAnonymous] == false): synced with Supabase `public.profiles`.
class UserProfile {
  final String name;
  final String headline;
  final String organization;
  final String bio;
  final List<String> interests;
  final String deviceId;
  final bool isAnonymous;
  final DateTime? updatedAt;
  final String? userId; // Supabase Auth UID (auth.uid())
  final String? email;  // Authenticated account email
  final String role;    // Default 'attendee' (server-controlled, never editable by client)
  final String? avatarUrl;

  const UserProfile({
    required this.name,
    this.headline = '',
    this.organization = '',
    this.bio = '',
    this.interests = const [],
    required this.deviceId,
    this.isAnonymous = true,
    this.updatedAt,
    this.userId,
    this.email,
    this.role = 'attendee',
    this.avatarUrl,
  });

  /// True if profile is backed by an authenticated Supabase user account.
  bool get isAuthenticated => userId != null && userId!.isNotEmpty;

  /// Default initial guest profile when user has not yet customized their name.
  factory UserProfile.defaultGuest(String deviceId) {
    return UserProfile(
      name: 'Attendee Guest',
      headline: 'Event Participant',
      organization: '',
      bio: '',
      interests: const ['AI', 'Mobile Development', 'Design'],
      deviceId: deviceId,
      isAnonymous: true,
      updatedAt: DateTime.now(),
      role: 'attendee',
    );
  }

  /// Factory creating an authenticated profile from a Supabase `public.profiles` row.
  factory UserProfile.fromSupabaseProfile(
    Map<String, dynamic> row, {
    required String deviceId,
    String? email,
  }) {
    final rawInterests = row['interests'];
    List<String> parsedInterests = [];
    if (rawInterests is List) {
      parsedInterests = rawInterests.map((e) => e.toString()).toList();
    }

    final fullName = row['full_name']?.toString() ?? '';
    final resolvedEmail = row['email']?.toString() ?? email;
    final fallbackName = (resolvedEmail != null && resolvedEmail.contains('@'))
        ? resolvedEmail.split('@').first
        : 'Attendee';

    return UserProfile(
      name: fullName.isNotEmpty ? fullName : fallbackName,
      headline: row['headline']?.toString() ?? '',
      organization: '',
      bio: row['bio']?.toString() ?? '',
      interests: parsedInterests.isNotEmpty ? parsedInterests : const ['AI', 'Mobile Development', 'Design'],
      deviceId: deviceId,
      isAnonymous: false,
      updatedAt: row['updated_at'] != null ? DateTime.tryParse(row['updated_at'].toString()) : null,
      userId: row['id']?.toString(),
      email: resolvedEmail,
      role: row['role']?.toString() ?? 'attendee',
      avatarUrl: row['avatar_url']?.toString(),
    );
  }

  /// Initial letter for avatar badge.
  String get initials {
    if (name.trim().isEmpty) return 'A';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  UserProfile copyWith({
    String? name,
    String? headline,
    String? organization,
    String? bio,
    List<String>? interests,
    String? deviceId,
    bool? isAnonymous,
    DateTime? updatedAt,
    String? userId,
    String? email,
    String? role,
    String? avatarUrl,
  }) {
    return UserProfile(
      name: name ?? this.name,
      headline: headline ?? this.headline,
      organization: organization ?? this.organization,
      bio: bio ?? this.bio,
      interests: interests ?? this.interests,
      deviceId: deviceId ?? this.deviceId,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      updatedAt: updatedAt ?? this.updatedAt,
      userId: userId ?? this.userId,
      email: email ?? this.email,
      role: role ?? this.role,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'headline': headline,
      'organization': organization,
      'bio': bio,
      'interests': interests,
      'deviceId': deviceId,
      'isAnonymous': isAnonymous,
      'updatedAt': updatedAt?.toIso8601String(),
      'userId': userId,
      'email': email,
      'role': role,
      'avatarUrl': avatarUrl,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map, {required String fallbackDeviceId}) {
    final uid = map['userId']?.toString();
    return UserProfile(
      name: map['name']?.toString() ?? 'Attendee Guest',
      headline: map['headline']?.toString() ?? '',
      organization: map['organization']?.toString() ?? '',
      bio: map['bio']?.toString() ?? '',
      interests: (map['interests'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      deviceId: map['deviceId']?.toString() ?? fallbackDeviceId,
      isAnonymous: map['isAnonymous'] as bool? ?? (uid == null && (map['name'] == null || map['name'] == 'Attendee Guest')),
      updatedAt: map['updatedAt'] != null ? DateTime.tryParse(map['updatedAt'].toString()) : null,
      userId: uid,
      email: map['email']?.toString(),
      role: map['role']?.toString() ?? 'attendee',
      avatarUrl: map['avatarUrl']?.toString(),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory UserProfile.fromJson(String source, {required String fallbackDeviceId}) =>
      UserProfile.fromMap(jsonDecode(source) as Map<String, dynamic>, fallbackDeviceId: fallbackDeviceId);
}
