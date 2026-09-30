import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/spatially_event.dart';

/// Centralized offline local cache manager for events, tickets, and content.
///
/// Ensures attendee screens (Home, Explore, Tickets, QR pass, Event Content)
/// remain resilient and accessible when network connectivity is lost.
///
/// Enforces safe account partitioning:
/// Account A's tickets must NEVER leak to Account B or Guest through cached storage.
class EventCacheManager {
  static const String _kPrimaryEventKey = 'spatially_cached_primary_event';
  static const String _kPrimaryTicketKeyLegacy = 'spatially_cached_primary_ticket';
  static const String _kExploreEventsKey = 'spatially_cached_explore_events';
  static const String _kMyTicketsKeyLegacy = 'spatially_cached_my_tickets';
  static const String _kLastSyncKey = 'spatially_cached_last_sync_time';

  static final EventCacheManager _instance = EventCacheManager._internal();
  factory EventCacheManager() => _instance;
  EventCacheManager._internal();

  String _ticketsKey(String? userId) => (userId != null && userId.isNotEmpty)
      ? 'spatially_cached_my_tickets_$userId'
      : 'spatially_cached_my_tickets_guest';

  String _primaryTicketKey(String? userId) => (userId != null && userId.isNotEmpty)
      ? 'spatially_cached_primary_ticket_$userId'
      : 'spatially_cached_primary_ticket_guest';

