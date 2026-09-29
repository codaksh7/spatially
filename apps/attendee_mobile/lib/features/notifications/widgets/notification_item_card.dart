import 'package:flutter/material.dart';
import '../../../design_system/design_system.dart';
import '../models/notification_models.dart';

/// Card component representing an individual attendee notification.
///
/// Features:
/// - Visual differentiation by category (Session, Activity, Safety, Connect, etc.)
/// - Read/unread status styling with subtle dot indicator
/// - Priority badge for high or urgent venue alerts
/// - Relative timestamp formatting
/// - Action CTA button for deep linking
class NotificationItemCard extends StatelessWidget {
  final NotificationItem notification;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;
  final ValueChanged<NotificationAction>? onAction;

  const NotificationItemCard({
    super.key,
    required this.notification,
    this.onTap,
    this.onDismiss,
    this.onAction,
  });

  String _formatTimestamp(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = isDark ? SpatiallyColors.darkTextPrimary : SpatiallyColors.lightTextPrimary;
    final textSecondary = isDark ? SpatiallyColors.darkTextSecondary : SpatiallyColors.lightTextSecondary;

    final categoryColor = notification.category.color;
    final hasAction = notification.action.type != NotificationActionType.none;

    final content = SpatiallyCard(
      padding: const EdgeInsets.all(SpatiallySpacing.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SpatiallyRadius.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category Icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: categoryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(SpatiallyRadius.sm),
                    border: Border.all(
                      color: categoryColor.withValues(alpha: 0.25),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      notification.category.icon,
                      color: categoryColor,
                      size: 20,
                    ),
                  ),
                ),
                SpatiallySpacing.gapHorizontalMd,

                // Title, Category & Timestamp
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: SpatiallyTypography.body(color: textPrimary).copyWith(
                                fontWeight: notification.isRead ? FontWeight.w500 : FontWeight.w700,
                              ),
                            ),
                          ),
                          if (!notification.isRead) ...[
                            SpatiallySpacing.gapHorizontalXs,
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: SpatiallyColors.violet,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            notification.category.label,
                            style: SpatiallyTypography.caption(color: categoryColor).copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '•',
                            style: SpatiallyTypography.caption(color: textSecondary),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _formatTimestamp(notification.timestamp),
                            style: SpatiallyTypography.caption(color: textSecondary),
                          ),
                          if (notification.priority == NotificationPriority.urgent) ...[
                            const SizedBox(width: 6),
                            const SpatiallyStatusBadge(
                              label: 'NOTICE',
                              variant: SpatiallyBadgeVariant.custom,
                              customColor: SpatiallyColors.error,
                            ),
                          ] else if (notification.priority == NotificationPriority.high) ...[
                            const SizedBox(width: 6),
                            const SpatiallyStatusBadge(
                              label: 'PRIORITY',
                              variant: SpatiallyBadgeVariant.custom,
                              customColor: SpatiallyColors.warning,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Message Body
            Padding(
              padding: const EdgeInsets.only(left: 48 + 4),
              child: Text(
                notification.body,
                style: SpatiallyTypography.secondary(color: textSecondary).copyWith(
                  height: 1.35,
                ),
              ),
            ),

            // Action CTA button if present
            if (hasAction) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(left: 48 + 4),
                child: InkWell(
                  onTap: () {
                    if (onAction != null) {
                      onAction!(notification.action);
                    } else if (onTap != null) {
                      onTap!();
                    }
                  },
                  borderRadius: BorderRadius.circular(SpatiallyRadius.xs),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          notification.action.displayLabel,
                          style: SpatiallyTypography.caption(color: SpatiallyColors.violet).copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 13,
                          color: SpatiallyColors.violet,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );

    if (onDismiss != null) {
      return Dismissible(
        key: Key(notification.id),
        direction: DismissDirection.endToStart,
        onDismissed: (_) => onDismiss!(),
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: SpatiallyColors.error.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(SpatiallyRadius.md),
          ),
          child: const Icon(
            Icons.delete_outline_rounded,
            color: SpatiallyColors.error,
            size: 22,
          ),
        ),
        child: content,
      );
    }

    return content;
  }
}
