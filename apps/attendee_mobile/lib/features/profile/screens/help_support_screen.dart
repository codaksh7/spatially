import 'package:flutter/material.dart';

import '../../../design_system/design_system.dart';
import '../models/profile_preferences.dart';
import '../widgets/profile_app_settings_section.dart';

/// Focused screen for venue safety guide, platform help, and production about info.
class HelpSupportScreen extends StatelessWidget {
  final ProfilePreferences preferences;
  final ValueChanged<ProfilePreferences> onPreferencesChanged;

  const HelpSupportScreen({
    super.key,
    required this.preferences,
    required this.onPreferencesChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SpatiallyAppBar(
        title: 'Help & About',
        automaticallyImplyLeading: true,
      ),
      body: SafeArea(
        bottom: true,
        child: SingleChildScrollView(
          padding: SpatiallySpacing.screenPadding,
          child: ProfileAppSettingsSection(
            preferences: preferences,
            onPreferencesChanged: onPreferencesChanged,
          ),
        ),
      ),
    );
  }
}
