/// SPATIALLY — VOLUNTEER BLOCK 2.5C
/// Screen displaying volunteer shift overview, break management, and handoff actions.
library;

import 'package:flutter/material.dart';
import '../models/volunteer_shift.dart';
import '../models/coverage_request.dart';
import '../repositories/team_shift_repository.dart';
import '../services/session_state.dart';
import 'shift_handoff_screen.dart';

class ShiftOverviewScreen extends StatefulWidget {
  final TeamShiftRepository? repository;

  const ShiftOverviewScreen({super.key, this.repository});

  @override
  State<ShiftOverviewScreen> createState() => _ShiftOverviewScreenState();
}

class _ShiftOverviewScreenState extends State<ShiftOverviewScreen> {
  late final TeamShiftRepository _repo;
  VolunteerShift? _activeShift;
  List<VolunteerShift> _allShifts = [];
  bool _isLoading = true;
  String? _error;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? TeamShiftRepository.instance;
    _loadShiftData();
    _repo.subscribeRealtime(
      eventId: SessionState.instance.eventId ?? '',
      onDataChanged: () {
        if (mounted) _loadShiftData(silent: true);
      },
    );
  }

  @override
  void dispose() {
    _repo.unsubscribeRealtime();
    super.dispose();
  }

  Future<void> _loadShiftData({bool silent = false}) async {
    final eventId = SessionState.instance.eventId;
    if (eventId == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'No active event selected.';
        });
      }
      return;
    }

    if (!silent) setState(() => _isLoading = true);

    try {
      final shifts = await _repo.fetchMyShifts(eventId: eventId, forceRefresh: true);
      VolunteerShift? active;
      for (final s in shifts) {
        if (s.status == ShiftStatus.active ||
            s.status == ShiftStatus.onBreak ||
            s.status == ShiftStatus.handoffPending) {
          active = s;
          break;
        }
      }
      active ??= shifts.isNotEmpty ? shifts.first : null;

      if (mounted) {
        setState(() {
          _allShifts = shifts;
          _activeShift = active;
          _isLoading = false;
          _error = null;
        });

        // Sync with SessionState
        if (active != null) {
          SessionState.instance.activeShiftId = active.id;
          SessionState.instance.activeShiftName = active.shiftName;
          SessionState.instance.shiftStatus = active.status.toDbString();
          SessionState.instance.teamId = active.teamId;
          SessionState.instance.teamName = active.teamName;
          SessionState.instance.supervisorName = active.supervisorName;
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Failed to load shift: $e';
        });
      }
    }
  }

  Future<void> _startShift() async {
    if (_activeShift == null || _isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      final updated = await _repo.startShift(_activeShift!.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Shift started! You are now active on duty.'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        setState(() {
          _activeShift = updated;
          _isProcessing = false;
        });
        _loadShiftData(silent: true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting shift: $e'), backgroundColor: Colors.red),
        );
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _confirmEndShift() async {
    if (_activeShift == null || _isProcessing) return;

    final notesCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('End Shift', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to end this shift? Before ending, ensure pending tasks and zone responsibilities have been handed over.',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: notesCtrl,
              maxLines: 2,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Optional closing shift notes...',
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
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('End Shift', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isProcessing = true);
    try {
      final res = await _repo.endShift(_activeShift!.id, notes: notesCtrl.text.trim());
      if (mounted) {
        final pendingTasks = res['pending_tasks_count'] as int? ?? 0;
        final pendingIncidents = res['pending_incidents_count'] as int? ?? 0;

        String msg = 'Shift ended successfully.';
        if (pendingTasks > 0 || pendingIncidents > 0) {
          msg += ' Note: You had $pendingTasks active tasks and $pendingIncidents active incidents.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: const Color(0xFF10B981)),
        );
        setState(() => _isProcessing = false);
        _loadShiftData(silent: true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error ending shift: $e'), backgroundColor: Colors.red),
        );
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _startBreakDialog() async {
    if (_activeShift == null || _isProcessing) return;

    int returnMinutes = 15;
    final reasonCtrl = TextEditingController(text: 'Meal / Rest Break');

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('Start Break', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Indicate your expected return duration and reason. If your station requires temporary coverage, request it below.',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              ),
              const SizedBox(height: 16),
              const Text('Duration:', style: TextStyle(color: Color(0xFFE2E8F0), fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [15, 30, 45].map((m) {
                  final isSelected = returnMinutes == m;
                  return ChoiceChip(
                    label: Text('$m min'),
                    selected: isSelected,
                    selectedColor: const Color(0xFF6366F1),
                    backgroundColor: const Color(0xFF0F172A),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (_) => setDlgState(() => returnMinutes = m),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Break Reason',
                  labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
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
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B)),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Take Break', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    setState(() => _isProcessing = true);
    try {
      final expectedReturn = DateTime.now().add(Duration(minutes: returnMinutes));
      await _repo.startBreak(
        _activeShift!.id,
        expectedReturn: expectedReturn,
        reason: reasonCtrl.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('On break. Expected return at ${_formatTime(expectedReturn)}.'),
            backgroundColor: const Color(0xFFF59E0B),
          ),
        );
        setState(() => _isProcessing = false);
        _loadShiftData(silent: true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting break: $e'), backgroundColor: Colors.red),
        );
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _endBreak() async {
    if (_activeShift == null || _isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      await _repo.endBreak(_activeShift!.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Welcome back! Your shift is active again.'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        setState(() => _isProcessing = false);
        _loadShiftData(silent: true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error ending break: $e'), backgroundColor: Colors.red),
        );
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _requestCoverageDialog() async {
    if (_activeShift == null || _isProcessing) return;

    CoverageReason selectedReason = CoverageReason.breakTime;
    String priority = 'normal';
    final notesCtrl = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('Request Station Coverage', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Request temporary relief or backup from available volunteers or roving staff.',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                ),
                const SizedBox(height: 16),
                const Text('Reason:', style: TextStyle(color: Color(0xFFE2E8F0), fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                DropdownButtonFormField<CoverageReason>(
                  initialValue: selectedReason,
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
                    if (val != null) setDlgState(() => selectedReason = val);
                  },
                ),
                const SizedBox(height: 12),
                const Text('Priority:', style: TextStyle(color: Color(0xFFE2E8F0), fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Row(
                  children: ['normal', 'important', 'urgent'].map((p) {
                    final isSel = priority == p;
                    Color color = const Color(0xFF6366F1);
                    if (p == 'urgent') color = const Color(0xFFEF4444);
                    if (p == 'important') color = const Color(0xFFF59E0B);

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(p.toUpperCase()),
                        selected: isSel,
                        selectedColor: color,
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
                    hintText: 'Additional details for covering staff...',
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

    setState(() => _isProcessing = true);
    try {
      await _repo.requestCoverage(
        eventId: _activeShift!.eventId,
        shiftId: _activeShift!.id,
        reason: selectedReason,
        notes: notesCtrl.text.trim(),
        priority: priority,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Coverage request broadcasted to team and roving staff.'),
            backgroundColor: Color(0xFF6366F1),
          ),
        );
        setState(() => _isProcessing = false);
        _loadShiftData(silent: true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error requesting coverage: $e'), backgroundColor: Colors.red),
        );
        setState(() => _isProcessing = false);
      }
    }
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$hour:$min';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Shift Operations', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E293B),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadShiftData(),
            tooltip: 'Refresh Shift',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                        const SizedBox(height: 12),
                        Text(_error!, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => _loadShiftData(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _activeShift == null
                  ? _buildEmptyShiftState()
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildShiftStatusBanner(),
                          const SizedBox(height: 16),
                          _buildShiftDetailCard(),
                          const SizedBox(height: 20),
                          _buildActionControls(),
                          const SizedBox(height: 24),
                          if (_allShifts.length > 1) _buildOtherShiftsSection(),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildEmptyShiftState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.event_busy, color: Color(0xFF64748B), size: 64),
            const SizedBox(height: 16),
            const Text(
              'No Scheduled Shifts',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'You do not have any operational shifts scheduled for ${SessionState.instance.eventName ?? 'this event'}. Contact your lead or coordinator to assign shifts.',
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShiftStatusBanner() {
    final shift = _activeShift!;
    Color bg = const Color(0xFF1E293B);
    Color border = const Color(0xFF334155);
    IconData icon = Icons.schedule;
    String statusTitle = 'Shift Scheduled';
    String statusSubtitle = 'Scheduled for ${_formatTime(shift.scheduledStart)} – ${_formatTime(shift.scheduledEnd)}';

    if (shift.status == ShiftStatus.active) {
      bg = const Color(0xFF064E3B);
      border = const Color(0xFF059669);
      icon = Icons.check_circle_outline;
      statusTitle = 'ACTIVE ON DUTY';
      statusSubtitle = 'Started at ${_formatTime(shift.actualStart ?? shift.scheduledStart)} • Working normally';
    } else if (shift.status == ShiftStatus.onBreak) {
      bg = const Color(0xFF78350F);
      border = const Color(0xFFD97706);
      icon = Icons.coffee_outlined;
      statusTitle = 'CURRENTLY ON BREAK';
      statusSubtitle = 'Break in progress • Remember to tap "End Break" upon return';
    } else if (shift.status == ShiftStatus.handoffPending) {
      bg = const Color(0xFF312E81);
      border = const Color(0xFF6366F1);
      icon = Icons.handshake_outlined;
      statusTitle = 'HANDOFF IN PROGRESS';
      statusSubtitle = 'Handoff briefing submitted • Awaiting incoming staff acknowledgment';
    } else if (shift.status == ShiftStatus.completed) {
      bg = const Color(0xFF1E293B);
      border = const Color(0xFF475569);
      icon = Icons.done_all;
      statusTitle = 'SHIFT COMPLETED';
      statusSubtitle = 'Finished at ${_formatTime(shift.actualEnd ?? DateTime.now())}';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusTitle,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
                const SizedBox(height: 2),
                Text(
                  statusSubtitle,
                  style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShiftDetailCard() {
    final shift = _activeShift!;
    final session = SessionState.instance;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                shift.shiftName,
                style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF475569)),
                ),
                child: Text(
                  shift.status.label,
                  style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFF334155), height: 1),
          const SizedBox(height: 14),
          _buildInfoRow(Icons.event, 'Event', session.eventName ?? 'Active Event'),
          const SizedBox(height: 10),
          _buildInfoRow(
            Icons.access_time,
            'Scheduled Hours',
            '${_formatTime(shift.scheduledStart)} – ${_formatTime(shift.scheduledEnd)}',
          ),
          const SizedBox(height: 10),
          _buildInfoRow(
            Icons.group_work_outlined,
            'Assigned Team',
            shift.teamName ?? session.teamName ?? 'General Operations',
          ),
          const SizedBox(height: 10),
          _buildInfoRow(
            Icons.place_outlined,
            'Station / Zone',
            shift.zoneName ?? session.zoneName ?? 'All Zones (Roving)',
          ),
          const SizedBox(height: 10),
          _buildInfoRow(
            Icons.supervisor_account,
            'Supervisor / Lead',
            shift.supervisorName ?? session.supervisorName ?? 'Event Operations Lead',
          ),
          if (shift.notes != null && shift.notes!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFF94A3B8), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      shift.notes!,
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String title, String value) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF64748B), size: 18),
        const SizedBox(width: 10),
        SizedBox(
          width: 120,
          child: Text(title, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildActionControls() {
    final shift = _activeShift!;

    if (shift.status == ShiftStatus.scheduled) {
      return SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF10B981),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: const Icon(Icons.play_arrow, color: Colors.white),
          label: const Text('START SHIFT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          onPressed: _isProcessing ? null : _startShift,
        ),
      );
    }

    if (shift.status == ShiftStatus.onBreak) {
      return SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF10B981),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: const Icon(Icons.check, color: Colors.white),
          label: const Text('END BREAK / RETURN TO DUTY', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          onPressed: _isProcessing ? null : _endBreak,
        ),
      );
    }

    if (shift.status == ShiftStatus.active) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFF59E0B),
                      side: const BorderSide(color: Color(0xFFF59E0B)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.coffee, size: 18),
                    label: const Text('Take Break', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: _isProcessing ? null : _startBreakDialog,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF6366F1),
                      side: const BorderSide(color: Color(0xFF6366F1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.person_pin_circle_outlined, size: 18),
                    label: const Text('Request Relief', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: _isProcessing ? null : _requestCoverageDialog,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF334155),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.handshake_outlined, color: Colors.white, size: 18),
                    label: const Text('Shift Handoff', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ShiftHandoffScreen(shift: shift, repository: _repo),
                        ),
                      ).then((_) => _loadShiftData(silent: true));
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.stop_circle_outlined, color: Colors.white, size: 18),
                    label: const Text('End Shift', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    onPressed: _isProcessing ? null : _confirmEndShift,
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    if (shift.status == ShiftStatus.handoffPending) {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.visibility_outlined, color: Colors.white),
              label: const Text('VIEW HANDOFF STATUS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ShiftHandoffScreen(shift: shift, repository: _repo),
                  ),
                ).then((_) => _loadShiftData(silent: true));
              },
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFEF4444),
                side: const BorderSide(color: Color(0xFFEF4444)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _isProcessing ? null : _confirmEndShift,
              child: const Text('Complete & Exit Shift'),
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildOtherShiftsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'All Scheduled Shifts',
          style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        ..._allShifts.map((s) {
          final isSelected = s.id == _activeShift?.id;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? const Color(0xFF6366F1) : const Color(0xFF334155),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.shiftName,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_formatTime(s.scheduledStart)} – ${_formatTime(s.scheduledEnd)} • ${s.zoneName ?? 'Roving'}',
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                    ),
                  ],
                ),
                Text(
                  s.status.label,
                  style: TextStyle(
                    color: s.isActive ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
