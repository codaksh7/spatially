import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/ticket_check_in_result.dart';
import '../models/offline_check_in_record.dart';
import '../services/observation_queue.dart';
import '../services/session_state.dart';

abstract class TicketCheckInRepository {
  /// Atomically checks in a ticket via the public.check_in_ticket RPC.
  /// If offline or network fails, automatically enqueues locally.
  Future<TicketCheckInResult> checkInTicket({
    required String ticketCode,
    required String eventId,
  });

  /// Flushes any locally queued offline ticket check-ins.
  Future<int> flushOfflineCheckIns();

  /// Gets the count of pending offline ticket check-ins.
  Future<int> getPendingCheckInsCount();
}

class TicketCheckInRepositoryImpl implements TicketCheckInRepository {
  final SupabaseClient _supabase;
  final ObservationQueue _queue;
  final _uuid = const Uuid();

  TicketCheckInRepositoryImpl({
    SupabaseClient? supabase,
    ObservationQueue? queue,
  })  : _supabase = supabase ?? Supabase.instance.client,
        _queue = queue ?? ObservationQueue();

  @override
  Future<TicketCheckInResult> checkInTicket({
    required String ticketCode,
    required String eventId,
  }) async {
    final currentVolunteerId = SessionState.instance.volunteerId;
    try {
      final response = await _supabase.rpc('check_in_ticket', params: {
        'p_ticket_code': ticketCode,
        'p_event_id': eventId,
        'p_volunteer_id': ?currentVolunteerId,
      });

      if (response is Map<String, dynamic>) {
        return TicketCheckInResult.fromRpc(response);
      }
      return TicketCheckInResult(
        success: false,
        errorCode: 'UNEXPECTED_RESPONSE',
        message: 'Invalid response from server.',
      );
    } catch (e) {
      print('TicketCheckInRepository: Network check-in failed, queueing offline: $e');

      // Enqueue offline check-in record
      final operationId = _uuid.v4();
      final record = OfflineCheckInRecord(
        operationId: operationId,
        ticketCode: ticketCode,
        eventId: eventId,
        volunteerId: currentVolunteerId,
        scannedAt: DateTime.now().toUtc(),
        syncStatus: 'pending',
      );

      await _queue.enqueueTicketCheckIn(record);

      return TicketCheckInResult.offlineQueued(
        ticketCode: ticketCode,
        eventId: eventId,
      );
    }
  }

  @override
  Future<int> flushOfflineCheckIns() async {
    final currentVolunteerId = SessionState.instance.volunteerId;
    final pending = await _queue.getPendingTicketCheckIns(volunteerId: currentVolunteerId);
    if (pending.isEmpty) return 0;

    int syncedCount = 0;
    for (final record in pending) {
      if (record.id == null) continue;
      try {
        final volunteerIdToPass = record.volunteerId ?? currentVolunteerId;
        final response = await _supabase.rpc('check_in_ticket', params: {
          'p_ticket_code': record.ticketCode,
          'p_event_id': record.eventId,
          'p_volunteer_id': ?volunteerIdToPass,
        });

        if (response is Map<String, dynamic> && response['success'] == true) {
          await _queue.updateTicketCheckInStatus(record.id!, 'synced');
          syncedCount++;
        } else {
          final error = response is Map<String, dynamic>
              ? response['message']?.toString()
              : 'Server check-in rejected';
          await _queue.updateTicketCheckInStatus(
            record.id!,
            'rejected',
            errorMessage: error,
          );
        }
      } catch (e) {
        print('TicketCheckInRepository: Failed to flush record ${record.operationId}: $e');
        // Stop on connection error; retry on next flush
        break;
      }
    }
    return syncedCount;
  }

  @override
  Future<int> getPendingCheckInsCount() async {
    return _queue.getPendingTicketCheckInCount(volunteerId: SessionState.instance.volunteerId);
  }
}
