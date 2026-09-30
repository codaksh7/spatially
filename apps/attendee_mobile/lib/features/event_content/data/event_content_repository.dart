import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../services/offline_service.dart';
import '../../explore/data/event_cache_manager.dart';
import '../models/spatially_session.dart';
import '../models/spatially_booth.dart';
import '../models/spatially_activity.dart';

/// Abstract contract for fetching event content (sessions, booths, activities).
/// 
/// Facilitates seamless migration between local demo fixtures and live Supabase
/// tables when the organizer/backend schema is provisioned.
abstract class EventContentRepository {
  Future<List<SpatiallySession>> getSessions(String eventId);
  Future<List<SpatiallyBooth>> getBooths(String eventId);
  Future<List<SpatiallyActivity>> getActivities(String eventId);

  Future<SpatiallySession?> getSessionById(String eventId, String sessionId);
  Future<SpatiallyBooth?> getBoothById(String eventId, String boothId);
  Future<SpatiallyActivity?> getActivityById(String eventId, String activityId);
  /// Phase 7B: Server-authoritative engagement verifications
  Future<Map<String, dynamic>> verifyActivity({
    required String eventId,
    required String attendeeId,
    required String activityId,
    required String verificationCode,
  });

  Future<Map<String, dynamic>> recordBoothVisit({
    required String eventId,
    required String attendeeId,
    required String boothId,
  });

  Future<Map<String, dynamic>> recordSessionAttendance({
    required String eventId,
    required String attendeeId,
    required String sessionId,
  });

  Future<Set<String>> getCompletedActivityIds(String eventId, String attendeeId);
  Future<Set<String>> getVisitedBoothIds(String eventId, String attendeeId);
  Future<Set<String>> getAttendedSessionIds(String eventId, String attendeeId);
}

/// Production implementation of [EventContentRepository].
/// 
/// Gracefully checks Supabase for content tables, and cleanly falls back to
/// event-scoped demo fixtures if the tables do not exist.
class EventContentRepositoryImpl implements EventContentRepository {
  final SupabaseClient _supabase;
  final EventCacheManager _cacheManager;

  EventContentRepositoryImpl({
    SupabaseClient? supabase,
    EventCacheManager? cacheManager,
  })  : _supabase = supabase ?? Supabase.instance.client,
        _cacheManager = cacheManager ?? EventCacheManager();

  @override
  Future<List<SpatiallySession>> getSessions(String eventId) async {
    try {
      final isOnline = await OfflineService().checkConnectivity();
      if (!isOnline) {
        return await _getCachedSessions(eventId);
      }

      final response = await _supabase
          .from('sessions')
          .select()
          .eq('event_id', eventId)
          .order('start_time', ascending: true)
          .timeout(const Duration(seconds: 4));

      final rawList = (response as List<dynamic>)
          .map((json) => Map<String, dynamic>.from(json as Map))
          .toList();

      await _cacheManager.cacheSessions(eventId, rawList);

      return rawList.map((json) => SpatiallySession.fromJson(json)).toList();
    } catch (_) {
      // Network or table issue, check local offline cache
      return await _getCachedSessions(eventId);
    }
  }

  Future<List<SpatiallySession>> _getCachedSessions(String eventId) async {
    final cached = await _cacheManager.getCachedSessions(eventId);
    return cached.map((json) => SpatiallySession.fromJson(json)).toList();
  }

  @override
  Future<List<SpatiallyBooth>> getBooths(String eventId) async {
    try {
      final isOnline = await OfflineService().checkConnectivity();
      if (!isOnline) {
        return await _getCachedBooths(eventId);
      }

      final response = await _supabase
          .from('booths')
          .select()
          .eq('event_id', eventId)
          .order('name', ascending: true)
          .timeout(const Duration(seconds: 4));

      final rawList = (response as List<dynamic>)
          .map((json) => Map<String, dynamic>.from(json as Map))
          .toList();

      await _cacheManager.cacheBooths(eventId, rawList);

      return rawList.map((json) => SpatiallyBooth.fromJson(json)).toList();
    } catch (_) {
      return await _getCachedBooths(eventId);
    }
  }

  Future<List<SpatiallyBooth>> _getCachedBooths(String eventId) async {
    final cached = await _cacheManager.getCachedBooths(eventId);
    return cached.map((json) => SpatiallyBooth.fromJson(json)).toList();
  }

