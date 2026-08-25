import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../attendee_identity.dart';
import 'my_tickets_screen.dart';

class EventListScreen extends StatefulWidget {
  const EventListScreen({super.key});

  @override
  State<EventListScreen> createState() => _EventListScreenState();
}

class _EventListScreenState extends State<EventListScreen> {
  final Future<List<Map<String, dynamic>>> _eventsFuture = Supabase.instance.client
      .from('events')
      .select()
      .inFilter('status', ['upcoming', 'live'])
      .order('event_date', ascending: true);

  Future<void> _purchaseTicket(BuildContext context, Map<String, dynamic> event) async {
    final eventName = event['name'] ?? 'Unknown Event';
    final eventId = event['id'];
    final attendeeId = AttendeeIdentity.deviceId;

    if (attendeeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Device ID not initialized.')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Get Ticket'),
        content: Text('Get ticket for $eventName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    try {
      // Check for existing ticket
      final existingTicket = await Supabase.instance.client
          .from('tickets')
          .select()
          .eq('event_id', eventId)
          .eq('attendee_id', attendeeId)
          .maybeSingle();

      if (!context.mounted) return;

      if (existingTicket != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You already have a ticket for this event.')),
        );
        return;
      }

      // Insert new ticket
      await Supabase.instance.client.from('tickets').insert({
        'event_id': eventId,
        'attendee_id': attendeeId,
        'ticket_code': const Uuid().v4(),
        'status': 'purchased',
      });

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Successfully got ticket for $eventName!')),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting ticket: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Event'),
        actions: [
          IconButton(
            icon: const Icon(Icons.confirmation_number),
            tooltip: 'My Tickets',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MyTicketsScreen()),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _eventsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error loading events: ${snapshot.error}'));
          }

          final events = snapshot.data;
          if (events == null || events.isEmpty) {
            return const Center(child: Text('No upcoming events found.'));
          }

          return ListView.builder(
            itemCount: events.length,
            itemBuilder: (context, index) {
              final event = events[index];
              final dateStr = event['event_date'] as String;
              final parsedDate = DateTime.parse(dateStr).toLocal();
              
              final month = parsedDate.month.toString().padLeft(2, '0');
              final day = parsedDate.day.toString().padLeft(2, '0');
              final hour = parsedDate.hour.toString().padLeft(2, '0');
              final minute = parsedDate.minute.toString().padLeft(2, '0');
              final formattedDate = '${parsedDate.year}-$month-$day $hour:$minute';

              return ListTile(
                title: Text(event['name'] ?? 'Unknown Event'),
                subtitle: Text('${event['venue'] ?? 'TBA'} • $formattedDate'),
                trailing: Text(
                  (event['status'] as String).toUpperCase(),
                  style: TextStyle(
                    color: event['status'] == 'live' ? Colors.green : Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () => _purchaseTicket(context, event),
              );
            },
          );
        },
      ),
    );
  }
}
