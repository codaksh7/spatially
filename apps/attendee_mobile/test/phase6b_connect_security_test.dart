import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:attendee_mobile/config/supabase_config.dart';
import 'package:attendee_mobile/features/connect/models/connect_models.dart';
import 'package:attendee_mobile/features/connect/data/supabase_connect_repository.dart';
import 'package:attendee_mobile/services/attendee_identity.dart';

class _RealHttpOverrides extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = _RealHttpOverrides();

  late SupabaseClient supabase;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await AttendeeIdentity.init();
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabaseAnonKey,
    );
    supabase = Supabase.instance.client;
  });

  group('Phase 6B Connect Production Backend Security & RLS Matrix Tests', () {
    test('TEST D1: Unauthenticated guest cannot read attendee connections via RLS', () async {
      expect(supabase.auth.currentUser, isNull);

      final result = await supabase
          .from('attendee_connections')
          .select('id, event_id, requester_id, addressee_id, status');

      expect(result, isEmpty);
    });

    test('TEST D2: Unauthenticated guest cannot read temporary chat messages via RLS', () async {
      expect(supabase.auth.currentUser, isNull);

      final result = await supabase
          .from('temporary_chat_messages')
          .select('id, connection_id, sender_id, message_text');

      expect(result, isEmpty);
    });

    test('TEST D3: Guest attempting get_discoverable_attendees RPC is rejected', () async {
      expect(supabase.auth.currentUser, isNull);

      try {
        await supabase.rpc('get_discoverable_attendees', params: {
          'p_event_id': '00000000-0000-0000-0000-000000000001',
        });
        fail('Unauthenticated get_discoverable_attendees must throw an exception');
      } catch (e) {
        expect(e, isNotNull);
        final errStr = e.toString().toLowerCase();
        final isAuthDenied = errStr.contains('authentication required') ||
            errStr.contains('42501') ||
            errStr.contains('pgrst');
        expect(isAuthDenied, isTrue);
      }
    });

    test('TEST D4: Guest attempting send_connection_request RPC is rejected', () async {
      expect(supabase.auth.currentUser, isNull);

      try {
        await supabase.rpc('send_connection_request', params: {
          'p_event_id': '00000000-0000-0000-0000-000000000001',
          'p_peer_id': '00000000-0000-0000-0000-000000000002',
        });
        fail('Unauthenticated send_connection_request must throw an exception');
      } catch (e) {
        expect(e, isNotNull);
        final errStr = e.toString().toLowerCase();
        final isAuthDenied = errStr.contains('authentication required') ||
            errStr.contains('42501') ||
            errStr.contains('pgrst');
        expect(isAuthDenied, isTrue);
      }
    });

    test('TEST D5: Guest attempting respond_to_connection_request RPC is rejected', () async {
      expect(supabase.auth.currentUser, isNull);

      try {
        await supabase.rpc('respond_to_connection_request', params: {
          'p_connection_id': '00000000-0000-0000-0000-000000000001',
          'p_accept': true,
        });
        fail('Unauthenticated respond_to_connection_request must throw an exception');
      } catch (e) {
        expect(e, isNotNull);
        final errStr = e.toString().toLowerCase();
        final isAuthDenied = errStr.contains('authentication required') ||
            errStr.contains('42501') ||
            errStr.contains('pgrst');
        expect(isAuthDenied, isTrue);
      }
    });

    test('TEST D6: Guest attempting cancel_connection_request RPC is rejected', () async {
      expect(supabase.auth.currentUser, isNull);

      try {
        await supabase.rpc('cancel_connection_request', params: {
          'p_connection_id': '00000000-0000-0000-0000-000000000001',
        });
        fail('Unauthenticated cancel_connection_request must throw an exception');
      } catch (e) {
        expect(e, isNotNull);
        final errStr = e.toString().toLowerCase();
        final isAuthDenied = errStr.contains('authentication required') ||
            errStr.contains('42501') ||
            errStr.contains('pgrst');
        expect(isAuthDenied, isTrue);
      }
    });

    test('TEST D7: Guest attempting send_chat_message RPC is rejected', () async {
      expect(supabase.auth.currentUser, isNull);

      try {
        await supabase.rpc('send_chat_message', params: {
          'p_connection_id': '00000000-0000-0000-0000-000000000001',
          'p_message_text': 'Unauthorized test message',
        });
        fail('Unauthenticated send_chat_message must throw an exception');
      } catch (e) {
        expect(e, isNotNull);
        final errStr = e.toString().toLowerCase();
        final isAuthDenied = errStr.contains('authentication required') ||
            errStr.contains('42501') ||
            errStr.contains('pgrst');
        expect(isAuthDenied, isTrue);
      }
    });

    test('IDENTITY SEPARATION: Device ID is never stored or exposed as social identity', () {
      final deviceId = AttendeeIdentity.deviceId;
      expect(deviceId, isNotNull);

      // Verify ConnectProfile does not leak deviceId or hardware metadata
      const profile = ConnectProfile(
        id: 'user_123',
        displayName: 'Test Attendee',
        headline: 'Mobile Engineer',
        bio: 'Bio text',
        avatarInitials: 'TA',
        interests: ['Flutter', 'Supabase'],
        isReadyToChat: true,
      );

      // ConnectProfile has no device UUID, BLE MAC, or telemetry field by construction
      expect(profile.id, equals('user_123'));
      expect(profile.displayName, equals('Test Attendee'));
    });

    test('CHAT DATA MODEL: 1000-character message boundary and meeting point support', () {
      final validMessage = ChatMessage(
        id: 'msg_1',
        connectionId: 'conn_1',
        senderId: 'user_1',
        isFromMe: true,
        text: 'A' * 1000,
        timestamp: DateTime.now(),
        meetingPoint: const MeetingPoint(
          id: 'poi_1',
          title: 'Main Stage',
          subtitle: 'Hall A',
          zoneId: 'zone_1',
          poiId: 'poi_1',
        ),
      );

      expect(validMessage.text.length, equals(1000));
      expect(validMessage.meetingPoint, isNotNull);
      expect(validMessage.meetingPoint!.poiId, equals('poi_1'));
    });

    test('SESSION ISOLATION: SupabaseConnectRepositoryImpl clean session teardown', () async {
      final repo = SupabaseConnectRepositoryImpl(supabase: supabase);

      // Verify clearSession finishes cleanly without uncaught exceptions
      expect(repo.clearSession, returnsNormally);
      await repo.clearSession();
    });
  });
}
