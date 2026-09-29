import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/passport_progress.dart';
import '../models/journey_entry.dart';
import '../models/achievement_badge.dart';
import '../models/event_history_item.dart';
import '../../explore/data/event_cache_manager.dart';

/// Abstract contract for Passport data access.
/// 
/// Allows clean separation of UI from real Supabase queries and future local caching.
abstract class PassportRepository {
  /// Fetches the attendee's complete history of registered and attended events.
  Future<List<EventHistoryItem>> getEventHistory(String attendeeId);

  /// Resolves the current event context for the Passport.
  Future<PassportEventContext?> getSelectedEventContext(String? eventId, String attendeeId);

  /// Fetches verified progress metrics for an event.
  Future<PassportProgress> getEventProgress(String eventId, String attendeeId);

  /// Fetches the verified journey timeline for an event.
  Future<List<JourneyEntry>> getJourneyTimeline(String eventId, String attendeeId);

  /// Fetches the event's achievement definitions and unlock statuses.
  Future<List<AchievementBadge>> getAchievements(String eventId, String attendeeId);

  /// Fetches the authoritative combined passport summary from the backend or cache.
  Future<Map<String, dynamic>?> getPassportSummary(String eventId, String attendeeId);
}

/// Production implementation querying Supabase for tickets and events,
/// while keeping session/booth/activity verification strictly honest.
class PassportRepositoryImpl implements PassportRepository {
  final SupabaseClient _supabase;

