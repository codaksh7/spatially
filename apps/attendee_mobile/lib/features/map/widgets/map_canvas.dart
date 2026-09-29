import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../design_system/spatially_colors.dart';
import '../../../design_system/components/spatially_crowd_indicator.dart';
import '../models/venue_map_models.dart';

/// Interactive Canvas for Spatially Venue Map.
/// 
/// Supports pinch-to-zoom, panning, level map asset rendering, normalized vector
/// zones (polygons or bounding boxes), POI icons, crowd density heatmaps,
/// and waypoint route preview.
class MapCanvas extends StatefulWidget {
  final VenueMapData venueData;
  final PoiCategory? selectedCategory;
  final bool showCrowdLayer;
  final MapZone? selectedZone;
  final MapPoi? selectedPoi;
  final MapRoute? activeRoute;
  final String? presenceZoneId;
  final TransformationController transformationController;
  final ValueChanged<MapZone?> onZoneTap;
  final ValueChanged<MapPoi?> onPoiTap;

  const MapCanvas({
    super.key,
    required this.venueData,
    this.selectedCategory,
    this.showCrowdLayer = false,
    this.selectedZone,
    this.selectedPoi,
    this.activeRoute,
    this.presenceZoneId,
    required this.transformationController,
    required this.onZoneTap,
    required this.onPoiTap,
  });

  @override
  State<MapCanvas> createState() => _MapCanvasState();
}

class _MapCanvasState extends State<MapCanvas> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _handleTapUp(TapUpDetails details, Size canvasSize) {
    // Convert tap position to canvas local coordinate
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final localPosition = details.localPosition;
    final transform = widget.transformationController.value;
    final inverse = Matrix4.tryInvert(transform);
    if (inverse == null) return;

    final transformed = MatrixUtils.transformPoint(inverse, localPosition);

    // 1. Check POI hit test first (radius ~ 24px)
    final pois = _getFilteredPois();
    for (final poi in pois.reversed) {
      final poiOffset = poi.point.toOffset(canvasSize);
      final distance = (transformed - poiOffset).distance;
      if (distance <= 24.0) {
        widget.onPoiTap(poi);
        return;
      }
    }

    // 2. Check Zone hit test
    final normalizedTap = MapPoint(
      (transformed.dx / canvasSize.width).clamp(0.0, 1.0),
      (transformed.dy / canvasSize.height).clamp(0.0, 1.0),
    );

    for (final zone in widget.venueData.zones.reversed) {
      if (zone.bounds.contains(normalizedTap)) {
        widget.onZoneTap(zone);
        return;
      }
    }

