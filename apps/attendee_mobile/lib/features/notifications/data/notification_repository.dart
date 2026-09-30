import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../services/attendee_identity.dart';
import '../../../services/auth_service.dart';
import '../../../services/offline_service.dart';
import '../../explore/data/event_cache_manager.dart';
import '../models/notification_models.dart';

/// Abstract repository contract for attendee notifications.
///
/// Ensures clear separation between Flutter UI and backend/cache layers.
abstract class NotificationRepository {
  Stream<List<NotificationItem>> observeNotifications({String? eventId});
  Stream<int> observeUnreadCount({String? eventId});

  Future<List<NotificationItem>> getNotifications({String? eventId});
  Future<int> getUnreadCount({String? eventId});

  Future<void> markAsRead(String id, {String? eventId});
  Future<void> markAllAsRead({String? eventId});
  Future<void> dismissNotification(String id, {String? eventId});
  Future<void> addNotification(NotificationItem item);
  Future<void> refresh({String? eventId});
  Future<void> resetToDefaults();

  /// Realtime lifecycle management (Phase 7C)
  void subscribeToRealtime(String eventId);
  void unsubscribeRealtime();
  Future<void> clearUserScopedNotifications();
}

/// Production Supabase-backed Notification Repository with Realtime CDC,
/// offline cache resilience, and strict event/account partitioning.
class NotificationRepositoryImpl implements NotificationRepository {
  final SupabaseClient _supabase;
  final EventCacheManager _cacheManager;
  final OfflineService _offlineService;

  // Singleton instance to ensure uniform reactive state across screens
  static final NotificationRepositoryImpl _instance =
      NotificationRepositoryImpl._internal();
  factory NotificationRepositoryImpl({
    SupabaseClient? supabase,
    EventCacheManager? cacheManager,
    OfflineService? offlineService,
  }) {
    if (supabase != null || cacheManager != null || offlineService != null) {
      return NotificationRepositoryImpl._custom(
        supabase: supabase,
        cacheManager: cacheManager,
        offlineService: offlineService,
      );
    }
    return _instance;
  }

  NotificationRepositoryImpl._internal()
      : _supabase = Supabase.instance.client,
        _cacheManager = EventCacheManager(),
        _offlineService = OfflineService() {
    _initAuthListener();
  }

  NotificationRepositoryImpl._custom({
    SupabaseClient? supabase,
    EventCacheManager? cacheManager,
    OfflineService? offlineService,
  })  : _supabase = supabase ?? Supabase.instance.client,
        _cacheManager = cacheManager ?? EventCacheManager(),
        _offlineService = offlineService ?? OfflineService() {
    _initAuthListener();
  }

  final StreamController<List<NotificationItem>> _controller =
      StreamController<List<NotificationItem>>.broadcast();

  List<NotificationItem>? _cachedNotifications;
  Set<String> _readIds = {};
  Set<String> _dismissedIds = {};
  String? _currentPartitionId;
  String? _currentEventId;
  bool _initialized = false;

  // Single active Realtime channel
  RealtimeChannel? _realtimeChannel;
  String? _subscribedEventId;
  StreamSubscription? _authSubscription;

  void _initAuthListener() {
    _authSubscription?.cancel();
    _authSubscription = AuthService().onAuthStateChange.listen((_) {
      _handleAuthChange();
    });
  }

  String get _partitionId =>
      _supabase.auth.currentUser?.id ?? AttendeeIdentity.deviceId ?? 'guest';

  Future<void> _handleAuthChange() async {
    final newPartition = _partitionId;
    if (_currentPartitionId != newPartition) {
      unsubscribeRealtime();
      _cachedNotifications = null;
      _readIds.clear();
      _dismissedIds.clear();
      _initialized = false;
      _currentPartitionId = newPartition;
      await _ensureInitialized(eventId: _currentEventId);
    }
  }

  Future<void> _ensureInitialized({String? eventId}) async {
    final partition = _partitionId;
    final targetEvent = eventId ?? _currentEventId ?? 'global';

    if (_initialized &&
        _currentPartitionId == partition &&
        _currentEventId == targetEvent) {
      return;
    }

    _currentPartitionId = partition;
    _currentEventId = targetEvent;

    // Load partitioned read and dismissed IDs
    _readIds = await _cacheManager.getCachedReadNotificationIds(partition, targetEvent);
    _dismissedIds = await _cacheManager.getCachedDismissedNotificationIds(partition, targetEvent);

    await refresh(eventId: eventId);
    _initialized = true;
  }

  @override
  Future<void> refresh({String? eventId}) async {
    final partition = _partitionId;
    final effectiveEventId = eventId ?? _currentEventId ?? 'global';

    final isOnline = await _offlineService.checkConnectivity();
    if (!isOnline) {
      await _loadFromLocalCache(partition, effectiveEventId);
      return;
    }

    try {
      var query = _supabase
          .from('event_notifications')
          .select()
          .eq('is_active', true);

      if (eventId != null && eventId.isNotEmpty) {
        query = query.eq('event_id', eventId);
      }

      final response = await query
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 4));

