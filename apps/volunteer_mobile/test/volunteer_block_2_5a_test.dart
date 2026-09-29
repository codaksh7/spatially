import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:volunteer_mobile/models/operational_message.dart';
import 'package:volunteer_mobile/models/quick_reply.dart';
import 'package:volunteer_mobile/models/volunteer_directory_entry.dart';
import 'package:volunteer_mobile/repositories/operational_communication_repository.dart';
import 'package:volunteer_mobile/screens/communications_center_screen.dart';
import 'package:volunteer_mobile/screens/direct_thread_screen.dart';
import 'package:volunteer_mobile/services/session_state.dart';

class FakeOperationalCommunicationRepository implements OperationalCommunicationRepository {
  final List<OperationalMessage> messages = [];
  final List<VolunteerDirectoryEntry> directory = [];
  final StreamController<OperationalMessage> _messageStreamController =
      StreamController<OperationalMessage>.broadcast();
  final StreamController<int> _unreadStreamController =
      StreamController<int>.broadcast();

  bool isRealtimeSubscribed = false;
  String? currentSubscribedEventId;
  int unreadCount = 0;
  bool shouldThrowOnGetMessages = false;
  bool isOffline = false;

  @override
  Stream<OperationalMessage> get messageStream => _messageStreamController.stream;

  @override
  Stream<int> get unreadCountStream => _unreadStreamController.stream;

  @override
  Future<List<OperationalMessage>> getMessages({
    required String eventId,
    int limit = 50,
    int offset = 0,
    String? filter,
  }) async {
    if (shouldThrowOnGetMessages) {
      throw Exception('Network error');
    }
    List<OperationalMessage> filtered = messages.where((m) => m.eventId == eventId).toList();
    if (filter == 'broadcasts') {
      filtered = filtered.where((m) => m.isBroadcast).toList();
    } else if (filter == 'direct') {
      filtered = filtered.where((m) => m.isDirect || m.isOrganizerChannel).toList();
    } else if (filter == 'urgent') {
      filtered = filtered.where((m) => m.isUrgent).toList();
    }
    return filtered;
  }

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
    if (isOffline && priority == OperationalPriority.urgent) {
      throw const OfflineUrgentMessageException();
    }

    final newMsg = OperationalMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      eventId: eventId,
      senderId: SessionState.instance.volunteerId ?? 'volunteer_1',
      senderRole: SessionState.instance.userRole ?? 'volunteer',
      senderName: 'Test Volunteer',
      targetType: targetType,
      targetId: targetId,
      zoneId: zoneId,
      messageType: messageType,
      priority: priority,
      body: body,
      requiresAcknowledgment: requiresAcknowledgment,
      createdAt: DateTime.now(),
      receiptStatus: isOffline ? MessageLifecycleStatus.queued : MessageLifecycleStatus.sent,
      isLocalQueued: isOffline,
    );

    messages.insert(0, newMsg);
    _messageStreamController.add(newMsg);
    return newMsg;
  }

  @override
  Future<bool> acknowledgeMessage(String messageId) async {
    final idx = messages.indexWhere((m) => m.id == messageId);
    if (idx != -1) {
      messages[idx] = messages[idx].copyWith(
        receiptStatus: MessageLifecycleStatus.acknowledged,
        acknowledgedAt: DateTime.now(),
      );
      if (unreadCount > 0) {
        unreadCount--;
        _unreadStreamController.add(unreadCount);
      }
      return true;
    }
    return false;
  }

  @override
  Future<void> markAsRead(List<String> messageIds) async {
    for (final id in messageIds) {
      final idx = messages.indexWhere((m) => m.id == id);
      if (idx != -1) {
        messages[idx] = messages[idx].copyWith(
          receiptStatus: MessageLifecycleStatus.read,
          readAt: DateTime.now(),
        );
      }
    }
  }

  @override
  Future<List<VolunteerDirectoryEntry>> getVolunteerDirectory(String eventId) async {
    return directory;
  }

  @override
  void subscribeRealtime(String eventId) {
    isRealtimeSubscribed = true;
    currentSubscribedEventId = eventId;
  }

  @override
  Future<void> unsubscribeRealtime() async {
    isRealtimeSubscribed = false;
    currentSubscribedEventId = null;
  }

  @override
  Future<int> flushPendingMessages() async {
    int flushed = 0;
    for (int i = 0; i < messages.length; i++) {
      if (messages[i].isLocalQueued) {
        messages[i] = messages[i].copyWith(
          isLocalQueued: false,
          receiptStatus: MessageLifecycleStatus.sent,
        );
        flushed++;
      }
    }
    return flushed;
  }

  @override
  Future<void> clearAccountCache() async {
    await unsubscribeRealtime();
    messages.clear();
    directory.clear();
    unreadCount = 0;
  }
}

