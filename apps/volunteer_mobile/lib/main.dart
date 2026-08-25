import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'services/telemetry_service.dart';
import 'services/session_state.dart';
import 'screens/login_screen.dart';
import 'screens/event_picker_screen.dart';
import 'screens/zone_selection_screen.dart';
import 'screens/scan_screen.dart';
import 'screens/battery_check_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await TelemetryService().init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Named routes used by ZoneSelectionScreen to push to ScanScreen,
      // and by EventPickerScreen to push to ZoneSelectionScreen.
      routes: {
        '/scan': (context) => const ScanScreen(),
        '/zone_selection': (context) => const ZoneSelectionScreen(),
      },
      home: const AuthGate(),
    );
  }
}

/// Listens to Supabase auth state changes and routes accordingly:
/// - No session → LoginScreen
/// - Session exists, no zone selected → ZoneSelectionScreen
/// - Session exists, zone selected → ScanScreen
///
/// Note: the zone→ScanScreen transition is handled by a direct
/// Navigator.pushReplacementNamed('/scan') inside ZoneSelectionScreen,
/// not by this StreamBuilder, because zone selection is NOT an auth event.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final supabaseInstance = Supabase.instance;
    final client = supabaseInstance.client;
    final auth = client.auth;

    return StreamBuilder<AuthState>(
      stream: auth.onAuthStateChange,
      builder: (context, snapshot) {
        // While waiting for the first auth event, show a blank scaffold
        // to avoid a flash of the login screen for already-signed-in users.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final session = snapshot.data?.session;

        if (session == null) {
          // Not logged in — clear any stale session state and show login.
          SessionState.instance.clear();
          return const LoginScreen();
        }

        // Logged in — ensure SessionState has the volunteer ID populated.
        // This is safe to set on every event; it's idempotent.
        SessionState.instance.volunteerId = session.user.id;

        // Battery check first.
        if (!SessionState.instance.batteryChecked) {
          return const BatteryCheckScreen();
        }

        // Event not yet selected → show event picker.
        if (SessionState.instance.eventId == null) {
          return const EventPickerScreen();
        }

        // Zone not yet selected for this session → go to zone selection.
        if (SessionState.instance.zone == null) {
          return const ZoneSelectionScreen();
        }

        // Zone already selected (e.g. user returned from background).
        return const ScanScreen();
      },
    );
  }
}
