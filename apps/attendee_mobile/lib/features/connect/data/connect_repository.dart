import 'dart:async';
import '../../profile/data/profile_repository.dart';
import '../../profile/models/profile_preferences.dart';
import '../models/connect_models.dart';
import 'connect_mock_data.dart';

/// Abstract contract for event-scoped temporary networking.
///
/// Follows the Spatially clean architecture pattern:
/// UI -> ConnectRepository -> Data Source.
///
/// In the future, this contract will be backed by Supabase Realtime Presence
/// and Broadcast channels without requiring modifications to the UI layer.
abstract class ConnectRepository {
  /// Stream that emits whenever connection or discovery states change.
  Stream<void> get updatesStream;

  /// Retrieves discoverable attendees for the given event, filtered by current
  /// user's profile networking preferences and interest overlap.
  Future<List<ConnectProfile>> getDiscoverableAttendees(String eventId);

  /// Retrieves all active and pending connections for the current event.
  Future<List<Connection>> getConnections(String eventId);

  /// Retrieves a specific connection by peer profile ID.
  Future<Connection?> getConnectionForPeer(String eventId, String peerId);

  /// Sends a connection request to a discoverable attendee.
  Future<Connection> sendConnectionRequest(String eventId, String peerId);

  /// Accepts an incoming connection request.
  Future<Connection> acceptConnectionRequest(String connectionId);

  /// Declines or dismisses a connection request.
  Future<void> declineConnectionRequest(String connectionId);

  /// Simulates peer acceptance of an outbound request (for testing mutual opt-in).
  Future<Connection> simulatePeerAcceptance(String connectionId);

  /// Retrieves chat messages for an active connection.
  Future<List<ChatMessage>> getMessages(String connectionId);

  /// Sends a temporary chat message or suggests a meeting point.
  Future<ChatMessage> sendMessage({
    required String connectionId,
    required String text,
    MeetingPoint? meetingPoint,
  });

  /// Retrieves available venue meeting points from the spatial model.
  Future<List<MeetingPoint>> getAvailableMeetingPoints({String? eventId});

  /// Calculates shared interests between the current attendee and a peer profile.
  Future<List<String>> getSharedInterests(List<String> peerInterests);

  /// Clears in-memory session caches and unsubscribes active Realtime channels.
  Future<void> clearSession();
}

/// In-memory repository implementation backing Phase 3G.
///
/// Seamlessly integrates with [ProfileRepository] to respect live user interests
/// and networking visibility preferences.
class ConnectRepositoryImpl implements ConnectRepository {
  final ProfileRepository _profileRepository;
  final StreamController<void> _updatesController = StreamController<void>.broadcast();

  // In-memory state for the active event session
  final Map<String, Connection> _connections = {};
  final Map<String, List<ChatMessage>> _messages = {};
  bool _initialized = false;

  ConnectRepositoryImpl({ProfileRepository? profileRepository})
      : _profileRepository = profileRepository ?? ProfileRepositoryImpl();

  @override
  Stream<void> get updatesStream => _updatesController.stream;

  void _notify() {
    if (!_updatesController.isClosed) {
      _updatesController.add(null);
    }
  }

  void _ensureInitialized(String eventId) {
    if (_initialized) return;
    _initialized = true;

    // Seed realistic initial demo state:
    // 1. Kabir Rao sent an incoming connection request
    final kabir = ConnectMockData.initialAttendees.firstWhere((a) => a.id == 'demo_kabir_rao');
    final kabirConnId = 'conn_kabir_${eventId.hashCode}';
    _connections[kabirConnId] = Connection(
      id: kabirConnId,
      eventId: eventId,
      peerProfile: kabir,
      status: ConnectionStatus.requestReceived,
      createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
      lastMessage: 'Hey! Saw your interests in Mobile & Robotics. Are you around the main floor?',
      lastMessageTime: DateTime.now().subtract(const Duration(minutes: 15)),
    );

    // Initial message from Kabir
    _messages[kabirConnId] = [
      ChatMessage(
        id: 'msg_init_1',
        connectionId: kabirConnId,
        senderId: kabir.id,
        isFromMe: false,
        text: 'Hey! Saw your interests in Mobile & Robotics. Are you around the main floor?',
        timestamp: DateTime.now().subtract(const Duration(minutes: 15)),
      ),
    ];
  }

  @override
  Future<List<String>> getSharedInterests(List<String> peerInterests) async {
    final myProfile = await _profileRepository.getProfile();
    final myInterests = myProfile.interests.toSet();
    return peerInterests.where((i) => myInterests.contains(i)).toList();
  }

  @override
  Future<List<ConnectProfile>> getDiscoverableAttendees(String eventId) async {
    _ensureInitialized(eventId);

    final prefs = await _profileRepository.getPreferences();
    final myProfile = await _profileRepository.getProfile();

    // 1. If user has chosen invisible mode, discovery is completely turned off
    if (prefs.networkingVisibility == NetworkingVisibility.invisible) {
      return [];
    }

    final myInterests = myProfile.interests.toSet();
    final allAttendees = ConnectMockData.initialAttendees;

    // 2. Filter based on visibility preference
    if (prefs.networkingVisibility == NetworkingVisibility.matchingInterests) {
      return allAttendees.where((attendee) {
        final hasShared = attendee.interests.any((interest) => myInterests.contains(interest));
        return hasShared;
      }).toList();
    }

    // 3. Discoverable to all: return full list
    return List.unmodifiable(allAttendees);
  }

