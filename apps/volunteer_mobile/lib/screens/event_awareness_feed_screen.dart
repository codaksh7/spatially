import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/operational_awareness_item.dart';
import '../services/event_awareness_service.dart';
import '../services/session_state.dart';
import 'incident_detail_screen.dart';
import 'supervisor_tasks_screen.dart';
import 'shift_overview_screen.dart';
import 'team_overview_screen.dart';
import 'communications_center_screen.dart';

/// Screen displaying the full chronological, filterable operational awareness activity feed.
class EventAwarenessFeedScreen extends StatefulWidget {
  const EventAwarenessFeedScreen({super.key});

  @override
  State<EventAwarenessFeedScreen> createState() => _EventAwarenessFeedScreenState();
}

class _EventAwarenessFeedScreenState extends State<EventAwarenessFeedScreen> {
  String _activeFilter = 'All'; // 'All', 'Attention', 'My Zone', 'Team', 'Crowd'
  final EventAwarenessService _service = EventAwarenessService.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text(
          'Operational Awareness',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: 'Mark All Seen',
            onPressed: () {
              _service.markAllSeen();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('All operational events marked as seen'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              final eId = SessionState.instance.eventId;
              if (eId != null) {
                _service.refreshLiveAwareness(eventId: eId);
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<List<OperationalAwarenessItem>>(
        stream: _service.itemsStream,
        initialData: _service.allItems,
        builder: (context, snapshot) {
          final allItems = snapshot.data ?? [];
          final filtered = _applyFilter(allItems);

          return Column(
            children: [
              _buildFilterChips(),
              Expanded(
                child: filtered.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: () async {
                          final eId = SessionState.instance.eventId;
                          if (eId != null) {
                            await _service.refreshLiveAwareness(eventId: eId);
                          }
                        },
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: filtered.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            return _buildAwarenessCard(filtered[index]);
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = ['All', 'Attention', 'My Zone', 'Team', 'Crowd'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFF1E293B),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.map((f) {
            final isSelected = _activeFilter == f;
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ChoiceChip(
                label: Text(f),
                selected: isSelected,
                selectedColor: const Color(0xFF6366F1),
                backgroundColor: const Color(0xFF334155),
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey.shade300,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
                onSelected: (val) {
                  if (val) setState(() => _activeFilter = f);
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  List<OperationalAwarenessItem> _applyFilter(List<OperationalAwarenessItem> items) {
    switch (_activeFilter) {
      case 'Attention':
        return items.where((i) => i.requiresAttention).toList();
      case 'My Zone':
        return items.where((i) => i.relevance == OperationalRelevance.myZone).toList();
      case 'Team':
        return items
            .where((i) =>
                i.relevance == OperationalRelevance.myTeam ||
                i.category == AwarenessCategory.team ||
                i.category == AwarenessCategory.coverage)
            .toList();
      case 'Crowd':
        return items.where((i) => i.category == AwarenessCategory.crowd).toList();
      default:
        return items;
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline, size: 64, color: Colors.grey.shade600),
          const SizedBox(height: 16),
          Text(
            'All Operational Areas Quiet',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'No operational awareness items for current filter.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  Widget _buildAwarenessCard(OperationalAwarenessItem item) {
    Color borderColor;
    Color iconColor;
    IconData iconData;

    switch (item.priority) {
      case OperationalPriority.urgent:
        borderColor = Colors.red.shade600;
        iconColor = Colors.red.shade400;
        break;
      case OperationalPriority.important:
        borderColor = Colors.amber.shade600;
        iconColor = Colors.amber.shade400;
        break;
      case OperationalPriority.normal:
        borderColor = Colors.transparent;
        iconColor = Colors.blue.shade400;
        break;
    }

    switch (item.category) {
      case AwarenessCategory.crowd:
        iconData = Icons.groups_outlined;
        break;
      case AwarenessCategory.incident:
        iconData = Icons.warning_amber_rounded;
        break;
      case AwarenessCategory.safety:
        iconData = Icons.health_and_safety_outlined;
        break;
      case AwarenessCategory.assistance:
        iconData = Icons.accessible;
        break;
      case AwarenessCategory.team:
        iconData = Icons.people_outline;
        break;
      case AwarenessCategory.shift:
        iconData = Icons.access_time;
        break;
      case AwarenessCategory.coverage:
        iconData = Icons.sync;
        break;
      case AwarenessCategory.task:
        iconData = Icons.assignment_outlined;
        break;
      case AwarenessCategory.communication:
        iconData = Icons.campaign_outlined;
        break;
      case AwarenessCategory.system:
        iconData = Icons.info_outline;
        break;
    }

    final timeStr =
        '${item.timestamp.hour.toString().padLeft(2, '0')}:${item.timestamp.minute.toString().padLeft(2, '0')}';

    return InkWell(
      onTap: () {
        _service.markAttentionSeen(item.id);
        _handleDeepLink(item);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: item.priority != OperationalPriority.normal
                ? borderColor
                : Colors.grey.shade800,
            width: item.priority == OperationalPriority.urgent ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(iconData, size: 18, color: iconColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.category.label.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.6,
                      color: iconColor,
                    ),
                  ),
                ),
                if (item.isCached)
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade900.withAlpha(80),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'CACHED',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.amber.shade300),
                    ),
                  ),
                Text(
                  timeStr,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              item.title,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              item.message,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade300, height: 1.3),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                if (item.zoneName != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF334155),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_on_outlined, size: 12, color: Colors.white70),
                        const SizedBox(width: 4),
                        Text(
                          item.zoneName!,
                          style: const TextStyle(fontSize: 11, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: item.relevance == OperationalRelevance.myZone
                        ? Colors.indigo.shade900.withAlpha(120)
                        : const Color(0xFF334155),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    item.relevance.label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: item.relevance == OperationalRelevance.myZone
                          ? Colors.indigo.shade200
                          : Colors.grey.shade400,
                    ),
                  ),
                ),
                const Spacer(),
                if (item.actionRoute != null)
                  TextButton.icon(
                    onPressed: () {
                      _service.markAttentionSeen(item.id);
                      _handleDeepLink(item);
                    },
                    icon: const Icon(Icons.arrow_forward, size: 14, color: Color(0xFF818CF8)),
                    label: const Text(
                      'VIEW',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF818CF8)),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _handleDeepLink(OperationalAwarenessItem item) {
    final route = item.actionRoute;
    if (route == null) return;

    switch (route) {
      case 'incident_detail':
        final incidentId = item.actionPayload?['incidentId'] as String?;
        if (incidentId != null) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => IncidentDetailScreen(incidentId: incidentId),
            ),
          );
        }
        break;
      case 'supervisor_tasks':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SupervisorTasksScreen()),
        );
        break;
      case 'shift_overview':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ShiftOverviewScreen()),
        );
        break;
      case 'team_overview':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const TeamOverviewScreen()),
        );
        break;
      case 'communications':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CommunicationsCenterScreen()),
        );
        break;
      case 'scanner':
        Navigator.of(context).pop(); // Return to scan screen
        break;
    }
  }
}