  /// Caches the attendee's primary event and ticket context.
  Future<void> cachePrimaryContext({
    required Map<String, dynamic> event,
    Map<String, dynamic>? ticket,
    String? userId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPrimaryEventKey, jsonEncode(event));
      if (ticket != null) {
        await prefs.setString(_primaryTicketKey(userId), jsonEncode(ticket));
      }
      await prefs.setString(_kLastSyncKey, DateTime.now().toIso8601String());
    } catch (_) {}
  }

  /// Retrieves the cached primary event, or null if none cached.
  Future<Map<String, dynamic>?> getCachedPrimaryEvent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kPrimaryEventKey);
      if (raw != null && raw.isNotEmpty) {
        return jsonDecode(raw) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  /// Retrieves the cached primary ticket partitioned by [userId], or null if none cached.
  Future<Map<String, dynamic>?> getCachedPrimaryTicket({String? userId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _primaryTicketKey(userId);
      var raw = prefs.getString(key);
      // Fallback to legacy key only if guest and no partitioned data yet
      if (raw == null && (userId == null || userId.isEmpty)) {
        raw = prefs.getString(_kPrimaryTicketKeyLegacy);
      }
      if (raw != null && raw.isNotEmpty) {
        return jsonDecode(raw) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  /// Caches the explore events list.
  Future<void> cacheExploreEvents(List<SpatiallyEvent> events) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final listJson = events.map((e) => e.toJson()).toList();
      await prefs.setString(_kExploreEventsKey, jsonEncode(listJson));
      await prefs.setString(_kLastSyncKey, DateTime.now().toIso8601String());
    } catch (_) {}
  }

  /// Retrieves cached explore events.
  Future<List<SpatiallyEvent>> getCachedExploreEvents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kExploreEventsKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        return decoded
            .map((item) => SpatiallyEvent.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  /// Caches attendee's ticket passes partitioned by [userId].
  Future<void> cacheTickets(List<Map<String, dynamic>> tickets, {String? userId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_ticketsKey(userId), jsonEncode(tickets));
      await prefs.setString(_kLastSyncKey, DateTime.now().toIso8601String());
    } catch (_) {}
  }

  /// Retrieves cached ticket passes partitioned by [userId].
  Future<List<Map<String, dynamic>>> getCachedTickets({String? userId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _ticketsKey(userId);
      var raw = prefs.getString(key);
      // Fallback to legacy key only if guest and no partitioned key yet
      if (raw == null && (userId == null || userId.isEmpty)) {
        raw = prefs.getString(_kMyTicketsKeyLegacy);
      }
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Clears cache for a specific user upon logout to ensure data isolation.
  Future<void> clearUserCache(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_ticketsKey(userId));
      await prefs.remove(_primaryTicketKey(userId));
    } catch (_) {}
  }

  /// Retrieves timestamp of the last successful synchronization.
  Future<DateTime?> getLastSyncTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kLastSyncKey);
      if (raw != null) return DateTime.tryParse(raw);
    } catch (_) {}
    return null;
  }

  String _spatialSnapshotKey(String eventId) => 'spatially_cached_spatial_snapshot_$eventId';

  /// Caches the complete spatial snapshot for an event.
  Future<void> cacheSpatialSnapshot(String eventId, Map<String, dynamic> snapshot) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_spatialSnapshotKey(eventId), jsonEncode(snapshot));
      await prefs.setString(_kLastSyncKey, DateTime.now().toIso8601String());
    } catch (_) {}
  }

  /// Retrieves the cached spatial snapshot for an event, or null if none cached.
  Future<Map<String, dynamic>?> getCachedSpatialSnapshot(String eventId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_spatialSnapshotKey(eventId));
      if (raw != null && raw.isNotEmpty) {
        return jsonDecode(raw) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  /// Clears the cached spatial snapshot for an event.
  Future<void> clearSpatialCache(String eventId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_spatialSnapshotKey(eventId));
    } catch (_) {}
  }

  String _passportSummaryKey(String eventId, String attendeeId) =>
      'spatially_cached_passport_${eventId}_$attendeeId';

  /// Caches the attendee's full passport summary (metrics, timeline, achievements).
  Future<void> cachePassportSummary(
    String eventId,
    String attendeeId,
    Map<String, dynamic> summary,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_passportSummaryKey(eventId, attendeeId), jsonEncode(summary));
      await prefs.setString(_kLastSyncKey, DateTime.now().toIso8601String());
    } catch (_) {}
  }

  /// Retrieves the cached passport summary for [eventId] and [attendeeId].
  Future<Map<String, dynamic>?> getCachedPassportSummary(
    String eventId,
    String attendeeId,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_passportSummaryKey(eventId, attendeeId));
      if (raw != null && raw.isNotEmpty) {
        return jsonDecode(raw) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  /// Clears cached passport summary for an event and attendee.
  Future<void> clearPassportCache(String eventId, String attendeeId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_passportSummaryKey(eventId, attendeeId));
    } catch (_) {}
  }

  // ==========================================================================
  // Phase 7C: Sessions, Notifications, Booths & Activities Caching
  // ==========================================================================

  String _sessionsKey(String eventId) => 'spatially_cached_sessions_$eventId';

  /// Caches the session list for [eventId].
  Future<void> cacheSessions(String eventId, List<Map<String, dynamic>> sessions) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sessionsKey(eventId), jsonEncode(sessions));
      await prefs.setString(_kLastSyncKey, DateTime.now().toIso8601String());
    } catch (_) {}
  }

  /// Retrieves cached sessions for [eventId].
  Future<List<Map<String, dynamic>>> getCachedSessions(String eventId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_sessionsKey(eventId));
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Clears cached sessions for [eventId].
  Future<void> clearSessionsCache(String eventId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionsKey(eventId));
    } catch (_) {}
  }

  String _notificationsKey(String partitionId, String eventId) =>
      'spatially_cached_notifs_${partitionId}_$eventId';

  /// Caches notifications partitioned by [partitionId] (userId or deviceId) and [eventId].
  Future<void> cacheNotifications(
    String partitionId,
    String eventId,
    List<Map<String, dynamic>> notifications,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_notificationsKey(partitionId, eventId), jsonEncode(notifications));
      await prefs.setString(_kLastSyncKey, DateTime.now().toIso8601String());
    } catch (_) {}
  }

  /// Retrieves cached notifications partitioned by [partitionId] and [eventId].
  Future<List<Map<String, dynamic>>> getCachedNotifications(
    String partitionId,
    String eventId,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_notificationsKey(partitionId, eventId));
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Clears cached notifications for [partitionId] and [eventId].
  Future<void> clearNotificationsCache(String partitionId, String eventId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_notificationsKey(partitionId, eventId));
    } catch (_) {}
  }

  String _readNotifsKey(String partitionId, String eventId) =>
      'spatially_read_notifs_${partitionId}_$eventId';

  String _dismissedNotifsKey(String partitionId, String eventId) =>
      'spatially_dismissed_notifs_${partitionId}_$eventId';

  /// Persists read notification IDs partitioned by [partitionId] and [eventId].
  Future<void> cacheReadNotificationIds(
    String partitionId,
    String eventId,
    Set<String> ids,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_readNotifsKey(partitionId, eventId), ids.toList());
    } catch (_) {}
  }

  /// Retrieves cached read notification IDs partitioned by [partitionId] and [eventId].
  Future<Set<String>> getCachedReadNotificationIds(
    String partitionId,
    String eventId,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_readNotifsKey(partitionId, eventId));
      if (list != null) return list.toSet();
    } catch (_) {}
    return {};
  }

  /// Persists dismissed notification IDs partitioned by [partitionId] and [eventId].
  Future<void> cacheDismissedNotificationIds(
    String partitionId,
    String eventId,
    Set<String> ids,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_dismissedNotifsKey(partitionId, eventId), ids.toList());
    } catch (_) {}
  }

  /// Retrieves cached dismissed notification IDs partitioned by [partitionId] and [eventId].
  Future<Set<String>> getCachedDismissedNotificationIds(
    String partitionId,
    String eventId,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_dismissedNotifsKey(partitionId, eventId));
      if (list != null) return list.toSet();
    } catch (_) {}
    return {};
  }

  String _boothsKey(String eventId) => 'spatially_cached_booths_$eventId';

  /// Caches exhibition booths for [eventId] (Phase 7C Option A).
  Future<void> cacheBooths(String eventId, List<Map<String, dynamic>> booths) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_boothsKey(eventId), jsonEncode(booths));
      await prefs.setString(_kLastSyncKey, DateTime.now().toIso8601String());
    } catch (_) {}
  }

  /// Retrieves cached booths for [eventId].
  Future<List<Map<String, dynamic>>> getCachedBooths(String eventId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_boothsKey(eventId));
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {}
    return [];
  }

  String _activitiesKey(String eventId) => 'spatially_cached_activities_$eventId';

  /// Caches quests & activities for [eventId] (Phase 7C Option A).
  Future<void> cacheActivities(String eventId, List<Map<String, dynamic>> activities) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_activitiesKey(eventId), jsonEncode(activities));
      await prefs.setString(_kLastSyncKey, DateTime.now().toIso8601String());
    } catch (_) {}
  }

  /// Retrieves cached activities for [eventId].
  Future<List<Map<String, dynamic>>> getCachedActivities(String eventId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_activitiesKey(eventId));
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {}
    return [];
  }
}

