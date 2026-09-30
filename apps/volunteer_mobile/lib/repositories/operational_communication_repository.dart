import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/operational_message.dart';
import '../models/volunteer_directory_entry.dart';
import '../services/observation_queue.dart';
import '../services/session_state.dart';

/// Exception thrown when an attempt is made to send an Urgent message while offline.
class OfflineUrgentMessageException implements Exception {
  final String message;
  const OfflineUrgentMessageException([this.message = 'Cannot send Urgent alert while offline. Connect to network or notify staff in person.']);

  @override
  String toString() => message;
}

abstract class OperationalCommunicationRepository {
  Future<List<OperationalMessage>> getMessages({
    required String eventId,
    int limit = 50,
    int offset = 0,
    String? filter, // 'all', 'broadcasts', 'direct', 'urgent'
  });

  Future<OperationalMessage> sendMessage({
    required String eventId,
    required OperationalTargetType targetType,
    required String body,
    String? targetId,
    String? zoneId,
    String messageType = 'operational',
    OperationalPriority priority = OperationalPriority.normal,
    bool requiresAcknowledgment = false,
  });

  Future<bool> acknowledgeMessage(String messageId);

  Future<void> markAsRead(List<String> messageIds);

  Future<List<VolunteerDirectoryEntry>> getVolunteerDirectory(String eventId);

  Stream<OperationalMessage> get messageStream;

  Stream<int> get unreadCountStream;

  void subscribeRealtime(String eventId);

  Future<void> unsubscribeRealtime();

  Future<int> flushPendingMessages();

  Future<void> clearAccountCache();
}

class OperationalCommunicationRepositoryImpl implements OperationalCommunicationRepository {
  final SupabaseClient _supabase;
  final ObservationQueue _queue;

  RealtimeChannel? _realtimeChannel;
  String? _subscribedEventId;

  final StreamController<OperationalMessage> _messageStreamController =
      StreamController<OperationalMessage>.broadcast();
  final StreamController<int> _unreadCountController =
      StreamController<int>.broadcast();

  int _cachedUnreadCount = 0;
  bool _isFlushingMessages = false;

  OperationalCommunicationRepositoryImpl({
    SupabaseClient? supabase,
    ObservationQueue? queue,
  })  : _supabase = supabase ?? Supabase.instance.client,
        _queue = queue ?? ObservationQueue();

  @override
  Stream<OperationalMessage> get messageStream => _messageStreamController.stream;

  @override
  Stream<int> get unreadCountStream => _unreadCountController.stream;

  String? get _currentUserId => SessionState.instance.volunteerId ?? _supabase.auth.currentUser?.id;

  // ---------------------------------------------------------------------------
  // Message Fetching & Offline-First Merge
  // ---------------------------------------------------------------------------

  @override
  Future<List<OperationalMessage>> getMessages({
    required String eventId,
    int limit = 50,
    int offset = 0,
    String? filter,
  }) async {
    final userId = _currentUserId;

    // Check connectivity
    final connectivity = await Connectivity().checkConnectivity();
    final isOnline = connectivity.any((c) => c != ConnectivityResult.none);

    List<OperationalMessage> remoteMessages = [];

    if (isOnline) {
      try {
        var query = _supabase
            .from('operational_messages')
            .select('''
              *,
              receipts:operational_message_receipts(
                recipient_id,
                status,
                read_at,
                acknowledged_at
              )
            ''')
            .eq('event_id', eventId)
            .order('created_at', ascending: false)
            .range(offset, offset + limit - 1);

        final List<dynamic> response = await query;
        remoteMessages = response.map((json) {
          return OperationalMessage.fromJson(
            json as Map<String, dynamic>,
            currentUserId: userId,
          );
        }).toList();

        // Cache remote messages to SQLite asynchronously
        unawaited(_cacheMessagesLocally(eventId, remoteMessages));
      } catch (e) {
        debugPrint('OperationalCommsRepo: Network query failed, falling back to local cache: $e');
        remoteMessages = await _loadLocalCachedMessages(eventId);
      }
    } else {
      remoteMessages = await _loadLocalCachedMessages(eventId);
    }

    // Merge with any locally queued messages for this event
    final queuedMessages = await _loadLocallyQueuedMessages(eventId);
    final allMessages = [...queuedMessages, ...remoteMessages];

    // Filter by tab if specified
    List<OperationalMessage> filtered = allMessages;
    if (filter == 'broadcasts') {
      filtered = allMessages.where((m) => m.isBroadcast).toList();
    } else if (filter == 'direct') {
      filtered = allMessages.where((m) => m.isDirect || m.isOrganizerChannel).toList();
    } else if (filter == 'urgent') {
      filtered = allMessages.where((m) => m.isUrgent).toList();
    }

    // Calculate unread count
    final unread = allMessages.where((m) => !m.isRead && m.senderId != userId).length;
    _cachedUnreadCount = unread;
    if (!_unreadCountController.isClosed) {
      _unreadCountController.add(unread);
    }

    return filtered;
  }

