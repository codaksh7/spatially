/// SPATIALLY — VOLUNTEER BLOCK 2.5C
/// Screen displaying assigned operational floor tasks with state transitions and incident links.
library;

import 'package:flutter/material.dart';
import '../models/supervisor_task.dart';
import '../repositories/team_shift_repository.dart';
import '../repositories/incident_repository.dart';
import '../services/session_state.dart';
import 'assign_task_dialog.dart';
import 'incident_detail_screen.dart';

class SupervisorTasksScreen extends StatefulWidget {
  final TeamShiftRepository? repository;

  const SupervisorTasksScreen({super.key, this.repository});

  @override
  State<SupervisorTasksScreen> createState() => _SupervisorTasksScreenState();
}

class _SupervisorTasksScreenState extends State<SupervisorTasksScreen>
    with SingleTickerProviderStateMixin {
  late final TeamShiftRepository _repo;
  late final TabController _tabController;
  List<SupervisorTask> _tasks = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? TeamShiftRepository.instance;
    _tabController = TabController(length: 3, vsync: this);
    _loadTasks();

    final eventId = SessionState.instance.eventId ?? '';
    _repo.subscribeRealtime(
      eventId: eventId,
      onDataChanged: () {
        if (mounted) _loadTasks(silent: true);
      },
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _repo.unsubscribeRealtime();
    super.dispose();
  }

  Future<void> _loadTasks({bool silent = false}) async {
    final eventId = SessionState.instance.eventId;
    if (eventId == null) return;

    if (!silent) setState(() => _isLoading = true);

    try {
      final list = await _repo.fetchTasks(eventId: eventId, forceRefresh: true);
      if (mounted) {
        setState(() {
          _tasks = list;
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Failed to load tasks: $e';
        });
      }
    }
  }

  Future<void> _updateTask(SupervisorTask task, TaskStatus newStatus) async {
    String? notes;
    if (newStatus == TaskStatus.completed) {
      final notesCtrl = TextEditingController();
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('Complete Task', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Mark this task as completed. You can optionally add completion notes.',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                maxLines: 2,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Completion notes / outcome...',
                  hintStyle: const TextStyle(color: Color(0xFF64748B)),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Complete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      if (confirm != true) return;
      notes = notesCtrl.text.trim();
    }

    try {
      await _repo.updateTaskStatus(task.id, newStatus, completionNotes: notes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Task status updated to ${newStatus.label}.'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        _loadTasks(silent: true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating task: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final myId = SessionState.instance.volunteerId;
    final myTasks = _tasks.where((t) => t.assignedToId == myId && !t.isCompleted).toList();
    final teamTasks = _tasks.where((t) => !t.isCompleted).toList();
    final completedTasks = _tasks.where((t) => t.isCompleted).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Supervisor Tasks', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E293B),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF6366F1),
          tabs: [
            Tab(text: 'My Tasks (${myTasks.length})'),
            Tab(text: 'Team Tasks (${teamTasks.length})'),
            Tab(text: 'Completed (${completedTasks.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _loadTasks, child: const Text('Retry')),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTaskList(myTasks, isMyTaskTab: true),
                    _buildTaskList(teamTasks),
                    _buildTaskList(completedTasks),
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF6366F1),
        icon: const Icon(Icons.add_task, color: Colors.white),
        label: const Text('Assign Task', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () async {
          final res = await showDialog<bool>(
            context: context,
            builder: (_) => const AssignTaskDialog(),
          );
          if (res == true) _loadTasks(silent: true);
        },
      ),
    );
  }

  Widget _buildTaskList(List<SupervisorTask> list, {bool isMyTaskTab = false}) {
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.task_alt, color: Color(0xFF64748B), size: 54),
              const SizedBox(height: 12),
              const Text('No Tasks', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                isMyTaskTab ? 'You have no pending tasks assigned.' : 'No active operational tasks in this category.',
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadTasks(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        itemBuilder: (ctx, i) => _buildTaskCard(list[i]),
      ),
    );
  }

  Widget _buildTaskCard(SupervisorTask task) {
    Color priorityColor = const Color(0xFF6366F1);
    if (task.priority == TaskPriority.urgent) priorityColor = const Color(0xFFEF4444);
    if (task.priority == TaskPriority.important) priorityColor = const Color(0xFFF59E0B);

    final isAssignedToMe = task.assignedToId == SessionState.instance.volunteerId;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: task.priority == TaskPriority.urgent ? const Color(0xFFEF4444) : const Color(0xFF334155),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: priorityColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: priorityColor, width: 0.8),
                ),
                child: Text(
                  task.priority.label.toUpperCase(),
                  style: TextStyle(color: priorityColor, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  task.status.label,
                  style: TextStyle(
                    color: task.isCompleted ? const Color(0xFF10B981) : Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            task.title,
            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
          ),
          if (task.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(task.description, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.person_outline, size: 14, color: Color(0xFF64748B)),
              const SizedBox(width: 4),
              Text(
                'Assigned to: ${isAssignedToMe ? 'Me' : task.assignedToName}',
                style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 12),
              ),
              const SizedBox(width: 14),
              const Icon(Icons.supervisor_account, size: 14, color: Color(0xFF64748B)),
              const SizedBox(width: 4),
              Text('By: ${task.supervisorName}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
            ],
          ),
          if (task.zoneName != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.place_outlined, size: 14, color: Color(0xFF64748B)),
                const SizedBox(width: 4),
                Text('Location: ${task.zoneName}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
              ],
            ),
          ],
          if (task.linkedIncidentId != null) ...[
            const SizedBox(height: 10),
            InkWell(
              onTap: () async {
                final incidents = await IncidentRepository.instance.fetchIncidents();
                final match = incidents.where((i) => i.id == task.linkedIncidentId).toList();
                if (match.isNotEmpty && mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => IncidentDetailScreen(
                        incidentId: match.first.id,
                        initialIncident: match.first,
                      ),
                    ),
                  );
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.orange.shade800),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.link, color: Colors.orangeAccent, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'Linked Incident #${task.linkedIncidentId!.substring(0, 8)}',
                      style: const TextStyle(color: Colors.orangeAccent, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (!task.isCompleted && isAssignedToMe) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                if (task.status == TaskStatus.assigned)
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
                      onPressed: () => _updateTask(task, TaskStatus.accepted),
                      child: const Text('Accept Task', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                if (task.status == TaskStatus.accepted)
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
                      onPressed: () => _updateTask(task, TaskStatus.inProgress),
                      child: const Text('Start Working', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                if (task.status == TaskStatus.inProgress || task.status == TaskStatus.accepted) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                      onPressed: () => _updateTask(task, TaskStatus.completed),
                      child: const Text('Complete', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
