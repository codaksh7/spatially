import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/volunteer_assignment.dart';
import '../repositories/volunteer_assignment_repository.dart';
import '../services/session_state.dart';

/// Shown after login (and battery check), before ZoneSelectionScreen.
/// Fetches volunteer_assignments for the logged-in user, joined with events and zones,
/// and lets the volunteer pick which event they are working today.
class EventPickerScreen extends StatefulWidget {
  final VolunteerAssignmentRepository? assignmentRepository;

  const EventPickerScreen({super.key, this.assignmentRepository});

  @override
  State<EventPickerScreen> createState() => _EventPickerScreenState();
}

class _EventPickerScreenState extends State<EventPickerScreen> {
  late final VolunteerAssignmentRepository _assignmentRepo;
  late Future<List<VolunteerAssignment>> _assignmentsFuture;

  @override
  void initState() {
    super.initState();
    _assignmentRepo = widget.assignmentRepository ?? VolunteerAssignmentRepositoryImpl();
    final volunteerId = SessionState.instance.volunteerId;
    if (volunteerId != null) {
      _assignmentsFuture = _assignmentRepo.getAssignments(volunteerId);
    } else {
      _assignmentsFuture = Future.value([]);
    }
  }

  void _reloadAssignments() {
    setState(() {
      final volunteerId = SessionState.instance.volunteerId;
      if (volunteerId != null) {
        _assignmentsFuture = _assignmentRepo.getAssignments(volunteerId);
      } else {
        _assignmentsFuture = Future.value([]);
      }
    });
  }

  Future<void> _signOut() async {
    await SessionState.instance.clear();
    await Supabase.instance.client.auth.signOut();
  }

  Future<void> _selectEvent(VolunteerAssignment assignment) async {
    SessionState.instance.eventId = assignment.eventId;
    SessionState.instance.eventName = assignment.eventName;

    // If the coordinator pre-assigned a specific normalized zone,
    // lock that assignment, persist shift, and navigate straight to scan.
    if (assignment.zoneId != null && assignment.zoneName != null) {
      await SessionState.instance.persistShift(
        newEventId: assignment.eventId,
        newZoneId: assignment.zoneId,
        newZoneName: assignment.zoneName!,
        newZoneCode: assignment.zoneCode,
        newEventName: assignment.eventName,
        isRoving: false,
        capacityLimit: assignment.capacityLimit,
      );
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/scan');
      }
    } else {
      // Event-wide / Roving assignment: navigate to ZoneSelectionScreen to select station
      await SessionState.instance.persistShift(
        newEventId: assignment.eventId,
        newZoneId: null,
        newZoneName: null,
        newZoneCode: null,
        newEventName: assignment.eventName,
        isRoving: true,
      );
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/zone_selection');
      }
    }
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
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh assignments',
            onPressed: _reloadAssignments,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: _signOut,
          ),
        ],
      ),
      body: FutureBuilder<List<VolunteerAssignment>>(
        future: _assignmentsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.wifi_off_rounded, size: 56, color: Colors.amber[700]),
                    const SizedBox(height: 16),
                    Text(
                      'Connection Issue',
                      style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Unable to load your volunteer assignments. Please check your network connection and try again.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _reloadAssignments,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final assignments = snapshot.data ?? [];

          if (assignments.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.event_busy_rounded, size: 56, color: Colors.blueGrey.shade400),
                    const SizedBox(height: 16),
                    Text(
                      'No Active Assignments',
                      style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No active event assignments found for your volunteer account.\nPlease contact your event coordinator to be assigned.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      onPressed: _reloadAssignments,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Check for Updates'),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: assignments.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final assignment = assignments[index];
              final eventName = assignment.eventName;
              final venue = assignment.venue;
              final status = assignment.eventStatus;

              String formattedDate = 'Unknown Date';
              if (assignment.eventDate != null) {
                final parsed = assignment.eventDate!;
                final month = parsed.month.toString().padLeft(2, '0');
                final day = parsed.day.toString().padLeft(2, '0');
                final hour = parsed.hour.toString().padLeft(2, '0');
                final minute = parsed.minute.toString().padLeft(2, '0');
                formattedDate = '${parsed.year}-$month-$day $hour:$minute';
              }

              return Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _selectEvent(assignment),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                eventName,
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: status == 'live' ? Colors.green.shade50 : Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: status == 'live' ? Colors.green.shade300 : Colors.blue.shade300,
                                ),
                              ),
                              child: Text(
                                status.toUpperCase(),
                                style: TextStyle(
                                  color: status == 'live' ? Colors.green.shade800 : Colors.blue.shade800,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.location_on_outlined, size: 14, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '$venue • $formattedDate',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: assignment.isRoving ? Colors.purple.shade50 : Colors.teal.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                assignment.isRoving ? Icons.directions_walk : Icons.pin_drop,
                                size: 14,
                                color: assignment.isRoving ? Colors.purple.shade700 : Colors.teal.shade700,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                assignment.isRoving
                                    ? 'Roving Assignment • All Event Zones'
                                    : 'Station: ${assignment.zoneName} (${assignment.zoneCode ?? "Zone"})',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: assignment.isRoving ? Colors.purple.shade800 : Colors.teal.shade800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
