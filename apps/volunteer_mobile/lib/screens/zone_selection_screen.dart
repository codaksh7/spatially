import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/session_state.dart';

/// Shown after login + event selection, before the main scan screen.
/// The volunteer selects their zone once per session.
/// Zone options come from the selected event's `zones` array column.
class ZoneSelectionScreen extends StatefulWidget {
  const ZoneSelectionScreen({super.key});

  @override
  State<ZoneSelectionScreen> createState() => _ZoneSelectionScreenState();
}

class _ZoneSelectionScreenState extends State<ZoneSelectionScreen> {
  late final Future<List<String>> _zonesFuture;
  String? _selectedZone;

  @override
  void initState() {
    super.initState();
    final eventId = SessionState.instance.eventId;
    if (eventId != null) {
      _zonesFuture = Supabase.instance.client
          .from('events')
          .select('zones')
          .eq('id', eventId)
          .single()
          .then((row) {
        final zonesRaw = row['zones'];
        if (zonesRaw is List) {
          return zonesRaw.map((z) => z.toString()).toList();
        }
        return <String>[];
      });
    } else {
      _zonesFuture = Future.value([]);
    }
  }

  void _confirm() {
    if (_selectedZone == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a zone before continuing.')),
      );
      return;
    }

    // Populate session state — volunteerId and eventId were already set upstream.
    SessionState.instance.zone = _selectedZone;

    // Navigate to ScanScreen directly. This is not an auth event so
    // the StreamBuilder in main.dart will not handle this transition.
    Navigator.of(context).pushReplacementNamed('/scan');
  }

  Future<void> _signOut() async {
    SessionState.instance.clear();
    await Supabase.instance.client.auth.signOut();
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
      body: FutureBuilder<List<String>>(
        future: _zonesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error loading zones: ${snapshot.error}'));
          }

          final zones = snapshot.data ?? [];

          if (zones.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  'No zones configured for this event. Contact your coordinator.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              ),
            );
          }

          return Padding(
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
                  items: zones.map((zone) {
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
          );
        },
      ),
    );
  }
}
