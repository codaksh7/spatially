import 'package:flutter/material.dart';
import '../models/operational_incident.dart';
import '../repositories/incident_repository.dart';
import '../services/session_state.dart';
import 'incident_detail_screen.dart';
import 'report_issue_dialog.dart';

class IncidentsListScreen extends StatefulWidget {
  const IncidentsListScreen({super.key});

  @override
  State<IncidentsListScreen> createState() => _IncidentsListScreenState();
}

class _IncidentsListScreenState extends State<IncidentsListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<OperationalIncident> _incidents = [];
  bool _isLoading = true;
  String? _error;
  String _priorityFilter = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadIncidents();
    IncidentRepository.instance.subscribeRealtime(
      onDataChanged: () {
        if (mounted) _loadIncidents(silent: true);
      },
    );
  }

  @override
  void dispose() {
    IncidentRepository.instance.unsubscribeRealtime();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadIncidents({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      final list = await IncidentRepository.instance.fetchIncidents(forceRefresh: true);
      if (mounted) {
        setState(() {
          _incidents = list;
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Failed to load incidents: $e';
        });
      }
    }
  }

  List<OperationalIncident> _filterList(int tabIndex) {
    final currentUserId = SessionState.instance.volunteerId;
    return _incidents.where((inc) {
      // Priority filter
      if (_priorityFilter != 'all' && inc.priority.toDbString() != _priorityFilter) {
        return false;
      }

      switch (tabIndex) {
        case 0: // All active
          return inc.status != IncidentStatus.resolved &&
              inc.status != IncidentStatus.closed &&
              inc.status != IncidentStatus.cancelled;
        case 1: // Attendee Assistance
          return inc.isAssistanceRequest &&
              inc.status != IncidentStatus.resolved &&
              inc.status != IncidentStatus.closed;
        case 2: // Assigned to me
          return inc.assignedToId == currentUserId &&
              inc.status != IncidentStatus.resolved &&
              inc.status != IncidentStatus.closed;
        case 3: // Resolved / History
          return inc.status == IncidentStatus.resolved ||
              inc.status == IncidentStatus.closed ||
              inc.status == IncidentStatus.cancelled;
        default:
          return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Operations Incidents & Help'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => _loadIncidents(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: theme.colorScheme.primary,
            unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
            indicatorColor: theme.colorScheme.primary,
            tabs: const [
              Tab(text: 'Active Issues'),
              Tab(text: 'Attendee Help'),
              Tab(text: 'Assigned to Me'),
              Tab(text: 'Resolved / History'),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          // Filter Chips row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            child: Row(
              children: [
                const Text('Priority:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                _buildFilterChip('All', 'all'),
                const SizedBox(width: 6),
                _buildFilterChip('Urgent', 'urgent', color: const Color(0xFFDC2626)),
                const SizedBox(width: 6),
                _buildFilterChip('Important', 'important', color: const Color(0xFFD97706)),
                const SizedBox(width: 6),
                _buildFilterChip('Normal', 'normal', color: const Color(0xFF2563EB)),
              ],
            ),
          ),
          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline, size: 40, color: Colors.red),
                              const SizedBox(height: 12),
                              Text(_error!, textAlign: TextAlign.center),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: () => _loadIncidents(),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildIncidentList(_filterList(0), 'No active operational issues reported.'),
                          _buildIncidentList(_filterList(1), 'No pending attendee assistance requests.'),
                          _buildIncidentList(_filterList(2), 'You have no incidents currently assigned.'),
                          _buildIncidentList(_filterList(3), 'No resolved or closed incidents in history.'),
                        ],
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await ReportIssueDialog.show(context);
          if (created != null) {
            _loadIncidents();
          }
        },
        icon: const Icon(Icons.add_alert_outlined),
        label: const Text('Report Issue'),
        backgroundColor: const Color(0xFFEA580C),
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, {Color? color}) {
    final isSelected = _priorityFilter == value;
    return InkWell(
      onTap: () => setState(() => _priorityFilter = value),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? (color ?? Theme.of(context).colorScheme.primary)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color ?? Colors.grey.withValues(alpha: 0.5),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : (color ?? Colors.grey.shade700),
          ),
        ),
      ),
    );
  }

  Widget _buildIncidentList(List<OperationalIncident> items, String emptyMessage) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_outline, size: 48, color: Colors.grey.withValues(alpha: 0.4)),
              const SizedBox(height: 12),
              Text(
                emptyMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadIncidents(),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (context, i) => const SizedBox(height: 12),
        itemBuilder: (ctx, index) {
          final item = items[index];
          return _buildIncidentCard(item);
        },
      ),
    );
  }

  Widget _buildIncidentCard(OperationalIncident incident) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: incident.isUrgent
            ? const BorderSide(color: Color(0xFFDC2626), width: 1.5)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => IncidentDetailScreen(incidentId: incident.id, initialIncident: incident),
            ),
          );
          _loadIncidents(silent: true);
        },
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top tags row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: priorityColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: priorityColor, width: 0.8),
                    ),
                    child: Text(
                      incident.priority.label.toUpperCase(),
                      style: TextStyle(
                        color: priorityColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white12 : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      incident.category.label,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
                    ),
                  ),
                  const Spacer(),
                  _buildStatusChip(incident.status),
                ],
              ),
              const SizedBox(height: 10),

              // Title
              Text(
                incident.title,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),

              // Description preview
              Text(
                incident.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 10),

              // Location and Reporter Footer
              Row(
                children: [
                  if (incident.venueZoneName != null || incident.specificLocation != null) ...[
                    const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        incident.specificLocation ?? incident.venueZoneName ?? '',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  if (incident.isOfflineQueued) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFD97706)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.cloud_off, size: 12, color: Color(0xFFD97706)),
                          SizedBox(width: 4),
                          Text(
                            'Queued Offline',
                            style: TextStyle(fontSize: 10, color: Color(0xFFB45309), fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  Text(
                    _formatTimeAgo(incident.createdAt),
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(IncidentStatus status) {
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.label,
        style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 10),
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
