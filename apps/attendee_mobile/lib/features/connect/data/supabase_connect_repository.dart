import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/auth_service.dart';
import '../../profile/data/profile_repository.dart';
import '../models/connect_models.dart';
import 'connect_mock_data.dart';
import 'connect_repository.dart';

/// Production Supabase-backed implementation of [ConnectRepository].
///
/// Features:
/// - Real PostgREST queries and RPC operations.
/// - Event-scoped attendee discovery and ticket authorization.
/// - Realtime PostgreSQL CDC subscription on `temporary_chat_messages` and `attendee_connections`.
/// - Automatic account-scoped session cleanup on logout / sign-in.
/// - Full decoupling: UI remains 100% free of raw Supabase calls.
class SupabaseConnectRepositoryImpl implements ConnectRepository {
  final SupabaseClient _supabase;
  final AuthService _authService;
  final ProfileRepository _profileRepository;
  final StreamController<void> _updatesController = StreamController<void>.broadcast();

  // Active Realtime channels
  RealtimeChannel? _connectionsChannel;
  final Map<String, RealtimeChannel> _chatChannels = {};

  // In-memory cache for fast UI lookups during an active session
  final Map<String, Connection> _connectionsCache = {};
  String? _subscribedUserId;

  SupabaseConnectRepositoryImpl({
    SupabaseClient? supabase,
    AuthService? authService,
    ProfileRepository? profileRepository,
  })  : _supabase = supabase ?? Supabase.instance.client,
        _authService = authService ?? AuthService(),
        _profileRepository = profileRepository ?? ProfileRepositoryImpl() {
    _initAuthListener();
  }