  PassportRepositoryImpl({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  @override
  Future<List<EventHistoryItem>> getEventHistory(String attendeeId) async {
    final user = _supabase.auth.currentUser;
    try {
      List<dynamic> response;
      if (user != null) {
        response = await _supabase
            .from('tickets')
            .select('*, events(*)')
            .eq('user_id', user.id)
            .order('purchased_at', ascending: false)
            .timeout(const Duration(seconds: 5));
      } else {
        response = await _supabase
            .from('tickets')
            .select('*, events(*)')
            .eq('attendee_id', attendeeId)
            .isFilter('user_id', null)
            .order('purchased_at', ascending: false)
            .timeout(const Duration(seconds: 5));
      }

      final items = <EventHistoryItem>[];
      for (final row in response) {
        final eventMap = row['events'] as Map<String, dynamic>?;
        if (eventMap == null) continue;

        final rawDate = eventMap['event_date'];
        DateTime parsedDate;
        if (rawDate is String) {
          parsedDate = DateTime.tryParse(rawDate)?.toLocal() ?? DateTime.now();
        } else if (rawDate is DateTime) {
          parsedDate = rawDate.toLocal();
        } else {
          parsedDate = DateTime.now();
        }

        final status = (eventMap['status']?.toString() ?? 'upcoming').toLowerCase();
        final ticketStatus = (row['status']?.toString() ?? 'purchased').toLowerCase();
        final rawCheckedIn = row['checked_in_at'];
        DateTime? checkedInAt;
        if (rawCheckedIn is String) {
          checkedInAt = DateTime.tryParse(rawCheckedIn)?.toLocal();
        }

        items.add(
          EventHistoryItem(
            eventId: eventMap['id']?.toString() ?? '',
            ticketId: row['id']?.toString() ?? '',
            eventName: eventMap['name']?.toString() ?? 'Unnamed Event',
            venue: eventMap['venue']?.toString() ?? 'Venue TBA',
            eventDate: parsedDate,
            ticketStatus: ticketStatus,
            ticketCode: row['ticket_code']?.toString() ?? '',
            isLive: status == 'live',
            isEnded: status == 'ended',
            checkedInAt: checkedInAt,
          ),
        );
      }
      return items;
    } catch (_) {
      return [];
    }
  }

  @override
  Future<PassportEventContext?> getSelectedEventContext(String? eventId, String attendeeId) async {
    try {
      // 1. If a specific eventId is provided, query that ticket
      if (eventId != null && eventId.isNotEmpty) {
        final user = _supabase.auth.currentUser;
        final dynamic baseQuery = _supabase
            .from('tickets')
            .select('*, events(*)')
            .eq('event_id', eventId);

        final Map<String, dynamic>? row;
        if (user != null) {
          row = await baseQuery.eq('user_id', user.id).maybeSingle();
        } else {
          row = await baseQuery.eq('attendee_id', attendeeId).isFilter('user_id', null).maybeSingle();
        }

        if (row != null && row['events'] != null) {
          final e = row['events'] as Map<String, dynamic>;
          final parsedDate = DateTime.tryParse(e['event_date']?.toString() ?? '')?.toLocal() ?? DateTime.now();
          return PassportEventContext(
            eventId: e['id']?.toString() ?? eventId,
            eventName: e['name']?.toString() ?? 'Event',
            venue: e['venue']?.toString() ?? 'Venue TBA',
            eventDate: parsedDate,
            ticketStatus: (row['status']?.toString() ?? 'purchased').toLowerCase(),
            ticketCode: row['ticket_code']?.toString(),
            isLive: (e['status']?.toString() ?? '').toLowerCase() == 'live',
          );
        }
      }

      // 2. Otherwise find primary ticket: prefer live event, then soonest upcoming
      final history = await getEventHistory(attendeeId);
      if (history.isNotEmpty) {
        // Find live event first
        final liveItem = history.where((h) => h.isLive).firstOrNull;
        final selected = liveItem ?? history.first;

        return PassportEventContext(
          eventId: selected.eventId,
          eventName: selected.eventName,
          venue: selected.venue,
          eventDate: selected.eventDate,
          ticketStatus: selected.ticketStatus,
          ticketCode: selected.ticketCode,
          isLive: selected.isLive,
        );
      }

      // 3. Fallback: if no ticket exists, query latest live/upcoming event as general context
      final eventRows = await _supabase
          .from('events')
          .select()
          .inFilter('status', ['live', 'upcoming'])
          .order('event_date', ascending: true)
          .limit(1);

      if (eventRows.isNotEmpty) {
        final e = eventRows.first;
        final parsedDate = DateTime.tryParse(e['event_date']?.toString() ?? '')?.toLocal() ?? DateTime.now();
        return PassportEventContext(
          eventId: e['id']?.toString() ?? '',
          eventName: e['name']?.toString() ?? 'Event',
          venue: e['venue']?.toString() ?? 'Venue TBA',
          eventDate: parsedDate,
          ticketStatus: 'none',
          isLive: (e['status']?.toString() ?? '').toLowerCase() == 'live',
        );
      }

      return await _getCachedFallbackContext(eventId);
    } catch (_) {
      return await _getCachedFallbackContext(eventId);
    }
  }

  Future<PassportEventContext?> _getCachedFallbackContext(String? eventId) async {
    final cachedTicket = await EventCacheManager().getCachedPrimaryTicket();
    final cachedEvent = await EventCacheManager().getCachedPrimaryEvent();

    if (cachedTicket != null && cachedTicket['events'] != null) {
      final e = cachedTicket['events'] as Map<String, dynamic>;
      final parsedDate = DateTime.tryParse(e['event_date']?.toString() ?? '')?.toLocal() ?? DateTime.now();
      return PassportEventContext(
        eventId: e['id']?.toString() ?? (eventId ?? ''),
        eventName: e['name']?.toString() ?? 'Event',
        venue: e['venue']?.toString() ?? 'Venue TBA',
        eventDate: parsedDate,
        ticketStatus: (cachedTicket['status']?.toString() ?? 'purchased').toLowerCase(),
        ticketCode: cachedTicket['ticket_code']?.toString(),
        isLive: (e['status']?.toString() ?? '').toLowerCase() == 'live',
      );
    } else if (cachedEvent != null) {
      final parsedDate = DateTime.tryParse(cachedEvent['event_date']?.toString() ?? '')?.toLocal() ?? DateTime.now();
      return PassportEventContext(
        eventId: cachedEvent['id']?.toString() ?? (eventId ?? ''),
        eventName: cachedEvent['name']?.toString() ?? 'Event',
        venue: cachedEvent['venue']?.toString() ?? 'Venue TBA',
        eventDate: parsedDate,
        ticketStatus: 'none',
        isLive: (cachedEvent['status']?.toString() ?? '').toLowerCase() == 'live',
      );
    }
    return null;
  }

  // In-memory request deduplication cache: (eventId_attendeeId -> Future<Map<String, dynamic>?>)
  final Map<String, Future<Map<String, dynamic>?>> _activeSummaryRequests = {};

  @override
  Future<Map<String, dynamic>?> getPassportSummary(String eventId, String attendeeId) {
    final key = '${eventId}_$attendeeId';
    if (_activeSummaryRequests.containsKey(key)) {
      return _activeSummaryRequests[key]!;
    }

    final future = _fetchPassportSummaryInternal(eventId, attendeeId);
    _activeSummaryRequests[key] = future;
    future.whenComplete(() {
      _activeSummaryRequests.remove(key);
    });
    return future;
  }

  Future<Map<String, dynamic>?> _fetchPassportSummaryInternal(String eventId, String attendeeId) async {
    try {
      final response = await _supabase.rpc(
        'get_attendee_passport_summary',
        params: {
          'p_event_id': eventId,
          'p_attendee_id': attendeeId,
        },
      ).timeout(const Duration(seconds: 4));

      if (response != null && response is Map) {
        final data = Map<String, dynamic>.from(response);
        // Persist to offline cache
        await EventCacheManager().cachePassportSummary(eventId, attendeeId, data);
        return data;
      }
    } catch (_) {
      // Fallback to offline cache on network/rpc failure
    }

    return await EventCacheManager().getCachedPassportSummary(eventId, attendeeId);
  }

  @override
  Future<PassportProgress> getEventProgress(String eventId, String attendeeId) async {
    final summary = await getPassportSummary(eventId, attendeeId);
    if (summary != null && summary['progress'] is Map) {
      final p = Map<String, dynamic>.from(summary['progress'] as Map);
      return PassportProgress(
        eventId: p['eventId']?.toString() ?? eventId,
        sessionsAttended: (p['sessionsAttended'] as num?)?.toInt() ?? 0,
        boothsVisited: (p['boothsVisited'] as num?)?.toInt() ?? 0,
        activitiesCompleted: (p['activitiesCompleted'] as num?)?.toInt() ?? 0,
        zonesVisited: (p['zonesVisited'] as num?)?.toInt() ?? 0,
        pointsEarned: (p['pointsEarned'] as num?)?.toInt() ?? 0,
        badgesUnlocked: (p['badgesUnlocked'] as num?)?.toInt() ?? 0,
      );
    }

    // Default honest fallback
    return PassportProgress.zero(eventId);
  }

  @override
  Future<List<JourneyEntry>> getJourneyTimeline(String eventId, String attendeeId) async {
    final summary = await getPassportSummary(eventId, attendeeId);
    if (summary != null && summary['timeline'] is List) {
      final list = summary['timeline'] as List;
      final entries = <JourneyEntry>[];

      for (final item in list) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);

        final rawTime = map['timestamp'];
        DateTime timestamp;
        if (rawTime is String) {
          timestamp = DateTime.tryParse(rawTime)?.toLocal() ?? DateTime.now();
        } else {
          timestamp = DateTime.now();
        }

        JourneyEntryType type;
        final typeStr = map['type']?.toString().toLowerCase() ?? '';
        switch (typeStr) {
          case 'checkin':
            type = JourneyEntryType.checkIn;
            break;
          case 'activity':
            type = JourneyEntryType.activityCompleted;
            break;
          case 'booth':
            type = JourneyEntryType.boothVisited;
            break;
          case 'session':
            type = JourneyEntryType.sessionAttended;
            break;
          case 'zone':
            type = JourneyEntryType.zoneDiscovered;
            break;
          default:
            type = JourneyEntryType.rewardUnlocked;
        }

        entries.add(
          JourneyEntry(
            id: map['id']?.toString() ?? '',
            eventId: map['eventId']?.toString() ?? eventId,
            timestamp: timestamp,
            title: map['title']?.toString() ?? 'Event Activity',
            subtitle: map['subtitle']?.toString() ?? 'Verified Milestone',
            type: type,
            locationName: map['locationName']?.toString() ?? 'Venue Zone',
            referenceId: map['referenceId']?.toString(),
            isVerified: map['isVerified'] == true,
          ),
        );
      }

      // Sort timeline descending
      entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return entries;
    }

    return [];
  }

