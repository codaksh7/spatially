import 'package:flutter/material.dart';
import '../../../design_system/design_system.dart';
import '../models/spatially_session.dart';

/// Compact, scannable session card following Spatially Design rules:
/// Communicates What, When, Where, State, and Who without card overload.
class SessionCard extends StatelessWidget {
  final SpatiallySession session;
  final VoidCallback? onTap;
  final VoidCallback? onMapTap;

  const SessionCard({
    super.key,
    required this.session,
    this.onTap,
    this.onMapTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = isDark ? SpatiallyColors.darkTextPrimary : SpatiallyColors.lightTextPrimary;
    final textSecondary = isDark ? SpatiallyColors.darkTextSecondary : SpatiallyColors.lightTextSecondary;

    return Semantics(
      label: '${session.title}, ${session.categoryDisplayName}, ${session.status.name}',
      button: true,
      child: SpatiallyCard(
        hasSubtleGlow: session.isLive,
        padding: const EdgeInsets.all(SpatiallySpacing.md),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Category Pill + Status Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: SpatiallyColors.violet.withValues(alpha: 0.12),
                    borderRadius: SpatiallyRadius.borderSm,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(session.categoryIcon, size: 13, color: SpatiallyColors.violet),
                      SpatiallySpacing.gapHorizontalXxs,
                      Text(
                        session.categoryDisplayName.toUpperCase(),
                        style: SpatiallyTypography.badge(color: SpatiallyColors.violet).copyWith(fontSize: 10),
                      ),
                    ],
                  ),
                ),
                if (session.isLive)
                  const SpatiallyStatusBadge(
                    label: 'LIVE NOW',
                    variant: SpatiallyBadgeVariant.live,
                  )
                else if (session.isUpcoming)
                  const SpatiallyStatusBadge(
                    label: 'UPCOMING',
                    variant: SpatiallyBadgeVariant.upcoming,
                  )
                else
                  SpatiallyStatusBadge(
                    label: 'ENDED',
                    variant: SpatiallyBadgeVariant.custom,
                    customColor: textSecondary,
                    showDot: false,
                  ),
              ],
            ),

            SpatiallySpacing.gapVerticalSm,

            // Session Title
            Text(
              session.title,
              style: SpatiallyTypography.subheading(color: textPrimary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            SpatiallySpacing.gapVerticalXs,

            // Speaker & Company
            Row(
              children: [
                Icon(Icons.person_outline_rounded, size: 14, color: textSecondary),
                SpatiallySpacing.gapHorizontalXs,
                Expanded(
                  child: Text(
                    session.speakerCompany != null
                        ? '${session.speaker} • ${session.speakerCompany}'
                        : session.speaker,
                    style: SpatiallyTypography.secondary(color: textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            SpatiallySpacing.gapVerticalSm,
            const Divider(height: 1),
            SpatiallySpacing.gapVerticalSm,

            // Bottom Row: Time and Room/Map Badge
            Row(
              children: [
                Icon(Icons.schedule_rounded, size: 14, color: SpatiallyColors.violet),
                SpatiallySpacing.gapHorizontalXs,
                Text(
                  session.formattedTimeRange,
                  style: SpatiallyTypography.caption(color: textPrimary).copyWith(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                InkWell(
                  onTap: onMapTap,
                  borderRadius: SpatiallyRadius.borderSm,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_on_rounded, size: 13, color: SpatiallyColors.spatialCyan),
                        SpatiallySpacing.gapHorizontalXxs,
                        Text(
                          session.roomName.split('•').first.trim(),
                          style: SpatiallyTypography.caption(color: SpatiallyColors.spatialCyan).copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
