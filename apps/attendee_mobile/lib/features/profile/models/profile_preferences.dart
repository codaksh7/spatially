import 'dart:convert';
import 'package:flutter/material.dart';

/// Visibility mode for future networking discovery.
enum NetworkingVisibility {
  discoverable,
  matchingInterests,
  invisible;

  String get label {
    switch (this) {
      case NetworkingVisibility.discoverable:
        return 'Discoverable to All';
      case NetworkingVisibility.matchingInterests:
        return 'Matching Interests Only';
      case NetworkingVisibility.invisible:
        return 'Invisible (Incognito)';
    }
  }

  String get description {
    switch (this) {
      case NetworkingVisibility.discoverable:
        return 'Visible to nearby attendees during open networking sessions.';
      case NetworkingVisibility.matchingInterests:
        return 'Only attendees sharing at least one common topic can discover you.';
      case NetworkingVisibility.invisible:
        return 'Your profile is completely hidden from networking discovery.';
    }
  }
}

/// User's application, accessibility, privacy, and networking preferences.
/// 
/// Strictly separates preference configuration from background execution systems.
class ProfilePreferences {
  // Networking Preferences
  final NetworkingVisibility networkingVisibility;
  final bool allowProximityDiscovery;

  // Accessibility Preferences
  final bool preferStepFreeRoutes;
  final bool minimizeWalking;
  final bool reduceMotion;

  // Notification Preferences
  final bool eventUpdates;
  final bool sessionReminders;
  final bool crowdAlerts;
  final bool activityRewards;
  final bool connectAlerts;
  final bool recommendations;

  // Privacy & Telemetry
  final bool shareAnalytics;

  // App Theme
  final ThemeMode themeMode;

  const ProfilePreferences({
    this.networkingVisibility = NetworkingVisibility.matchingInterests,
    this.allowProximityDiscovery = true,
    this.preferStepFreeRoutes = false,
    this.minimizeWalking = false,
    this.reduceMotion = false,
    this.eventUpdates = true,
    this.sessionReminders = true,
    this.crowdAlerts = true,
    this.activityRewards = true,
    this.connectAlerts = true,
    this.recommendations = true,
    this.shareAnalytics = false,
    this.themeMode = ThemeMode.system,
  });

  factory ProfilePreferences.defaults() => const ProfilePreferences();

  ProfilePreferences copyWith({
    NetworkingVisibility? networkingVisibility,
    bool? allowProximityDiscovery,
    bool? preferStepFreeRoutes,
    bool? minimizeWalking,
    bool? reduceMotion,
    bool? eventUpdates,
    bool? sessionReminders,
    bool? crowdAlerts,
    bool? activityRewards,
    bool? connectAlerts,
    bool? recommendations,
    bool? shareAnalytics,
    ThemeMode? themeMode,
  }) {
    return ProfilePreferences(
      networkingVisibility: networkingVisibility ?? this.networkingVisibility,
      allowProximityDiscovery: allowProximityDiscovery ?? this.allowProximityDiscovery,
      preferStepFreeRoutes: preferStepFreeRoutes ?? this.preferStepFreeRoutes,
      minimizeWalking: minimizeWalking ?? this.minimizeWalking,
      reduceMotion: reduceMotion ?? this.reduceMotion,
      eventUpdates: eventUpdates ?? this.eventUpdates,
      sessionReminders: sessionReminders ?? this.sessionReminders,
      crowdAlerts: crowdAlerts ?? this.crowdAlerts,
      activityRewards: activityRewards ?? this.activityRewards,
      connectAlerts: connectAlerts ?? this.connectAlerts,
      recommendations: recommendations ?? this.recommendations,
      shareAnalytics: shareAnalytics ?? this.shareAnalytics,
      themeMode: themeMode ?? this.themeMode,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'networkingVisibility': networkingVisibility.name,
      'allowProximityDiscovery': allowProximityDiscovery,
      'preferStepFreeRoutes': preferStepFreeRoutes,
      'minimizeWalking': minimizeWalking,
      'reduceMotion': reduceMotion,
      'eventUpdates': eventUpdates,
      'sessionReminders': sessionReminders,
      'crowdAlerts': crowdAlerts,
      'activityRewards': activityRewards,
      'connectAlerts': connectAlerts,
      'recommendations': recommendations,
      'shareAnalytics': shareAnalytics,
      'themeMode': themeMode.name,
    };
  }

  factory ProfilePreferences.fromMap(Map<String, dynamic> map) {
    NetworkingVisibility parseVisibility(String? val) {
      if (val == null) return NetworkingVisibility.matchingInterests;
      for (final v in NetworkingVisibility.values) {
        if (v.name == val) return v;
      }
      return NetworkingVisibility.matchingInterests;
    }

    ThemeMode parseTheme(String? val) {
      if (val == null) return ThemeMode.system;
      for (final t in ThemeMode.values) {
        if (t.name == val) return t;
      }
      return ThemeMode.system;
    }

    return ProfilePreferences(
      networkingVisibility: parseVisibility(map['networkingVisibility']?.toString()),
      allowProximityDiscovery: map['allowProximityDiscovery'] as bool? ?? true,
      preferStepFreeRoutes: map['preferStepFreeRoutes'] as bool? ?? false,
      minimizeWalking: map['minimizeWalking'] as bool? ?? false,
      reduceMotion: map['reduceMotion'] as bool? ?? false,
      eventUpdates: map['eventUpdates'] as bool? ?? true,
      sessionReminders: map['sessionReminders'] as bool? ?? true,
      crowdAlerts: map['crowdAlerts'] as bool? ?? true,
      activityRewards: map['activityRewards'] as bool? ?? true,
      connectAlerts: map['connectAlerts'] as bool? ?? true,
      recommendations: map['recommendations'] as bool? ?? true,
      shareAnalytics: map['shareAnalytics'] as bool? ?? false,
      themeMode: parseTheme(map['themeMode']?.toString()),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory ProfilePreferences.fromJson(String source) =>
      ProfilePreferences.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
