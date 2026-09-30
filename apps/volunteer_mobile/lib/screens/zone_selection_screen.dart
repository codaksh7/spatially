import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/event_zone.dart';
import '../repositories/volunteer_assignment_repository.dart';
import '../services/session_state.dart';

/// Shown after login + event selection, before the main scan screen.
/// The volunteer selects their normalized zone/station once per session.
/// Normalized zone options come from public.event_zones (via VolunteerAssignmentRepository).
class ZoneSelectionScreen extends StatefulWidget {
  final VolunteerAssignmentRepository? assignmentRepository;

  const ZoneSelectionScreen({super.key, this.assignmentRepository});

  @override
  State<ZoneSelectionScreen> createState() => _ZoneSelectionScreenState();
}

class _ZoneSelectionScreenState extends State<ZoneSelectionScreen> {
  late final VolunteerAssignmentRepository _assignmentRepo;
  late Future<List<EventZone>> _zonesFuture;
  EventZone? _selectedZone;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _assignmentRepo = widget.assignmentRepository ?? VolunteerAssignmentRepositoryImpl();
    final eventId = SessionState.instance.eventId;
    if (eventId != null) {
      _zonesFuture = _assignmentRepo.getEventZones(eventId);
    } else {
      _zonesFuture = Future.value([]);
    }
  }

  void _reloadZones() {
    setState(() {
      final eventId = SessionState.instance.eventId;
      if (eventId != null) {
        _zonesFuture = _assignmentRepo.getEventZones(eventId);
      } else {
        _zonesFuture = Future.value([]);
      }
    });
  }

  Future<void> _confirm() async {
    final eventId = SessionState.instance.eventId;
    if (eventId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active event found. Please re-select event.')),
      );
      Navigator.of(context).pushReplacementNamed('/event_picker');
      return;
    }

    if (_selectedZone == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an operational zone before continuing.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    // Populate session state and persist active shift to local storage (survives app restart)
    await SessionState.instance.persistShift(
      newEventId: eventId,
      newZoneId: _selectedZone!.id,
      newZoneName: _selectedZone!.name,
      newZoneCode: _selectedZone!.code,
      newEventName: SessionState.instance.eventName,
      isRoving: false,
      capacityLimit: _selectedZone!.capacityLimit,
    );

    if (mounted) {
      // Navigate to ScanScreen
      Navigator.of(context).pushReplacementNamed('/scan');
    }
  }

  Future<void> _signOut() async {
    await SessionState.instance.clear();
    await Supabase.instance.client.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final activeEventName = SessionState.instance.eventName ?? 'Assigned Event';

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
                text: 'Station Setup',
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
            tooltip: 'Refresh zones',
            onPressed: _reloadZones,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: _signOut,
          ),
        ],
      ),
      body: FutureBuilder<List<EventZone>>(
        future: _zonesFuture,
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
                      'Unable to load operational zones for this event. Please check your network connection and retry.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _reloadZones,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Navigator.of(context).pushReplacementNamed('/event_picker'),
                      child: const Text('Choose Different Event'),
                    ),
                  ],
                ),
              ),
            );
          }

          final zones = snapshot.data ?? [];

          if (zones.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.map_outlined, size: 56, color: Colors.blueGrey.shade400),
                    const SizedBox(height: 16),
                    Text(
                      'No Operational Zones',
                      style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No zones are configured for $activeEventName.\nPlease ask your event coordinator to set up zones.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      onPressed: _reloadZones,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Check Again'),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Navigator.of(context).pushReplacementNamed('/event_picker'),
                      child: const Text('Back to Events'),
                    ),
                  ],
                ),
              ),
            );
          }

          // If a zone is pre-assigned in SessionState, match it
          final currentZoneId = SessionState.instance.zoneId;
          if (_selectedZone == null && currentZoneId != null) {
            final match = zones.where((z) => z.id == currentZoneId).firstOrNull;
            if (match != null) {
              _selectedZone = match;
            }
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Event context banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.event, size: 20, color: Colors.blue.shade700),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'CURRENT EVENT',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade800,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              activeEventName,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue.shade900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pushReplacementNamed('/event_picker'),
                        child: const Text('Change', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  'Select Your Station',
                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  'Your crowd telemetry and ticket check-ins will be linked to this operational zone.',
                  style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 20),

                DropdownButtonFormField<EventZone>(
                  initialValue: _selectedZone,
                  hint: const Text('Choose a station zone...'),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    prefixIcon: const Icon(Icons.location_on_outlined),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                  items: zones.map((zone) {
                    return DropdownMenuItem<EventZone>(
                      value: zone,
                      child: Text(
                        '${zone.name} (${zone.code})',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedZone = value;
                    });
                  },
                ),
                const SizedBox(height: 16),

                if (_selectedZone != null)
                  Card(
                    color: Colors.grey.shade50,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.info_outline, size: 16, color: Colors.blueGrey),
                              const SizedBox(width: 6),
                              Text(
                                'Station Identity',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blueGrey.shade800,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Display Name:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              Text(_selectedZone!.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Operational Code:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              Text(_selectedZone!.code, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.indigo)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Capacity Limit:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              Text('${_selectedZone!.capacityLimit} persons', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: (_isSaving || _selectedZone == null) ? null : _confirm,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Confirm Station & Open Dashboard', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