  @override
  Future<List<AchievementBadge>> getAchievements(String eventId, String attendeeId) async {
    final summary = await getPassportSummary(eventId, attendeeId);
    if (summary != null && summary['achievements'] is List) {
      final list = summary['achievements'] as List;
      final badges = <AchievementBadge>[];

      for (final item in list) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);

        final id = map['id']?.toString() ?? '';
        final categoryStr = map['category']?.toString().toLowerCase() ?? '';

        AchievementCategory category;
        switch (categoryStr) {
          case 'checkin':
            category = AchievementCategory.checkIn;
            break;
          case 'session':
            category = AchievementCategory.session;
            break;
          case 'booth':
            category = AchievementCategory.booth;
            break;
          case 'activity':
            category = AchievementCategory.activity;
            break;
          case 'exploration':
            category = AchievementCategory.exploration;
            break;
          default:
            category = AchievementCategory.activity;
        }

        IconData icon;
        switch (id) {
          case 'badge_pioneer':
            icon = Icons.how_to_reg_rounded;
            break;
          case 'badge_keynote':
            icon = Icons.campaign_rounded;
            break;
          case 'badge_explorer':
            icon = Icons.explore_rounded;
            break;
          case 'badge_booths':
            icon = Icons.storefront_rounded;
            break;
          case 'badge_quest_master':
            icon = Icons.task_alt_rounded;
            break;
          case 'badge_finisher':
            icon = Icons.military_tech_rounded;
            break;
          default:
            icon = Icons.emoji_events_rounded;
        }

        DateTime? unlockedAt;
        final rawUnlockedAt = map['unlockedAt'];
        if (rawUnlockedAt != null) {
          unlockedAt = DateTime.tryParse(rawUnlockedAt.toString())?.toLocal();
        }

        badges.add(
          AchievementBadge(
            id: id,
            title: map['title']?.toString() ?? '',
            description: map['description']?.toString() ?? '',
            icon: icon,
            category: category,
            requiredCount: (map['requiredCount'] as num?)?.toInt() ?? 1,
            currentCount: (map['currentCount'] as num?)?.toInt() ?? 0,
            isUnlocked: map['isUnlocked'] == true,
            unlockedAt: unlockedAt,
          ),
        );
      }

