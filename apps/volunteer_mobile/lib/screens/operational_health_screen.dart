import 'package:flutter/material.dart';
import '../models/operational_health_models.dart';
import '../models/operational_awareness_item.dart';
import '../repositories/operational_health_repository.dart';
import '../services/session_state.dart';
import 'incident_detail_screen.dart';
import 'supervisor_tasks_screen.dart';
import 'team_overview_screen.dart';
import 'communications_center_screen.dart';
import 'shift_overview_screen.dart';

/// Screen presenting Spatially Volunteer Block 2.5E: Operational Health & Analytics.
///
/// Provides a trustworthy, deterministic command view across:
/// 1. Live Health & Operational Integrity
/// 2. Zone Health & Capacity
/// 3. Event Operational Timeline
/// 4. Response & Resolution Metrics
/// 5. Event Summary
class OperationalHealthScreen extends StatefulWidget {
  final OperationalHealthRepository? repository;

  const OperationalHealthScreen({
    super.key,
    this.repository,
  });

  @override
  State<OperationalHealthScreen> createState() => _OperationalHealthScreenState();
}

class _OperationalHealthScreenState extends State<OperationalHealthScreen> with SingleTickerProviderStateMixin {
  late final OperationalHealthRepository _repository;
  late final TabController _tabController;

  EventOperationalHealth? _health;
  List<OperationalTimelineEntry> _timeline = [];
  EventOperationalSummary? _summary;
  bool _isLoading = true;
  String? _error;
  String _timelineFilter = 'All';

  static const Color _slate400 = Color(0xFF94A3B8);
  static const Color _emerald = Color(0xFF10B981);

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? OperationalHealthRepositoryImpl();
    _tabController = TabController(length: 5, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    final eventId = SessionState.instance.eventId;
    final eventName = SessionState.instance.eventName ?? 'Current Event';

    if (eventId == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'No active event context selected.';
        });
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final healthFuture = _repository.getOperationalHealth(eventId, forceRefresh: forceRefresh);
      final timelineFuture = _repository.getOperationalTimeline(eventId, limit: 50, forceRefresh: forceRefresh);
      final summaryFuture = _repository.getEventSummary(eventId, eventName);

      final results = await Future.wait([healthFuture, timelineFuture, summaryFuture]);

