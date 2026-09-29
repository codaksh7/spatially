import 'package:flutter/material.dart';

import '../../../design_system/design_system.dart';
import '../models/profile_preferences.dart';

/// Privacy & Spatial Beacon section within Profile & Settings.
/// 
/// Communicates Spatially's zero-knowledge, ephemeral spatial architecture honestly
/// without making false privacy claims or unbacked backend guarantees.
class ProfilePrivacySection extends StatelessWidget {
  final ProfilePreferences preferences;
  final ValueChanged<ProfilePreferences> onPreferencesChanged;

  const ProfilePrivacySection({
    super.key,
    required this.preferences,
    required this.onPreferencesChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = isDark ? SpatiallyColors.darkTextPrimary : SpatiallyColors.lightTextPrimary;
    final textSecondary = isDark ? SpatiallyColors.darkTextSecondary : SpatiallyColors.lightTextSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SpatiallySectionHeader(
          title: 'Privacy & Spatial Beacon',
          subtitle: 'Architectural guarantees protecting your real-world identity',
        ),
        SpatiallySpacing.gapVerticalSm,
        SpatiallyCard(
          padding: const EdgeInsets.all(SpatiallySpacing.md),
          child: Column(
            children: [
              // Rotating Ephemeral ID
              Padding(
                padding: const EdgeInsets.symmetric(vertical: SpatiallySpacing.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.shield_outlined,
                      color: SpatiallyColors.spatialCyan,
                      size: 22,
                    ),
                    SpatiallySpacing.gapHorizontalMd,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Rotating Ephemeral ID',
                                style: SpatiallyTypography.body(color: textPrimary).copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SpatiallySpacing.gapHorizontalXs,
                              const SpatiallyStatusBadge(
                                label: 'ACTIVE',
                                variant: SpatiallyBadgeVariant.live,
                              ),
                            ],
                          ),
                          SpatiallySpacing.gapVerticalXxs,
                          Text(
                            'Your Bluetooth beacon ID rotates every 5 minutes on-device. This mathematically prevents third-party tracking across event zones.',
                            style: SpatiallyTypography.caption(color: textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(),

              // BLE Broadcasting Boundary
              Padding(
                padding: const EdgeInsets.symmetric(vertical: SpatiallySpacing.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.bluetooth_searching_rounded,
                      color: SpatiallyColors.violet,
                      size: 22,
                    ),
                    SpatiallySpacing.gapHorizontalMd,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Local Proximity Only',
                            style: SpatiallyTypography.body(color: textPrimary).copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SpatiallySpacing.gapVerticalXxs,
                          Text(
                            'Beacon frames never leave physical radio range (~15 meters). No GPS, cellular, or continuous cloud coordinates are logged.',
                            style: SpatiallyTypography.caption(color: textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.check_circle_rounded,
                      color: SpatiallyColors.success,
                      size: 20,
                    ),
                  ],
                ),
              ),

              const Divider(),

              // Anonymous Venue Telemetry Toggle
              Padding(
                padding: const EdgeInsets.symmetric(vertical: SpatiallySpacing.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.analytics_outlined,
                      color: preferences.shareAnalytics ? SpatiallyColors.violet : textSecondary,
                      size: 22,
                    ),
                    SpatiallySpacing.gapHorizontalMd,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Anonymous Crowd Telemetry',
                            style: SpatiallyTypography.body(color: textPrimary).copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            'Share de-identified density data to help organizers relieve bottlenecks.',
                            style: SpatiallyTypography.caption(color: textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: preferences.shareAnalytics,
                      activeThumbColor: SpatiallyColors.violet,
                      onChanged: (val) {
                        onPreferencesChanged(preferences.copyWith(shareAnalytics: val));
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
