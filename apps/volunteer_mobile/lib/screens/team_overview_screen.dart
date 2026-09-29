/// SPATIALLY — VOLUNTEER BLOCK 2.5C
/// Screen displaying team overview, operational member roster, relief/coverage claims,
/// and team tasks.
library;

import 'package:flutter/material.dart';
import '../models/event_team.dart';
import '../models/coverage_request.dart';
import '../models/supervisor_task.dart';
import '../repositories/team_shift_repository.dart';
import '../repositories/operational_communication_repository.dart';
import '../models/volunteer_directory_entry.dart';
import '../services/session_state.dart';
import 'assign_task_dialog.dart';
import 'direct_thread_screen.dart';

class TeamOverviewScreen extends StatefulWidget {
  final TeamShiftRepository? repository;

  const TeamOverviewScreen({super.key, this.repository});

  @override
  State<TeamOverviewScreen> createState() => _TeamOverviewScreenState();
}

class _TeamOverviewScreenState extends State<TeamOverviewScreen>
    with SingleTickerProviderStateMixin {
  late final TeamShiftRepository _repo;
  late final TabController _tabController;

  List<EventTeam> _teams = [];
  EventTeam? _selectedTeam;
  List<CoverageRequest> _coverageRequests = [];
  List<SupervisorTask> _teamTasks = [];
  bool _isLoading = true;
  String? _error;
  bool _isClaiming = false;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? TeamShiftRepository.instance;
    _tabController = TabController(length: 3, vsync: this);
    _loadTeamData();

    final eventId = SessionState.instance.eventId ?? '';
    _repo.subscribeRealtime(
      eventId: eventId,
      onDataChanged: () {
        if (mounted) _loadTeamData(silent: true);
      },
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _repo.unsubscribeRealtime();
    super.dispose();
  }

  Future<void> _loadTeamData({bool silent = false}) async {
    final eventId = SessionState.instance.eventId;
    if (eventId == null) return;

    if (!silent) setState(() => _isLoading = true);

    try {
      final teams = await _repo.fetchTeams(eventId: eventId, forceRefresh: true);
      final coverage = await _repo.fetchCoverageRequests(eventId: eventId, forceRefresh: true);
      final tasks = await _repo.fetchTasks(eventId: eventId, forceRefresh: true);

      EventTeam? activeTeam;
      if (teams.isNotEmpty) {
        final myTeamId = SessionState.instance.teamId;
        if (myTeamId != null) {
          final match = teams.where((t) => t.id == myTeamId).toList();
          activeTeam = match.isNotEmpty ? match.first : teams.first;
        } else {
          activeTeam = teams.first;
        }
      }

      if (mounted) {
        setState(() {
          _teams = teams;
          _selectedTeam = activeTeam;
          _coverageRequests = coverage;
          _teamTasks = tasks;
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Failed to load team data: $e';
        });
      }
    }
  }

  Future<void> _claimCoverage(CoverageRequest req) async {
    if (_isClaiming) return;
    setState(() => _isClaiming = true);

    try {
      await _repo.acceptCoverage(req.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Coverage accepted! You are now assigned to cover this station.'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        setState(() => _isClaiming = false);
        _loadTeamData(silent: true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error claiming coverage: $e'), backgroundColor: Colors.red),
        );
        setState(() => _isClaiming = false);
      }
    }
  }

  Future<void> _requestCoverageDialog() async {
    CoverageReason reason = CoverageReason.breakTime;
    String priority = 'normal';
    final notesCtrl = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('Request Relief / Coverage', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Reason:', style: TextStyle(color: Color(0xFFE2E8F0), fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                DropdownButtonFormField<CoverageReason>(
                  initialValue: reason,
                  dropdownColor: const Color(0xFF1E293B),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  items: CoverageReason.values.map((r) {
                    return DropdownMenuItem(value: r, child: Text(r.label));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setDlgState(() => reason = val);
                  },
                ),
                const SizedBox(height: 12),
                const Text('Priority:', style: TextStyle(color: Color(0xFFE2E8F0), fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Row(
                  children: ['normal', 'important', 'urgent'].map((p) {
                    final isSel = priority == p;
                    Color c = const Color(0xFF6366F1);
                    if (p == 'urgent') c = const Color(0xFFEF4444);
                    if (p == 'important') c = const Color(0xFFF59E0B);

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(p.toUpperCase()),
                        selected: isSel,
                        selectedColor: c,
                        backgroundColor: const Color(0xFF0F172A),
                        labelStyle: TextStyle(
                          color: isSel ? Colors.white : const Color(0xFF94A3B8),
                          fontSize: 11,
                          fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                        ),
                        onSelected: (_) => setDlgState(() => priority = p),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  maxLines: 2,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Station details or instructions...',
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
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Broadcast Request', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    try {
      final shift = await _repo.fetchActiveShift(eventId: SessionState.instance.eventId!);
      await _repo.requestCoverage(
        eventId: SessionState.instance.eventId!,
        shiftId: shift?.id ?? '00000000-0000-0000-0000-000000000000',
        reason: reason,
        notes: notesCtrl.text.trim(),
        priority: priority,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Coverage request broadcasted.'), backgroundColor: Color(0xFF10B981)),
        );
        _loadTeamData(silent: true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingCoverage = _coverageRequests.where((c) => c.isPending).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Team Operations', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E293B),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF6366F1),
          tabs: [
            const Tab(text: 'Roster & Status'),
            Tab(text: 'Relief (${pendingCoverage.length})'),
            Tab(text: 'Tasks (${_teamTasks.length})'),
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
                      ElevatedButton(onPressed: _loadTeamData, child: const Text('Retry')),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildRosterTab(),
                    _buildCoverageTab(pendingCoverage),
                    _buildTasksTab(),
                  ],
                ),
    );
  }

  Widget _buildRosterTab() {
    if (_teams.isEmpty) {
      return const Center(
        child: Text('No operational teams configured.', style: TextStyle(color: Color(0xFF94A3B8))),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadTeamData(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_teams.length > 1) ...[
              DropdownButtonFormField<EventTeam>(
                initialValue: _selectedTeam,
                dropdownColor: const Color(0xFF1E293B),
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Select Team',
                  labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: _teams.map((t) {
                  return DropdownMenuItem(value: t, child: Text(t.name));
                }).toList(),
                onChanged: (val) => setState(() => _selectedTeam = val),
              ),
              const SizedBox(height: 16),
            ],
            if (_selectedTeam != null) ...[
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _selectedTeam!.name,
                          style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${_selectedTeam!.members.length} members',
                            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                    if (_selectedTeam!.description != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        _selectedTeam!.description!,
                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Color(0xFFF59E0B), size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Team Lead: ${_selectedTeam!.leadName ?? 'Unassigned'}',
                          style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Team Members',
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              ..._selectedTeam!.members.map((member) => _buildMemberTile(member)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMemberTile(TeamMember member) {
    final isMe = member.volunteerId == SessionState.instance.volunteerId;
    Color statusColor = const Color(0xFF94A3B8);
    String statusText = member.shiftStatus ?? 'Scheduled';

    if (member.isOnBreak) {
      statusColor = const Color(0xFFF59E0B);
      statusText = 'ON BREAK';
    } else if (member.shiftStatus == 'active') {
      statusColor = const Color(0xFF10B981);
      statusText = 'ACTIVE';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isMe ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isMe ? const Color(0xFF6366F1) : const Color(0xFF334155),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: member.isLead ? const Color(0xFFF59E0B) : const Color(0xFF334155),
            radius: 18,
            child: Text(
              member.fullName.isNotEmpty ? member.fullName[0].toUpperCase() : '?',
              style: TextStyle(
                color: member.isLead ? Colors.black : Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      member.fullName + (isMe ? ' (You)' : ''),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    if (member.isLead) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('LEAD', style: TextStyle(color: Color(0xFFF59E0B), fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  member.zoneName != null ? 'Zone: ${member.zoneName}' : 'Roving / Float',
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: statusColor, width: 0.8),
            ),
            child: Text(
              statusText.toUpperCase(),
              style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
          if (!isMe) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline, color: Color(0xFF6366F1), size: 18),
              tooltip: 'Message ${member.fullName}',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DirectThreadScreen(
                      repository: OperationalCommunicationRepositoryImpl(),
                      eventId: SessionState.instance.eventId ?? '',
                      recipient: VolunteerDirectoryEntry(
                        volunteerId: member.volunteerId,
                        fullName: member.fullName,
                        role: member.role,
                        staffType: member.role,
                        zoneName: member.zoneName,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCoverageTab(List<CoverageRequest> pending) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Open Coverage Requests (${pending.length})',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
                icon: const Icon(Icons.add, size: 16, color: Colors.white),
                label: const Text('Request Relief', style: TextStyle(color: Colors.white, fontSize: 12)),
                onPressed: _requestCoverageDialog,
              ),
            ],
          ),
        ),
        Expanded(
          child: pending.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.thumb_up_alt_outlined, color: Color(0xFF64748B), size: 48),
                        SizedBox(height: 12),
                        Text('All Stations Covered', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        SizedBox(height: 4),
                        Text('No active coverage requests from team members.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: pending.length,
                  itemBuilder: (ctx, i) {
                    final req = pending[i];
                    Color pColor = const Color(0xFF6366F1);
                    if (req.priority == 'urgent') pColor = const Color(0xFFEF4444);
                    if (req.priority == 'important') pColor = const Color(0xFFF59E0B);

                    final isMe = req.requesterId == SessionState.instance.volunteerId;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: pColor, width: 1.2),
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
                                  color: pColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  req.priority.toUpperCase(),
                                  style: TextStyle(color: pColor, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                              Text(
                                req.reason.label,
                                style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Requester: ${req.requesterName}${isMe ? ' (You)' : ''}',
                            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          if (req.zoneName != null) ...[
                            const SizedBox(height: 2),
                            Text('Station: ${req.zoneName}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                          ],
                          if (req.notes != null && req.notes!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(req.notes!, style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 12)),
                          ],
                          if (!isMe) ...[
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              height: 38,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                                icon: const Icon(Icons.check, size: 16, color: Colors.white),
                                label: const Text('CLAIM COVERAGE', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                onPressed: _isClaiming ? null : () => _claimCoverage(req),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTasksTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Active Floor Tasks (${_teamTasks.where((t) => !t.isCompleted).length})',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
                icon: const Icon(Icons.add_task, size: 16, color: Colors.white),
                label: const Text('Assign Task', style: TextStyle(color: Colors.white, fontSize: 12)),
                onPressed: () async {
                  final res = await showDialog<bool>(
                    context: context,
                    builder: (_) => AssignTaskDialog(team: _selectedTeam),
                  );
                  if (res == true) _loadTeamData(silent: true);
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: _teamTasks.isEmpty
              ? const Center(
                  child: Text('No operational tasks for this team.', style: TextStyle(color: Color(0xFF94A3B8))),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _teamTasks.length,
                  itemBuilder: (ctx, i) {
                    final t = _teamTasks[i];
                    return Card(
                      color: const Color(0xFF1E293B),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(t.title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          'Assigned to ${t.assignedToName} • ${t.status.label}',
                          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: t.isCompleted ? const Color(0xFF064E3B) : const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            t.status.label,
                            style: TextStyle(color: t.isCompleted ? const Color(0xFF10B981) : Colors.white70, fontSize: 10),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