  Future<void> _cacheMessagesLocally(String eventId, List<OperationalMessage> messages) async {
    final userId = _currentUserId;
    if (userId == null) return;

    try {
      final db = await _queue.getDb();
      final batch = db.batch();
      for (final msg in messages) {
        batch.insert(
          'cached_operational_messages',
          {
            'id': msg.id,
            'event_id': eventId,
            'payload_json': jsonEncode(msg.toJson()),
            'created_at': msg.createdAt.toIso8601String(),
            'volunteer_id': userId,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    } catch (e) {
      debugPrint('OperationalCommsRepo: Error caching messages locally: $e');
    }
  }

  Future<List<OperationalMessage>> _loadLocalCachedMessages(String eventId) async {
    final userId = _currentUserId;
    if (userId == null) return [];

    try {
      final db = await _queue.getDb();
      final rows = await db.query(
        'cached_operational_messages',
        where: 'event_id = ? AND volunteer_id = ?',
        whereArgs: [eventId, userId],
        orderBy: 'created_at DESC',
        limit: 100,
      );

      return rows.map((r) {
        final payload = jsonDecode(r['payload_json'] as String) as Map<String, dynamic>;
        return OperationalMessage.fromJson(payload, currentUserId: userId);
      }).toList();
    } catch (e) {
      debugPrint('OperationalCommsRepo: Error loading local cached messages: $e');
      return [];
    }
  }

  Future<List<OperationalMessage>> _loadLocallyQueuedMessages(String eventId) async {
    final userId = _currentUserId;
    if (userId == null) return [];

    try {
      final db = await _queue.getDb();
      final rows = await db.query(
        'pending_operational_messages',
        where: 'event_id = ? AND volunteer_id = ? AND sync_status = ?',
        whereArgs: [eventId, userId, 'pending'],
        orderBy: 'created_at DESC',
      );

      return rows.map((r) {
        return OperationalMessage(
          id: r['local_id'] as String,
          eventId: r['event_id'] as String,
          senderId: userId,
          senderRole: SessionState.instance.userRole ?? 'volunteer',
          senderName: 'Me',
          targetType: OperationalTargetType.fromString(r['target_type'] as String?),
          targetId: r['target_id'] as String?,
          zoneId: r['zone_id'] as String?,
          messageType: r['message_type'] as String? ?? 'operational',
          priority: OperationalPriority.fromString(r['priority'] as String?),
          body: r['body'] as String? ?? '',
          requiresAcknowledgment: (r['requires_acknowledgment'] as int? ?? 0) == 1,
          createdAt: DateTime.parse(r['created_at'] as String),
          receiptStatus: MessageLifecycleStatus.queued,
          isLocalQueued: true,
        );
      }).toList();
    } catch (e) {
      debugPrint('OperationalCommsRepo: Error loading locally queued messages: $e');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Message Sending with Honest Offline Queueing
  // ---------------------------------------------------------------------------

  @override
  Future<OperationalMessage> sendMessage({
    required String eventId,
    required OperationalTargetType targetType,
    required String body,
    String? targetId,
    String? zoneId,
    String messageType = 'operational',
    OperationalPriority priority = OperationalPriority.normal,
    bool requiresAcknowledgment = false,
  }) async {
    final userId = _currentUserId;
    if (userId == null) {
      throw Exception('Cannot send message: Not authenticated.');
    }

    final trimmedBody = body.trim();
    if (trimmedBody.isEmpty || trimmedBody.length > 1000) {
      throw Exception('Message body must be between 1 and 1000 characters.');
    }

    final connectivity = await Connectivity().checkConnectivity();
    final isOnline = connectivity.any((c) => c != ConnectivityResult.none);

    // If completely offline:
    if (!isOnline) {
      // Urgent messages MUST NOT give false confidence when offline
      if (priority == OperationalPriority.urgent) {
        throw const OfflineUrgentMessageException();
      }

      // Normal and important messages are queued with clear indicator
      final queuedMsg = await _enqueueMessageLocally(
        eventId: eventId,
        userId: userId,
        targetType: targetType,
        body: trimmedBody,
        targetId: targetId,
        zoneId: zoneId,
        messageType: messageType,
        priority: priority,
        requiresAcknowledgment: requiresAcknowledgment,
      );

      if (!_messageStreamController.isClosed) {
        _messageStreamController.add(queuedMsg);
      }
      return queuedMsg;
    }

    // When online, call atomic RPC
    try {
      final response = await _supabase.rpc('send_operational_message', params: {
        'p_event_id': eventId,
        'p_target_type': targetType.value,
        'p_body': trimmedBody,
        'p_target_id': targetId,
        'p_zone_id': zoneId,
        'p_message_type': messageType,
        'p_priority': priority.value,
        'p_requires_acknowledgment': requiresAcknowledgment,
      });

      if (response is Map<String, dynamic> && response['success'] == true) {
        final newMsg = OperationalMessage(
          id: response['message_id'] as String,
          eventId: eventId,
          senderId: userId,
          senderRole: response['sender_role'] as String? ?? 'volunteer',
          senderName: response['sender_name'] as String? ?? 'Me',
          targetType: targetType,
          targetId: targetId,
          zoneId: zoneId,
          messageType: messageType,
          priority: priority,
          body: trimmedBody,
          requiresAcknowledgment: requiresAcknowledgment,
          createdAt: DateTime.now(),
          receiptStatus: MessageLifecycleStatus.sent,
          isLocalQueued: false,
        );

        // Cache the newly sent message
        unawaited(_cacheMessagesLocally(eventId, [newMsg]));

        if (!_messageStreamController.isClosed) {
          _messageStreamController.add(newMsg);
        }
        return newMsg;
      } else {
        final errorMsg = response is Map<String, dynamic>
            ? response['message']?.toString() ?? 'Server rejected message'
            : 'Unknown server error';
        throw Exception(errorMsg);
      }
    } catch (e) {
      if (e is OfflineUrgentMessageException) rethrow;

      debugPrint('OperationalCommsRepo: Send failed over network: $e');
      if (priority == OperationalPriority.urgent) {
        throw OfflineUrgentMessageException('Failed to deliver Urgent alert: $e');
      }

      // Fallback: enqueue locally
      final queuedMsg = await _enqueueMessageLocally(
        eventId: eventId,
        userId: userId,
        targetType: targetType,
        body: trimmedBody,
        targetId: targetId,
        zoneId: zoneId,
        messageType: messageType,
        priority: priority,
        requiresAcknowledgment: requiresAcknowledgment,
      );

      if (!_messageStreamController.isClosed) {
        _messageStreamController.add(queuedMsg);
      }
      return queuedMsg;
    }
  }

  Future<OperationalMessage> _enqueueMessageLocally({
    required String eventId,
    required String userId,
    required OperationalTargetType targetType,
    required String body,
    String? targetId,
    String? zoneId,
    required String messageType,
    required OperationalPriority priority,
    required bool requiresAcknowledgment,
  }) async {
    final localId = 'local_${DateTime.now().millisecondsSinceEpoch}_${userId.substring(0, 4)}';
    final now = DateTime.now();

    final db = await _queue.getDb();
    await db.insert('pending_operational_messages', {
      'local_id': localId,
      'event_id': eventId,
      'volunteer_id': userId,
      'target_type': targetType.value,
      'target_id': targetId,
      'zone_id': zoneId,
      'message_type': messageType,
      'priority': priority.value,
      'body': body,
      'requires_acknowledgment': requiresAcknowledgment ? 1 : 0,
      'created_at': now.toIso8601String(),
      'sync_status': 'pending',
    });

    return OperationalMessage(
      id: localId,
      eventId: eventId,
      senderId: userId,
      senderRole: SessionState.instance.userRole ?? 'volunteer',
      senderName: 'Me',
      targetType: targetType,
      targetId: targetId,
      zoneId: zoneId,
      messageType: messageType,
      priority: priority,
      body: body,
      requiresAcknowledgment: requiresAcknowledgment,
      createdAt: now,
      receiptStatus: MessageLifecycleStatus.queued,
      isLocalQueued: true,
    );
  }

  // ---------------------------------------------------------------------------
  // Acknowledgment & Read Operations
  // ---------------------------------------------------------------------------

  @override
  Future<bool> acknowledgeMessage(String messageId) async {
    try {
      final response = await _supabase.rpc('acknowledge_operational_message', params: {
        'p_message_id': messageId,
      });

      if (response is Map<String, dynamic> && response['success'] == true) {
        if (_cachedUnreadCount > 0) {
          _cachedUnreadCount--;
          if (!_unreadCountController.isClosed) {
            _unreadCountController.add(_cachedUnreadCount);
          }
        }
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('OperationalCommsRepo: Error acknowledging message: $e');
      return false;
    }
  }

  @override
  Future<void> markAsRead(List<String> messageIds) async {
    if (messageIds.isEmpty) return;
    try {
      await _supabase.rpc('mark_operational_messages_read', params: {
        'p_message_ids': messageIds,
      });
    } catch (e) {
      debugPrint('OperationalCommsRepo: Error marking messages read: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Event Staff Directory
  // ---------------------------------------------------------------------------

  @override
  Future<List<VolunteerDirectoryEntry>> getVolunteerDirectory(String eventId) async {
    try {
      final response = await _supabase.rpc('get_event_volunteer_directory', params: {
        'p_event_id': eventId,
      });

      if (response is List) {
        return response
            .map((json) => VolunteerDirectoryEntry.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('OperationalCommsRepo: Error fetching volunteer directory: $e');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Supabase Realtime Lifecycle Management
  // ---------------------------------------------------------------------------

  @override
  void subscribeRealtime(String eventId) {
    if (_subscribedEventId == eventId && _realtimeChannel != null) {
      return; // Already subscribed to this event
    }

    unsubscribeRealtime();
    _subscribedEventId = eventId;

    try {
      _realtimeChannel = _supabase
          .channel('operational_comms_$eventId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'operational_messages',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'event_id',
              value: eventId,
            ),
            callback: (payload) {
              final newRecord = payload.newRecord;
              final msg = OperationalMessage.fromJson(newRecord, currentUserId: _currentUserId);

              // Update unread count if message is not from self
              if (msg.senderId != _currentUserId) {
                _cachedUnreadCount++;
                if (!_unreadCountController.isClosed) {
                  _unreadCountController.add(_cachedUnreadCount);
                }
              }

              if (!_messageStreamController.isClosed) {
                _messageStreamController.add(msg);
              }
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'operational_message_receipts',
            callback: (payload) {
              // Receipts update: triggers UI refresh if needed
              debugPrint('OperationalCommsRepo: Receipt state updated.');
            },
          )
          .subscribe();
      debugPrint('OperationalCommsRepo: Subscribed to Realtime for event $eventId');
    } catch (e) {
      debugPrint('OperationalCommsRepo: Realtime subscription failed: $e');
    }
  }

  @override
  Future<void> unsubscribeRealtime() async {
    if (_realtimeChannel != null) {
      try {
        await _supabase.removeChannel(_realtimeChannel!);
        debugPrint('OperationalCommsRepo: Unsubscribed Realtime channel for $_subscribedEventId');
      } catch (e) {
        debugPrint('OperationalCommsRepo: Error removing Realtime channel: $e');
      }
      _realtimeChannel = null;
      _subscribedEventId = null;
    }
  }

  // ---------------------------------------------------------------------------
  // Queue Flush for Outgoing Messages
  // ---------------------------------------------------------------------------

  @override
  Future<int> flushPendingMessages() async {
    if (_isFlushingMessages) return 0;
    _isFlushingMessages = true;

    int flushed = 0;
    try {
      final userId = _currentUserId;
      if (userId == null) return 0;

      final db = await _queue.getDb();
      final pendingRows = await db.query(
        'pending_operational_messages',
        where: 'volunteer_id = ? AND sync_status = ?',
        whereArgs: [userId, 'pending'],
        orderBy: 'created_at ASC',
      );

      if (pendingRows.isEmpty) return 0;

      debugPrint('OperationalCommsRepo: Flushing ${pendingRows.length} queued operational message(s).');

      for (final row in pendingRows) {
        try {
          final response = await _supabase.rpc('send_operational_message', params: {
            'p_event_id': row['event_id'],
            'p_target_type': row['target_type'],
            'p_body': row['body'],
            'p_target_id': row['target_id'],
            'p_zone_id': row['zone_id'],
            'p_message_type': row['message_type'],
            'p_priority': row['priority'],
            'p_requires_acknowledgment': (row['requires_acknowledgment'] as int) == 1,
          });

          if (response is Map<String, dynamic> && response['success'] == true) {
            await db.delete(
              'pending_operational_messages',
              where: 'id = ?',
              whereArgs: [row['id']],
            );
            flushed++;
          } else {
            final error = response is Map<String, dynamic>
                ? response['message']?.toString()
                : 'Server rejected message';
            await db.update(
              'pending_operational_messages',
              {'sync_status': 'rejected', 'error_message': error},
              where: 'id = ?',
              whereArgs: [row['id']],
            );
          }
        } catch (e) {
          debugPrint('OperationalCommsRepo: Network error flushing queued message: $e');
          break; // Stop loop on network disconnect
        }
      }
    } finally {
      _isFlushingMessages = false;
    }
    return flushed;
  }

  @override
  Future<void> clearAccountCache() async {
    await unsubscribeRealtime();
    _cachedUnreadCount = 0;
    if (!_unreadCountController.isClosed) {
      _unreadCountController.add(0);
    }
    debugPrint('OperationalCommsRepo: Account cache and Realtime subscriptions cleared.');
  }
}