      final currentUserId = _supabase.auth.currentUser?.id;
      final rawList = <Map<String, dynamic>>[];

      for (final row in response as List<dynamic>) {
        final r = Map<String, dynamic>.from(row as Map);
        final targetUserId = r['target_user_id']?.toString();
        // RLS / Target User Security Filter:
        // Broadcast notifications have null target_user_id.
        // Targeted notifications must match the current user.
        if (targetUserId == null || targetUserId == currentUserId) {
          rawList.add(r);
        }
      }

      // Persist raw list into partitioned offline cache
      await _cacheManager.cacheNotifications(partition, effectiveEventId, rawList);

      _processAndEmitNotifications(rawList);
    } catch (_) {
      // PostgREST or network failure: fallback to partitioned local cache (NO mock data)
      await _loadFromLocalCache(partition, effectiveEventId);
    }
  }

  Future<void> _loadFromLocalCache(String partition, String eventId) async {
    final cachedRows = await _cacheManager.getCachedNotifications(partition, eventId);
    _processAndEmitNotifications(cachedRows);
  }

  void _processAndEmitNotifications(List<Map<String, dynamic>> rawRows) {
    final processed = <NotificationItem>[];

    for (final row in rawRows) {
      final item = NotificationItem.fromMap(row);

      // Check dismissed filter
      if (_dismissedIds.contains(item.id)) continue;

      // Check read filter
      final isRead = item.isRead || _readIds.contains(item.id);
      processed.add(item.copyWith(isRead: isRead));
    }

    // Sort: unread first, then by timestamp descending
    processed.sort((a, b) {
      if (a.isRead != b.isRead) {
        return a.isRead ? 1 : -1;
      }
      return b.timestamp.compareTo(a.timestamp);
    });

    _cachedNotifications = processed;
    _controller.add(List.unmodifiable(_cachedNotifications!));
  }

  Future<void> _persistPartitionedState() async {
    final partition = _partitionId;
    final effectiveEventId = _currentEventId ?? 'global';
    await _cacheManager.cacheReadNotificationIds(partition, effectiveEventId, _readIds);
    await _cacheManager.cacheDismissedNotificationIds(partition, effectiveEventId, _dismissedIds);
  }

  @override
  void subscribeToRealtime(String eventId) {
    if (eventId.isEmpty) return;

    if (_subscribedEventId == eventId && _realtimeChannel != null) {
      return; // Already subscribed to this active event
    }

    // Single active channel enforcement: cleanup previous channel
    unsubscribeRealtime();
    _subscribedEventId = eventId;
    _currentEventId = eventId;

    try {
      _realtimeChannel = _supabase
          .channel('event_notifications:$eventId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'event_notifications',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'event_id',
              value: eventId,
            ),
            callback: (payload) {
              _handleRealtimeInsert(payload);
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('NotificationRepository: Realtime subscription failed: $e');
    }
  }

  void _handleRealtimeInsert(PostgresChangePayload payload) {
    try {
      final newRecord = Map<String, dynamic>.from(payload.newRecord);
      final eventId = newRecord['event_id']?.toString();
      if (_subscribedEventId != null && eventId != _subscribedEventId) {
        return; // Reject notifications belonging to another event
      }

      final targetUserId = newRecord['target_user_id']?.toString();
      final currentUserId = _supabase.auth.currentUser?.id;
      if (targetUserId != null && targetUserId != currentUserId) {
        return; // Reject notifications not addressed to this user
      }

      final newItem = NotificationItem.fromMap(newRecord);
      final currentList = List<NotificationItem>.from(_cachedNotifications ?? []);

      // Idempotent deduplication
      final existingIndex = currentList.indexWhere((n) => n.id == newItem.id);
      if (existingIndex >= 0) {
        return; // Already merged
      }

      currentList.insert(0, newItem);

      // Re-sort: unread first, timestamp descending
      currentList.sort((a, b) {
        if (a.isRead != b.isRead) {
          return a.isRead ? 1 : -1;
        }
        return b.timestamp.compareTo(a.timestamp);
      });

      _cachedNotifications = currentList;
      _controller.add(List.unmodifiable(_cachedNotifications!));

      // Asynchronously update partitioned cache
      final partition = _partitionId;
      final effectiveEventId = _subscribedEventId ?? 'global';
      _cacheManager.getCachedNotifications(partition, effectiveEventId).then((cached) {
        final updatedRaw = List<Map<String, dynamic>>.from(cached);
        if (!updatedRaw.any((r) => r['id']?.toString() == newItem.id)) {
          updatedRaw.insert(0, newRecord);
          _cacheManager.cacheNotifications(partition, effectiveEventId, updatedRaw);
        }
      });
    } catch (e) {
      debugPrint('NotificationRepository: Error handling Realtime insert: $e');
    }
  }

  @override
  void unsubscribeRealtime() {
    if (_realtimeChannel != null) {
      try {
        _realtimeChannel!.unsubscribe();
        _supabase.removeChannel(_realtimeChannel!);
      } catch (_) {}
      _realtimeChannel = null;
      _subscribedEventId = null;
    }
  }

  @override
  Stream<List<NotificationItem>> observeNotifications({String? eventId}) async* {
    await _ensureInitialized(eventId: eventId);
    if (eventId != null && eventId.isNotEmpty) {
      subscribeToRealtime(eventId);
    }
    yield _filterByEvent(_cachedNotifications ?? [], eventId);
    yield* _controller.stream.map((list) => _filterByEvent(list, eventId));
  }

  @override
  Stream<int> observeUnreadCount({String? eventId}) async* {
    await _ensureInitialized(eventId: eventId);
    yield _calculateUnread(_cachedNotifications ?? [], eventId);
    yield* _controller.stream.map((list) => _calculateUnread(list, eventId));
  }

  @override
  Future<List<NotificationItem>> getNotifications({String? eventId}) async {
    await _ensureInitialized(eventId: eventId);
    return _filterByEvent(_cachedNotifications ?? [], eventId);
  }

  @override
  Future<int> getUnreadCount({String? eventId}) async {
    await _ensureInitialized(eventId: eventId);
    return _calculateUnread(_cachedNotifications ?? [], eventId);
  }

  @override
  Future<void> markAsRead(String id, {String? eventId}) async {
    await _ensureInitialized(eventId: eventId);
    if (!_readIds.contains(id)) {
      _readIds.add(id);
      await _persistPartitionedState();
      _updateLocalReadStatus(id, true);
    }
  }

  @override
  Future<void> markAllAsRead({String? eventId}) async {
    await _ensureInitialized(eventId: eventId);
    final current = _filterByEvent(_cachedNotifications ?? [], eventId);
    for (final item in current) {
      _readIds.add(item.id);
    }
    await _persistPartitionedState();

    if (_cachedNotifications != null) {
      final updated = _cachedNotifications!.map((n) {
        if (eventId == null || n.eventId == null || n.eventId == eventId) {
          return n.copyWith(isRead: true);
        }
        return n;
      }).toList();
      _cachedNotifications = updated;
      _controller.add(List.unmodifiable(_cachedNotifications!));
    }
  }

  @override
  Future<void> dismissNotification(String id, {String? eventId}) async {
    await _ensureInitialized(eventId: eventId);
    _dismissedIds.add(id);
    await _persistPartitionedState();

    if (_cachedNotifications != null) {
      final updated = _cachedNotifications!.where((n) => n.id != id).toList();
      _cachedNotifications = updated;
      _controller.add(List.unmodifiable(_cachedNotifications!));
    }
  }

  void _updateLocalReadStatus(String id, bool isRead) {
    if (_cachedNotifications == null) return;
    final updated = _cachedNotifications!.map((item) {
      if (item.id == id) {
        return item.copyWith(isRead: isRead);
      }
      return item;
    }).toList();

    updated.sort((a, b) {
      if (a.isRead != b.isRead) {
        return a.isRead ? 1 : -1;
      }
      return b.timestamp.compareTo(a.timestamp);
    });

    _cachedNotifications = updated;
    _controller.add(List.unmodifiable(_cachedNotifications!));
  }

  @override
  Future<void> addNotification(NotificationItem item) async {
    await _ensureInitialized(eventId: item.eventId);
    final list = List<NotificationItem>.from(_cachedNotifications ?? []);
    if (!list.any((n) => n.id == item.id)) {
      list.insert(0, item);
      _cachedNotifications = list;
      _controller.add(List.unmodifiable(_cachedNotifications!));
    }
  }

  @override
  Future<void> clearUserScopedNotifications() async {
    unsubscribeRealtime();
    final partition = _partitionId;
    final eventId = _currentEventId ?? 'global';
    await _cacheManager.clearNotificationsCache(partition, eventId);
    _readIds.clear();
    _dismissedIds.clear();
    await _persistPartitionedState();
    _cachedNotifications = [];
    _controller.add(List.unmodifiable(_cachedNotifications!));
  }

  @override
  Future<void> resetToDefaults() async {
    unsubscribeRealtime();
    _readIds.clear();
    _dismissedIds.clear();
    await _persistPartitionedState();
    _cachedNotifications = null;
    await refresh();
  }

  List<NotificationItem> _filterByEvent(List<NotificationItem> list, String? eventId) {
    if (eventId == null || eventId.isEmpty) return list;
    return list.where((n) => n.eventId == null || n.eventId == eventId).toList();
  }

  int _calculateUnread(List<NotificationItem> list, String? eventId) {
    return _filterByEvent(list, eventId).where((n) => !n.isRead).length;
  }

  @visibleForTesting
  void dispose() {
    unsubscribeRealtime();
    _authSubscription?.cancel();
    _controller.close();
  }
}