      return badges;
    }

    // Default zero-state badges
    return _defaultBadges();
  }

  List<AchievementBadge> _defaultBadges() {
    return const [
      AchievementBadge(
        id: 'badge_pioneer',
        title: 'Event Pioneer',
        description: 'Check in to the venue with your contactless admission ticket',
        icon: Icons.how_to_reg_rounded,
        category: AchievementCategory.checkIn,
        requiredCount: 1,
        currentCount: 0,
        isUnlocked: false,
      ),
      AchievementBadge(
        id: 'badge_keynote',
        title: 'Keynote Listener',
        description: 'Attend a live keynote or plenary session',
        icon: Icons.campaign_rounded,
        category: AchievementCategory.session,
        requiredCount: 1,
        currentCount: 0,
        isUnlocked: false,
      ),
      AchievementBadge(
        id: 'badge_explorer',
        title: 'Spatial Explorer',
        description: 'Explore 3 or more distinct venue zones and rooms',
        icon: Icons.explore_rounded,
        category: AchievementCategory.exploration,
        requiredCount: 3,
        currentCount: 0,
        isUnlocked: false,
      ),
      AchievementBadge(
        id: 'badge_booths',
        title: 'Booth Hunter',
        description: 'Visit 4 project or exhibitor showcases on the floor',
        icon: Icons.storefront_rounded,
        category: AchievementCategory.booth,
        requiredCount: 4,
        currentCount: 0,
        isUnlocked: false,
      ),
      AchievementBadge(
        id: 'badge_quest_master',
        title: 'Quest Master',
        description: 'Complete an interactive on-site engagement challenge',
        icon: Icons.task_alt_rounded,
        category: AchievementCategory.activity,
        requiredCount: 1,
        currentCount: 0,
        isUnlocked: false,
      ),
      AchievementBadge(
        id: 'badge_finisher',
        title: 'Event Finisher',
        description: 'Earn 100+ points across all event experiences',
        icon: Icons.military_tech_rounded,
        category: AchievementCategory.activity,
        requiredCount: 100,
        currentCount: 0,
        isUnlocked: false,
      ),
    ];
  }
}

