import 'package:flutter/material.dart';
import '../../../design_system/spatially_colors.dart';
import '../../../design_system/spatially_typography.dart';
import '../../../design_system/spatially_spacing.dart';
import '../../../design_system/spatially_radius.dart';
import '../../../design_system/components/spatially_card.dart';
import '../../../design_system/components/spatially_button.dart';
import '../../../design_system/components/spatially_crowd_indicator.dart';
import '../models/venue_map_models.dart';

/// Floating contextual detail sheet for a selected Zone or POI on the Map.
class MapZoneSheet extends StatelessWidget {
  final MapZone? zone;
  final MapPoi? poi;
  final List<MapPoi> allPois;
  final bool isLiveCrowdData;
  final bool isOffline;
  final VoidCallback onNavigate;
  final VoidCallback onClose;

  const MapZoneSheet({
    super.key,
    this.zone,
    this.poi,
    required this.allPois,
    this.isLiveCrowdData = false,
    this.isOffline = false,
    required this.onNavigate,
    required this.onClose,
  }) : assert(zone != null || poi != null, 'Either zone or poi must be provided');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = isDark ? SpatiallyColors.darkTextPrimary : SpatiallyColors.lightTextPrimary;
    final textSecondary = isDark ? SpatiallyColors.darkTextSecondary : SpatiallyColors.lightTextSecondary;

    final title = poi != null ? poi!.name : '${zone!.roomNumber} • ${zone!.name}';
    final subtitle = poi != null ? poi!.description : zone!.purpose;

    // Find POIs inside this zone
    final List<MapPoi> containedPois = [];
    if (zone != null) {
      containedPois.addAll(allPois.where((p) => p.zoneId == zone!.id));
    }

    return SpatiallyCard(
      padding: const EdgeInsets.all(SpatiallySpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row with category / icon & close button
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: (poi != null ? _poiColor(poi!.category) : SpatiallyColors.spatialCyan)
                      .withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  poi != null ? poi!.icon : Icons.meeting_room_rounded,
                  size: 20,
                  color: poi != null ? _poiColor(poi!.category) : SpatiallyColors.spatialCyan,
                ),
              ),
              SpatiallySpacing.gapHorizontalMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: SpatiallyTypography.sectionHeading(color: textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: SpatiallyTypography.caption(color: textSecondary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                color: textSecondary,
                tooltip: 'Close',
                onPressed: onClose,
              ),
            ],
          ),

          SpatiallySpacing.gapVerticalMd,

          // Operational Status Banner (if closed / restricted)
          if (zone != null && !zone!.isActive) ...[
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: SpatiallySpacing.md,
                vertical: SpatiallySpacing.xs,
              ),
              decoration: BoxDecoration(
                color: zone!.isClosed
                    ? SpatiallyColors.error.withValues(alpha: 0.12)
                    : SpatiallyColors.warning.withValues(alpha: 0.12),
                borderRadius: SpatiallyRadius.borderSm,
                border: Border.all(
                  color: zone!.isClosed
                      ? SpatiallyColors.error.withValues(alpha: 0.3)
                      : SpatiallyColors.warning.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    zone!.isClosed ? Icons.block_rounded : Icons.lock_outline_rounded,
                    size: 14,
                    color: zone!.isClosed ? SpatiallyColors.error : SpatiallyColors.warning,
                  ),
                  SpatiallySpacing.gapHorizontalSm,
                  Expanded(
                    child: Text(
                      zone!.isClosed
                          ? 'Room is currently closed${zone!.statusReason != null ? ': ${zone!.statusReason}' : ''}'
                          : 'Restricted area${zone!.statusReason != null ? ': ${zone!.statusReason}' : ''}',
                      style: SpatiallyTypography.caption(
                        color: zone!.isClosed ? SpatiallyColors.error : SpatiallyColors.warning,
                      ).copyWith(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            SpatiallySpacing.gapVerticalSm,
          ],

          // Zone Crowd Level (if zone is active)
          if (zone != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: SpatiallySpacing.md,
                vertical: SpatiallySpacing.sm,
              ),
              decoration: BoxDecoration(
                color: isDark ? SpatiallyColors.darkSurfaceElevated : const Color(0xFFF1F4FA),
                borderRadius: SpatiallyRadius.borderSm,
              ),
              child: Row(
                children: [
                  if (zone!.crowdFreshness != SpatialCrowdFreshness.unavailable) ...[
                    SpatiallyCrowdIndicator(level: zone!.crowdLevel, compact: true),
                    SpatiallySpacing.gapHorizontalSm,
                  ] else ...[
                    const Icon(
                      Icons.people_outline_rounded,
                      size: 14,
                      color: SpatiallyColors.darkTextSecondary,
                    ),
                    SpatiallySpacing.gapHorizontalSm,
                  ],
                  Expanded(
                    child: Text(
                      isOffline || zone!.crowdFreshness == SpatialCrowdFreshness.unavailable
                          ? 'Crowd unavailable'
                          : (zone!.crowdFreshness == SpatialCrowdFreshness.stale
                              ? 'Stale telemetry (> 10m ago)'
                              : (zone!.crowdFreshness == SpatialCrowdFreshness.recent
                                  ? 'Recent telemetry (3–10m ago)'
                                  : (isLiveCrowdData ? 'Live volunteer sensor sync' : 'Live telemetry'))),
                      style: SpatiallyTypography.caption(color: textSecondary).copyWith(fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    'Cap ~${zone!.operatingCapacity > 0 ? zone!.operatingCapacity : zone!.capacity}',
                    style: SpatiallyTypography.caption(color: textSecondary).copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            SpatiallySpacing.gapVerticalMd,
          ],

          // Contained POIs (Booths, Stages in this room)
          if (containedPois.isNotEmpty) ...[
            Text(
              'IN THIS ROOM',
              style: SpatiallyTypography.badge(color: textSecondary).copyWith(fontSize: 10),
            ),
            SpatiallySpacing.gapVerticalXs,
            Wrap(
              spacing: SpatiallySpacing.xs,
              runSpacing: SpatiallySpacing.xs,
              children: containedPois.map((p) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _poiColor(p.category).withValues(alpha: 0.10),
                    borderRadius: SpatiallyRadius.borderFull,
                    border: Border.all(
                      color: _poiColor(p.category).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(p.icon, size: 12, color: _poiColor(p.category)),
                      const SizedBox(width: 4),
                      Text(
                        p.name,
                        style: SpatiallyTypography.caption(
                          color: _poiColor(p.category),
                        ).copyWith(fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            SpatiallySpacing.gapVerticalMd,
          ],

          // Navigate Action CTA using SpatiallyPrimaryButton
          SpatiallyPrimaryButton(
            label: 'Navigate to ${poi != null ? poi!.name : zone!.roomNumber}',
            icon: const Icon(Icons.navigation_rounded, color: Colors.white, size: 18),
            onPressed: onNavigate,
          ),
        ],
      ),
    );
  }

  Color _poiColor(PoiCategory category) {
    switch (category) {
      case PoiCategory.stages:
        return SpatiallyColors.violet;
      case PoiCategory.booths:
        return const Color(0xFF0284C7);
      case PoiCategory.facilities:
        return const Color(0xFF0D9488);
      case PoiCategory.safety:
        return SpatiallyColors.error;
    }
  }
}
