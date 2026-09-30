import 'package:flutter/foundation.dart';

/// Connection status between two attendees within the scope of an event.
enum ConnectionStatus {
  /// No connection initiated.
  none,

  /// Current user sent a connection request; waiting for peer acceptance.
  requestSent,

  /// Peer sent a connection request; current user can accept or decline.
  requestReceived,

  /// Both parties accepted; temporary event chat is active.
  connected,

  /// Request was declined or dismissed.
  declined,

  /// The event concluded or connection session timed out.
  expired;

  String get label {
    switch (this) {
      case ConnectionStatus.none:
        return 'Not Connected';
      case ConnectionStatus.requestSent:
        return 'Request Pending';
      case ConnectionStatus.requestReceived:
        return 'Request Received';
      case ConnectionStatus.connected:
        return 'Connected for Event';
      case ConnectionStatus.declined:
        return 'Declined';
      case ConnectionStatus.expired:
        return 'Session Expired';
    }
  }
}

/// Represents a physical venue location that attendees can agree to meet at.
///
/// Directly references Spatially venue zones and POIs from [VenueMockData]
/// to seamlessly bridge into the existing [MapScreen] wayfinding experience.
@immutable
class MeetingPoint {
  final String id;
  final String title;
  final String subtitle;
  final String? zoneId;
  final String? poiId;
  final String roomNumber;

  const MeetingPoint({
    required this.id,
    required this.title,
    required this.subtitle,
    this.zoneId,
    this.poiId,
    this.roomNumber = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'zoneId': zoneId,
      'poiId': poiId,
      'roomNumber': roomNumber,
    };
  }

  factory MeetingPoint.fromMap(Map<String, dynamic> map) {
    return MeetingPoint(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      subtitle: map['subtitle']?.toString() ?? '',
      zoneId: map['zoneId']?.toString(),
      poiId: map['poiId']?.toString(),
      roomNumber: map['roomNumber']?.toString() ?? '',
    );
  }
}

/// A social attendee profile discoverable within the context of an event.
///
/// CRITICAL PRIVACY BOUNDARY:
/// This model MUST NEVER contain or expose persistent device UUIDs,
/// BLE rotating ephemeral IDs, advertiser beacons, or crowd telemetry identifiers.
@immutable
class ConnectProfile {
  /// Event-scoped social identity identifier (NOT device UUID or BLE beacon ID).
  final String id;
  final String displayName;
  final String headline;
  final String organization;
  final String bio;
  final List<String> interests;

  /// Coarse spatial zone indicator (e.g. "Near Auditorium (Room 701)").
  /// NEVER precise GPS coordinates or real-time BLE distance measurements.
  final String locationNote;
  final bool isReadyToChat;
  final String avatarInitials;

  const ConnectProfile({
    required this.id,
    required this.displayName,
    this.headline = '',
    this.organization = '',
    this.bio = '',
    this.interests = const [],
    this.locationNote = '',
    this.isReadyToChat = true,
    required this.avatarInitials,
  });

  ConnectProfile copyWith({
    String? id,
    String? displayName,
    String? headline,
    String? organization,
    String? bio,
    List<String>? interests,
    String? locationNote,
    bool? isReadyToChat,
    String? avatarInitials,
  }) {
    return ConnectProfile(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      headline: headline ?? this.headline,
      organization: organization ?? this.organization,
      bio: bio ?? this.bio,
      interests: interests ?? this.interests,
      locationNote: locationNote ?? this.locationNote,
      isReadyToChat: isReadyToChat ?? this.isReadyToChat,
      avatarInitials: avatarInitials ?? this.avatarInitials,
    );
  }
}

/// An active or historical temporary connection between the attendee and a peer.
@immutable
class Connection {
  final String id;
  final String eventId;
  final ConnectProfile peerProfile;
  final ConnectionStatus status;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final String? lastMessage;
  final DateTime? lastMessageTime;

  const Connection({
    required this.id,
    required this.eventId,
    required this.peerProfile,
    required this.status,
    required this.createdAt,
    this.expiresAt,
    this.lastMessage,
    this.lastMessageTime,
  });

  bool get isConnected => status == ConnectionStatus.connected;
  bool get isPendingOutbound => status == ConnectionStatus.requestSent;
  bool get isPendingInbound => status == ConnectionStatus.requestReceived;

  Connection copyWith({
    String? id,
    String? eventId,
    ConnectProfile? peerProfile,
    ConnectionStatus? status,
    DateTime? createdAt,
    DateTime? expiresAt,
    String? lastMessage,
    DateTime? lastMessageTime,
  }) {
    return Connection(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      peerProfile: peerProfile ?? this.peerProfile,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
    );
  }
}

/// An ephemeral chat message sent during an event connection.
@immutable
class ChatMessage {
  final String id;
  final String connectionId;
  final String senderId;
  final bool isFromMe;
  final String text;
  final DateTime timestamp;
  final MeetingPoint? meetingPoint;

  const ChatMessage({
    required this.id,
    required this.connectionId,
    required this.senderId,
    required this.isFromMe,
    required this.text,
    required this.timestamp,
    this.meetingPoint,
  });

  bool get isMeetingPoint => meetingPoint != null;
}
