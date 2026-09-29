import 'package:flutter/material.dart';
import '../../../design_system/design_system.dart';
import '../models/connect_models.dart';

/// Card representing a discoverable attendee within the event networking list.
class ConnectAttendeeCard extends StatelessWidget {
  final ConnectProfile profile;
  final Connection? connection;
  final List<String> sharedInterests;
  final VoidCallback onTap;
  final VoidCallback onConnect;
  final VoidCallback onOpenChat;

  const ConnectAttendeeCard({
    super.key,
    required this.profile,
    this.connection,
    required this.sharedInterests,
    required this.onTap,
    required this.onConnect,
    required this.onOpenChat,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = isDark ? SpatiallyColors.darkTextPrimary : SpatiallyColors.lightTextPrimary;
    final textSecondary = isDark ? SpatiallyColors.darkTextSecondary : SpatiallyColors.lightTextSecondary;

    final status = connection?.status ?? ConnectionStatus.none;

    return SpatiallyCard(
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
                CircleAvatar(
                  radius: 24,
                  backgroundColor: SpatiallyColors.violet.withValues(alpha: 0.15),
                  child: Text(
                    profile.avatarInitials,
                    style: SpatiallyTypography.subheading(color: SpatiallyColors.violet).copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SpatiallySpacing.gapHorizontalMd,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              profile.displayName,
                              style: SpatiallyTypography.subheading(color: textPrimary).copyWith(fontSize: 16),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (profile.isReadyToChat)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: SpatiallySpacing.xs,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: SpatiallyColors.spatialCyan.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(SpatiallyRadius.full),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 5,
                                    height: 5,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: SpatiallyColors.spatialCyan,
                                    ),
                                  ),
                                  SpatiallySpacing.gapHorizontalXxs,
                                  Text(
                                    'Ready to Chat',
                                    style: SpatiallyTypography.caption(color: SpatiallyColors.spatialCyan).copyWith(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      if (profile.headline.isNotEmpty) ...[
                        SpatiallySpacing.gapVerticalXxs,
                        Text(
                          profile.headline,
                          style: SpatiallyTypography.caption(color: textSecondary).copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (profile.organization.isNotEmpty) ...[
                        Text(
                          profile.organization,
                          style: SpatiallyTypography.caption(color: textSecondary).copyWith(fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            if (profile.locationNote.isNotEmpty) ...[
              SpatiallySpacing.gapVerticalSm,
              Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 13,
                    color: textSecondary,
                  ),
                  SpatiallySpacing.gapHorizontalXxs,
                  Expanded(
                    child: Text(
                      profile.locationNote,
                      style: SpatiallyTypography.caption(color: textSecondary).copyWith(fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],

            SpatiallySpacing.gapVerticalSm,

            // Shared interests tag
            if (sharedInterests.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: SpatiallySpacing.xs,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: SpatiallyColors.violet.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(SpatiallyRadius.xs),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.hub_outlined,
                      size: 12,
                      color: SpatiallyColors.violet,
                    ),
                    SpatiallySpacing.gapHorizontalXxs,
                    Flexible(
                      child: Text(
                        '${sharedInterests.length} shared: ${sharedInterests.join(', ')}',
                        style: SpatiallyTypography.caption(color: SpatiallyColors.violet).copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              SpatiallySpacing.gapVerticalSm,
            ],

            // Action row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: onTap,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(50, 30),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'View Profile',
                    style: SpatiallyTypography.caption(color: SpatiallyColors.spatialCyan).copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _buildActionButton(status),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.none:
        return ElevatedButton.icon(
          onPressed: onConnect,
          icon: const Icon(Icons.person_add_outlined, size: 14),
          label: const Text('Connect'),
          style: ElevatedButton.styleFrom(
            backgroundColor: SpatiallyColors.violet,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(
              horizontal: SpatiallySpacing.md,
              vertical: SpatiallySpacing.xs,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(SpatiallyRadius.sm),
            ),
            minimumSize: const Size(0, 32),
          ),
        );

      case ConnectionStatus.requestSent:
        return OutlinedButton.icon(
          onPressed: onTap,
          icon: const Icon(Icons.hourglass_top_rounded, size: 14),
          label: const Text('Pending...'),
          style: OutlinedButton.styleFrom(
            foregroundColor: SpatiallyColors.warning,
            side: const BorderSide(color: SpatiallyColors.warning),
            padding: const EdgeInsets.symmetric(
              horizontal: SpatiallySpacing.sm,
              vertical: SpatiallySpacing.xs,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(SpatiallyRadius.sm),
            ),
            minimumSize: const Size(0, 32),
          ),
        );

      case ConnectionStatus.requestReceived:
        return ElevatedButton.icon(
          onPressed: onTap,
          icon: const Icon(Icons.mark_email_unread_outlined, size: 14),
          label: const Text('Respond'),
          style: ElevatedButton.styleFrom(
            backgroundColor: SpatiallyColors.spatialCyan,
            foregroundColor: SpatiallyColors.darkBackground,
            padding: const EdgeInsets.symmetric(
              horizontal: SpatiallySpacing.sm,
              vertical: SpatiallySpacing.xs,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(SpatiallyRadius.sm),
            ),
            minimumSize: const Size(0, 32),
          ),
        );

      case ConnectionStatus.connected:
        return ElevatedButton.icon(
          onPressed: onOpenChat,
          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 14),
          label: const Text('Chat'),
          style: ElevatedButton.styleFrom(
            backgroundColor: SpatiallyColors.violet,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(
              horizontal: SpatiallySpacing.md,
              vertical: SpatiallySpacing.xs,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(SpatiallyRadius.sm),
            ),
            minimumSize: const Size(0, 32),
          ),
        );

      case ConnectionStatus.declined:
      case ConnectionStatus.expired:
        return const SizedBox.shrink();
    }
  }
}
