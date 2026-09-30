import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/attendee_identity.dart';
import '../../../services/auth_service.dart';
import '../../../services/offline_service.dart';
import '../../explore/data/event_cache_manager.dart';

/// Abstract contract for attendee ticket operations.
///
/// Strictly separates:
/// - GUEST DATA: tickets where `attendee_id = deviceId AND user_id IS NULL`.
/// - AUTHENTICATED USER DATA: tickets where `user_id = auth.uid()`.
abstract class TicketRepository {
  Future<List<Map<String, dynamic>>> getMyTickets();
  Future<ClaimTicketsResult> claimGuestTickets();
  Future<Map<String, dynamic>?> getGuestTicketByCode(String ticketCode);
}

/// Production implementation backed by Supabase with offline caching.
class TicketRepositoryImpl implements TicketRepository {
  final SupabaseClient _supabase;
  final EventCacheManager _cacheManager;
  final OfflineService _offlineService;

  TicketRepositoryImpl({
    SupabaseClient? supabase,
    EventCacheManager? cacheManager,
    OfflineService? offlineService,
  })  : _supabase = supabase ?? Supabase.instance.client,
        _cacheManager = cacheManager ?? EventCacheManager(),
        _offlineService = offlineService ?? OfflineService();

  @override
  Future<List<Map<String, dynamic>>> getMyTickets() async {
    final user = _supabase.auth.currentUser;
    final deviceId = AttendeeIdentity.deviceId;
    final isOnline = await _offlineService.checkConnectivity();

    if (!isOnline) {
      return _cacheManager.getCachedTickets(userId: user?.id);
    }

    try {
      List<dynamic> result;
      if (user != null) {
        // 1. Authenticated User: Query tickets owned by this user account via RLS
        result = await _supabase
            .from('tickets')
            .select('*, events(*)')
            .eq('user_id', user.id)
            .order('purchased_at', ascending: false)
            .timeout(const Duration(seconds: 4));
      } else if (deviceId != null) {
        // 2. Guest User: Query unclaimed tickets matching local device UUID
        result = await _supabase
            .from('tickets')
            .select('*, events(*)')
            .eq('attendee_id', deviceId)
            .isFilter('user_id', null)
            .order('purchased_at', ascending: false)
            .timeout(const Duration(seconds: 4));
      } else {
        return [];
      }

      final tickets = List<Map<String, dynamic>>.from(result);
      await _cacheManager.cacheTickets(tickets, userId: user?.id);
      _offlineService.reportSuccessfulOnlineRequest();
      return tickets;
    } catch (e) {
      debugPrint('Error fetching tickets online, falling back to cache: $e');
      _offlineService.reportFailedNetworkRequest();
      return _cacheManager.getCachedTickets(userId: user?.id);
    }
  }

  @override
  Future<ClaimTicketsResult> claimGuestTickets() async {
    return AuthService().claimGuestTickets();
  }

  @override
  Future<Map<String, dynamic>?> getGuestTicketByCode(String ticketCode) async {
    try {
      final response = await _supabase.rpc(
        'get_guest_ticket',
        params: {'p_ticket_code': ticketCode},
      ).timeout(const Duration(seconds: 4));

      if (response is Map<String, dynamic> && response['found'] == true) {
        return response['ticket'] as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching ticket via get_guest_ticket RPC: $e');
      return null;
    }
  }
}
