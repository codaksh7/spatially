import 'package:flutter/material.dart';
import '../../../design_system/design_system.dart';
import '../../../services/attendee_identity.dart';
import '../../explore/models/spatially_event.dart';
import '../../map/map_screen.dart';
import '../data/event_content_repository.dart';
import '../models/spatially_activity.dart';
import '../widgets/activity_card.dart';
import 'activity_detail_screen.dart';

/// Full interactive engagement and activities directory for an event.
class ActivitiesScreen extends StatefulWidget {
  final SpatiallyEvent? event;
  final String eventId;
  final String? eventName;

  const ActivitiesScreen({
    super.key,
    this.event,
    required this.eventId,
    this.eventName,
  });

  @override
  State<ActivitiesScreen> createState() => _ActivitiesScreenState();
}

class _ActivitiesScreenState extends State<ActivitiesScreen> {
  final EventContentRepository _repository = EventContentRepositoryImpl();

  bool _loading = true;
  String? _errorMessage;
  List<SpatiallyActivity> _allActivities = [];
  Set<String> _completedActivityIds = {};
  ActivityType? _selectedType;

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  Future<void> _loadActivities() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final attendeeId = AttendeeIdentity.deviceId ?? '';
      final results = await Future.wait([
        _repository.getActivities(widget.eventId),
        _repository.getCompletedActivityIds(widget.eventId, attendeeId),
      ]);

      if (mounted) {
        setState(() {
          _allActivities = results[0] as List<SpatiallyActivity>;
          _completedActivityIds = results[1] as Set<String>;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _loading = false;
        });
      }
    }
  }

  List<SpatiallyActivity> get _filteredActivities {
    if (_selectedType == null) return _allActivities;
    return _allActivities.where((a) => a.type == _selectedType).toList();
  }

  int get _totalAvailablePoints {
    return _allActivities.fold<int>(0, (sum, a) => sum + a.points);
  }

  void _openMapForActivity(SpatiallyActivity activity) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MapScreen(
          initialEvent: widget.event,
          initialZoneId: activity.zoneId,
          initialPoiId: activity.poiId,
        ),
      ),
    );
  }

  Future<void> _openActivityDetail(SpatiallyActivity activity) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ActivityDetailScreen(
          activity: activity,
          event: widget.event,
          isAlreadyCompleted: _completedActivityIds.contains(activity.id),
          onNavigateToMap: () => _openMapForActivity(activity),
        ),
      ),
    );
    if (changed == true && mounted) {
      _loadActivities();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = isDark ? SpatiallyColors.darkTextPrimary : SpatiallyColors.lightTextPrimary;
    final textSecondary = isDark ? SpatiallyColors.darkTextSecondary : SpatiallyColors.lightTextSecondary;

    final displayTitle = widget.eventName != null ? 'Activities • ${widget.eventName}' : 'Event Activities';

    return Scaffold(
      appBar: SpatiallyAppBar(
        title: displayTitle,
        automaticallyImplyLeading: true,
      ),
      body: RefreshIndicator(
        onRefresh: _loadActivities,
        color: SpatiallyColors.violet,
        child: Column(
          children: [
            // Points Banner & Filter Header
            Container(
              padding: const EdgeInsets.fromLTRB(
                SpatiallySpacing.md,
                SpatiallySpacing.md,
                SpatiallySpacing.md,
                SpatiallySpacing.sm,
              ),
              child: Column(
                children: [
                  // Total Points Banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: SpatiallyColors.violet.withValues(alpha: 0.12),
                      borderRadius: SpatiallyRadius.borderSm,
                      border: Border.all(
                        color: SpatiallyColors.violet.withValues(alpha: 0.25),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.stars_rounded, color: SpatiallyColors.violet, size: 24),
                        SpatiallySpacing.gapHorizontalMd,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ENGAGEMENT ENGINE',
                                style: SpatiallyTypography.badge(color: SpatiallyColors.violet).copyWith(fontSize: 10),
                              ),
                              Text(
                                '$_totalAvailablePoints Points Available Across Event',
                                style: SpatiallyTypography.caption(color: textPrimary)
                                    .copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  SpatiallySpacing.gapVerticalMd,

                  // Type filter pills
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterPill(
                          label: 'All (${_allActivities.length})',
                          isSelected: _selectedType == null,
                          onTap: () => setState(() => _selectedType = null),
                        ),
                        SpatiallySpacing.gapHorizontalXs,
                        _buildFilterPill(
                          label: 'Checkpoints',
                          isSelected: _selectedType == ActivityType.checkpoint,
                          onTap: () => setState(() => _selectedType = ActivityType.checkpoint),
                        ),
                        SpatiallySpacing.gapHorizontalXs,
                        _buildFilterPill(
                          label: 'Quests',
                          isSelected: _selectedType == ActivityType.quest,
                          onTap: () => setState(() => _selectedType = ActivityType.quest),
                        ),
                        SpatiallySpacing.gapHorizontalXs,
                        _buildFilterPill(
                          label: 'Challenges',
                          isSelected: _selectedType == ActivityType.challenge,
                          onTap: () => setState(() => _selectedType = ActivityType.challenge),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            Expanded(
              child: _buildContent(context, textPrimary, textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, Color textPrimary, Color textSecondary) {
    if (_loading) {
      return const Center(
        child: SpatiallyLoadingState(message: 'Loading activities...'),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: SpatiallyErrorState(
          error: 'Unable to load activities.',
          onRetry: _loadActivities,
        ),
      );
    }

    final filtered = _filteredActivities;
    if (filtered.isEmpty) {
      return const Center(
        child: SpatiallyEmptyState(
          icon: Icons.emoji_events_outlined,
          title: 'No activities found',
          description: 'There are no activities matching this category.',
        ),
      );
    }

    return ListView.separated(
      padding: SpatiallySpacing.screenPadding,
      itemCount: filtered.length,
      separatorBuilder: (ctx, index) => SpatiallySpacing.gapVerticalMd,
      itemBuilder: (context, index) {
        final activity = filtered[index];
        final isCompleted = _completedActivityIds.contains(activity.id);
        return ActivityCard(
          activity: activity,
          isCompleted: isCompleted,
          onTap: () => _openActivityDetail(activity),
          onMapTap: () => _openMapForActivity(activity),
        );
      },
    );
  }

  Widget _buildFilterPill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const color = SpatiallyColors.warning;

    return InkWell(
      onTap: onTap,
      borderRadius: SpatiallyRadius.borderFull,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.16)
              : (isDark ? SpatiallyColors.darkSurface : SpatiallyColors.lightSurface),
          borderRadius: SpatiallyRadius.borderFull,
          border: Border.all(
            color: isSelected ? color : (isDark ? SpatiallyColors.darkBorderSubdued : SpatiallyColors.lightBorderSubdued),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: SpatiallyTypography.caption(
            color: isSelected ? color : (isDark ? SpatiallyColors.darkTextSecondary : SpatiallyColors.lightTextSecondary),
          ).copyWith(fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal),
        ),
      ),
    );
  }
}
