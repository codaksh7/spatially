import 'package:flutter/material.dart';
import '../../../design_system/spatially_colors.dart';
import '../../../design_system/spatially_typography.dart';
import '../../../design_system/spatially_spacing.dart';
import '../../../design_system/spatially_radius.dart';
import '../../../design_system/spatially_shadows.dart';
import '../models/venue_map_models.dart';

/// Search item wrapper for either a Zone or a POI.
class MapSearchResult {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final MapZone? zone;
  final MapPoi? poi;

  const MapSearchResult({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    this.zone,
    this.poi,
  });
}

/// Search bar with instant matching dropdown for zones and POIs.
class MapSearchBar extends StatefulWidget {
  final VenueMapData venueData;
  final ValueChanged<MapSearchResult> onResultSelected;
  final VoidCallback onClear;

  const MapSearchBar({
    super.key,
    required this.venueData,
    required this.onResultSelected,
    required this.onClear,
  });

  @override
  State<MapSearchBar> createState() => _MapSearchBarState();
}

class _MapSearchBarState extends State<MapSearchBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<MapSearchResult> _results = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_performSearch);
    _focusNode.addListener(() {
      setState(() {
        _isSearching = _focusNode.hasFocus && _controller.text.isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _performSearch() {
    final query = _controller.text.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() {
        _results = [];
        _isSearching = false;
      });
      return;
    }

    final matched = <MapSearchResult>[];

    // 1. Search Zones
    for (final zone in widget.venueData.zones) {
      if (zone.roomNumber.toLowerCase().contains(query) ||
          zone.name.toLowerCase().contains(query) ||
          zone.purpose.toLowerCase().contains(query) ||
          zone.id.contains(query)) {
        matched.add(
          MapSearchResult(
            title: '${zone.roomNumber} • ${zone.name}',
            subtitle: zone.purpose,
            icon: Icons.meeting_room_rounded,
            iconColor: SpatiallyColors.spatialCyan,
            zone: zone,
          ),
        );
      }
    }

    // 2. Search POIs
    for (final poi in widget.venueData.pois) {
      if (poi.name.toLowerCase().contains(query) ||
          poi.description.toLowerCase().contains(query)) {
        matched.add(
          MapSearchResult(
            title: poi.name,
            subtitle: poi.description,
            icon: poi.icon,
            iconColor: _poiColor(poi.category),
            poi: poi,
          ),
        );
      }
    }

    setState(() {
      _results = matched;
      _isSearching = true;
    });
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

  void _selectResult(MapSearchResult item) {
    _focusNode.unfocus();
    _controller.text = item.title;
    setState(() {
      _isSearching = false;
    });
    widget.onResultSelected(item);
  }

  void _clearSearch() {
    _controller.clear();
    _focusNode.unfocus();
    setState(() {
      _results = [];
      _isSearching = false;
    });
    widget.onClear();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? SpatiallyColors.darkSurface : SpatiallyColors.lightSurface;
    final textPrimary = isDark ? SpatiallyColors.darkTextPrimary : SpatiallyColors.lightTextPrimary;
    final textSecondary = isDark ? SpatiallyColors.darkTextSecondary : SpatiallyColors.lightTextSecondary;
    final border = isDark ? SpatiallyColors.darkBorderSubdued : SpatiallyColors.lightBorderSubdued;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Search Input Field
        Container(
          height: 44,
          decoration: BoxDecoration(
            color: surface,
            borderRadius: SpatiallyRadius.borderFull,
            border: Border.all(
              color: _focusNode.hasFocus ? SpatiallyColors.spatialCyan : border,
              width: _focusNode.hasFocus ? 1.5 : 1.0,
            ),
            boxShadow: SpatiallyShadows.cardShadow(isDark: isDark),
          ),
          child: Row(
            children: [
              const SizedBox(width: 14),
              Icon(
                Icons.search_rounded,
                size: 20,
                color: _focusNode.hasFocus ? SpatiallyColors.spatialCyan : textSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  style: SpatiallyTypography.body(color: textPrimary).copyWith(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search rooms, booths, stages, exits...',
                    hintStyle: SpatiallyTypography.secondary(color: textSecondary).copyWith(fontSize: 13),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              if (_controller.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  color: textSecondary,
                  onPressed: _clearSearch,
                ),
              const SizedBox(width: 4),
            ],
          ),
        ),

        // Dropdown Search Results Overlay
        if (_isSearching)
          Container(
            margin: const EdgeInsets.only(top: 8),
            constraints: const BoxConstraints(maxHeight: 240),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: SpatiallyRadius.borderMd,
              border: Border.all(color: border),
              boxShadow: SpatiallyShadows.cardShadow(isDark: isDark),
            ),
            child: _results.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(SpatiallySpacing.lg),
                    child: Text(
                      'No matching rooms, booths or facilities found.',
                      style: SpatiallyTypography.secondary(color: textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: SpatiallySpacing.xs),
                    itemCount: _results.length,
                    separatorBuilder: (_, index) => Divider(height: 1, color: border),
                    itemBuilder: (context, index) {
                      final item = _results[index];
                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: SpatiallySpacing.md,
                          vertical: 2,
                        ),
                        leading: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: item.iconColor.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(item.icon, size: 16, color: item.iconColor),
                        ),
                        title: Text(
                          item.title,
                          style: SpatiallyTypography.secondaryMedium(color: textPrimary),
                        ),
                        subtitle: Text(
                          item.subtitle,
                          style: SpatiallyTypography.caption(color: textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => _selectResult(item),
                      );
                    },
                  ),
          ),
      ],
    );
  }
}
