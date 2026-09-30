import 'package:flutter/material.dart';
import '../spatially_colors.dart';
import '../spatially_typography.dart';
import '../spatially_spacing.dart';
import '../spatially_radius.dart';

enum SpatiallySyncState {
  live,
  syncing,
  cached,
  offline,
}

/// Centralized Offline & Sync Status Banner / Pill based on SPATIALLY_DESIGN.md.
/// 
/// Clearly distinguishes between live, syncing, cached, and offline states.
class SpatiallySyncStatus extends StatelessWidget {
  final SpatiallySyncState state;
  final String? customMessage;
  final bool isBanner;

  const SpatiallySyncStatus({
    super.key,
    required this.state,
    this.customMessage,
    this.isBanner = false,
  });

  Color _resolveColor() {
    switch (state) {
      case SpatiallySyncState.live:
        return SpatiallyColors.success;
      case SpatiallySyncState.syncing:
        return SpatiallyColors.spatialCyan;
      case SpatiallySyncState.cached:
        return SpatiallyColors.warning;
      case SpatiallySyncState.offline:
        return SpatiallyColors.error;
    }
  }

  IconData _resolveIcon() {
    switch (state) {
      case SpatiallySyncState.live:
        return Icons.wifi_rounded;
      case SpatiallySyncState.syncing:
        return Icons.sync_rounded;
      case SpatiallySyncState.cached:
        return Icons.cloud_done_outlined;
      case SpatiallySyncState.offline:
        return Icons.cloud_off_rounded;
    }
  }

  String _resolveMessage() {
    if (customMessage != null) return customMessage!;
    switch (state) {
      case SpatiallySyncState.live:
        return 'Connected • Live';
      case SpatiallySyncState.syncing:
        return 'Syncing latest updates...';
      case SpatiallySyncState.cached:
        return 'Offline • Showing cached data';
      case SpatiallySyncState.offline:
        return 'No internet connection';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _resolveColor();
    final message = _resolveMessage();
    final icon = _resolveIcon();

    if (isBanner) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: color.withValues(alpha: 0.14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            SpatiallySpacing.gapHorizontalXs,
            Text(
              message,
              style: SpatiallyTypography.caption(color: color),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: SpatiallyRadius.borderFull,
        border: Border.all(color: color.withValues(alpha: 0.28), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          SpatiallySpacing.gapHorizontalXs,
          Text(
            message,
            style: SpatiallyTypography.caption(color: color),
          ),
        ],
      ),
    );
  }
}
