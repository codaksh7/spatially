import 'package:flutter/material.dart';
import '../../design_system/design_system.dart';
import '../../services/offline_service.dart';
import '../explore/models/spatially_event.dart';
import '../explore/event_detail_screen.dart';
import '../event_content/data/event_content_repository.dart';
import '../event_content/sessions/session_detail_screen.dart';
import '../event_content/booths/booth_detail_screen.dart';
import '../event_content/activities/activity_detail_screen.dart';
import '../map/map_screen.dart';
import '../connect/connect_screen.dart';
import '../safety/safety_screen.dart';
import 'data/notification_repository.dart';
import 'models/notification_models.dart';
import 'widgets/notification_item_card.dart';

/// Notification Center screen for attendees.
///
/// Features:
/// - Reactive unread notification tracking
/// - Category filtering (All, Sessions, Activities, Networking, Safety, Announcements)
/// - One-tap Mark All as Read
/// - Swipe to dismiss
/// - Deep linking to Sessions, Booths, Activities, Map, Connect, and Safety
/// - Standard Spatially Design System typography, cards, and states
class NotificationCenterScreen extends StatefulWidget {
  final SpatiallyEvent? event;

  const NotificationCenterScreen({
    super.key,
    this.event,
  });

  @override
  State<NotificationCenterScreen> createState() => _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  final NotificationRepository _repository = NotificationRepositoryImpl();
  final EventContentRepository _contentRepo = EventContentRepositoryImpl();

  NotificationCategory? _selectedCategory;
  bool _filterUnreadOnly = false;

  Future<void> _handleAction(NotificationItem item) async {
    // Always mark as read when attendee interacts
    await _repository.markAsRead(item.id);

    if (!mounted) return;

    final action = item.action;
    final eventId = action.eventId ?? widget.event?.id ?? 'default_event';

    switch (action.type) {
      case NotificationActionType.session:
        final sessionId = action.targetId;
        if (sessionId != null) {
          final session = await _contentRepo.getSessionById(eventId, sessionId);
          if (session != null && mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SessionDetailScreen(
                  session: session,
                  event: widget.event,
                ),
              ),
            );
            return;
          }
        }
        break;

