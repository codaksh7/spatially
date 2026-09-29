/// SPATIALLY — VOLUNTEER BLOCK 2.5C
/// Screen for creating, viewing, and acknowledging shift handoffs.
library;

import 'package:flutter/material.dart';
import '../models/volunteer_shift.dart';
import '../models/shift_handoff.dart';
import '../models/event_team.dart';
import '../models/operational_incident.dart';
import '../repositories/team_shift_repository.dart';
import '../repositories/incident_repository.dart';
import '../services/session_state.dart';
import 'incident_detail_screen.dart';

class ShiftHandoffScreen extends StatefulWidget {
  final VolunteerShift shift;
  final TeamShiftRepository? repository;

  const ShiftHandoffScreen({
    super.key,
    required this.shift,
    this.repository,
  });

  @override
  State<ShiftHandoffScreen> createState() => _ShiftHandoffScreenState();
}

class _ShiftHandoffScreenState extends State<ShiftHandoffScreen> {
  late final TeamShiftRepository _repo;
  ShiftHandoff? _existingHandoff;
  bool _isLoading = true;
  bool _isSubmitting = false;

  // Form controllers
  final _summaryCtrl = TextEditingController();
  final _equipmentCtrl = TextEditingController(text: 'Equipment operational; battery good.');
  final _attendeeNotesCtrl = TextEditingController();

  List<TeamMember> _availableStaff = [];
  TeamMember? _selectedIncomingStaff;

  List<OperationalIncident> _activeIncidents = [];
  final Set<String> _selectedIncidentIds = {};

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? TeamShiftRepository.instance;
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final eventId = widget.shift.eventId;

      // 1. Check if handoff already exists for this shift
      final handoffs = await _repo.fetchHandoffs(eventId: eventId, forceRefresh: true);
      final match = handoffs.where((h) => h.shiftId == widget.shift.id).toList();
      if (match.isNotEmpty) {
        _existingHandoff = match.first;
      }

      // 2. Fetch team members for incoming staff picker
      final teams = await _repo.fetchTeams(eventId: eventId);
      final staffList = <TeamMember>[];
      for (final t in teams) {
        staffList.addAll(t.members);
      }
      // Remove self
      staffList.removeWhere((m) => m.volunteerId == SessionState.instance.volunteerId);

      // 3. Fetch active incidents for linking
      final incidents = await IncidentRepository.instance.fetchIncidents(forceRefresh: true);
      final activeIssues = incidents.where((i) => !i.isResolved).toList();

