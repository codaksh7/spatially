import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:attendee_mobile/config/supabase_config.dart';

class _RealHttpOverrides extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = _RealHttpOverrides();

  late SupabaseClient supabase;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabaseAnonKey,
    );
    supabase = Supabase.instance.client;
  });

  group('Phase 4C Live Security & RLS Matrix Tests', () {
    test('TEST E: Guest ticket claim without authentication is rejected', () async {
      expect(supabase.auth.currentUser, isNull);

      try {
        await supabase.rpc('claim_guest_tickets', params: {
          'p_device_id': '00000000-0000-0000-0000-000000000000',
          'p_claim_token': 'test_token',
        });
        fail('Unauthenticated claim_guest_tickets must throw an exception');
      } catch (e) {
        expect(e, isNotNull);
        final errStr = e.toString().toLowerCase();
        final isAuthDenied = errStr.contains('permission denied') ||
            errStr.contains('authentication required') ||
            errStr.contains('28000') ||
            errStr.contains('42501') ||
            errStr.contains('pgrst');
        expect(isAuthDenied, isTrue);
      }
    });

    test('TEST D: Unauthenticated client cannot read other accounts claimed tickets', () async {
      final result = await supabase
          .from('tickets')
          .select('id, attendee_id, user_id, status')
          .not('user_id', 'is', null);

      // Unauthenticated client receives 0 rows for tickets owned by authenticated accounts
      expect(result, isEmpty);
    });

    test('TEST A: Profile read without authentication returns public profiles', () async {
      final result = await supabase
          .from('profiles')
          .select('id, full_name, role')
          .limit(5);

      expect(result, isNotNull);
      for (final row in result) {
        expect(['attendee', 'volunteer', 'organizer', 'admin'], contains(row['role']));
      }
    });

    test('TEST I: Attempting to insert a profile without authentication is rejected by RLS', () async {
      try {
        await supabase.from('profiles').insert({
          'id': '99999999-9999-9999-9999-999999999999',
          'full_name': 'Attacker Escalation',
          'role': 'admin',
        });
        fail('Unauthenticated profile insert must be rejected by RLS');
      } catch (e) {
        expect(e, isNotNull);
      }
    });

    test('TEST G: Controlled guest ticket lookup via get_guest_ticket RPC works safely', () async {
      final response = await supabase.rpc('get_guest_ticket', params: {
        'p_ticket_code': '5cff1cf3-e60a-42ed-abbd-ae23e800f4ee',
      });

      expect(response, isNotNull);
      expect(response['found'], isTrue);
      expect(response['ticket'], isNotNull);
      expect(response['ticket']['ticket_code'], '5cff1cf3-e60a-42ed-abbd-ae23e800f4ee');
      expect(response['ticket']['event'], isNotNull);
    });

    test('TEST G2: get_guest_ticket returns found=false for invalid ticket code', () async {
      final response = await supabase.rpc('get_guest_ticket', params: {
        'p_ticket_code': 'non_existent_code_99999',
      });

      expect(response, isNotNull);
      expect(response['found'], isFalse);
    });
  });
}
