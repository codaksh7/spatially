import 'package:flutter/material.dart';
import '../../../design_system/spatially_spacing.dart';
import '../../../design_system/components/spatially_chip.dart';

/// Filter selection for Map layers.
enum MapFilterType {
  all,
  crowd,
  booths,
  stages,
  facilities,
  safety,
}

/// Category chip filter row for the Map surface.
class MapCategoryFilters extends StatelessWidget {
  final MapFilterType activeFilter;
  final ValueChanged<MapFilterType> onFilterChanged;

  const MapCategoryFilters({
    super.key,
    required this.activeFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: SpatiallySpacing.md),
      child: Row(
        children: [
          SpatiallyCategoryChip(
            label: 'All',
            isSelected: activeFilter == MapFilterType.all,
            onTap: () => onFilterChanged(MapFilterType.all),
          ),
          SpatiallySpacing.gapHorizontalXs,
          SpatiallyCategoryChip(
            label: 'Crowd Heatmap',
            icon: const Icon(Icons.people_outline_rounded, size: 14),
            isSelected: activeFilter == MapFilterType.crowd,
            onTap: () => onFilterChanged(MapFilterType.crowd),
          ),
          SpatiallySpacing.gapHorizontalXs,
          SpatiallyCategoryChip(
            label: 'Booths',
            icon: const Icon(Icons.storefront_rounded, size: 14),
            isSelected: activeFilter == MapFilterType.booths,
            onTap: () => onFilterChanged(MapFilterType.booths),
          ),
          SpatiallySpacing.gapHorizontalXs,
          SpatiallyCategoryChip(
            label: 'Stages',
            icon: const Icon(Icons.mic_external_on_rounded, size: 14),
            isSelected: activeFilter == MapFilterType.stages,
            onTap: () => onFilterChanged(MapFilterType.stages),
          ),
          SpatiallySpacing.gapHorizontalXs,
          SpatiallyCategoryChip(
            label: 'Facilities',
            icon: const Icon(Icons.wc_rounded, size: 14),
            isSelected: activeFilter == MapFilterType.facilities,
            onTap: () => onFilterChanged(MapFilterType.facilities),
          ),
          SpatiallySpacing.gapHorizontalXs,
          SpatiallyCategoryChip(
            label: 'Safety & Exits',
            icon: const Icon(Icons.emergency_rounded, size: 14),
            isSelected: activeFilter == MapFilterType.safety,
            onTap: () => onFilterChanged(MapFilterType.safety),
          ),
        ],
      ),
    );
  }
}
