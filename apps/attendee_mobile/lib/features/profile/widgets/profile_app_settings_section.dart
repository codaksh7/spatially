import 'package:flutter/material.dart';

import '../../../design_system/design_system.dart';
import '../../safety/safety_screen.dart';
import '../models/profile_preferences.dart';

/// App preferences, theme mode switcher, Help & Support, and About dialogs.
class ProfileAppSettingsSection extends StatelessWidget {
  final ProfilePreferences preferences;
  final ValueChanged<ProfilePreferences> onPreferencesChanged;

  const ProfileAppSettingsSection({
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
          title: 'App Settings & Support',
          subtitle: 'Interface theme, platform information, and assistance',
        ),
        SpatiallySpacing.gapVerticalSm,
        SpatiallyCard(
          padding: const EdgeInsets.all(SpatiallySpacing.md),
          child: Column(
            children: [
              // Theme Mode Selector Row
              _buildThemeSelectorRow(
                context: context,
                isDark: isDark,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),

              const Divider(),

              // Venue Safety & Emergency Help trigger
              InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const SafetyScreen(),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(SpatiallyRadius.sm),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: SpatiallySpacing.xs),
                  child: Row(
                    children: [
                      const Icon(Icons.shield_outlined, color: SpatiallyColors.error, size: 22),
                      SpatiallySpacing.gapHorizontalMd,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Venue Safety & Help Center',
                              style: SpatiallyTypography.body(color: textPrimary).copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              'First aid, emergency exits, security & lost property',
                              style: SpatiallyTypography.caption(color: textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: textSecondary, size: 20),
                    ],
                  ),
                ),
              ),

              const Divider(),

              // Help & Support Modal trigger
              InkWell(
                onTap: () => _showHelpSupportSheet(context),
                borderRadius: BorderRadius.circular(SpatiallyRadius.sm),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: SpatiallySpacing.xs),
                  child: Row(
                    children: [
                      Icon(Icons.help_outline_rounded, color: textSecondary, size: 22),
                      SpatiallySpacing.gapHorizontalMd,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Help & Support',
                              style: SpatiallyTypography.body(color: textPrimary).copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              'FAQs, spatial guide, and event staff assistance',
                              style: SpatiallyTypography.caption(color: textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: textSecondary, size: 20),
                    ],
                  ),
                ),
              ),

              const Divider(),

              // About Spatially Modal trigger
              InkWell(
                onTap: () => _showAboutSheet(context),
                borderRadius: BorderRadius.circular(SpatiallyRadius.sm),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: SpatiallySpacing.xs),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: textSecondary, size: 22),
                      SpatiallySpacing.gapHorizontalMd,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'About Spatially',
                              style: SpatiallyTypography.body(color: textPrimary).copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              'Version 1.0.0',
                              style: SpatiallyTypography.caption(color: textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: textSecondary, size: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildThemeSelectorRow({
    required BuildContext context,
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    String currentThemeLabel;
    switch (preferences.themeMode) {
      case ThemeMode.system:
        currentThemeLabel = 'System Auto';
        break;
      case ThemeMode.light:
        currentThemeLabel = 'Light Mode';
        break;
      case ThemeMode.dark:
        currentThemeLabel = 'Dark Mode';
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SpatiallySpacing.xs),
      child: Row(
        children: [
          Icon(Icons.palette_outlined, color: textSecondary, size: 22),
          SpatiallySpacing.gapHorizontalMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Theme Appearance',
                  style: SpatiallyTypography.body(color: textPrimary).copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  currentThemeLabel,
                  style: SpatiallyTypography.caption(color: textSecondary),
                ),
              ],
            ),
          ),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment<ThemeMode>(
                value: ThemeMode.system,
                icon: Icon(Icons.brightness_auto_rounded, size: 16),
                tooltip: 'System Theme',
              ),
              ButtonSegment<ThemeMode>(
                value: ThemeMode.light,
                icon: Icon(Icons.light_mode_rounded, size: 16),
                tooltip: 'Light Theme',
              ),
              ButtonSegment<ThemeMode>(
                value: ThemeMode.dark,
                icon: Icon(Icons.dark_mode_rounded, size: 16),
                tooltip: 'Dark Theme',
              ),
            ],
            selected: {preferences.themeMode},
            onSelectionChanged: (newSelection) {
              if (newSelection.isNotEmpty) {
                onPreferencesChanged(preferences.copyWith(themeMode: newSelection.first));
              }
            },
            showSelectedIcon: false,
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  void _showHelpSupportSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final isDark = theme.brightness == Brightness.dark;
        final bg = isDark ? SpatiallyColors.darkSurfaceElevated : SpatiallyColors.lightSurface;
        final textPrimary = isDark ? SpatiallyColors.darkTextPrimary : SpatiallyColors.lightTextPrimary;
        final textSecondary = isDark ? SpatiallyColors.darkTextSecondary : SpatiallyColors.lightTextSecondary;

        return Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(SpatiallyRadius.lg)),
          ),
          padding: const EdgeInsets.all(SpatiallySpacing.lg),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.75,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Help & Support',
                    style: SpatiallyTypography.sectionHeading(color: textPrimary),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: textSecondary),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              SpatiallySpacing.gapVerticalMd,
              Expanded(
                child: ListView(
                  children: [
                    _buildFaqItem(
                      question: 'How do I claim session & booth badges?',
                      answer: 'When you are physically near a session hall or sponsor booth at the event, tap "I\'m Here" on the Passport or booth details card to register presence and earn your verified stamp.',
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                    ),
                    const Divider(),
                    _buildFaqItem(
                      question: 'How does the Bluetooth beacon work?',
                      answer: 'Spatially uses low-energy Bluetooth (BLE) to detect proximity to venue checkpoints. It emits an anonymous, rotating beacon ID that changes periodically to keep your movements private.',
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                    ),
                    const Divider(),
                    _buildFaqItem(
                      question: 'Where can I find my digital ticket & QR code?',
                      answer: 'Go to your Tickets & Passes section from Profile or Home, select your registered event, and present the high-contrast QR code at venue check-in counters.',
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                    ),
                    const Divider(),
                    _buildFaqItem(
                      question: 'Need on-site organizer assistance?',
                      answer: 'Visit the Info & Help Desk located at the main venue lobby. On-site staff can assist with physical badge printing, accessibility escorts, and technical queries.',
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFaqItem({
    required String question,
    required String answer,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SpatiallySpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: SpatiallyTypography.body(color: textPrimary).copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          SpatiallySpacing.gapVerticalXxs,
          Text(
            answer,
            style: SpatiallyTypography.caption(color: textSecondary).copyWith(
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  void _showAboutSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final isDark = theme.brightness == Brightness.dark;
        final bg = isDark ? SpatiallyColors.darkSurfaceElevated : SpatiallyColors.lightSurface;
        final textPrimary = isDark ? SpatiallyColors.darkTextPrimary : SpatiallyColors.lightTextPrimary;
        final textSecondary = isDark ? SpatiallyColors.darkTextSecondary : SpatiallyColors.lightTextSecondary;

        return Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(SpatiallyRadius.lg)),
          ),
          padding: const EdgeInsets.all(SpatiallySpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: SpatiallyColors.brandGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: SpatiallyColors.violet.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(Icons.hub_rounded, size: 32, color: Colors.white),
                ),
              ),
              SpatiallySpacing.gapVerticalMd,
              Text(
                'Spatially Attendee',
                style: SpatiallyTypography.sectionHeading(color: textPrimary).copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              SpatiallySpacing.gapVerticalXxs,
              Text(
                'Version 1.0.0',
                style: SpatiallyTypography.caption(color: textSecondary),
              ),
              SpatiallySpacing.gapVerticalMd,
              Text(
                'Spatial Event Operating System & Attendee Experience Platform. Designed for modern multi-zone expos, conferences, and technical summits.',
                textAlign: TextAlign.center,
                style: SpatiallyTypography.body(color: textSecondary).copyWith(height: 1.4),
              ),
              SpatiallySpacing.gapVerticalLg,
              SpatiallySoftButton(
                label: 'Close',
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        );
      },
    );
  }
}
