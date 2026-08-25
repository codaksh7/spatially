import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../attendee_identity.dart';
import 'ticket_detail_screen.dart';

class MyTicketsScreen extends StatefulWidget {
  const MyTicketsScreen({super.key});

  @override
  State<MyTicketsScreen> createState() => _MyTicketsScreenState();
}

class _MyTicketsScreenState extends State<MyTicketsScreen> {
  late final Future<List<Map<String, dynamic>>> _ticketsFuture;

  @override
  void initState() {
    super.initState();
    final attendeeId = AttendeeIdentity.deviceId;
    if (attendeeId != null) {
      _ticketsFuture = Supabase.instance.client
          .from('tickets')
          .select('*, events(*)')
          .eq('attendee_id', attendeeId)
          .order('purchased_at', ascending: false);
    } else {
      _ticketsFuture = Future.value([]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Tickets')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _ticketsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error loading tickets: ${snapshot.error}'));
          }

          final tickets = snapshot.data;
          if (tickets == null || tickets.isEmpty) {
            return const Center(child: Text('You have no tickets yet.'));
          }

          return ListView.builder(
            itemCount: tickets.length,
            itemBuilder: (context, index) {
              final ticket = tickets[index];
              final event = ticket['events'] as Map<String, dynamic>?;
              final eventName = event?['name'] ?? 'Unknown Event';
              final venue = event?['venue'] ?? 'TBA';
              
              String formattedDate = 'Unknown Date';
              if (event?['event_date'] != null) {
                final parsedDate = DateTime.parse(event!['event_date'] as String).toLocal();
                final month = parsedDate.month.toString().padLeft(2, '0');
                final day = parsedDate.day.toString().padLeft(2, '0');
                final hour = parsedDate.hour.toString().padLeft(2, '0');
                final minute = parsedDate.minute.toString().padLeft(2, '0');
                formattedDate = '${parsedDate.year}-$month-$day $hour:$minute';
              }

              return ListTile(
                title: Text(eventName),
                subtitle: Text('$venue • $formattedDate'),
                trailing: Text(
                  (ticket['status'] as String).toUpperCase(),
                  style: TextStyle(
                    color: ticket['status'] == 'checked_in' ? Colors.grey : Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TicketDetailScreen(ticket: ticket),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