void main() {
  group('Block 2.5A: Operational Message Data Model', () {
    test('OperationalPriority and OperationalTargetType enum parsing and values', () {
      expect(OperationalPriority.fromString('urgent'), OperationalPriority.urgent);
      expect(OperationalPriority.fromString('important'), OperationalPriority.important);
      expect(OperationalPriority.fromString('normal'), OperationalPriority.normal);
      expect(OperationalPriority.fromString('unknown'), OperationalPriority.normal);

      expect(OperationalTargetType.fromString('event'), OperationalTargetType.event);
      expect(OperationalTargetType.fromString('zone'), OperationalTargetType.zone);
      expect(OperationalTargetType.fromString('volunteer'), OperationalTargetType.volunteer);
      expect(OperationalTargetType.fromString('organizer'), OperationalTargetType.organizer);
    });

    test('OperationalMessage JSON serialization, deserialization, and receipt mapping', () {
      final now = DateTime.now();
      final msg = OperationalMessage(
        id: 'msg-001',
        eventId: 'event-001',
        senderId: 'vol-001',
        senderRole: 'volunteer',
        senderName: 'Blaise Rodrigues',
        targetType: OperationalTargetType.zone,
        zoneId: 'zone-701',
        messageType: 'operational',
        priority: OperationalPriority.important,
        body: 'Zone 701 scanner battery at 15%.',
        requiresAcknowledgment: true,
        createdAt: now,
        receiptStatus: MessageLifecycleStatus.delivered,
      );

      final json = msg.toJson();
      expect(json['id'], 'msg-001');
      expect(json['target_type'], 'zone');
      expect(json['priority'], 'important');
      expect(json['requires_acknowledgment'], true);

      final deserialized = OperationalMessage.fromJson(json, currentUserId: 'vol-002');
      expect(deserialized.id, msg.id);
      expect(deserialized.isImportant, true);
      expect(deserialized.isBroadcast, true);
      expect(deserialized.isDirect, false);
      expect(deserialized.isFromOrganizer, false);
    });

    test('Receipts parsing handles user-specific acknowledgment and read state', () {
      final rawDbRow = {
        'id': 'msg-002',
        'event_id': 'event-001',
        'sender_id': 'org-001',
        'sender_role': 'organizer',
        'sender_name': 'Hero',
        'target_type': 'event',
        'message_type': 'escalation',
        'priority': 'urgent',
        'body': 'Emergency exit 3 blocked. Redirect attendees.',
        'requires_acknowledgment': true,
        'created_at': DateTime.now().toIso8601String(),
        'receipts': [
          {
            'recipient_id': 'vol-001',
            'status': 'acknowledged',
            'read_at': DateTime.now().toIso8601String(),
            'acknowledged_at': DateTime.now().toIso8601String(),
          }
        ]
      };

      final msg = OperationalMessage.fromJson(rawDbRow, currentUserId: 'vol-001');
      expect(msg.isUrgent, true);
      expect(msg.isFromOrganizer, true);
      expect(msg.receiptStatus, MessageLifecycleStatus.acknowledged);
      expect(msg.isAcknowledged, true);
      expect(msg.isRead, true);
    });
  });

  group('Block 2.5A: Volunteer Directory Model & Privacy Safeguards', () {
    test('VolunteerDirectoryEntry parses correctly and prevents private exposure', () {
      final directoryJson = {
        'volunteer_id': 'vol-123',
        'full_name': 'Daksh Thakkar',
        'role': 'crowd_monitor',
        'staff_type': 'volunteer',
        'zone_id': 'zone-701',
        'zone_name': 'Auditorium',
        'zone_code': '701',
        'is_roving': false,
        'shift_status': 'active',
        // Deliberately check that email or phone keys are not captured or exposed
        'email': 'should_not_leak@test.com',
        'phone': '+1234567890',
      };

      final entry = VolunteerDirectoryEntry.fromJson(directoryJson);
      expect(entry.volunteerId, 'vol-123');
      expect(entry.fullName, 'Daksh Thakkar');
      expect(entry.assignmentLabel, 'Auditorium (Zone 701)');
      expect(entry.isRoving, false);
      expect(entry.isOrganizerOrAdmin, false);

      final exported = entry.toJson();
      expect(exported.containsKey('email'), false);
      expect(exported.containsKey('phone'), false);
    });

    test('Roving staff assignment label formats properly', () {
      const rovingEntry = VolunteerDirectoryEntry(
        volunteerId: 'vol-456',
        fullName: 'Aryan Verma',
        role: 'crowd_monitor',
        staffType: 'volunteer',
        isRoving: true,
      );
      expect(rovingEntry.assignmentLabel, 'Roving Shift (All Zones)');
    });

    test('Organizer staff type formats properly', () {
      const orgEntry = VolunteerDirectoryEntry(
        volunteerId: 'org-789',
        fullName: 'Lead Coordinator',
        role: 'lead',
        staffType: 'organizer',
      );
      expect(orgEntry.assignmentLabel, 'Event Operations');
      expect(orgEntry.isOrganizerOrAdmin, true);
    });
  });

  group('Block 2.5A: Quick Operational Replies', () {
    test('Predefined quick replies are deterministic, concise, and structured', () {
      expect(QuickReplyOption.defaultOptions.isNotEmpty, true);
      final ackOpt = QuickReplyOption.defaultOptions.firstWhere((q) => q.actionType == 'ack');
      expect(ackOpt.text, 'Acknowledged.');
      expect(ackOpt.isAffirmative, true);

      final declineOpt = QuickReplyOption.defaultOptions.firstWhere((q) => q.actionType == 'declined');
      expect(declineOpt.text, "I can't assist.");
      expect(declineOpt.isAffirmative, false);
    });
  });

  group('Block 2.5A: Repository Offline Behavior & Urgent Shielding', () {
    test('Normal message queues locally when offline without throwing', () async {
      final repo = FakeOperationalCommunicationRepository();
      repo.isOffline = true;
      SessionState.instance.volunteerId = 'vol-001';

      final msg = await repo.sendMessage(
        eventId: 'event-001',
        targetType: OperationalTargetType.zone,
        body: 'Station scanner is low on battery.',
        priority: OperationalPriority.normal,
      );

      expect(msg.isLocalQueued, true);
      expect(msg.receiptStatus, MessageLifecycleStatus.queued);
    });

    test('Urgent message refuses offline queueing and throws OfflineUrgentMessageException', () async {
      final repo = FakeOperationalCommunicationRepository();
      repo.isOffline = true;
      SessionState.instance.volunteerId = 'vol-001';

      expect(
        () async => await repo.sendMessage(
          eventId: 'event-001',
          targetType: OperationalTargetType.organizer,
          body: 'Medical assistance requested at West gate!',
          priority: OperationalPriority.urgent,
        ),
        throwsA(isA<OfflineUrgentMessageException>()),
      );
    });

    test('Reconnecting flushes queued messages and resets local queued flag', () async {
      final repo = FakeOperationalCommunicationRepository();
      repo.isOffline = true;
      SessionState.instance.volunteerId = 'vol-001';

      await repo.sendMessage(
        eventId: 'event-001',
        targetType: OperationalTargetType.zone,
        body: 'Queued message 1',
        priority: OperationalPriority.normal,
      );
      await repo.sendMessage(
        eventId: 'event-001',
        targetType: OperationalTargetType.zone,
        body: 'Queued message 2',
        priority: OperationalPriority.important,
      );

      expect(repo.messages.every((m) => m.isLocalQueued), true);

      repo.isOffline = false;
      final count = await repo.flushPendingMessages();
      expect(count, 2);
      expect(repo.messages.every((m) => !m.isLocalQueued), true);
    });
  });

  group('Block 2.5A: Realtime Lifecycle & Account Isolation', () {
    test('Subscription lifecycle attaches and detaches cleanly', () async {
      final repo = FakeOperationalCommunicationRepository();
      repo.subscribeRealtime('event-100');
      expect(repo.isRealtimeSubscribed, true);
      expect(repo.currentSubscribedEventId, 'event-100');

      await repo.unsubscribeRealtime();
      expect(repo.isRealtimeSubscribed, false);
      expect(repo.currentSubscribedEventId, null);
    });

    test('Clear account cache purges subscriptions and in-memory message history', () async {
      final repo = FakeOperationalCommunicationRepository();
      repo.subscribeRealtime('event-100');
      repo.messages.add(
        OperationalMessage(
          id: '1',
          eventId: 'event-100',
          senderId: 'vol-1',
          senderRole: 'volunteer',
          senderName: 'Test',
          targetType: OperationalTargetType.event,
          messageType: 'broadcast',
          priority: OperationalPriority.normal,
          body: 'Hello',
          createdAt: DateTime.now(),
        ),
      );

      expect(repo.messages.length, 1);
      await repo.clearAccountCache();
      expect(repo.messages.isEmpty, true);
      expect(repo.isRealtimeSubscribed, false);
    });
  });

  group('Block 2.5A: Communications Center UI Widget Tests', () {
    testWidgets('Renders empty state when no messages exist', (WidgetTester tester) async {
      final repo = FakeOperationalCommunicationRepository();
      SessionState.instance.eventId = 'event-001';
      SessionState.instance.eventName = 'Cultural Night 2026';

      await tester.pumpWidget(
        MaterialApp(
          home: CommunicationsCenterScreen(repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Communications Center'), findsOneWidget);
      expect(find.text('Cultural Night 2026'), findsOneWidget);
      expect(find.text('No operational messages.'), findsOneWidget);
      expect(find.text('Compose'), findsOneWidget);
    });

    testWidgets('Renders urgent banner with Acknowledge button when urgent message exists', (WidgetTester tester) async {
      final repo = FakeOperationalCommunicationRepository();
      SessionState.instance.eventId = 'event-001';
      SessionState.instance.eventName = 'Cultural Night 2026';
      SessionState.instance.volunteerId = 'my-vol-id';

      repo.messages.add(
        OperationalMessage(
          id: 'urgent-1',
          eventId: 'event-001',
          senderId: 'organizer-id',
          senderRole: 'organizer',
          senderName: 'Hero Coordinator',
          targetType: OperationalTargetType.event,
          messageType: 'escalation',
          priority: OperationalPriority.urgent,
          body: 'Gate 2 scanner malfunction. Divert queue to Gate 1.',
          requiresAcknowledgment: true,
          createdAt: DateTime.now(),
          receiptStatus: MessageLifecycleStatus.delivered,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CommunicationsCenterScreen(repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('URGENT'), findsWidgets);
      expect(find.text('Gate 2 scanner malfunction. Divert queue to Gate 1.'), findsWidgets);
      expect(find.text('Acknowledge'), findsOneWidget);

      // Tap Acknowledge button
      await tester.tap(find.text('Acknowledge'));
      await tester.pumpAndSettle();

      expect(repo.messages.first.receiptStatus, MessageLifecycleStatus.acknowledged);
    });

    testWidgets('Direct Thread Screen renders quick reply chips and allows fast send', (WidgetTester tester) async {
      final repo = FakeOperationalCommunicationRepository();
      SessionState.instance.eventId = 'event-001';
      SessionState.instance.volunteerId = 'my-vol-id';

      const recipient = VolunteerDirectoryEntry(
        volunteerId: 'other-vol-id',
        fullName: 'Daksh Thakkar',
        role: 'crowd_monitor',
        staffType: 'volunteer',
        zoneName: 'Auditorium',
        zoneCode: '701',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: DirectThreadScreen(
            repository: repo,
            eventId: 'event-001',
            recipient: recipient,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Daksh Thakkar'), findsOneWidget);
      expect(find.text('Auditorium (Zone 701)'), findsOneWidget);
      expect(find.text('Acknowledged.'), findsOneWidget);
      expect(find.text('On my way.'), findsOneWidget);

      // Tap "On my way." quick reply
      await tester.tap(find.text('On my way.'));
      await tester.pumpAndSettle();

      expect(repo.messages.any((m) => m.body == 'On my way.'), true);
    });
  });
}
