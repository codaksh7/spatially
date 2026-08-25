import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/session_state.dart';

/// Shown after login (and battery check), before ZoneSelectionScreen.
/// Fetches volunteer_assignments for the logged-in user, joined with events,
/// and lets the volunteer pick which event they are working today.
class EventPickerScreen extends StatefulWidget {
  const EventPickerScreen({super.key});

  @override
  State<EventPickerScreen> createState() => _EventPickerScreenState();
}

class _EventPickerScreenState extends State<EventPickerScreen> {
  late final Future<List<Map<String, dynamic>>> _assignmentsFuture;

  @override
  void initState() {
    super.initState();
    final volunteerId = SessionState.instance.volunteerId;
    if (volunteerId != null) {
      _assignmentsFuture = Supabase.instance.client
          .from('volunteer_assignments')
          .select('event_id, events(id, name, venue, event_date, status)')
          .eq('volunteer_id', volunteerId);
    } else {
      _assignmentsFuture = Future.value([]);
    }
  }

  Future<void> _signOut() async {
    SessionState.instance.clear();
    await Supabase.instance.client.auth.signOut();
  }

  void _selectEvent(Map<String, dynamic> assignment) {
    final event = assignment['events'] as Map<String, dynamic>;
    SessionState.instance.eventId = event['id'] as String;

    // Navigate to ZoneSelectionScreen — not a named route, push directly.
    // Zone selection is not an auth event so StreamBuilder won't handle it.
    Navigator.of(context).pushReplacementNamed('/zone_selection');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'Spatially ',
                style: GoogleFonts.audiowide(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextSpan(
                text: 'for Volunteer',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: _signOut,
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _assignmentsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error loading events: ${snapshot.error}'));
          }

          final assignments = snapshot.data ?? [];

          if (assignments.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  'No events assigned. Contact your event coordinator.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              ),
            );
          }

          return ListView.builder(
            itemCount: assignments.length,
            itemBuilder: (context, index) {
              final assignment = assignments[index];
              final event = assignment['events'] as Map<String, dynamic>?;
              final eventName = event?['name'] ?? 'Unknown Event';
              final venue = event?['venue'] ?? 'TBA';
              final status = (event?['status'] as String?) ?? 'unknown';

              String formattedDate = 'Unknown Date';
              if (event?['event_date'] != null) {
                final parsed = DateTime.parse(event!['event_date'] as String).toLocal();
                final month = parsed.month.toString().padLeft(2, '0');
                final day = parsed.day.toString().padLeft(2, '0');
                final hour = parsed.hour.toString().padLeft(2, '0');
                final minute = parsed.minute.toString().padLeft(2, '0');
                formattedDate = '${parsed.year}-$month-$day $hour:$minute';
              }

              return ListTile(
                title: Text(eventName),
                subtitle: Text('$venue • $formattedDate'),
                trailing: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    color: status == 'live' ? Colors.green : Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () => _selectEvent(assignment),
              );
            },
          );
        },
      ),
    );
  }
}
