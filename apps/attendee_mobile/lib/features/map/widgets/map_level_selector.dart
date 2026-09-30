import 'package:flutter/material.dart';
import '../../../design_system/spatially_colors.dart';
import '../../../design_system/spatially_typography.dart';
import '../../../design_system/spatially_radius.dart';
import '../../../design_system/spatially_shadows.dart';
import '../models/venue_map_models.dart';

/// Minimal, production-ready floating Level / Floor Selector for the Spatially Map surface.
///
/// Automatically presents available architectural levels for the current venue.
/// Highlights the active level and notifies listeners upon selection.
class MapLevelSelector extends StatelessWidget {
  final List<SpatialLevel> levels;
  final String? selectedLevelId;
  final ValueChanged<SpatialLevel> onLevelSelected;

  const MapLevelSelector({
    super.key,
    required this.levels,
    required this.selectedLevelId,
    required this.onLevelSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (levels.length <= 1) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? SpatiallyColors.darkSurface : SpatiallyColors.lightSurface;
    final border = isDark ? SpatiallyColors.darkBorderSubdued : SpatiallyColors.lightBorderSubdued;
    final textSecondary = isDark ? SpatiallyColors.darkTextSecondary : SpatiallyColors.lightTextSecondary;

    // Display levels top-to-bottom in descending order (highest floor on top)
    final sortedLevels = List<SpatialLevel>.from(levels)
      ..sort((a, b) => b.levelIndex.compareTo(a.levelIndex));

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor.withValues(alpha: 0.94),
        borderRadius: SpatiallyRadius.borderFull,
        border: Border.all(color: border),
        boxShadow: SpatiallyShadows.card,
      ),
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: sortedLevels.map((lvl) {
          final isSelected = lvl.id == selectedLevelId ||
              (selectedLevelId == null && lvl.levelIndex == 1);

          final label = lvl.shortCode.isNotEmpty ? lvl.shortCode : 'L${lvl.levelIndex}';

          return Tooltip(
            message: lvl.name,
            child: InkWell(
              onTap: () => onLevelSelected(lvl),
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                width: 34,
                height: 34,
                margin: const EdgeInsets.symmetric(vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? SpatiallyColors.spatialCyan
                      : Colors.transparent,
                  shape: BoxShape.circle,
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: SpatiallyColors.spatialCyan.withValues(alpha: 0.35),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  label,
                  style: SpatiallyTypography.caption(
                    color: isSelected
                        ? const Color(0xFF0F172A)
                        : textSecondary,
                  ).copyWith(
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
