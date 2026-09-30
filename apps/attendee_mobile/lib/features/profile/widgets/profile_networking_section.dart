import 'package:flutter/material.dart';

import '../../../design_system/design_system.dart';
import '../../explore/models/spatially_event.dart';
import '../models/profile_preferences.dart';

/// Networking preferences section within Profile & Settings.
/// 
/// Strictly manages attendee discovery preferences without initiating 
/// active live networking, chat, or matching algorithms.
class ProfileNetworkingSection extends StatelessWidget {
  final ProfilePreferences preferences;
  final ValueChanged<ProfilePreferences> onPreferencesChanged;
  final SpatiallyEvent? activeEvent;

  const ProfileNetworkingSection({
    super.key,
    required this.preferences,
    required this.onPreferencesChanged,
    this.activeEvent,
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
          title: 'Networking & Discovery',
          subtitle: 'Control how your profile appears during event networking',
        ),
        SpatiallySpacing.gapVerticalSm,
        SpatiallyCard(
          padding: const EdgeInsets.all(SpatiallySpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Visibility Mode Selector
              Text(
                'VISIBILITY MODE',
                style: SpatiallyTypography.caption(color: textSecondary).copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
              SpatiallySpacing.gapVerticalSm,
              ...NetworkingVisibility.values.map((mode) {
                final isSelected = preferences.networkingVisibility == mode;
                return InkWell(
                  onTap: () {
                    onPreferencesChanged(preferences.copyWith(networkingVisibility: mode));
                  },
                  borderRadius: BorderRadius.circular(SpatiallyRadius.sm),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: SpatiallySpacing.xs),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          margin: const EdgeInsets.only(top: 2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? SpatiallyColors.violet : textSecondary.withValues(alpha: 0.5),
                              width: 2,
                            ),
                          ),
                          child: isSelected
                              ? Center(
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: SpatiallyColors.violet,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                        SpatiallySpacing.gapHorizontalMd,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                mode.label,
                                style: SpatiallyTypography.body(color: textPrimary).copyWith(
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                ),
                              ),
                              SpatiallySpacing.gapVerticalXxs,
                              Text(
                                mode.description,
                                style: SpatiallyTypography.caption(color: textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),

              const Divider(),
              SpatiallySpacing.gapVerticalXs,

              // Proximity Discovery Toggle
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    Icons.radar_rounded,
                    color: preferences.allowProximityDiscovery ? SpatiallyColors.violet : textSecondary,
                    size: 22,
                  ),
                  SpatiallySpacing.gapHorizontalMd,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Proximity Networking Opt-In',
                          style: SpatiallyTypography.body(color: textPrimary).copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          'Allow Bluetooth-based discovery when in designated networking zones.',
                          style: SpatiallyTypography.caption(color: textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: preferences.allowProximityDiscovery,
                    activeThumbColor: SpatiallyColors.violet,
                    onChanged: (val) {
                      onPreferencesChanged(preferences.copyWith(allowProximityDiscovery: val));
                    },
                  ),
                ],
              ),
              SpatiallySpacing.gapVerticalMd,
              Container(
                padding: const EdgeInsets.all(SpatiallySpacing.sm),
                decoration: BoxDecoration(
                  color: isDark
                      ? SpatiallyColors.darkSurfaceElevated
                      : SpatiallyColors.lightBackground,
                  borderRadius: BorderRadius.circular(SpatiallyRadius.sm),
                  border: Border.all(
                    color: isDark ? SpatiallyColors.darkBorderSubdued : SpatiallyColors.lightBorderSubdued,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_user_outlined, size: 16, color: SpatiallyColors.spatialCyan),
                    SpatiallySpacing.gapHorizontalSm,
                    Expanded(
                      child: Text(
                        'Networking is temporary, event-scoped, and mutual opt-in. Anonymous BLE crowd telemetry is strictly separate from your social identity.',
                        style: SpatiallyTypography.caption(color: textSecondary).copyWith(fontSize: 11),
                      ),
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
