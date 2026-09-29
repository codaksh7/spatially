import 'package:flutter/material.dart';

import '../../../design_system/design_system.dart';
import '../models/profile_preferences.dart';

/// Accessibility preferences section within Profile & Settings.
/// 
/// Stores routing and UI accessibility options for Spatially's map and navigation.
class ProfileAccessibilitySection extends StatelessWidget {
  final ProfilePreferences preferences;
  final ValueChanged<ProfilePreferences> onPreferencesChanged;

  const ProfileAccessibilitySection({
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
          title: 'Accessibility & Mobility',
          subtitle: 'Personalize navigation and visual presentation for your comfort',
        ),
        SpatiallySpacing.gapVerticalSm,
        SpatiallyCard(
          padding: const EdgeInsets.all(SpatiallySpacing.md),
          child: Column(
            children: [
              // Step-free routes
              _buildPreferenceSwitchRow(
                icon: Icons.accessible_forward_rounded,
                title: 'Prefer Step-Free Routes',
                subtitle: 'Prioritize elevators, ramps, and flat walkways across venue floors.',
                value: preferences.preferStepFreeRoutes,
                onChanged: (val) {
                  onPreferencesChanged(preferences.copyWith(preferStepFreeRoutes: val));
                },
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),

              const Divider(),

              // Minimize walking
              _buildPreferenceSwitchRow(
                icon: Icons.airline_seat_recline_normal_rounded,
                title: 'Minimize Walking Distance',
                subtitle: 'Favor direct pathways and zones with accessible seating/rest stops.',
                value: preferences.minimizeWalking,
                onChanged: (val) {
                  onPreferencesChanged(preferences.copyWith(minimizeWalking: val));
                },
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),

              const Divider(),

              // Reduce motion
              _buildPreferenceSwitchRow(
                icon: Icons.motion_photos_off_rounded,
                title: 'Reduce UI Animations',
                subtitle: 'Subdue animated transitions, map pulses, and background motion.',
                value: preferences.reduceMotion,
                onChanged: (val) {
                  onPreferencesChanged(preferences.copyWith(reduceMotion: val));
                },
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),

              SpatiallySpacing.gapVerticalSm,
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
                    const Icon(Icons.check_circle_outline_rounded, size: 16, color: SpatiallyColors.success),
                    SpatiallySpacing.gapHorizontalSm,
                    Expanded(
                      child: Text(
                        'System font scaling and screen readers (TalkBack / VoiceOver) are supported natively.',
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

  Widget _buildPreferenceSwitchRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SpatiallySpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: value ? SpatiallyColors.violet : textSecondary,
            size: 22,
          ),
          SpatiallySpacing.gapHorizontalMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: SpatiallyTypography.body(color: textPrimary).copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  subtitle,
                  style: SpatiallyTypography.caption(color: textSecondary),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            activeThumbColor: SpatiallyColors.violet,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
