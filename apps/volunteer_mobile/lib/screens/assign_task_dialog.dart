/// SPATIALLY — VOLUNTEER BLOCK 2.5C
/// Dialog modal allowing supervisors and leads to assign operational floor tasks.
library;

import 'package:flutter/material.dart';
import '../models/supervisor_task.dart';
import '../models/event_team.dart';
import '../models/event_zone.dart';
import '../repositories/team_shift_repository.dart';
import '../repositories/volunteer_assignment_repository.dart';
import '../services/session_state.dart';

class AssignTaskDialog extends StatefulWidget {
  final EventTeam? team;
  final TeamShiftRepository? repository;

  const AssignTaskDialog({
    super.key,
    this.team,
    this.repository,
  });

  @override
  State<AssignTaskDialog> createState() => _AssignTaskDialogState();
}

class _AssignTaskDialogState extends State<AssignTaskDialog> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  TeamMember? _selectedMember;
  EventZone? _selectedZone;
  TaskPriority _priority = TaskPriority.normal;
  final int _dueMinutes = 30;

  List<TeamMember> _teamMembers = [];
  List<EventZone> _eventZones = [];
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadDependencies();
  }

  Future<void> _loadDependencies() async {
    final eventId = SessionState.instance.eventId;
    if (eventId == null) return;

    try {
      final repo = widget.repository ?? TeamShiftRepository.instance;
      final teams = await repo.fetchTeams(eventId: eventId);
      final members = <TeamMember>[];

      if (widget.team != null) {
        members.addAll(widget.team!.members);
      } else {
        for (final t in teams) {
          members.addAll(t.members);
        }
      }

      final assignmentRepo = VolunteerAssignmentRepositoryImpl();
      final zones = await assignmentRepo.getEventZones(eventId);

      if (mounted) {
        setState(() {
          _teamMembers = members;
          _eventZones = zones;
          if (_teamMembers.isNotEmpty) _selectedMember = _teamMembers.first;
          if (_eventZones.isNotEmpty) _selectedZone = _eventZones.first;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitTask() async {
    final title = _titleCtrl.text.trim();
    final desc = _descCtrl.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a task title.'), backgroundColor: Colors.orange),
      );
      return;
    }

    if (_selectedMember == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a volunteer to assign.'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final repo = widget.repository ?? TeamShiftRepository.instance;
      final dueTime = DateTime.now().add(Duration(minutes: _dueMinutes));

      await repo.createTask(
        eventId: SessionState.instance.eventId!,
        title: title,
        description: desc,
        assignedToId: _selectedMember!.volunteerId,
        teamId: widget.team?.id ?? _selectedMember!.teamId,
        zoneId: _selectedZone?.id,
        priority: _priority,
        dueTime: dueTime,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task assigned successfully!'), backgroundColor: Color(0xFF10B981)),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error assigning task: $e'), backgroundColor: Colors.red),
        );
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: const Text('Assign Operational Task', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      content: _isLoading
          ? const SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator(color: Color(0xFF6366F1))),
            )
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Task Title *', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _titleCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'e.g. Check Hall A queue or Replace scanner',
                      hintStyle: const TextStyle(color: Color(0xFF64748B)),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Assign To Volunteer *', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<TeamMember>(
                    initialValue: _selectedMember,
                    dropdownColor: const Color(0xFF1E293B),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    items: _teamMembers.map((m) {
                      return DropdownMenuItem(
                        value: m,
                        child: Text('${m.fullName} (${m.role})'),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedMember = val),
                  ),
                  const SizedBox(height: 14),
                  const Text('Priority', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Row(
                    children: TaskPriority.values.map((p) {
                      final isSel = _priority == p;
                      Color c = const Color(0xFF6366F1);
                      if (p == TaskPriority.urgent) c = const Color(0xFFEF4444);
                      if (p == TaskPriority.important) c = const Color(0xFFF59E0B);

                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(p.label),
                          selected: isSel,
                          selectedColor: c,
                          backgroundColor: const Color(0xFF0F172A),
                          labelStyle: TextStyle(
                            color: isSel ? Colors.white : const Color(0xFF94A3B8),
                            fontSize: 11,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                          ),
                          onSelected: (_) => setState(() => _priority = p),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  const Text('Target Zone / Station', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<EventZone>(
                    initialValue: _selectedZone,
                    dropdownColor: const Color(0xFF1E293B),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    items: _eventZones.map((z) {
                      return DropdownMenuItem(value: z, child: Text(z.name));
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedZone = val),
                  ),
                  const SizedBox(height: 14),
                  const Text('Instructions / Notes', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _descCtrl,
                    maxLines: 2,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Specific operational instructions...',
                      hintStyle: const TextStyle(color: Color(0xFF64748B)),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
          onPressed: _isSubmitting ? null : _submitTask,
          child: const Text('Assign Task', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