  void _initAuthListener() {
    _authService.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedOut) {
        clearSession();
      } else if (data.event == AuthChangeEvent.signedIn ||
          data.event == AuthChangeEvent.tokenRefreshed) {
        _ensureRealtimeConnectionsSub();
      }
    });
    _ensureRealtimeConnectionsSub();
  }

  void _ensureRealtimeConnectionsSub() {
    final currentUserId = _authService.currentUserId;
    if (currentUserId == null || currentUserId == _subscribedUserId) return;

    _connectionsChannel?.unsubscribe();
    _subscribedUserId = currentUserId;

    try {
      _connectionsChannel = _supabase
          .channel('public:attendee_connections:$currentUserId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'attendee_connections',
            callback: (payload) {
              _notify();
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Error subscribing to connections realtime: $e');
    }
  }

  @override
  Stream<void> get updatesStream => _updatesController.stream;

  void _notify() {
    if (!_updatesController.isClosed) {
      _updatesController.add(null);
    }
  }

  @override
  Future<void> clearSession() async {
    _connectionsCache.clear();
    _subscribedUserId = null;

    try {
      await _connectionsChannel?.unsubscribe();
      _connectionsChannel = null;
    } catch (_) {}

    for (final channel in _chatChannels.values) {
      try {
        await channel.unsubscribe();
      } catch (_) {}
    }
    _chatChannels.clear();
    _notify();
  }

  @override
  Future<List<ConnectProfile>> getDiscoverableAttendees(String eventId) async {
    final currentUserId = _authService.currentUserId;
    if (currentUserId == null) return [];

    try {
      final response = await _supabase.rpc(
        'get_discoverable_attendees',
        params: {
          'p_event_id': eventId,
          'p_limit': 50,
          'p_offset': 0,
        },
      ).timeout(const Duration(seconds: 6));

      if (response is List) {
        final profiles = <ConnectProfile>[];
        for (final item in response) {
          if (item is Map) {
            final map = Map<String, dynamic>.from(item);
            final profile = ConnectProfile(
              id: map['id']?.toString() ?? '',
              displayName: map['displayName']?.toString() ?? 'Attendee',
              headline: map['headline']?.toString() ?? '',
              bio: map['bio']?.toString() ?? '',
              interests: (map['interests'] as List<dynamic>?)
                      ?.map((e) => e.toString())
                      .toList() ??
                  [],
              locationNote: map['locationNote']?.toString() ?? '',
              isReadyToChat: map['isReadyToChat'] as bool? ?? true,
              avatarInitials: map['avatarInitials']?.toString() ?? 'A',
            );
            profiles.add(profile);

            // Populate connection cache if connection exists
            final connId = map['connectionId']?.toString();
            final statusStr = map['connectionStatus']?.toString();
            if (connId != null && connId.isNotEmpty && statusStr != null) {
              final status = _parseStatus(statusStr);
              _connectionsCache[connId] = Connection(
                id: connId,
                eventId: eventId,
                peerProfile: profile,
                status: status,
                createdAt: DateTime.now(),
              );
            }
          }
        }
        return profiles;
      }
    } catch (e) {
      debugPrint('Error fetching discoverable attendees: $e');
    }
    return [];
  }

  @override
  Future<List<Connection>> getConnections(String eventId) async {
    final currentUserId = _authService.currentUserId;
    if (currentUserId == null) return [];

    try {
      final response = await _supabase
          .from('attendee_connections')
          .select('''
            id,
            event_id,
            requester_id,
            addressee_id,
            status,
            created_at,
            updated_at,
            requester:profiles!requester_id(id, full_name, headline, bio, interests, location_note, networking_opt_in),
            addressee:profiles!addressee_id(id, full_name, headline, bio, interests, location_note, networking_opt_in)
          ''')
          .eq('event_id', eventId)
          .or('requester_id.eq.$currentUserId,addressee_id.eq.$currentUserId')
          .order('updated_at', ascending: false)
          .timeout(const Duration(seconds: 6));

      final connections = <Connection>[];

      for (final row in response as List<dynamic>) {
        final r = Map<String, dynamic>.from(row as Map);
        final connId = r['id']?.toString() ?? '';
        final requesterId = r['requester_id']?.toString() ?? '';
        final isOutbound = requesterId == currentUserId;

        // Peer is the other side of the connection
        final peerMapRaw = isOutbound ? r['addressee'] : r['requester'];
        if (peerMapRaw == null || peerMapRaw is! Map) continue;
        final peerMap = Map<String, dynamic>.from(peerMapRaw);

        final peerProfile = ConnectProfile(
          id: peerMap['id']?.toString() ?? '',
          displayName: peerMap['full_name']?.toString() ?? 'Attendee',
          headline: peerMap['headline']?.toString() ?? '',
          bio: peerMap['bio']?.toString() ?? '',
          interests: (peerMap['interests'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [],
          locationNote: peerMap['location_note']?.toString() ?? '',
          isReadyToChat: peerMap['networking_opt_in'] as bool? ?? true,
          avatarInitials: _deriveInitials(peerMap['full_name']?.toString() ?? ''),
        );

        final rawStatus = r['status']?.toString();
        ConnectionStatus status = ConnectionStatus.none;
        if (rawStatus == 'pending') {
          status = isOutbound
              ? ConnectionStatus.requestSent
              : ConnectionStatus.requestReceived;
        } else if (rawStatus == 'accepted') {
          status = ConnectionStatus.connected;
        } else if (rawStatus == 'declined') {
          status = ConnectionStatus.declined;
        } else if (rawStatus == 'cancelled') {
          continue; // Do not display cancelled requests
        }

        // Fetch last message for this connection
        String? lastMsg;
        DateTime? lastMsgTime;
        try {
          final msgRow = await _supabase
              .from('temporary_chat_messages')
              .select('message_text, created_at')
              .eq('connection_id', connId)
              .order('created_at', ascending: false)
              .limit(1)
              .maybeSingle();

          if (msgRow != null) {
            lastMsg = msgRow['message_text']?.toString();
            lastMsgTime = DateTime.tryParse(msgRow['created_at']?.toString() ?? '');
          }
        } catch (_) {}

        final conn = Connection(
          id: connId,
          eventId: eventId,
          peerProfile: peerProfile,
          status: status,
          createdAt: DateTime.tryParse(r['created_at']?.toString() ?? '') ?? DateTime.now(),
          lastMessage: lastMsg ?? (status == ConnectionStatus.connected ? 'Connected for this event' : null),
          lastMessageTime: lastMsgTime,
        );

        connections.add(conn);
        _connectionsCache[connId] = conn;
      }

      return connections;
    } catch (e) {
      debugPrint('Error fetching connections: $e');
    }
    return [];
  }

  @override
  Future<Connection?> getConnectionForPeer(String eventId, String peerId) async {
    final currentUserId = _authService.currentUserId;
    if (currentUserId == null) return null;

    // Check cache first
    for (final c in _connectionsCache.values) {
      if (c.eventId == eventId && c.peerProfile.id == peerId) {
        return c;
      }
    }

    try {
      final response = await _supabase
          .from('attendee_connections')
          .select('''
            id,
            event_id,
            requester_id,
            addressee_id,
            status,
            created_at,
            updated_at,
            requester:profiles!requester_id(id, full_name, headline, bio, interests, location_note, networking_opt_in),
            addressee:profiles!addressee_id(id, full_name, headline, bio, interests, location_note, networking_opt_in)
          ''')
          .eq('event_id', eventId)
          .or('and(requester_id.eq.$currentUserId,addressee_id.eq.$peerId),and(requester_id.eq.$peerId,addressee_id.eq.$currentUserId)')
          .maybeSingle()
          .timeout(const Duration(seconds: 4));

      if (response != null) {
        final r = Map<String, dynamic>.from(response);
        final connId = r['id']?.toString() ?? '';
        final requesterId = r['requester_id']?.toString() ?? '';
        final isOutbound = requesterId == currentUserId;

        final peerMapRaw = isOutbound ? r['addressee'] : r['requester'];
        if (peerMapRaw != null && peerMapRaw is Map) {
          final peerMap = Map<String, dynamic>.from(peerMapRaw);
          final peerProfile = ConnectProfile(
            id: peerMap['id']?.toString() ?? '',
            displayName: peerMap['full_name']?.toString() ?? 'Attendee',
            headline: peerMap['headline']?.toString() ?? '',
            bio: peerMap['bio']?.toString() ?? '',
            interests: (peerMap['interests'] as List<dynamic>?)
                    ?.map((e) => e.toString())
                    .toList() ??
                [],
            locationNote: peerMap['location_note']?.toString() ?? '',
            isReadyToChat: peerMap['networking_opt_in'] as bool? ?? true,
            avatarInitials: _deriveInitials(peerMap['full_name']?.toString() ?? ''),
          );

          final rawStatus = r['status']?.toString();
          ConnectionStatus status = ConnectionStatus.none;
          if (rawStatus == 'pending') {
            status = isOutbound
                ? ConnectionStatus.requestSent
                : ConnectionStatus.requestReceived;
          } else if (rawStatus == 'accepted') {
            status = ConnectionStatus.connected;
          } else if (rawStatus == 'declined') {
            status = ConnectionStatus.declined;
          }

          final conn = Connection(
            id: connId,
            eventId: eventId,
            peerProfile: peerProfile,
            status: status,
            createdAt: DateTime.tryParse(r['created_at']?.toString() ?? '') ?? DateTime.now(),
          );
          _connectionsCache[connId] = conn;
          return conn;
        }
      }
    } catch (e) {
      debugPrint('Error getting connection for peer: $e');
    }
    return null;
  }

  @override
  Future<Connection> sendConnectionRequest(String eventId, String peerId) async {
    final currentUserId = _authService.currentUserId;
    if (currentUserId == null) {
      throw StateError('Authentication required to send connection request');
    }

    try {
      final response = await _supabase.rpc(
        'send_connection_request',
        params: {
          'p_event_id': eventId,
          'p_peer_id': peerId,
        },
      ).timeout(const Duration(seconds: 6));

      if (response is Map) {
        final connId = response['connection_id']?.toString() ?? '';
        final statusStr = response['status']?.toString() ?? 'requestSent';
        final status = _parseStatus(statusStr);

        final peerConn = await getConnectionForPeer(eventId, peerId);
        if (peerConn != null) {
          final updated = peerConn.copyWith(status: status);
          _connectionsCache[connId] = updated;
          _notify();
          return updated;
        }

        // Fallback placeholder if peer profile fetch delayed
        final newConn = Connection(
          id: connId,
          eventId: eventId,
          peerProfile: ConnectProfile(
            id: peerId,
            displayName: 'Attendee',
            avatarInitials: 'A',
          ),
          status: status,
          createdAt: DateTime.now(),
        );
        _connectionsCache[connId] = newConn;
        _notify();
        return newConn;
      }
    } on PostgrestException catch (e) {
      debugPrint('PostgrestException sending connection request: ${e.message}');
      throw StateError(e.message);
    } catch (e) {
      debugPrint('Error sending connection request: $e');
      rethrow;
    }
    throw StateError('Failed to send connection request');
  }

  @override
  Future<Connection> acceptConnectionRequest(String connectionId) async {
    try {
      final response = await _supabase.rpc(
        'respond_to_connection_request',
        params: {
          'p_connection_id': connectionId,
          'p_accept': true,
        },
      ).timeout(const Duration(seconds: 6));

      if (response is Map) {
        final existing = _connectionsCache[connectionId];
        if (existing != null) {
          final updated = existing.copyWith(
            status: ConnectionStatus.connected,
            lastMessage: 'Connected for this event',
            lastMessageTime: DateTime.now(),
          );
          _connectionsCache[connectionId] = updated;
          _notify();
          return updated;
        }
      }
    } on PostgrestException catch (e) {
      debugPrint('PostgrestException accepting connection: ${e.message}');
      throw StateError(e.message);
    } catch (e) {
      debugPrint('Error accepting connection request: $e');
      rethrow;
    }

    final refreshed = _connectionsCache[connectionId];
    if (refreshed != null) return refreshed;
    throw StateError('Connection not found after acceptance');
  }

  @override
  Future<void> declineConnectionRequest(String connectionId) async {
    try {
      await _supabase.rpc(
        'respond_to_connection_request',
        params: {
          'p_connection_id': connectionId,
          'p_accept': false,
        },
      ).timeout(const Duration(seconds: 6));

      final existing = _connectionsCache[connectionId];
      if (existing != null) {
        _connectionsCache[connectionId] = existing.copyWith(
          status: ConnectionStatus.declined,
        );
      }
      _notify();
    } catch (e) {
      debugPrint('Error declining connection request: $e');
    }
  }

  @override
  Future<Connection> simulatePeerAcceptance(String connectionId) async {
    // Development / demo helper - in production environment, forwards to accept
    return acceptConnectionRequest(connectionId);
  }

  @override
  Future<List<ChatMessage>> getMessages(String connectionId) async {
    final currentUserId = _authService.currentUserId;
    if (currentUserId == null) return [];

    // Ensure Realtime subscription active for this specific chat
    _subscribeToChatRealtime(connectionId);

    try {
      final response = await _supabase
          .from('temporary_chat_messages')
          .select('''
            id,
            connection_id,
            event_id,
            sender_id,
            message_text,
            meeting_poi_id,
            created_at,
            meeting_poi:venue_pois(id, name, description, zone_id, category)
          ''')
          .eq('connection_id', connectionId)
          .order('created_at', ascending: true)
          .timeout(const Duration(seconds: 6));

      final messages = <ChatMessage>[];

      for (final row in response as List<dynamic>) {
        final r = Map<String, dynamic>.from(row as Map);
        final senderId = r['sender_id']?.toString() ?? '';
        final isFromMe = senderId == currentUserId;

        MeetingPoint? meetingPoint;
        if (r['meeting_poi'] != null && r['meeting_poi'] is Map) {
          final poi = Map<String, dynamic>.from(r['meeting_poi'] as Map);
          meetingPoint = MeetingPoint(
            id: poi['id']?.toString() ?? '',
            title: poi['name']?.toString() ?? 'Meeting Point',
            subtitle: poi['description']?.toString() ?? poi['category']?.toString() ?? '',
            zoneId: poi['zone_id']?.toString(),
            poiId: poi['id']?.toString(),
          );
        }

        messages.add(
          ChatMessage(
            id: r['id']?.toString() ?? '',
            connectionId: connectionId,
            senderId: senderId,
            isFromMe: isFromMe,
            text: r['message_text']?.toString() ?? '',
            timestamp: DateTime.tryParse(r['created_at']?.toString() ?? '') ?? DateTime.now(),
            meetingPoint: meetingPoint,
          ),
        );
      }

      return messages;
    } catch (e) {
      debugPrint('Error fetching chat messages: $e');
    }
    return [];
  }

  void _subscribeToChatRealtime(String connectionId) {
    if (_chatChannels.containsKey(connectionId)) return;

    try {
      final channel = _supabase
          .channel('chat:$connectionId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'temporary_chat_messages',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'connection_id',
              value: connectionId,
            ),
            callback: (payload) {
              _notify();
            },
          )
          .subscribe();

      _chatChannels[connectionId] = channel;
    } catch (e) {
      debugPrint('Error subscribing to chat realtime for $connectionId: $e');
    }
  }

  @override
  Future<ChatMessage> sendMessage({
    required String connectionId,
    required String text,
    MeetingPoint? meetingPoint,
  }) async {
    final currentUserId = _authService.currentUserId;
    if (currentUserId == null) {
      throw StateError('Authentication required to send chat messages');
    }

    try {
      final response = await _supabase.rpc(
        'send_chat_message',
        params: {
          'p_connection_id': connectionId,
          'p_message_text': text,
          'p_meeting_poi_id': meetingPoint?.poiId ?? meetingPoint?.id,
        },
      ).timeout(const Duration(seconds: 6));

      if (response is Map) {
        final r = Map<String, dynamic>.from(response);
        final message = ChatMessage(
          id: r['id']?.toString() ?? '',
          connectionId: connectionId,
          senderId: currentUserId,
          isFromMe: true,
          text: r['text']?.toString() ?? text,
          timestamp: DateTime.tryParse(r['timestamp']?.toString() ?? '') ?? DateTime.now(),
          meetingPoint: meetingPoint,
        );

        // Update connection in cache
        final existing = _connectionsCache[connectionId];
        if (existing != null) {
          _connectionsCache[connectionId] = existing.copyWith(
            lastMessage: meetingPoint != null ? 'Suggested meeting: ${meetingPoint.title}' : text,
            lastMessageTime: DateTime.now(),
          );
        }

        _notify();
        return message;
      }
    } on PostgrestException catch (e) {
      debugPrint('PostgrestException sending chat message: ${e.message}');
      throw StateError(e.message);
    } catch (e) {
      debugPrint('Error sending chat message: $e');
      rethrow;
    }
    throw StateError('Failed to send message');
  }

  @override
  Future<List<MeetingPoint>> getAvailableMeetingPoints({String? eventId}) async {
    try {
      var query = _supabase
          .from('venue_pois')
          .select('id, name, description, zone_id, category')
          .eq('is_active', true);

      if (eventId != null && eventId.isNotEmpty) {
        query = query.eq('event_id', eventId);
      }

      final response = await query.timeout(const Duration(seconds: 4));

      if (response.isNotEmpty) {
        final points = <MeetingPoint>[];
        for (final row in response) {
          final r = Map<String, dynamic>.from(row);
          points.add(
            MeetingPoint(
              id: r['id']?.toString() ?? '',
              title: r['name']?.toString() ?? 'Venue Location',
              subtitle: r['description']?.toString() ?? r['category']?.toString() ?? '',
              zoneId: r['zone_id']?.toString(),
              poiId: r['id']?.toString(),
            ),
          );
        }
        return points;
      }
    } catch (e) {
      debugPrint('Error fetching available meeting points from venue_pois: $e');
    }

    // Fall back to clean spatial mock fixture if venue POIs not yet defined
    return ConnectMockData.availableMeetingPoints;
  }

  @override
  Future<List<String>> getSharedInterests(List<String> peerInterests) async {
    final myProfile = await _profileRepository.getProfile();
    final myInterests = myProfile.interests.toSet();
    return peerInterests.where((i) => myInterests.contains(i)).toList();
  }

  ConnectionStatus _parseStatus(String status) {
    switch (status) {
      case 'requestSent':
        return ConnectionStatus.requestSent;
      case 'requestReceived':
        return ConnectionStatus.requestReceived;
      case 'connected':
      case 'accepted':
        return ConnectionStatus.connected;
      case 'declined':
        return ConnectionStatus.declined;
      case 'expired':
        return ConnectionStatus.expired;
      default:
        return ConnectionStatus.none;
    }
  }

  String _deriveInitials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'A';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }
}