  @override
  Future<List<SpatiallyActivity>> getActivities(String eventId) async {
    try {
      final isOnline = await OfflineService().checkConnectivity();
      if (!isOnline) {
        return await _getCachedActivities(eventId);
      }

      final response = await _supabase
          .from('activities')
          .select()
          .eq('event_id', eventId)
          .order('points_reward', ascending: true)
          .timeout(const Duration(seconds: 4));

      final rawList = (response as List<dynamic>)
          .map((json) => Map<String, dynamic>.from(json as Map))
          .toList();

      await _cacheManager.cacheActivities(eventId, rawList);

      return rawList.map((json) => SpatiallyActivity.fromJson(json)).toList();
    } catch (_) {
      return await _getCachedActivities(eventId);
    }
  }

  Future<List<SpatiallyActivity>> _getCachedActivities(String eventId) async {
    final cached = await _cacheManager.getCachedActivities(eventId);
    return cached.map((json) => SpatiallyActivity.fromJson(json)).toList();
  }

  @override
  Future<SpatiallySession?> getSessionById(String eventId, String sessionId) async {
    final list = await getSessions(eventId);
    return list.cast<SpatiallySession?>().firstWhere(
          (s) => s?.id == sessionId,
          orElse: () => null,
        );
  }

  @override
  Future<SpatiallyBooth?> getBoothById(String eventId, String boothId) async {
    final list = await getBooths(eventId);
    return list.cast<SpatiallyBooth?>().firstWhere(
          (b) => b?.id == boothId,
          orElse: () => null,
        );
  }

  @override
  Future<SpatiallyActivity?> getActivityById(String eventId, String activityId) async {
    final list = await getActivities(eventId);
    return list.cast<SpatiallyActivity?>().firstWhere(
          (a) => a?.id == activityId,
          orElse: () => null,
        );
  }

  @override
  Future<Map<String, dynamic>> verifyActivity({
    required String eventId,
    required String attendeeId,
    required String activityId,
    required String verificationCode,
  }) async {
    // Section 15: Offline verification refusal
    // Connectivity required to verify checkpoint and award passport points
    final isOnline = await OfflineService().checkConnectivity();
    if (!isOnline) {
      return {
        'success': false,
        'error': 'OFFLINE',
        'message': 'Connectivity required to verify checkpoint and award passport points',
      };
    }

    try {
      final res = await _supabase.rpc(
        'verify_activity_completion',
        params: {
          'p_event_id': eventId,
          'p_attendee_id': attendeeId,
          'p_activity_id': activityId,
          'p_verification_code': verificationCode,
        },
      ).timeout(const Duration(seconds: 6));

      if (res is Map) {
        final result = Map<String, dynamic>.from(res);
        if (result['success'] == true) {
          // Clear passport cache to ensure fresh read on next view
          await EventCacheManager().clearPassportCache(eventId, attendeeId);
        }
        return result;
      }
      return {
        'success': false,
        'error': 'UNKNOWN_RESPONSE',
        'message': 'Unexpected response from verification service',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'NETWORK_ERROR',
        'message': 'Verification failed. Please check connectivity and try again.',
      };
    }
  }

  @override
  Future<Map<String, dynamic>> recordBoothVisit({
    required String eventId,
    required String attendeeId,
    required String boothId,
  }) async {
    final isOnline = await OfflineService().checkConnectivity();
    if (!isOnline) {
      return {
        'success': false,
        'error': 'OFFLINE',
        'message': 'Connectivity required to log booth visit in passport',
      };
    }

    try {
      final res = await _supabase.rpc(
        'record_booth_visit',
        params: {
          'p_event_id': eventId,
          'p_attendee_id': attendeeId,
          'p_booth_id': boothId,
        },
      ).timeout(const Duration(seconds: 6));

      if (res is Map) {
        final result = Map<String, dynamic>.from(res);
        if (result['success'] == true) {
          await EventCacheManager().clearPassportCache(eventId, attendeeId);
        }
        return result;
      }
      return {
        'success': false,
        'error': 'UNKNOWN_RESPONSE',
        'message': 'Unexpected response from booth service',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'NETWORK_ERROR',
        'message': 'Failed to log booth visit. Please try again.',
      };
    }
  }