  @override
  Future<List<Connection>> getConnections(String eventId) async {
    _ensureInitialized(eventId);
    return _connections.values.where((c) => c.eventId == eventId).toList();
  }

  @override
  Future<Connection?> getConnectionForPeer(String eventId, String peerId) async {
    _ensureInitialized(eventId);
    for (final conn in _connections.values) {
      if (conn.eventId == eventId && conn.peerProfile.id == peerId) {
        return conn;
      }
    }
    return null;
  }

  @override
  Future<Connection> sendConnectionRequest(String eventId, String peerId) async {
    _ensureInitialized(eventId);
    final peer = ConnectMockData.initialAttendees.firstWhere(
      (a) => a.id == peerId,
      orElse: () => throw ArgumentError('Attendee not found: $peerId'),
    );

    final existing = await getConnectionForPeer(eventId, peerId);
    if (existing != null) {
      return existing;
    }

    final newId = 'conn_${peerId}_${DateTime.now().millisecondsSinceEpoch}';
    final newConn = Connection(
      id: newId,
      eventId: eventId,
      peerProfile: peer,
      status: ConnectionStatus.requestSent,
      createdAt: DateTime.now(),
      lastMessage: 'Connection request sent',
      lastMessageTime: DateTime.now(),
    );

    _connections[newId] = newConn;
    _notify();
    return newConn;
  }

  @override
  Future<Connection> acceptConnectionRequest(String connectionId) async {
    final conn = _connections[connectionId];
    if (conn == null) throw ArgumentError('Connection not found: $connectionId');

    final updated = conn.copyWith(
      status: ConnectionStatus.connected,
      lastMessage: 'Connected for this event',
      lastMessageTime: DateTime.now(),
    );
    _connections[connectionId] = updated;

    // Add a system welcome message to the chat
    final msgs = _messages.putIfAbsent(connectionId, () => []);
    msgs.add(
      ChatMessage(
        id: 'sys_${DateTime.now().millisecondsSinceEpoch}',
        connectionId: connectionId,
        senderId: 'system',
        isFromMe: false,
        text: 'You are now connected for this event! Messages and shared points are temporary.',
        timestamp: DateTime.now(),
      ),
    );

    _notify();
    return updated;
  }

  @override
  Future<void> declineConnectionRequest(String connectionId) async {
    final conn = _connections[connectionId];
    if (conn == null) return;

    _connections[connectionId] = conn.copyWith(
      status: ConnectionStatus.declined,
    );
    _notify();
  }

  @override
  Future<Connection> simulatePeerAcceptance(String connectionId) async {
    final conn = _connections[connectionId];
    if (conn == null) throw ArgumentError('Connection not found: $connectionId');

    final updated = conn.copyWith(
      status: ConnectionStatus.connected,
      lastMessage: 'Accepted! Excited to connect.',
      lastMessageTime: DateTime.now(),
    );
    _connections[connectionId] = updated;

    final msgs = _messages.putIfAbsent(connectionId, () => []);
    msgs.add(
      ChatMessage(
        id: 'peer_msg_${DateTime.now().millisecondsSinceEpoch}',
        connectionId: connectionId,
        senderId: conn.peerProfile.id,
        isFromMe: false,
        text: 'Hey! Thanks for connecting. What sessions are you catching today?',
        timestamp: DateTime.now(),
      ),
    );

    _notify();
    return updated;
  }

  @override
  Future<List<ChatMessage>> getMessages(String connectionId) async {
    return List.unmodifiable(_messages[connectionId] ?? []);
  }

  @override
  Future<ChatMessage> sendMessage({
    required String connectionId,
    required String text,
    MeetingPoint? meetingPoint,
  }) async {
    final conn = _connections[connectionId];
    if (conn == null) throw ArgumentError('Connection not found: $connectionId');

    final message = ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      connectionId: connectionId,
      senderId: 'current_user',
      isFromMe: true,
      text: text,
      timestamp: DateTime.now(),
      meetingPoint: meetingPoint,
    );

    final msgs = _messages.putIfAbsent(connectionId, () => []);
    msgs.add(message);

    // Update connection last message
    _connections[connectionId] = conn.copyWith(
      lastMessage: meetingPoint != null ? 'Suggested meeting: ${meetingPoint.title}' : text,
      lastMessageTime: DateTime.now(),
    );

    _notify();
    return message;
  }

  @override
  Future<List<MeetingPoint>> getAvailableMeetingPoints({String? eventId}) async {
    return ConnectMockData.availableMeetingPoints;
  }

  @override
  Future<void> clearSession() async {
    _connections.clear();
    _messages.clear();
    _initialized = false;
    _notify();
  }
}
