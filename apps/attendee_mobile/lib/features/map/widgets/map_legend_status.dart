import 'package:flutter/material.dart';
import '../../../design_system/spatially_colors.dart';
import '../../../design_system/spatially_typography.dart';
import '../../../design_system/spatially_radius.dart';
import '../models/venue_map_models.dart';

/// Status and legend banner showing level context and authoritative crowd telemetry state.
class MapLegendStatus extends StatelessWidget {
  final String? presenceZoneName;
  final String? floorName;
  final bool isLiveCrowd;
  final SpatialCrowdFreshness crowdFreshness;
  final bool isOffline;
  final VoidCallback? onResetView;

  const MapLegendStatus({
    super.key,
    this.presenceZoneName,
    this.floorName,
    this.isLiveCrowd = false,
    this.crowdFreshness = SpatialCrowdFreshness.live,
    this.isOffline = false,
    this.onResetView,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? SpatiallyColors.darkSurface : SpatiallyColors.lightSurface;
    final border = isDark ? SpatiallyColors.darkBorderSubdued : SpatiallyColors.lightBorderSubdued;
    final textSecondary = isDark ? SpatiallyColors.darkTextSecondary : SpatiallyColors.lightTextSecondary;

    // Resolve context label
    final contextLabel = presenceZoneName != null && presenceZoneName!.isNotEmpty
        ? presenceZoneName!
        : (floorName ?? 'Venue Map');

    // Resolve crowd telemetry presentation
    String crowdLabel;
    Color crowdColor;
    IconData? crowdIcon;

    if (isOffline) {
      crowdLabel = 'Crowd Offline';
      crowdColor = SpatiallyColors.warning;
      crowdIcon = Icons.wifi_off_rounded;
    } else {
      switch (crowdFreshness) {
        case SpatialCrowdFreshness.live:
          crowdLabel = isLiveCrowd || crowdFreshness == SpatialCrowdFreshness.live
              ? 'Live Telemetry'
              : 'Demo Crowd';
          crowdColor = SpatiallyColors.success;
          break;
        case SpatialCrowdFreshness.recent:
          crowdLabel = 'Recent Telemetry';
          crowdColor = SpatiallyColors.crowdModerate;
          break;
        case SpatialCrowdFreshness.stale:
          crowdLabel = 'Stale Telemetry';
          crowdColor = SpatiallyColors.crowdBusy;
          break;
        case SpatialCrowdFreshness.unavailable:
          crowdLabel = 'Crowd Unavailable';
          crowdColor = textSecondary;
          crowdIcon = Icons.info_outline_rounded;
          break;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: surface.withValues(alpha: 0.92),
        borderRadius: SpatiallyRadius.borderFull,
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Context Dot or Icon
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: SpatiallyColors.spatialCyan,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              contextLabel,
              style: SpatiallyTypography.caption(color: textSecondary).copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 3,
            height: 3,
            decoration: BoxDecoration(
              color: textSecondary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          if (crowdIcon != null) ...[
            Icon(
              crowdIcon,
              size: 11,
              color: crowdColor,
            ),
            const SizedBox(width: 4),
          ] else ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: crowdColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            crowdLabel,
            style: SpatiallyTypography.caption(
              color: crowdColor,
            ).copyWith(fontSize: 11, fontWeight: FontWeight.w600),
          ),
          if (onResetView != null) ...[
            const SizedBox(width: 8),
            InkWell(
              onTap: onResetView,
              borderRadius: SpatiallyRadius.borderFull,
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(
                  Icons.center_focus_strong_rounded,
                  size: 14,
                  color: SpatiallyColors.violet,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
