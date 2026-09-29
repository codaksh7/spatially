import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/app.dart';
import '../../../services/attendee_identity.dart';
import '../models/profile_preferences.dart';
import '../models/user_profile.dart';

/// Abstract contract for profile and preferences data operations.
/// 
/// Provides a clean boundary separating UI from local storage and cloud sync.
abstract class ProfileRepository {
  Future<UserProfile> getProfile();
  Future<void> saveProfile(UserProfile profile);
  Future<ProfilePreferences> getPreferences();
  Future<void> savePreferences(ProfilePreferences preferences);
  Future<void> resetProfile();
  List<String> getAvailableInterests();
}

/// Production implementation supporting guest-first local storage with
/// optional authenticated cloud synchronization via Supabase `public.profiles`.
class ProfileRepositoryImpl implements ProfileRepository {
  static const String _kGuestProfileKey = 'spatially_user_profile';
  static const String _kPreferencesKey = 'spatially_user_preferences';

  final SupabaseClient _supabase;

  ProfileRepositoryImpl({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  static const List<String> _kAvailableInterests = [
    'AI & Machine Learning',
    'Cloud & DevOps',
    'Cybersecurity',
    'Mobile Engineering',
    'UI/UX & Product Design',
    'Robotics & IoT',
    'Web3 & Blockchain',
    'Startups & Venture',
    'Game Development',
    'Data Science & Analytics',
  ];

  @override
  List<String> getAvailableInterests() => List.unmodifiable(_kAvailableInterests);

  String _accountProfileKey(String userId) => 'spatially_user_profile_$userId';

  @override
  Future<UserProfile> getProfile() async {
    final deviceId = AttendeeIdentity.deviceId ?? 'guest_device';
    final user = _supabase.auth.currentUser;

    // 1. Authenticated User Flow -> Sync with public.profiles
    if (user != null) {
      try {
        final row = await _supabase
            .from('profiles')
            .select()
            .eq('id', user.id)
            .maybeSingle()
            .timeout(const Duration(seconds: 4));

        if (row != null) {
          final profile = UserProfile.fromSupabaseProfile(
            row,
            deviceId: deviceId,
            email: user.email,
          );
          // Cache cloud profile for offline access
          await _cacheAccountProfile(user.id, profile);
          return profile;
        }
      } catch (_) {
        // Fall back to account-scoped cached profile if network query times out or offline
        final cached = await _getCachedAccountProfile(user.id, deviceId);
        if (cached != null) return cached;
      }

      // If no profile exists yet in public.profiles or network failed without cache
      return UserProfile(
        name: user.userMetadata?['full_name']?.toString() ??
            (user.email != null ? user.email!.split('@').first : 'Attendee'),
        headline: 'Event Participant',
        organization: '',
        bio: '',
        interests: const ['AI', 'Mobile Development', 'Design'],
        deviceId: deviceId,
        isAnonymous: false,
        updatedAt: DateTime.now(),
        userId: user.id,
        email: user.email,
        role: 'attendee',
      );
    }

    // 2. Guest User Flow -> Read from local SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kGuestProfileKey);
      if (raw != null && raw.isNotEmpty) {
        return UserProfile.fromJson(raw, fallbackDeviceId: deviceId);
      }
    } catch (_) {}

    return UserProfile.defaultGuest(deviceId);
  }

  @override
  Future<void> saveProfile(UserProfile profile) async {
    final user = _supabase.auth.currentUser;

    if (user != null) {
      // 1. Authenticated: Update public.profiles via RLS (id and role are immutable)
      try {
        await _supabase.from('profiles').update({
          'full_name': profile.name,
          'headline': profile.headline,
          'bio': profile.bio,
          'interests': profile.interests,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', user.id).timeout(const Duration(seconds: 5));
      } catch (_) {
        // Network failure will rely on cached profile until reconnection
      }
      await _cacheAccountProfile(user.id, profile);
    } else {
      // 2. Guest: Save to local SharedPreferences
      try {
        final prefs = await SharedPreferences.getInstance();
        final updated = profile.copyWith(updatedAt: DateTime.now());
        await prefs.setString(_kGuestProfileKey, updated.toJson());
      } catch (_) {}
    }
  }

  Future<void> _cacheAccountProfile(String userId, UserProfile profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_accountProfileKey(userId), profile.toJson());
    } catch (_) {}
  }

  Future<UserProfile?> _getCachedAccountProfile(String userId, String deviceId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_accountProfileKey(userId));
      if (raw != null && raw.isNotEmpty) {
        return UserProfile.fromJson(raw, fallbackDeviceId: deviceId);
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<ProfilePreferences> getPreferences() async {
    ProfilePreferences preferences = ProfilePreferences.defaults();
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kPreferencesKey);
      if (raw != null && raw.isNotEmpty) {
        preferences = ProfilePreferences.fromJson(raw);
      }
    } catch (_) {}

    // Synchronize cloud networking preference if authenticated
    final user = _supabase.auth.currentUser;
    if (user != null) {
      try {
        final row = await _supabase
            .from('profiles')
            .select('networking_opt_in, networking_visibility, allow_proximity_discovery')
            .eq('id', user.id)
            .maybeSingle()
            .timeout(const Duration(seconds: 4));

        if (row != null) {
          NetworkingVisibility vis = preferences.networkingVisibility;
          final visStr = row['networking_visibility']?.toString();
          if (visStr != null) {
            for (final v in NetworkingVisibility.values) {
              if (v.name == visStr) vis = v;
            }
          }
          final allowProx = row['allow_proximity_discovery'] as bool? ?? preferences.allowProximityDiscovery;
          preferences = preferences.copyWith(
            networkingVisibility: vis,
            allowProximityDiscovery: allowProx,
          );
        }
      } catch (_) {}
    }

    // Ensure app theme mode matches stored preference
    appThemeModeNotifier.value = preferences.themeMode;
    return preferences;
  }

  @override
  Future<void> savePreferences(ProfilePreferences preferences) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPreferencesKey, preferences.toJson());
      // Update global theme notifier immediately
      appThemeModeNotifier.value = preferences.themeMode;
    } catch (_) {}

    // Cloud sync for networking preferences if user is authenticated
    final user = _supabase.auth.currentUser;
    if (user != null) {
      try {
        await _supabase.from('profiles').update({
          'networking_opt_in': preferences.networkingVisibility != NetworkingVisibility.invisible,
          'networking_visibility': preferences.networkingVisibility.name,
          'allow_proximity_discovery': preferences.allowProximityDiscovery,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', user.id).timeout(const Duration(seconds: 4));
      } catch (_) {}
    }
  }

  @override
  Future<void> resetProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kGuestProfileKey);
      final user = _supabase.auth.currentUser;
      if (user != null) {
        await prefs.remove(_accountProfileKey(user.id));
      }
      await prefs.remove(_kPreferencesKey);
      appThemeModeNotifier.value = ThemeMode.system;
    } catch (_) {}
  }
}
