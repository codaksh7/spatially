import 'package:flutter/material.dart';

import '../../../design_system/design_system.dart';
import '../models/profile_preferences.dart';
import '../widgets/profile_accessibility_section.dart';

/// Focused screen for managing app theme, contrast, mobility, and accessibility preferences.
class AppPreferencesScreen extends StatefulWidget {
  final ProfilePreferences preferences;
  final ValueChanged<ProfilePreferences> onPreferencesChanged;

  const AppPreferencesScreen({
    super.key,
    required this.preferences,
    required this.onPreferencesChanged,
  });

  @override
  State<AppPreferencesScreen> createState() => _AppPreferencesScreenState();
}

class _AppPreferencesScreenState extends State<AppPreferencesScreen> {
  late ProfilePreferences _prefs;

  @override
  void initState() {
    super.initState();
    _prefs = widget.preferences;
  }

  void _handleChanged(ProfilePreferences updated) {
    setState(() {
      _prefs = updated;
    });
    widget.onPreferencesChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = isDark ? SpatiallyColors.darkTextPrimary : SpatiallyColors.lightTextPrimary;
    final textSecondary = isDark ? SpatiallyColors.darkTextSecondary : SpatiallyColors.lightTextSecondary;

    return Scaffold(
      appBar: const SpatiallyAppBar(
        title: 'Preferences & Accessibility',
        automaticallyImplyLeading: true,
      ),
      body: SafeArea(
        bottom: true,
        child: SingleChildScrollView(
          padding: SpatiallySpacing.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Theme Mode Selector
              const SpatiallySectionHeader(
                title: 'Interface Appearance',
                subtitle: 'Customize dark mode and visual comfort',
              ),
              SpatiallySpacing.gapVerticalSm,
              SpatiallyCard(
                padding: const EdgeInsets.all(SpatiallySpacing.md),
                child: Row(
                  children: [
                    Icon(
                      isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                      color: SpatiallyColors.violet,
                      size: 22,
                    ),
                    SpatiallySpacing.gapHorizontalMd,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Theme Mode',
                            style: SpatiallyTypography.body(color: textPrimary).copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            _prefs.themeMode == ThemeMode.system
                                ? 'System Auto'
                                : (_prefs.themeMode == ThemeMode.dark ? 'Dark Mode' : 'Light Mode'),
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
                          tooltip: 'System',
                        ),
                        ButtonSegment<ThemeMode>(
                          value: ThemeMode.light,
                          icon: Icon(Icons.light_mode_rounded, size: 16),
                          tooltip: 'Light',
                        ),
                        ButtonSegment<ThemeMode>(
                          value: ThemeMode.dark,
                          icon: Icon(Icons.dark_mode_rounded, size: 16),
                          tooltip: 'Dark',
                        ),
                      ],
                      selected: {_prefs.themeMode},
                      onSelectionChanged: (newSelection) {
                        if (newSelection.isNotEmpty) {
                          _handleChanged(_prefs.copyWith(themeMode: newSelection.first));
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
              ),

              SpatiallySpacing.gapVerticalLg,

              // Accessibility Section
              ProfileAccessibilitySection(
                preferences: _prefs,
                onPreferencesChanged: _handleChanged,
              ),

              SpatiallySpacing.gapVerticalXl,
            ],
          ),
        ),
      ),
    );
  }
}
