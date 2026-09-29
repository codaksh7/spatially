import 'package:flutter/material.dart';

import '../../../design_system/design_system.dart';
import '../models/profile_preferences.dart';

/// Notification Preferences section within Profile & Settings.
/// 
/// Manages notification categories honestly. Authoritative emergency/safety alerts
/// are strictly kept enabled per event safety protocol.
class ProfileNotificationsSection extends StatelessWidget {
  final ProfilePreferences preferences;
  final ValueChanged<ProfilePreferences> onPreferencesChanged;

  const ProfileNotificationsSection({
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
          title: 'Notifications',
          subtitle: 'Choose which alerts and reminders you wish to receive',
        ),
        SpatiallySpacing.gapVerticalSm,
        SpatiallyCard(
          padding: const EdgeInsets.all(SpatiallySpacing.md),
          child: Column(
            children: [
              // Event Updates
              _buildSwitchRow(
                icon: Icons.campaign_rounded,
                title: 'Event Announcements',
                subtitle: 'Keynote start times, schedule revisions, and organizer updates.',
                value: preferences.eventUpdates,
                onChanged: (val) {
                  onPreferencesChanged(preferences.copyWith(eventUpdates: val));
                },
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),

              const Divider(),

              // Session Reminders
              _buildSwitchRow(
                icon: Icons.alarm_rounded,
                title: 'Session & Bookmark Reminders',
                subtitle: '10-minute reminders before saved sessions begin.',
                value: preferences.sessionReminders,
                onChanged: (val) {
                  onPreferencesChanged(preferences.copyWith(sessionReminders: val));
                },
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),

              const Divider(),

              // Crowd Density Alerts
              _buildSwitchRow(
                icon: Icons.people_outline_rounded,
                title: 'Crowd Density Alerts',
                subtitle: 'Gentle heads-ups when stages or dining halls reach capacity.',
                value: preferences.crowdAlerts,
                onChanged: (val) {
                  onPreferencesChanged(preferences.copyWith(crowdAlerts: val));
                },
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),

              const Divider(),

              // Activity & Passport Milestones
              _buildSwitchRow(
                icon: Icons.military_tech_rounded,
                title: 'Activities & Passport Milestones',
                subtitle: 'Badges unlocked, booth check-in confirmation, and challenges.',
                value: preferences.activityRewards,
                onChanged: (val) {
                  onPreferencesChanged(preferences.copyWith(activityRewards: val));
                },
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),

              const Divider(),

              // Networking & Connect Alerts
              _buildSwitchRow(
                icon: Icons.hub_outlined,
                title: 'Networking & Connect Alerts',
                subtitle: 'Connection requests, accepted invites, and meeting point updates.',
                value: preferences.connectAlerts,
                onChanged: (val) {
                  onPreferencesChanged(preferences.copyWith(connectAlerts: val));
                },
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),

              const Divider(),

              // Contextual Recommendations
              _buildSwitchRow(
                icon: Icons.lightbulb_outline_rounded,
                title: 'Event Recommendations',
                subtitle: 'Relevant booths, workshops, and featured talks.',
                value: preferences.recommendations,
                onChanged: (val) {
                  onPreferencesChanged(preferences.copyWith(recommendations: val));
                },
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),

              const Divider(),

              // Mandatory Safety & Emergency (Non-mutable)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: SpatiallySpacing.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.shield_rounded,
                      color: SpatiallyColors.warning,
                      size: 22,
                    ),
                    SpatiallySpacing.gapHorizontalMd,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Emergency & Safety Alerts',
                                  style: SpatiallyTypography.body(color: textPrimary).copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              SpatiallySpacing.gapHorizontalXs,
                              const SpatiallyStatusBadge(
                                label: 'ALWAYS ON',
                                variant: SpatiallyBadgeVariant.custom,
                                customColor: SpatiallyColors.warning,
                              ),
                            ],
                          ),
                          Text(
                            'Critical evacuation and venue emergency broadcasts cannot be disabled.',
                            style: SpatiallyTypography.caption(color: textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.lock_outline_rounded,
                      color: Colors.grey,
                      size: 18,
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

  Widget _buildSwitchRow({
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