  @override
  Future<Map<String, dynamic>> recordSessionAttendance({
    required String eventId,
    required String attendeeId,
    required String sessionId,
  }) async {
    final isOnline = await OfflineService().checkConnectivity();
    if (!isOnline) {
      return {
        'success': false,
        'error': 'OFFLINE',
        'message': 'Connectivity required to record session attendance in passport',
      };
    }

    try {
      final res = await _supabase.rpc(
        'record_session_attendance',
        params: {
          'p_event_id': eventId,
          'p_attendee_id': attendeeId,
          'p_session_id': sessionId,
        },
      ).timeout(const Duration(seconds: 6));

      if (res is Map) {
        final result = Map<String, dynamic>.from(res);
        if (result['success'] == true) {
          await EventCacheManager().clearPassportCache(eventId, attendeeId);
        }
        return result;
      }
      return {
        'success': false,
        'error': 'UNKNOWN_RESPONSE',
        'message': 'Unexpected response from session service',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'NETWORK_ERROR',
        'message': 'Failed to record session attendance. Please try again.',
      };
    }
  }

  @override
  Future<Set<String>> getCompletedActivityIds(String eventId, String attendeeId) async {
    try {
      // Direct SELECT works for authenticated users
      final rows = await _supabase
          .from('attendee_engagements')
          .select('reference_id')
          .eq('event_id', eventId)
          .eq('attendee_id', attendeeId)
          .eq('engagement_type', 'activity')
          .timeout(const Duration(seconds: 3));

      final ids = <String>{};
      for (final r in rows) {
        final refId = r['reference_id']?.toString();
        if (refId != null && refId.isNotEmpty) ids.add(refId);
      }
      if (ids.isNotEmpty) return ids;

      // Fallback for guest attendees whose reads are mediated via RPC
      final summary = await _supabase.rpc(
        'get_attendee_passport_summary',
        params: {'p_event_id': eventId, 'p_attendee_id': attendeeId},
      ).timeout(const Duration(seconds: 3));

      if (summary is Map && summary['timeline'] is List) {
        for (final item in summary['timeline'] as List) {
          if (item is Map && item['type'] == 'activity') {
            final ref = item['referenceId']?.toString();
            if (ref != null && ref.isNotEmpty) ids.add(ref);
          }
        }
      }
      return ids;
    } catch (_) {
      return {};
    }
  }

  @override
  Future<Set<String>> getVisitedBoothIds(String eventId, String attendeeId) async {
    try {
      final rows = await _supabase
          .from('attendee_engagements')
          .select('reference_id')
          .eq('event_id', eventId)
          .eq('attendee_id', attendeeId)
          .eq('engagement_type', 'booth')
          .timeout(const Duration(seconds: 3));

      final ids = <String>{};
      for (final r in rows) {
        final refId = r['reference_id']?.toString();
        if (refId != null && refId.isNotEmpty) ids.add(refId);
      }
      if (ids.isNotEmpty) return ids;

      final summary = await _supabase.rpc(
        'get_attendee_passport_summary',
        params: {'p_event_id': eventId, 'p_attendee_id': attendeeId},
      ).timeout(const Duration(seconds: 3));

      if (summary is Map && summary['timeline'] is List) {
        for (final item in summary['timeline'] as List) {
          if (item is Map && item['type'] == 'booth') {
            final ref = item['referenceId']?.toString();
            if (ref != null && ref.isNotEmpty) ids.add(ref);
          }
        }
      }
      return ids;
    } catch (_) {
      return {};
    }
  }

  @override
  Future<Set<String>> getAttendedSessionIds(String eventId, String attendeeId) async {
    try {
      final rows = await _supabase
          .from('attendee_engagements')
          .select('reference_id')
          .eq('event_id', eventId)
          .eq('attendee_id', attendeeId)
          .eq('engagement_type', 'session')
          .timeout(const Duration(seconds: 3));

      final ids = <String>{};
      for (final r in rows) {
        final refId = r['reference_id']?.toString();
        if (refId != null && refId.isNotEmpty) ids.add(refId);
      }
      if (ids.isNotEmpty) return ids;

      final summary = await _supabase.rpc(
        'get_attendee_passport_summary',
        params: {'p_event_id': eventId, 'p_attendee_id': attendeeId},
      ).timeout(const Duration(seconds: 3));

      if (summary is Map && summary['timeline'] is List) {
        for (final item in summary['timeline'] as List) {
          if (item is Map && item['type'] == 'session') {
            final ref = item['referenceId']?.toString();
            if (ref != null && ref.isNotEmpty) ids.add(ref);
          }
        }
      }
      return ids;
    } catch (_) {
      return {};
    }
  }
}