    // Tapped outside
    widget.onZoneTap(null);
    widget.onPoiTap(null);
  }

  List<MapPoi> _getFilteredPois() {
    if (widget.selectedCategory == null) {
      return widget.venueData.pois;
    }
    return widget.venueData.pois
        .where((poi) => poi.category == widget.selectedCategory)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final canvasWidth = constraints.maxWidth;
        final canvasHeight = math.max(constraints.maxHeight, canvasWidth * 1.25);
        final canvasSize = Size(canvasWidth, canvasHeight);
        final hasMapAsset = widget.venueData.mapAssetUrl != null &&
            widget.venueData.mapAssetUrl!.trim().isNotEmpty;

        return GestureDetector(
          onTapUp: (details) => _handleTapUp(details, canvasSize),
          child: InteractiveViewer(
            transformationController: widget.transformationController,
            boundaryMargin: const EdgeInsets.all(120),
            minScale: 0.85,
            maxScale: 3.5,
            clipBehavior: Clip.none,
            child: SizedBox(
              width: canvasSize.width,
              height: canvasSize.height,
              child: Stack(
                children: [
                  // 1. Optional Level Map Asset (Background)
                  if (hasMapAsset)
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          widget.venueData.mapAssetUrl!,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return const SizedBox.shrink(); // Fallback to vector canvas cleanly
                          },
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                  // 2. Vector Map Painter (Zones, Bounds, POIs, Routes, Crowd)
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return CustomPaint(
                          size: canvasSize,
                          painter: _VenueMapPainter(
                            venueData: widget.venueData,
                            filteredPois: _getFilteredPois(),
                            selectedZone: widget.selectedZone,
                            selectedPoi: widget.selectedPoi,
                            activeRoute: widget.activeRoute,
                            presenceZoneId: widget.presenceZoneId,
                            showCrowdLayer: widget.showCrowdLayer,
                            pulseValue: _pulseController.value,
                            isDark: isDark,
                            hasMapAsset: hasMapAsset,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _VenueMapPainter extends CustomPainter {
  final VenueMapData venueData;
  final List<MapPoi> filteredPois;
  final MapZone? selectedZone;
  final MapPoi? selectedPoi;
  final MapRoute? activeRoute;
  final String? presenceZoneId;
  final bool showCrowdLayer;
  final double pulseValue;
  final bool isDark;
  final bool hasMapAsset;

  _VenueMapPainter({
    required this.venueData,
    required this.filteredPois,
    this.selectedZone,
    this.selectedPoi,
    this.activeRoute,
    this.presenceZoneId,
    required this.showCrowdLayer,
    required this.pulseValue,
    required this.isDark,
    required this.hasMapAsset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawVenueBoundary(canvas, size);
    _drawZones(canvas, size);
    _drawRoute(canvas, size);
    _drawPois(canvas, size);
    _drawPresenceIndicator(canvas, size);
  }

  void _drawVenueBoundary(Canvas canvas, Size size) {
    final floorRect = Rect.fromLTWH(8, 8, size.width - 16, size.height - 16);
    final floorRRect = RRect.fromRectAndRadius(floorRect, const Radius.circular(16));

    if (!hasMapAsset) {
      // Draw background plate only when no asset is loaded
      final floorBg = Paint()
        ..color = isDark ? const Color(0xFF13131A) : const Color(0xFFEFF2F9)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(floorRRect, floorBg);
    }

    final floorBorder = Paint()
      ..color = isDark ? SpatiallyColors.darkBorderSubdued : SpatiallyColors.lightBorderSubdued
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(floorRRect, floorBorder);
  }

  void _drawZones(Canvas canvas, Size size) {
    for (final zone in venueData.zones) {
      final isSelected = selectedZone?.id == zone.id;
      final zoneRect = zone.bounds.toRect(size);
      if (zoneRect.width <= 0 || zoneRect.height <= 0) continue;

      final hasPolygon = zone.polygon != null && zone.polygon!.length >= 3;
      Path? zonePath;
      if (hasPolygon) {
        zonePath = Path();
        final firstPt = zone.polygon!.first.toOffset(size);
        zonePath.moveTo(firstPt.dx, firstPt.dy);
        for (int i = 1; i < zone.polygon!.length; i++) {
          final pt = zone.polygon![i].toOffset(size);
          zonePath.lineTo(pt.dx, pt.dy);
        }
        zonePath.close();
      }

      final zoneRRect = RRect.fromRectAndRadius(zoneRect, const Radius.circular(10));

      // Resolve zone fill color based on operational status and crowd
      Color baseColor;
      if (zone.isClosed) {
        baseColor = isDark ? const Color(0xFF1A1A22) : const Color(0xFFE2E8F0);
      } else if (zone.isRestricted) {
        baseColor = isDark ? const Color(0xFF2A2418) : const Color(0xFFFEF3C7);
      } else {
        baseColor = isDark ? SpatiallyColors.darkSurfaceElevated : Colors.white;
      }

      // Blend crowd color if crowd layer active and crowd is available
      final isCrowdAvailable = zone.crowdFreshness != SpatialCrowdFreshness.unavailable;
      if (showCrowdLayer && isCrowdAvailable && !zone.isClosed) {
        final crowdColor = _resolveCrowdColor(zone.crowdLevel);
        baseColor = Color.alphaBlend(
          crowdColor.withValues(alpha: isDark ? 0.24 : 0.16),
          baseColor,
        );
      }

      final zoneFill = Paint()
        ..color = hasMapAsset ? baseColor.withValues(alpha: 0.85) : baseColor
        ..style = PaintingStyle.fill;

      if (hasPolygon && zonePath != null) {
        canvas.drawPath(zonePath, zoneFill);
      } else {
        canvas.drawRRect(zoneRRect, zoneFill);
      }

      // Zone border
      Color strokeColor;
      if (isSelected) {
        strokeColor = SpatiallyColors.spatialCyan;
      } else if (zone.isClosed) {
        strokeColor = isDark ? const Color(0xFF333344) : const Color(0xFFCBD5E1);
      } else if (zone.isRestricted) {
        strokeColor = SpatiallyColors.warning;
      } else {
        strokeColor = isDark ? SpatiallyColors.darkBorderSubdued : SpatiallyColors.lightBorderSubdued;
      }

      final zoneStroke = Paint()
        ..color = strokeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? 2.5 : 1.2;

      if (hasPolygon && zonePath != null) {
        canvas.drawPath(zonePath, zoneStroke);
      } else {
        canvas.drawRRect(zoneRRect, zoneStroke);
      }

      // Selection glow
      if (isSelected) {
        final glowPaint = Paint()
          ..color = SpatiallyColors.spatialCyan.withValues(alpha: 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6.0;
        if (hasPolygon && zonePath != null) {
          canvas.drawPath(zonePath, glowPaint);
        } else {
          canvas.drawRRect(zoneRRect, glowPaint);
        }
      }

      // Zone Labels
      _drawZoneText(canvas, zone, zoneRect);

      // Crowd telemetry badge dot (only if crowd is available)
      if (isCrowdAvailable && !zone.isClosed) {
        final crowdDotColor = _resolveCrowdColor(zone.crowdLevel);
        final dotOffset = Offset(zoneRect.right - 14, zoneRect.top + 14);
        final dotPaint = Paint()..color = crowdDotColor;
        canvas.drawCircle(dotOffset, 4.5, dotPaint);

        if (showCrowdLayer) {
          final dotRing = Paint()
            ..color = crowdDotColor.withValues(alpha: 0.3)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3;
          canvas.drawCircle(dotOffset, 8.0, dotRing);
        }
      }
    }
  }

  void _drawZoneText(Canvas canvas, MapZone zone, Rect rect) {
    if (rect.width < 45 || rect.height < 30) return;

    final primaryTextColor = isDark ? SpatiallyColors.darkTextPrimary : SpatiallyColors.lightTextPrimary;
    final secondaryTextColor = isDark ? SpatiallyColors.darkTextSecondary : SpatiallyColors.lightTextSecondary;

    // Room Code / Number
    final roomSpan = TextSpan(
      text: zone.roomNumber,
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: rect.width < 100 ? 11 : 13,
        fontWeight: FontWeight.w700,
        color: zone.isClosed ? secondaryTextColor : primaryTextColor,
        letterSpacing: -0.2,
      ),
    );
    final roomPainter = TextPainter(
      text: roomSpan,
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: rect.width - 24);

    roomPainter.paint(canvas, Offset(rect.left + 12, rect.top + 12));

    // Room Name
    if (zone.name.isNotEmpty && rect.height > 55) {
      final nameSpan = TextSpan(
        text: zone.isClosed ? '${zone.name} (Closed)' : zone.name,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: rect.width < 100 ? 10 : 11,
          fontWeight: FontWeight.w500,
          color: zone.isClosed ? SpatiallyColors.error : secondaryTextColor,
        ),
      );
      final namePainter = TextPainter(
        text: nameSpan,
        textDirection: TextDirection.ltr,
        maxLines: 2,
        ellipsis: '...',
      )..layout(maxWidth: rect.width - 24);

      namePainter.paint(canvas, Offset(rect.left + 12, rect.top + 12 + roomPainter.height + 2));
    }
  }

  void _drawPois(Canvas canvas, Size size) {
    for (final poi in filteredPois) {
      final isSelected = selectedPoi?.id == poi.id;
      final center = poi.point.toOffset(size);
      final color = _resolvePoiColor(poi.category);

      // Outer ripple if selected
      if (isSelected) {
        final ringPaint = Paint()
          ..color = color.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5;
        canvas.drawCircle(center, 18, ringPaint);
      }

      // POI Base Circle
      final basePaint = Paint()
        ..color = isDark ? SpatiallyColors.darkSurface : Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, 12, basePaint);

      final borderPaint = Paint()
        ..color = isSelected ? color : color.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? 2.5 : 1.5;
      canvas.drawCircle(center, 12, borderPaint);

      // Icon
      final iconSpan = TextSpan(
        text: String.fromCharCode(poi.icon.codePoint),
        style: TextStyle(
          fontSize: 14,
          fontFamily: poi.icon.fontFamily,
          package: poi.icon.fontPackage,
          color: color,
        ),
      );
      final iconPainter = TextPainter(
        text: iconSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      iconPainter.paint(
        canvas,
        Offset(center.dx - iconPainter.width / 2, center.dy - iconPainter.height / 2),
      );
    }
  }

  void _drawPresenceIndicator(Canvas canvas, Size size) {
    if (presenceZoneId == null) return;

    final presenceZone = venueData.findZoneById(presenceZoneId!);
    if (presenceZone == null) return;

    final center = presenceZone.bounds.center.toOffset(size);

    final waveRadius = 14 + (pulseValue * 18);
    final waveOpacity = (1.0 - pulseValue).clamp(0.0, 1.0) * 0.45;

    final wavePaint = Paint()
      ..color = SpatiallyColors.spatialCyan.withValues(alpha: waveOpacity)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, waveRadius, wavePaint);

    final dotPaint = Paint()..color = SpatiallyColors.spatialCyan;
    canvas.drawCircle(center, 7, dotPaint);

    final whiteCenter = Paint()..color = Colors.white;
    canvas.drawCircle(center, 3, whiteCenter);
  }

  void _drawRoute(Canvas canvas, Size size) {
    if (activeRoute == null || activeRoute!.waypoints.length < 2) return;

    final waypoints = activeRoute!.waypoints.map((p) => p.toOffset(size)).toList();

    final path = Path()..moveTo(waypoints.first.dx, waypoints.first.dy);
    for (int i = 1; i < waypoints.length; i++) {
      path.lineTo(waypoints[i].dx, waypoints[i].dy);
    }

    // Glowing underlay
    final glowPaint = Paint()
      ..color = (activeRoute!.isAccessible ? SpatiallyColors.spatialCyan : SpatiallyColors.violet)
          .withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 9.0;
    canvas.drawPath(path, glowPaint);

    // Main route line
    final routePaint = Paint()
      ..color = activeRoute!.isAccessible ? SpatiallyColors.spatialCyan : SpatiallyColors.violet
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 4.0;
    canvas.drawPath(path, routePaint);

    // Origin marker
    final originPaint = Paint()..color = SpatiallyColors.spatialCyan;
    canvas.drawCircle(waypoints.first, 8, originPaint);
    canvas.drawCircle(waypoints.first, 4, Paint()..color = Colors.white);

    // Destination marker
    final destPaint = Paint()..color = SpatiallyColors.violet;
    canvas.drawCircle(waypoints.last, 8, destPaint);
    canvas.drawCircle(waypoints.last, 4, Paint()..color = Colors.white);
  }

  Color _resolveCrowdColor(SpatiallyCrowdLevel level) {
    switch (level) {
      case SpatiallyCrowdLevel.low:
        return SpatiallyColors.crowdLow;
      case SpatiallyCrowdLevel.moderate:
        return SpatiallyColors.crowdModerate;
      case SpatiallyCrowdLevel.busy:
        return SpatiallyColors.crowdBusy;
      case SpatiallyCrowdLevel.high:
        return SpatiallyColors.crowdHigh;
    }
  }

  Color _resolvePoiColor(PoiCategory category) {
    switch (category) {
      case PoiCategory.stages:
        return SpatiallyColors.violet;
      case PoiCategory.booths:
        return const Color(0xFF0284C7);
      case PoiCategory.facilities:
        return const Color(0xFF0D9488);
      case PoiCategory.safety:
        return const Color(0xFFDC2626);
    }
  }

  @override
  bool shouldRepaint(covariant _VenueMapPainter oldDelegate) {
    return oldDelegate.selectedZone != selectedZone ||
        oldDelegate.selectedPoi != selectedPoi ||
        oldDelegate.activeRoute != activeRoute ||
        oldDelegate.showCrowdLayer != showCrowdLayer ||
        oldDelegate.presenceZoneId != presenceZoneId ||
        oldDelegate.pulseValue != pulseValue ||
        oldDelegate.isDark != isDark ||
        oldDelegate.hasMapAsset != hasMapAsset ||
        oldDelegate.venueData.levelId != venueData.levelId ||
        oldDelegate.venueData.zones.length != venueData.zones.length ||
        oldDelegate.filteredPois.length != filteredPois.length;
  }
}
