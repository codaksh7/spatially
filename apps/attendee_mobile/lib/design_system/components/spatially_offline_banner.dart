import 'package:flutter/material.dart';
import '../spatially_colors.dart';
import '../spatially_typography.dart';
import '../spatially_radius.dart';
import '../spatially_spacing.dart';

/// Calm, non-intrusive offline status banner based on SPATIALLY_DESIGN.md.
///
/// Clearly communicates that the user is viewing cached/offline data without
/// overwhelming the interface or blocking navigation.
class SpatiallyOfflineBanner extends StatelessWidget {
  final String message;
  final String? syncTime;
  final VoidCallback? onRetry;

  const SpatiallyOfflineBanner({
    super.key,
    this.message = 'Offline Mode • Showing cached data',
    this.syncTime,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: SpatiallySpacing.md),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? SpatiallyColors.darkSurface : SpatiallyColors.lightSurface,
        borderRadius: BorderRadius.circular(SpatiallyRadius.md),
        border: Border.all(
          color: SpatiallyColors.warning.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: SpatiallyColors.warning.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(SpatiallyRadius.xs),
            ),
            child: const Center(
              child: Icon(
                Icons.wifi_off_rounded,
                size: 15,
                color: SpatiallyColors.warning,
              ),
            ),
          ),
          SpatiallySpacing.gapHorizontalMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message,
                  style: SpatiallyTypography.caption(
                    color: isDark ? SpatiallyColors.darkTextPrimary : SpatiallyColors.lightTextPrimary,
                  ).copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (syncTime != null)
                  Text(
                    syncTime!,
                    style: SpatiallyTypography.caption(
                      color: isDark ? SpatiallyColors.darkTextSecondary : SpatiallyColors.lightTextSecondary,
                    ).copyWith(fontSize: 10),
                  ),
              ],
            ),
          ),
          if (onRetry != null) ...[
            SpatiallySpacing.gapHorizontalSm,
            InkWell(
              onTap: onRetry,
              borderRadius: BorderRadius.circular(SpatiallyRadius.xs),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  'Retry',
                  style: SpatiallyTypography.caption(color: SpatiallyColors.violet).copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
