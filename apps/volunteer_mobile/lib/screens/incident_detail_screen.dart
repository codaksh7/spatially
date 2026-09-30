import 'package:flutter/material.dart';
import '../models/operational_incident.dart';
import '../repositories/incident_repository.dart';
import '../services/session_state.dart';
import '../repositories/operational_communication_repository.dart';
import 'direct_thread_screen.dart';

class IncidentDetailScreen extends StatefulWidget {
  final String incidentId;
  final OperationalIncident? initialIncident;

  const IncidentDetailScreen({
    super.key,
    required this.incidentId,
    this.initialIncident,
  });

  @override
  State<IncidentDetailScreen> createState() => _IncidentDetailScreenState();
}

class _IncidentDetailScreenState extends State<IncidentDetailScreen> {
  OperationalIncident? _incident;
  bool _isLoading = false;
  String? _actionError;

  @override
  void initState() {
    super.initState();
    _incident = widget.initialIncident;
    _refreshIncident();
  }

  Future<void> _refreshIncident() async {
    try {
      final list = await IncidentRepository.instance.fetchIncidents();
      final match = list.where((i) => i.id == widget.incidentId);
      if (match.isNotEmpty && mounted) {
        setState(() {
          _incident = match.first;
        });
      }
    } catch (_) {}
  }