      case NotificationActionType.booth:
        final boothId = action.targetId;
        if (boothId != null) {
          final booth = await _contentRepo.getBoothById(eventId, boothId);
          if (booth != null && mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => BoothDetailScreen(
                  booth: booth,
                  event: widget.event,
                ),
              ),
            );
            return;
          }
        }
        break;

      case NotificationActionType.activity:
        final activityId = action.targetId;
        if (activityId != null) {
          final activity = await _contentRepo.getActivityById(eventId, activityId);
          if (activity != null && mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ActivityDetailScreen(
                  activity: activity,
                  event: widget.event,
                ),
              ),
            );
            return;
          }
        }
        break;

      case NotificationActionType.map:
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MapScreen(
              initialEvent: widget.event,
              initialZoneId: action.zoneId,
              initialPoiId: action.poiId,
            ),
          ),
        );
        return;

      case NotificationActionType.connect:
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ConnectScreen(event: widget.event),
          ),
        );
        return;

      case NotificationActionType.safety:
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SafetyScreen(event: widget.event),
          ),
        );
        return;

      case NotificationActionType.eventDetail:
        if (widget.event != null && mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => EventDetailScreen(event: widget.event!),
            ),
          );
        }
        return;

      case NotificationActionType.none:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final background = isDark ? SpatiallyColors.darkBackground : SpatiallyColors.lightBackground;
    final textPrimary = isDark ? SpatiallyColors.darkTextPrimary : SpatiallyColors.lightTextPrimary;
    final textSecondary = isDark ? SpatiallyColors.darkTextSecondary : SpatiallyColors.lightTextSecondary;

    return Scaffold(
      backgroundColor: background,
      appBar: SpatiallyAppBar(
        title: 'Notifications',
        actions: [
          StreamBuilder<int>(
            stream: _repository.observeUnreadCount(eventId: widget.event?.id),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data ?? 0;
              if (unreadCount == 0) return const SizedBox.shrink();

              return TextButton.icon(
                onPressed: () async {
                  await _repository.markAllAsRead(eventId: widget.event?.id);
                },
                icon: const Icon(
                  Icons.done_all_rounded,
                  size: 16,
                  color: SpatiallyColors.violet,
                ),
                label: Text(
                  'Mark all read',
                  style: SpatiallyTypography.caption(color: SpatiallyColors.violet).copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Filter categories horizontal bar
            _buildCategoryFilters(isDark, textPrimary, textSecondary),

            const Divider(height: 1),

            ValueListenableBuilder<bool>(
              valueListenable: OfflineService().isOnlineNotifier,
              builder: (context, isOnline, _) {
                if (isOnline) return const SizedBox.shrink();
                return const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: SpatiallyOfflineBanner(
                    message: 'Offline Mode • Stored notification history available. Cloud updates require connection.',
                  ),
                );
              },
            ),

            // Notification stream list
            Expanded(
              child: StreamBuilder<List<NotificationItem>>(
                stream: _repository.observeNotifications(eventId: widget.event?.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                    return const Center(
                      child: SpatiallyLoadingState(message: 'Loading notifications…'),
                    );
                  }

                  final allNotifs = snapshot.data ?? [];
                  var filtered = allNotifs;

                  if (_selectedCategory != null) {
                    filtered = filtered.where((n) => n.category == _selectedCategory).toList();
                  }

                  if (_filterUnreadOnly) {
                    filtered = filtered.where((n) => !n.isRead).toList();
                  }

                  if (filtered.isEmpty) {
                    return Center(
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: SpatiallyEmptyState(
                          icon: _filterUnreadOnly
                              ? Icons.mark_email_read_outlined
                              : Icons.notifications_none_rounded,
                          title: _filterUnreadOnly
                              ? 'All Caught Up'
                              : (_selectedCategory != null
                                  ? 'No ${_selectedCategory!.label}'
                                  : 'No Notifications'),
                          description: _filterUnreadOnly
                              ? 'You have read all notifications in this category.'
                              : 'Event updates, session alerts, and recommendations will appear here.',
                        ),
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      await _repository.refresh(eventId: widget.event?.id);
                    },
                    color: SpatiallyColors.violet,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: SpatiallySpacing.md,
                        vertical: SpatiallySpacing.md,
                      ),
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => SpatiallySpacing.gapVerticalSm,
                      itemBuilder: (context, index) {
                        final notif = filtered[index];
                        return NotificationItemCard(
                          notification: notif,
                          onTap: () => _handleAction(notif),
                          onAction: (_) => _handleAction(notif),
                          onDismiss: () => _repository.dismissNotification(notif.id),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryFilters(bool isDark, Color textPrimary, Color textSecondary) {
    final categories = [
      null, // All
      NotificationCategory.session,
      NotificationCategory.crowd,
      NotificationCategory.activity,
      NotificationCategory.connect,
      NotificationCategory.safety,
      NotificationCategory.recommendation,
      NotificationCategory.event,
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: SpatiallySpacing.md,
        vertical: SpatiallySpacing.sm,
      ),
      child: Row(
        children: [
          // Filter unread toggle button
          FilterChip(
            selected: _filterUnreadOnly,
            label: Text(
              'Unread',
              style: SpatiallyTypography.caption(
                color: _filterUnreadOnly
                    ? Colors.white
                    : (isDark ? SpatiallyColors.darkTextPrimary : SpatiallyColors.lightTextPrimary),
              ).copyWith(
                fontWeight: _filterUnreadOnly ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            avatar: Icon(
              Icons.circle,
              size: 8,
              color: _filterUnreadOnly ? Colors.white : SpatiallyColors.violet,
            ),
            selectedColor: SpatiallyColors.violet,
            backgroundColor: isDark ? SpatiallyColors.darkSurface : SpatiallyColors.lightSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(SpatiallyRadius.full),
              side: BorderSide(
                color: _filterUnreadOnly
                    ? SpatiallyColors.violet
                    : (isDark
                        ? SpatiallyColors.darkBorderSubdued
                        : SpatiallyColors.lightBorderSubdued),
              ),
            ),
            showCheckmark: false,
            onSelected: (val) {
              setState(() {
                _filterUnreadOnly = val;
              });
            },
          ),
          const SizedBox(width: 8),

          // Categories chips
          for (final cat in categories) ...[
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                selected: _selectedCategory == cat,
                label: Text(
                  cat == null ? 'All' : cat.label,
                  style: SpatiallyTypography.caption(
                    color: _selectedCategory == cat
                        ? Colors.white
                        : (isDark ? SpatiallyColors.darkTextPrimary : SpatiallyColors.lightTextPrimary),
                  ).copyWith(
                    fontWeight: _selectedCategory == cat ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
                selectedColor: SpatiallyColors.violet,
                backgroundColor: isDark ? SpatiallyColors.darkSurface : SpatiallyColors.lightSurface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(SpatiallyRadius.full),
                  side: BorderSide(
                    color: _selectedCategory == cat
                        ? SpatiallyColors.violet
                        : (isDark
                            ? SpatiallyColors.darkBorderSubdued
                            : SpatiallyColors.lightBorderSubdued),
                  ),
                ),
                showCheckmark: false,
                onSelected: (_) {
                  setState(() {
                    _selectedCategory = cat;
                  });
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
