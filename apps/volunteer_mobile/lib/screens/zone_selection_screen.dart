import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/session_state.dart';

/// Shown immediately after login, before the main scan screen.
/// The volunteer selects their zone once per session.
/// On confirm, writes the selection into SessionState.instance.zone
/// and pops — the StreamBuilder in main.dart then routes to ScanScreen
/// because zone is now non-null.
class ZoneSelectionScreen extends StatefulWidget {
  const ZoneSelectionScreen({super.key});

  @override
  State<ZoneSelectionScreen> createState() => _ZoneSelectionScreenState();
}

class _ZoneSelectionScreenState extends State<ZoneSelectionScreen> {
  static const List<String> _zones = [
    'Entrance',
    'Main Stage',
    'Food Court',
    'Exit',
  ];

  String? _selectedZone;

  void _confirm() {
    if (_selectedZone == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a zone before continuing.')),
      );
      return;
    }

    // Populate session state — volunteerId was already set in main.dart's
    // StreamBuilder when the auth event fired.
    final session = SessionState.instance;
    session.zone = _selectedZone;

    // No explicit navigation needed: main.dart's StreamBuilder checks
    // SessionState.instance.zone after each setState trigger. We push a
    // dummy setState via Navigator.pop so the parent rebuilds and re-routes.
    // Actually, since the StreamBuilder only fires on auth events (not zone
    // changes), we need to use a Notifier approach or Navigator.pushReplacement.
    // The simplest CFE-safe approach: pushReplacement to ScanScreen directly.
    //
    // This is the one intentional direct navigation in the app. The
    // StreamBuilder handles login→zone and logout→login transitions; this
    // handles the zone→scan transition which is not an auth event.
    Navigator.of(context).pushReplacementNamed('/scan');
  }

  Future<void> _signOut() async {
    final supabaseInstance = Supabase.instance;
    final client = supabaseInstance.client;
    final auth = client.auth;
    SessionState.instance.clear();
    await auth.signOut();
    // StreamBuilder in main.dart will see the signed-out event and show LoginScreen.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Your Zone'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: _signOut,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Which zone are you stationed at?',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            DropdownButtonFormField<String>(
              value: _selectedZone,
              hint: const Text('Select zone'),
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: _zones.map((zone) {
                return DropdownMenuItem<String>(
                  value: zone,
                  child: Text(zone),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedZone = value;
                });
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _confirm,
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
  }
}
