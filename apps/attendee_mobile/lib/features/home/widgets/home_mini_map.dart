import 'package:flutter/material.dart';
import '../../../design_system/design_system.dart';
import '../../map/models/venue_map_models.dart';

/// Glanceable mini-map card for the Home screen.
///
/// Consumes production [SpatialMapSnapshot] topology and crowd telemetry.
/// Serves as a glanceable preview and entry point to the full Map screen.
/// Does NOT invent positioning or duplicate map rendering algorithms.
class HomeMiniMap extends StatelessWidget {
  final VoidCallback? onTap;
  final String? activeZone;
  final SpatialMapSnapshot? snapshot;

  const HomeMiniMap({
    super.key,
    this.onTap,
    this.activeZone,
    this.snapshot,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = isDark ? SpatiallyColors.darkSurface : SpatiallyColors.lightSurface;
    final textPrimary =
        isDark ? SpatiallyColors.darkTextPrimary : SpatiallyColors.lightTextPrimary;
    final textSecondary =
        isDark ? SpatiallyColors.darkTextSecondary : SpatiallyColors.lightTextSecondary;
    final border =
        isDark ? SpatiallyColors.darkBorderSubdued : SpatiallyColors.lightBorderSubdued;

    final hasData = snapshot != null && snapshot!.eventZones.isNotEmpty;
    final zoneCount = snapshot?.eventZones.length ?? 0;
    final levelName = snapshot?.levels.isNotEmpty == true ? snapshot!.levels.first.name : null;

    String subtitleText;
    if (activeZone != null) {
      subtitleText = 'You\'re in $activeZone';
    } else if (hasData) {
      subtitleText = levelName != null ? '$levelName · $zoneCount Zones' : '$zoneCount Venue Zones';
    } else {
      subtitleText = 'No active zone · Venue overview';
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 168,
        decoration: BoxDecoration(
          color: surface,
          borderRadius: SpatiallyRadius.borderMd,
          border: Border.all(color: border),
          boxShadow: SpatiallyShadows.cardShadow(isDark: isDark),
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          children: [
            // Background: Real production spatial zones or neutral preview
            Positioned.fill(
              child: _ZoneBackground(
                isDark: isDark,
                snapshot: snapshot,
              ),
            ),

            // Top-left: label
            Positioned(
              top: 12,
              left: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: surface.withValues(alpha: 0.88),
                  borderRadius: SpatiallyRadius.borderXs,
                  border: Border.all(color: border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.grid_view_rounded,
                      size: 12,
                      color: SpatiallyColors.spatialCyan,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'VENUE MAP',
                      style: SpatiallyTypography.badge(
                        color: textPrimary,
                      ).copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),

            // Zone label (if active)
            if (activeZone != null)
              Positioned(
                top: 12,
                right: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: SpatiallyColors.spatialCyan.withValues(alpha: 0.15),
                    borderRadius: SpatiallyRadius.borderXs,
                    border: Border.all(
                      color: SpatiallyColors.spatialCyan.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    activeZone!,
                    style: SpatiallyTypography.badge(
                      color: SpatiallyColors.spatialCyan,
                    ).copyWith(fontSize: 11),
                  ),
                ),
              ),

            // Bottom bar: action hint with translucent overlay
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: surface.withValues(alpha: 0.9),
                  border: Border(top: BorderSide(color: border)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        subtitleText,
                        style: SpatiallyTypography.secondary(color: textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Open Map',
                      style: SpatiallyTypography.secondaryMedium(
                        color: SpatiallyColors.violet,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 13,
                      color: SpatiallyColors.violet,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Visual spatial rendering consuming [SpatialMapSnapshot].
class _ZoneBackground extends StatelessWidget {
  final bool isDark;
  final SpatialMapSnapshot? snapshot;

  const _ZoneBackground({
    required this.isDark,
    this.snapshot,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = isDark
        ? SpatiallyColors.darkSurfaceElevated
        : const Color(0xFFEEF0F8);
    final zoneColor = isDark
        ? SpatiallyColors.darkBorderSubdued
        : const Color(0xFFE0E3EF);
    final accentColor = SpatiallyColors.spatialCyan;
    final violetColor = SpatiallyColors.violet;

    return CustomPaint(
      painter: _ProductionVenuePainter(
        baseColor: baseColor,
        zoneColor: zoneColor,
        accentColor: accentColor,
        violetColor: violetColor,
        isDark: isDark,
        snapshot: snapshot,
      ),
    );
  }
}

class _ProductionVenuePainter extends CustomPainter {
  final Color baseColor;
  final Color zoneColor;
  final Color accentColor;
  final Color violetColor;
  final bool isDark;
  final SpatialMapSnapshot? snapshot;

  _ProductionVenuePainter({
    required this.baseColor,
    required this.zoneColor,
    required this.accentColor,
    required this.violetColor,
    required this.isDark,
    this.snapshot,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Background Fill
    final bg = Paint()..color = baseColor;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bg);

    final currentSnapshot = snapshot;
    if (currentSnapshot == null || currentSnapshot.eventZones.isEmpty) {
      // Neutral fallback grid lines
      _paintNeutralPlaceholder(canvas, size);
      return;
    }

    // 2. Render real zones from snapshot bounds
    final defaultLevelId = currentSnapshot.levels.isNotEmpty ? currentSnapshot.levels.first.id : null;
    final relevantZones = defaultLevelId != null
        ? currentSnapshot.eventZones.where((z) => z.levelId == defaultLevelId).toList()
        : currentSnapshot.eventZones;

    final zonesToDraw = relevantZones.isNotEmpty ? relevantZones : currentSnapshot.eventZones;

    final zoneBorderPaint = Paint()
      ..color = isDark ? SpatiallyColors.darkBorderSubdued : const Color(0xFFD4D8E8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (final zone in zonesToDraw) {
      // Map normalized 0.0-1.0 coordinate space to canvas size (with padding to clear top & bottom bars)
      const topPadding = 36.0;
      const bottomPadding = 42.0;
      const horizontalPadding = 12.0;

      final availWidth = size.width - (horizontalPadding * 2);
      final availHeight = size.height - topPadding - bottomPadding;

      final rect = Rect.fromLTWH(
        horizontalPadding + (zone.bounds.left * availWidth),
        topPadding + (zone.bounds.top * availHeight),
        (zone.bounds.width * availWidth).clamp(28.0, availWidth),
        (zone.bounds.height * availHeight).clamp(24.0, availHeight),
      );

      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(6));

      // Resolve crowd tint
      final crowd = currentSnapshot.crowdStates[zone.code];
      Color fillColor = zoneColor;
      if (crowd != null && crowd.freshness == SpatialCrowdFreshness.live) {
        switch (crowd.crowdLevel) {
          case SpatiallyCrowdLevel.low:
            fillColor = SpatiallyColors.crowdLow.withValues(alpha: 0.18);
            break;
          case SpatiallyCrowdLevel.moderate:
            fillColor = SpatiallyColors.crowdModerate.withValues(alpha: 0.22);
            break;
          case SpatiallyCrowdLevel.busy:
            fillColor = SpatiallyColors.crowdBusy.withValues(alpha: 0.25);
            break;
          case SpatiallyCrowdLevel.high:
            fillColor = SpatiallyColors.crowdHigh.withValues(alpha: 0.28);
            break;
        }
      }

      final fillPaint = Paint()
        ..color = fillColor
        ..style = PaintingStyle.fill;

      canvas.drawRRect(rrect, fillPaint);
      canvas.drawRRect(rrect, zoneBorderPaint);

      // Label text
      final textSpan = TextSpan(
        text: zone.code.isNotEmpty ? zone.code : zone.name,
        style: TextStyle(
          color: isDark ? SpatiallyColors.darkTextSecondary : SpatiallyColors.lightTextSecondary,
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: rect.width - 4);

      if (textPainter.width < rect.width && textPainter.height < rect.height) {
        textPainter.paint(
          canvas,
          Offset(
            rect.center.dx - (textPainter.width / 2),
            rect.center.dy - (textPainter.height / 2),
          ),
        );
      }
    }

    // 3. Draw POI points
    final poiPaint = Paint()
      ..color = SpatiallyColors.spatialCyan
      ..style = PaintingStyle.fill;

    for (final poi in currentSnapshot.pois) {
      if (defaultLevelId != null && poi.levelId != defaultLevelId) continue;
      const topPadding = 36.0;
      const bottomPadding = 42.0;
      const horizontalPadding = 12.0;
      final availWidth = size.width - (horizontalPadding * 2);
      final availHeight = size.height - topPadding - bottomPadding;

      final offset = Offset(
        horizontalPadding + (poi.point.x * availWidth),
        topPadding + (poi.point.y * availHeight),
      );

      canvas.drawCircle(offset, 2.5, poiPaint);
    }
  }

  void _paintNeutralPlaceholder(Canvas canvas, Size size) {
    final dotPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;

    const step = 20.0;
    for (double x = 16; x < size.width - 16; x += step) {
      for (double y = 40; y < size.height - 40; y += step) {
        canvas.drawCircle(Offset(x, y), 1.2, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ProductionVenuePainter oldDelegate) {
    return oldDelegate.snapshot != snapshot ||
        oldDelegate.isDark != isDark ||
        oldDelegate.baseColor != baseColor;
  }
}