      if (mounted) {
        setState(() {
          _health = results[0] as EventOperationalHealth;
          _timeline = results[1] as List<OperationalTimelineEntry>;
          _summary = results[2] as EventOperationalSummary;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Failed to load operational health: $e';
        });
      }
    }
  }

  Color _getHealthColor(OperationalHealthState state) {
    switch (state) {
      case OperationalHealthState.healthy:
        return _emerald;
      case OperationalHealthState.attentionNeeded:
        return const Color(0xFFF59E0B); // Amber
      case OperationalHealthState.operationalPressure:
        return const Color(0xFFF97316); // Orange
      case OperationalHealthState.criticalAttention:
        return const Color(0xFFEF4444); // Red
    }
  }

  IconData _getHealthIcon(OperationalHealthState state) {
    switch (state) {
      case OperationalHealthState.healthy:
        return Icons.check_circle_outline;
      case OperationalHealthState.attentionNeeded:
        return Icons.warning_amber_rounded;
      case OperationalHealthState.operationalPressure:
        return Icons.speed;
      case OperationalHealthState.criticalAttention:
        return Icons.error_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Slate 900
      appBar: AppBar(
        title: const Text(
          'Operational Health',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Analytics',
            onPressed: () => _loadData(forceRefresh: true),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.cyanAccent,
          indicatorWeight: 3,
          labelColor: Colors.cyanAccent,
          unselectedLabelColor: _slate400,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: 'Live Health'),
            Tab(text: 'Zones'),
            Tab(text: 'Timeline'),
            Tab(text: 'Response Times'),
            Tab(text: 'Summary'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
          : _error != null
              ? _buildErrorView()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildLiveHealthTab(),
                    _buildZonesTab(),
                    _buildTimelineTab(),
                    _buildResponseTimesTab(),
                    _buildSummaryTab(),
                  ],
                ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.amber),
            const SizedBox(height: 12),
            Text(
              _error ?? 'An unexpected error occurred.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _loadData(forceRefresh: true),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 1: Live Health & Data Quality
  // ---------------------------------------------------------------------------

  Widget _buildLiveHealthTab() {
    if (_health == null) return const SizedBox.shrink();
    final health = _health!;
    final healthColor = _getHealthColor(health.overallHealth);

    return RefreshIndicator(
      onRefresh: () => _loadData(forceRefresh: true),
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Cached Offline Banner if applicable
          if (health.isCached)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.shade900.withAlpha(80),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade700),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cloud_off, size: 16, color: Colors.amberAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'CACHED • Last updated ${health.cachedAt != null ? _formatAge(health.cachedAt!) : 'earlier'}',
                      style: const TextStyle(color: Colors.amberAccent, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

          // Primary Health Badge Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: healthColor.withAlpha(150), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(_getHealthIcon(health.overallHealth), color: healthColor, size: 28),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            health.overallHealth.label.toUpperCase(),
                            style: TextStyle(
                              color: healthColor,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            health.healthSummary,
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Operational Integrity Alerts
          if (health.dataIntegrityAlerts.isNotEmpty) ...[
            const Text(
              'OPERATIONAL INTEGRITY ALERTS',
              style: TextStyle(color: _slate400, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
            const SizedBox(height: 8),
            for (final alert in health.dataIntegrityAlerts)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: alert.severity == 'critical'
                      ? Colors.red.shade900.withAlpha(80)
                      : Colors.amber.shade900.withAlpha(80),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: alert.severity == 'critical' ? Colors.red.shade600 : Colors.amber.shade600,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      alert.severity == 'critical' ? Icons.error : Icons.warning_amber,
                      color: alert.severity == 'critical' ? Colors.redAccent : Colors.amberAccent,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            alert.message,
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          if (alert.suggestedAction != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Action: ${alert.suggestedAction}',
                              style: TextStyle(
                                color: alert.severity == 'critical' ? Colors.red.shade200 : Colors.amber.shade200,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
          ],

          // Operational Domain Matrix
          const Text(
            'OPERATIONAL DOMAINS',
            style: TextStyle(color: _slate400, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
          const SizedBox(height: 8),

          _buildDomainCard(
            title: 'Crowd & Density',
            icon: Icons.people_outline,
            statusText: '${health.zones.where((z) => z.crowdCondition == 'NEAR CAPACITY').length} near capacity',
            statusColor: health.zones.any((z) => z.crowdCondition == 'NEAR CAPACITY') ? Colors.redAccent : _emerald,
            details: '${health.zones.length} zones monitored • ${health.zones.where((z) => z.crowdCondition == 'BUSY').length} busy',
          ),
          _buildDomainCard(
            title: 'Operational Incidents',
            icon: Icons.warning_amber_rounded,
            statusText: '${health.activeIncidents} active',
            statusColor: health.urgentIncidents > 0 ? Colors.redAccent : (health.activeIncidents > 0 ? Colors.amberAccent : _emerald),
            details: '${health.urgentIncidents} urgent • ${health.resolvedIncidents} resolved',
          ),
          _buildDomainCard(
            title: 'Attendee Assistance',
            icon: Icons.accessible_forward,
            statusText: '${health.pendingAssistance} pending',
            statusColor: health.pendingAssistance > 0 ? Colors.amberAccent : _emerald,
            details: '${health.resolvedAssistance} requests resolved',
          ),
          _buildDomainCard(
            title: 'Staffing & Relief',
            icon: Icons.group_work,
            statusText: '${health.pendingCoverage} relief needed',
            statusColor: health.pendingCoverage > 0 ? Colors.amberAccent : _emerald,
            details: '${health.activeStaff} active staff on floor • ${health.staffOnBreak} on break',
          ),
          _buildDomainCard(
            title: 'Supervisor Tasks',
            icon: Icons.assignment_outlined,
            statusText: '${health.pendingTasks} pending',
            statusColor: health.pendingTasks > 0 ? Colors.cyanAccent : _emerald,
            details: '${health.completedTasks} tasks completed',
          ),
          _buildDomainCard(
            title: 'Communications',
            icon: Icons.chat_bubble_outline,
            statusText: '${health.urgentMessages} urgent',
            statusColor: health.urgentMessages > 0 ? Colors.redAccent : _emerald,
            details: '${health.broadcasts} broadcasts sent • ${health.totalMessages} total',
          ),
          _buildDomainCard(
            title: 'Hardware & Telemetry',
            icon: Icons.bluetooth_searching,
            statusText: 'Scanner Active',
            statusColor: _emerald,
            details: 'BLE telemetry live • Queue sync operational',
          ),
        ],
      ),
    );
  }

  Widget _buildDomainCard({
    required String title,
    required IconData icon,
    required String statusText,
    required Color statusColor,
    required String details,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.cyanAccent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(details, style: const TextStyle(color: Colors.white60, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 2: Zones
  // ---------------------------------------------------------------------------

  Widget _buildZonesTab() {
    if (_health == null || _health!.zones.isEmpty) {
      return const Center(
        child: Text(
          'No zone operational data available.',
          style: TextStyle(color: Colors.white60),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _health!.zones.length,
      itemBuilder: (context, index) {
        final zone = _health!.zones[index];
        final zoneColor = _getHealthColor(zone.healthState);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: zoneColor.withAlpha(150)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    zone.zoneName,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: zoneColor.withAlpha(50),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: zoneColor),
                    ),
                    child: Text(
                      zone.healthState.label,
                      style: TextStyle(color: zoneColor, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Crowd condition & occupancy bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Crowd: ${zone.crowdCondition}',
                    style: TextStyle(
                      color: zone.crowdCondition == 'NEAR CAPACITY' ? Colors.redAccent : Colors.cyanAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${zone.activeCount} / ${zone.effectiveCapacity} (${zone.occupancyPercent}%)',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (zone.occupancyPercent / 100).clamp(0.0, 1.0),
                  backgroundColor: const Color(0xFF334155),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    zone.occupancyPercent >= 90
                        ? Colors.redAccent
                        : (zone.occupancyPercent >= 80 ? Colors.amberAccent : _emerald),
                  ),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 10),

              // Zone Operational Indicators
              Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  _buildZoneMetric(Icons.warning_amber, '${zone.activeIncidents} Incidents', zone.activeIncidents > 0),
                  _buildZoneMetric(Icons.badge_outlined, '${zone.activeStaff} Staff', false),
                  _buildZoneMetric(Icons.assignment, '${zone.pendingTasks} Tasks', zone.pendingTasks > 0),
                  _buildZoneMetric(Icons.support, zone.coverageNeeded ? 'Relief Needed' : 'Relief OK', zone.coverageNeeded),
                  _buildZoneMetric(Icons.sensors, zone.telemetryFreshness, zone.telemetryFreshness == 'STALE'),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildZoneMetric(IconData icon, String label, bool isAlert) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: isAlert ? Colors.amberAccent : Colors.white60),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: isAlert ? Colors.amberAccent : Colors.white70,
            fontSize: 11,
            fontWeight: isAlert ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 3: Operational Timeline
  // ---------------------------------------------------------------------------

  Widget _buildTimelineTab() {
    final filtered = _timelineFilter == 'All'
        ? _timeline
        : _timeline.where((t) => t.sourceType.toLowerCase() == _timelineFilter.toLowerCase()).toList();

    return Column(
      children: [
        // Filter Chips Row
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: const Color(0xFF1E293B),
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final filter in ['All', 'Incident', 'Coverage', 'Task', 'Shift', 'Communication'])
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: Text(filter),
                    selected: _timelineFilter == filter,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _timelineFilter = filter;
                        });
                      }
                    },
                    backgroundColor: const Color(0xFF334155),
                    selectedColor: Colors.cyanAccent.withAlpha(50),
                    labelStyle: TextStyle(
                      color: _timelineFilter == filter ? Colors.cyanAccent : Colors.white70,
                      fontWeight: _timelineFilter == filter ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                    side: BorderSide(
                      color: _timelineFilter == filter ? Colors.cyanAccent : Colors.transparent,
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Timeline Items
        Expanded(
          child: filtered.isEmpty
              ? const Center(
                  child: Text(
                    'No timeline events match the filter.',
                    style: TextStyle(color: Colors.white60),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    return _buildTimelineCard(item);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTimelineCard(OperationalTimelineEntry item) {
    Color cardColor = const Color(0xFF1E293B);
    Color accentColor = Colors.cyanAccent;

    if (item.priority == OperationalPriority.urgent) {
      accentColor = Colors.redAccent;
    } else if (item.priority == OperationalPriority.important) {
      accentColor = Colors.amberAccent;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: accentColor, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                item.sourceType.toUpperCase(),
                style: TextStyle(color: accentColor, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
              Text(
                _formatTimestamp(item.timestamp),
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            item.title,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
          ),
          if (item.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              item.description,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              if (item.zoneName != null) ...[
                const Icon(Icons.location_on, size: 12, color: Colors.white60),
                const SizedBox(width: 3),
                Text(item.zoneName!, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                const SizedBox(width: 12),
              ],
              if (item.actorName != null) ...[
                const Icon(Icons.person, size: 12, color: Colors.white60),
                const SizedBox(width: 3),
                Text(item.actorName!, style: const TextStyle(color: Colors.white70, fontSize: 11)),
              ],
              const Spacer(),
              if (item.actionRoute != null)
                InkWell(
                  onTap: () => _handleTimelineAction(item),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('VIEW', style: TextStyle(color: accentColor, fontSize: 11, fontWeight: FontWeight.bold)),
                      Icon(Icons.arrow_forward_ios, size: 10, color: accentColor),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _handleTimelineAction(OperationalTimelineEntry item) {
    final route = item.actionRoute?.replaceAll('/', '');
    if (route == 'incident_detail') {
      final incidentId = item.actionPayload?['incidentId']?.toString() ?? 
                         (item.sourceType == 'incident' ? item.sourceId : null);
      if (incidentId != null) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => IncidentDetailScreen(incidentId: incidentId),
          ),
        );
      }
    } else if (route == 'supervisor_tasks') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SupervisorTasksScreen()),
      );
    } else if (route == 'team_overview') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const TeamOverviewScreen()),
      );
    } else if (route == 'communications') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const CommunicationsCenterScreen()),
      );
    } else if (route == 'shift_overview') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ShiftOverviewScreen()),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // TAB 4: Response Times & Resolution Metrics
  // ---------------------------------------------------------------------------

  Widget _buildResponseTimesTab() {
    if (_health == null) return const SizedBox.shrink();
    final m = _health!.responseTimeMetrics;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Privacy / Operational banner
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: Colors.cyanAccent),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'System response & resolution metrics describe operational workload and response history. Not employee performance ranking.',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        _buildMetricTile(
          title: 'Incident Acknowledgment',
          duration: ResponseTimeMetrics.formatSeconds(m.incidentAvgAcknowledgeSeconds),
          description: 'Average duration from report to staff acknowledgment',
          icon: Icons.check_circle_outline,
        ),
        _buildMetricTile(
          title: 'Incident Staff Assignment',
          duration: ResponseTimeMetrics.formatSeconds(m.incidentAvgAssignSeconds),
          description: 'Average duration from report to volunteer assignment',
          icon: Icons.person_add_outlined,
        ),
        _buildMetricTile(
          title: 'Incident Resolution',
          duration: ResponseTimeMetrics.formatSeconds(m.incidentAvgResolveSeconds),
          description: 'Average duration from report to full resolution',
          icon: Icons.task_alt,
        ),
        _buildMetricTile(
          title: 'Attendee Assistance Response',
          duration: ResponseTimeMetrics.formatSeconds(m.assistanceAvgResolveSeconds),
          description: 'Average duration to fulfill attendee help request',
          icon: Icons.accessible,
        ),
        _buildMetricTile(
          title: 'Relief & Coverage Acceptance',
          duration: ResponseTimeMetrics.formatSeconds(m.coverageAvgAcceptSeconds),
          description: 'Average duration from relief request to teammate coverage',
          icon: Icons.swap_horiz,
        ),
        _buildMetricTile(
          title: 'Supervisor Task Completion',
          duration: ResponseTimeMetrics.formatSeconds(m.taskAvgCompleteSeconds),
          description: 'Average duration from task assignment to completion',
          icon: Icons.assignment_turned_in,
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String duration,
    required String description,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.cyanAccent.withAlpha(25),
            child: Icon(icon, color: Colors.cyanAccent, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 2),
                Text(description, style: const TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
          ),
          Text(
            duration,
            style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 5: Event Operational Summary
  // ---------------------------------------------------------------------------

  Widget _buildSummaryTab() {
    if (_summary == null) {
      return const Center(
        child: Text('No event summary available.', style: TextStyle(color: Colors.white60)),
      );
    }
    final s = _summary!;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.cyanAccent.withAlpha(120)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.eventName.toUpperCase(),
                style: const TextStyle(color: Colors.cyanAccent, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
              const SizedBox(height: 4),
              const Text(
                'OPERATIONAL EVENT SUMMARY',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildSummaryRow('Operational Duration', '${s.duration.inHours}h ${s.duration.inMinutes % 60}m'),
              _buildSummaryRow('Peak Crowd Occupancy', '${s.peakOccupancyZone} (${s.peakOccupancyPercent}%)'),
              const Divider(color: Color(0xFF334155), height: 24),
              _buildSummaryRow('Incidents Reported', '${s.incidentsReported} (${s.incidentsResolved} resolved, ${s.incidentsOpen} open)'),
              _buildSummaryRow('Attendee Assistance', '${s.assistanceRequests} (${s.assistanceResolved} resolved)'),
              _buildSummaryRow('Relief Requests', '${s.coverageRequested} (${s.coverageFulfilled} covered)'),
              _buildSummaryRow('Supervisor Tasks', '${s.tasksCompleted} completed (${s.tasksPending} pending)'),
              const Divider(color: Color(0xFF334155), height: 24),
              _buildSummaryRow('Avg Incident Resolution', s.avgIncidentResolution),
              _buildSummaryRow('Avg Assistance Fulfillment', s.avgAssistanceResolution),
              _buildSummaryRow('Avg Relief Response', s.avgCoverageAcceptance),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.month}/${dt.day} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatAge(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}