      if (mounted) {
        setState(() {
          _availableStaff = staffList;
          _activeIncidents = activeIssues;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _submitHandoff() async {
    final summary = _summaryCtrl.text.trim();
    if (summary.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide an operational summary.'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await _repo.createHandoff(
        shiftId: widget.shift.id,
        operationalSummary: summary,
        incomingVolunteerId: _selectedIncomingStaff?.volunteerId,
        equipmentCondition: _equipmentCtrl.text.trim(),
        attendeeNotes: _attendeeNotesCtrl.text.trim(),
        unresolvedIncidentIds: _selectedIncidentIds.toList(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Shift handoff briefing submitted successfully!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting handoff: $e'), backgroundColor: Colors.red),
        );
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _acknowledgeHandoff() async {
    if (_existingHandoff == null || _isSubmitting) return;

    setState(() => _isSubmitting = true);
    try {
      await _repo.acknowledgeHandoff(_existingHandoff!.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Handoff acknowledged. Responsibility transferred.'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Shift Handoff Briefing', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E293B),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _existingHandoff != null
                  ? _buildExistingHandoffView()
                  : _buildHandoffCreationForm(),
            ),
    );
  }

  Widget _buildExistingHandoffView() {
    final h = _existingHandoff!;
    final isAcknowledged = h.status == HandoffStatus.acknowledged;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isAcknowledged ? const Color(0xFF064E3B) : const Color(0xFF312E81),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isAcknowledged ? const Color(0xFF059669) : const Color(0xFF6366F1),
            ),
          ),
          child: Row(
            children: [
              Icon(
                isAcknowledged ? Icons.check_circle : Icons.pending_actions,
                color: Colors.white,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAcknowledged ? 'HANDOFF ACKNOWLEDGED' : 'HANDOFF PENDING ACKNOWLEDGMENT',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isAcknowledged
                          ? 'Incoming staff confirmed takeover at ${h.acknowledgedAt?.hour.toString().padLeft(2, '0')}:${h.acknowledgedAt?.minute.toString().padLeft(2, '0')}'
                          : 'Awaiting incoming volunteer or lead acknowledgment',
                      style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Outgoing Staff: ${h.outgoingVolunteerName}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              ),
              if (h.incomingVolunteerName != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Incoming Staff: ${h.incomingVolunteerName}',
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                'Zone / Station: ${h.zoneName ?? 'All Zones'}',
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              ),
              const SizedBox(height: 14),
              const Divider(color: Color(0xFF334155)),
              const SizedBox(height: 10),
              const Text('Operational Summary:', style: TextStyle(color: Color(0xFFE2E8F0), fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 4),
              Text(h.operationalSummary, style: const TextStyle(color: Colors.white, fontSize: 13)),
              if (h.equipmentCondition != null && h.equipmentCondition!.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Equipment & Scanner Condition:', style: TextStyle(color: Color(0xFFE2E8F0), fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                Text(h.equipmentCondition!, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
              ],
              if (h.attendeeNotes != null && h.attendeeNotes!.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Attendee Issues Handled:', style: TextStyle(color: Color(0xFFE2E8F0), fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                Text(h.attendeeNotes!, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
              ],
            ],
          ),
        ),
        if (h.unresolvedIncidentIds.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text('Linked Active Incidents:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          ...h.unresolvedIncidentIds.map((id) {
            return Card(
              color: const Color(0xFF1E293B),
              child: ListTile(
                leading: const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
                title: Text('Incident #$id', style: const TextStyle(color: Colors.white, fontSize: 13)),
                subtitle: const Text('Tap to view incident details', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                trailing: const Icon(Icons.arrow_forward_ios, color: Color(0xFF64748B), size: 14),
                onTap: () async {
                  final incidents = await IncidentRepository.instance.fetchIncidents();
                  final inc = incidents.where((i) => i.id == id).toList();
                  if (inc.isNotEmpty && mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => IncidentDetailScreen(
                          incidentId: inc.first.id,
                          initialIncident: inc.first,
                        ),
                      ),
                    );
                  }
                },
              ),
            );
          }),
        ],
        if (!isAcknowledged) ...[
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.check, color: Colors.white),
              label: const Text('ACKNOWLEDGE & ACCEPT HANDOFF', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: _isSubmitting ? null : _acknowledgeHandoff,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildHandoffCreationForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Color(0xFF6366F1), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Prepare a shift handover for incoming relief or team lead. Document station status, scanner condition, and pending issues.',
                  style: TextStyle(color: Colors.grey.shade300, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text('Operational Summary *', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 6),
        TextField(
          controller: _summaryCtrl,
          maxLines: 3,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Describe flow, crowd state, queue bottlenecks, or general briefing...',
            hintStyle: const TextStyle(color: Color(0xFF64748B)),
            filled: true,
            fillColor: const Color(0xFF1E293B),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Incoming Staff Member (Optional)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 6),
        DropdownButtonFormField<TeamMember>(
          initialValue: _selectedIncomingStaff,
          dropdownColor: const Color(0xFF1E293B),
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF1E293B),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            hintText: 'Select incoming volunteer / supervisor',
            hintStyle: const TextStyle(color: Color(0xFF64748B)),
          ),
          items: _availableStaff.map((m) {
            return DropdownMenuItem(
              value: m,
              child: Text('${m.fullName} (${m.role.toUpperCase()})'),
            );
          }).toList(),
          onChanged: (val) => setState(() => _selectedIncomingStaff = val),
        ),
        const SizedBox(height: 16),
        const Text('Equipment & Scanner Condition', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 6),
        TextField(
          controller: _equipmentCtrl,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Scanner battery level, connectivity, charging station...',
            hintStyle: const TextStyle(color: Color(0xFF64748B)),
            filled: true,
            fillColor: const Color(0xFF1E293B),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Attendee Inquiries / Issues Handled', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 6),
        TextField(
          controller: _attendeeNotesCtrl,
          maxLines: 2,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Notable attendee questions, accessibility assists, or lost items...',
            hintStyle: const TextStyle(color: Color(0xFF64748B)),
            filled: true,
            fillColor: const Color(0xFF1E293B),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        if (_activeIncidents.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text('Attach Unresolved Incidents', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: _activeIncidents.map((inc) {
              final isSel = _selectedIncidentIds.contains(inc.id);
              return FilterChip(
                label: Text('${inc.title} (${inc.priority.label})'),
                selected: isSel,
                selectedColor: const Color(0xFF6366F1),
                backgroundColor: const Color(0xFF1E293B),
                labelStyle: TextStyle(color: isSel ? Colors.white : const Color(0xFF94A3B8), fontSize: 12),
                onSelected: (val) {
                  setState(() {
                    if (val) {
                      _selectedIncidentIds.add(inc.id);
                    } else {
                      _selectedIncidentIds.remove(inc.id);
                    }
                  });
                },
              );
            }).toList(),
          ),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.send, color: Colors.white),
            label: const Text('SUBMIT SHIFT HANDOFF', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            onPressed: _isSubmitting ? null : _submitHandoff,
          ),
        ),
      ],
    );
  }
}