  Future<void> _acknowledge() async {
    setState(() => _isLoading = true);
    try {
      await IncidentRepository.instance.acknowledgeIncident(widget.incidentId);
      await _refreshIncident();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Incident acknowledged.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _actionError = 'Error acknowledging: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _assignToMe() async {
    setState(() => _isLoading = true);
    try {
      await IncidentRepository.instance.assignIncident(widget.incidentId);
      await _refreshIncident();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF10B981),
            content: Text('Incident assigned to you.'),
          ),
        );
      }
    } on IncidentAlreadyAssignedException catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Assignment Conflict'),
            content: Text(e.message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _actionError = 'Error assigning: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markInProgress() async {
    setState(() => _isLoading = true);
    try {
      await IncidentRepository.instance.updateStatus(
        widget.incidentId,
        IncidentStatus.inProgress,
      );
      await _refreshIncident();
    } catch (e) {
      if (mounted) setState(() => _actionError = 'Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resolveDialog() async {
    final notesCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Resolve Incident'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Provide resolution details or actions taken:'),
            const SizedBox(height: 10),
            TextField(
              controller: notesCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'e.g., Dispatched backup scanner; crowd cleared; item returned.',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
            ),
            child: const Text('Mark Resolved'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isLoading = true);
      try {
        await IncidentRepository.instance.updateStatus(
          widget.incidentId,
          IncidentStatus.resolved,
          resolutionNotes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
        );
        await _refreshIncident();
      } catch (e) {
        if (mounted) setState(() => _actionError = 'Error resolving: $e');
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _addStaffNoteDialog() async {
    final noteCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Staff Internal Note'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Staff notes are confidential and NEVER visible to attendees.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: noteCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Enter internal notes, instructions, or coordination info...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Save Note'),
          ),
        ],
      ),
    );

    if (confirmed == true && noteCtrl.text.trim().isNotEmpty && mounted) {
      setState(() => _isLoading = true);
      try {
        await IncidentRepository.instance.updateStatus(
          widget.incidentId,
          _incident?.status ?? IncidentStatus.open,
          staffNotes: noteCtrl.text.trim(),
        );
        await _refreshIncident();
      } catch (e) {
        if (mounted) setState(() => _actionError = 'Error saving note: $e');
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final incident = _incident;

    if (incident == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Incident Details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final currentUserId = SessionState.instance.volunteerId;
    final isAssignedToMe = incident.assignedToId == currentUserId;

    Color priorityColor;
    switch (incident.priority) {
      case IncidentPriority.urgent:
        priorityColor = const Color(0xFFDC2626);
        break;
      case IncidentPriority.important:
        priorityColor = const Color(0xFFD97706);
        break;
      case IncidentPriority.normal:
        priorityColor = const Color(0xFF2563EB);
        break;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Incident #${incident.id.substring(0, 8)}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshIncident,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_actionError != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _actionError!,
                        style: const TextStyle(color: Color(0xFF991B1B), fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Priority & Status Card
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: priorityColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: priorityColor),
                          ),
                          child: Text(
                            incident.priority.label.toUpperCase(),
                            style: TextStyle(
                              color: priorityColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white12 : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            incident.category.label,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                        const Spacer(),
                        _buildStatusBadge(incident.status),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      incident.title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      incident.description,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white70 : Colors.black87,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Operational Context
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Operational Context', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      Icons.person_outline,
                      'Reported By',
                      '${incident.reporterName} (${incident.reporterType})',
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      Icons.location_on_outlined,
                      'Location',
                      incident.specificLocation ?? incident.venueZoneName ?? 'Venue / Not specified',
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      Icons.assignment_ind_outlined,
                      'Assigned Staff',
                      incident.assignedToName ?? 'Unassigned',
                      color: incident.assignedToName != null ? Colors.purple : Colors.grey,
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      Icons.access_time,
                      'Created At',
                      '${incident.createdAt.toLocal().toString().substring(0, 16)} (${_formatTimeAgo(incident.createdAt)})',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Photo Evidence (if any)
            if (incident.imageUrl != null && incident.imageUrl!.isNotEmpty) ...[
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(14),
                      child: Text('Photo Evidence', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                    Image.network(
                      incident.imageUrl!,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, err, stack) => Container(
                        height: 100,
                        color: Colors.grey.shade300,
                        alignment: Alignment.center,
                        child: const Text('Failed to load evidence image'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Resolution Notes (if resolved/closed)
            if (incident.resolutionNotes != null && incident.resolutionNotes!.isNotEmpty) ...[
              Card(
                color: const Color(0xFFF0FDF4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: Color(0xFF86EFAC)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 18),
                          SizedBox(width: 8),
                          Text('Resolution Notes', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(incident.resolutionNotes!, style: const TextStyle(fontSize: 13, color: Color(0xFF14532D))),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Staff Internal Notes Card
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.lock_outline, size: 18, color: Color(0xFF6B7280)),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text('Staff Confidential Notes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        ),
                        TextButton.icon(
                          onPressed: _addStaffNoteDialog,
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add Note', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (incident.staffNotes != null && incident.staffNotes!.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.black26 : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          incident.staffNotes!,
                          style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                        ),
                      ),
                    ] else ...[
                      const Text(
                        'No internal notes added yet.',
                        style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Linked Operational Communication
            if (incident.linkedMessageId != null) ...[
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFF2563EB),
                    child: Icon(Icons.forum, color: Colors.white, size: 18),
                  ),
                  title: const Text('Operational Comms Thread', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text('Discuss this incident with organizers and supervisors', style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => DirectThreadScreen(
                          repository: OperationalCommunicationRepositoryImpl(),
                          eventId: incident.eventId,
                          isOrganizerChannel: true,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Action Buttons
            const Text('Operational Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (incident.status == IncidentStatus.open)
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _acknowledge,
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Acknowledge'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD97706),
                      foregroundColor: Colors.white,
                    ),
                  ),
                if (!isAssignedToMe && incident.status != IncidentStatus.resolved && incident.status != IncidentStatus.closed)
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _assignToMe,
                    icon: const Icon(Icons.person_add_alt_1, size: 18),
                    label: const Text('Assign to Me'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      foregroundColor: Colors.white,
                    ),
                  ),
                if (isAssignedToMe && incident.status != IncidentStatus.inProgress && incident.status != IncidentStatus.resolved && incident.status != IncidentStatus.closed)
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _markInProgress,
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('Start Working'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                    ),
                  ),
                if (incident.status != IncidentStatus.resolved && incident.status != IncidentStatus.closed)
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _resolveDialog,
                    icon: const Icon(Icons.done_all, size: 18),
                    label: const Text('Resolve Incident'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {Color? color}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(fontSize: 13, color: Colors.grey)),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(IncidentStatus status) {
    Color bg;
    Color fg;
    switch (status) {
      case IncidentStatus.open:
        bg = const Color(0xFFEFF6FF);
        fg = const Color(0xFF2563EB);
        break;
      case IncidentStatus.acknowledged:
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFD97706);
        break;
      case IncidentStatus.assigned:
      case IncidentStatus.inProgress:
        bg = const Color(0xFFF3E8FF);
        fg = const Color(0xFF9333EA);
        break;
      case IncidentStatus.resolved:
      case IncidentStatus.closed:
        bg = const Color(0xFFECFDF5);
        fg = const Color(0xFF059669);
        break;
      case IncidentStatus.cancelled:
        bg = const Color(0xFFF1F5F9);
        fg = Colors.grey;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.label,
        style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
