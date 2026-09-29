import 'package:flutter/material.dart';
import '../spatially_colors.dart';
import '../spatially_typography.dart';
import '../spatially_spacing.dart';
import '../spatially_radius.dart';

enum SpatiallyCrowdLevel {
  low,
  moderate,
  busy,
  high,
}

/// Centralized Crowd Indicator based on SPATIALLY_DESIGN.md.
/// 
/// Communicates crowd density using intuitive color language AND text labels
/// to guarantee accessibility.
class SpatiallyCrowdIndicator extends StatelessWidget {
  final SpatiallyCrowdLevel level;
  final bool compact;

  const SpatiallyCrowdIndicator({
    super.key,
    required this.level,
    this.compact = false,
  });

  Color _resolveColor() {
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

  String _resolveLabel() {
    switch (level) {
      case SpatiallyCrowdLevel.low:
        return 'Low Crowd';
      case SpatiallyCrowdLevel.moderate:
        return 'Moderate Crowd';
      case SpatiallyCrowdLevel.busy:
        return 'Busy';
      case SpatiallyCrowdLevel.high:
        return 'High Crowd';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _resolveColor();
    final label = _resolveLabel();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 3 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: SpatiallyRadius.borderFull,
        border: Border.all(color: color.withValues(alpha: 0.28), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: compact ? 6 : 8,
            height: compact ? 6 : 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          SpatiallySpacing.gapHorizontalXs,
          Text(
            label,
            style: SpatiallyTypography.badge(color: color).copyWith(
              fontSize: compact ? 11 : 12,
            ),
          ),
        ],
      ),
    );
  }
}
