import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'services/telemetry_service.dart';
import 'services/session_state.dart';
import 'repositories/volunteer_assignment_repository.dart';
import 'screens/login_screen.dart';
import 'screens/event_picker_screen.dart';
import 'screens/zone_selection_screen.dart';
import 'screens/scan_screen.dart';
import 'screens/battery_check_screen.dart';

import 'screens/communications_center_screen.dart';

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
      routes: {
        '/scan': (context) => const ScanScreen(),
        '/zone_selection': (context) => const ZoneSelectionScreen(),
        '/comms': (context) => const CommunicationsCenterScreen(),
      },
      home: const AuthGate(),
    );
  }
}

/// Listens to Supabase auth state changes and manages active shift restoration:
/// 1. No session → LoginScreen
/// 2. Session exists → Verify server role ('volunteer' or 'admin')
/// 3. Session exists + role valid → Attempt restoring persistent shift
/// 4. If shift restored and verified against server → ScanScreen
/// 5. Otherwise → BatteryCheckScreen → EventPickerScreen → ZoneSelectionScreen
class AuthGate extends StatefulWidget {
  final VolunteerAssignmentRepository? assignmentRepository;

  const AuthGate({super.key, this.assignmentRepository});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final VolunteerAssignmentRepository _assignmentRepo;

  @override
  void initState() {
    super.initState();
    _assignmentRepo = widget.assignmentRepository ?? VolunteerAssignmentRepositoryImpl();
  }

  Future<Widget> _resolveAuthenticatedDestination(User user) async {
    SessionState.instance.volunteerId = user.id;

    // Step 1: Authoritative server role check
    final role = await _assignmentRepo.getVolunteerRole(user.id);
    if (role != 'volunteer' && role != 'admin') {
      await Supabase.instance.client.auth.signOut();
      await SessionState.instance.clear();
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.gpp_bad, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Unauthorized Staff Access',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your account role ("${role ?? "none"}") does not have Volunteer privileges.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    setState(() {});
                  },
                  child: const Text('Back to Login'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    SessionState.instance.userRole = role;

    // Step 2: Attempt restoring active shift from persistent storage
    if (SessionState.instance.eventId == null || SessionState.instance.zone == null) {
      final restored = await SessionState.instance.restoreAndValidate(_assignmentRepo);
      if (restored) {
        return const ScanScreen();
      }
    } else {
      // In-memory shift already active — revalidate against server
      final isValid = await _assignmentRepo.isAssignmentValid(
        volunteerId: user.id,
        eventId: SessionState.instance.eventId!,
        zoneId: SessionState.instance.zoneId,
      );
      if (isValid) {
        return const ScanScreen();
      } else {
        SessionState.instance.eventId = null;
        SessionState.instance.zoneId = null;
        SessionState.instance.zoneName = null;
        SessionState.instance.zoneCode = null;
        await SessionState.instance.clearPersistence();
      }
    }

    // Battery check first
    if (!SessionState.instance.batteryChecked) {
      return const BatteryCheckScreen();
    }

    // Event selection
    if (SessionState.instance.eventId == null) {
      return const EventPickerScreen();
    }

    // Zone selection
    if (SessionState.instance.zone == null) {
      return const ZoneSelectionScreen();
    }

    return const ScanScreen();
  }

  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;

    return StreamBuilder<AuthState>(
      stream: client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final session = snapshot.data?.session ?? client.auth.currentSession;

        if (session == null) {
          SessionState.instance.clear();
          return const LoginScreen();
        }

        return FutureBuilder<Widget>(
          future: _resolveAuthenticatedDestination(session.user),
          builder: (context, destSnapshot) {
            if (destSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (destSnapshot.hasError) {
              return Scaffold(
                body: Center(
                  child: Text('Session Error: ${destSnapshot.error}'),
                ),
              );
            }
            return destSnapshot.data ?? const LoginScreen();
          },
        );
      },
    );
  }
}
