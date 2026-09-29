import 'package:flutter/material.dart';

import '../../../design_system/design_system.dart';
import '../models/profile_preferences.dart';
import '../widgets/profile_notifications_section.dart';

/// Focused screen for managing all notification and alert preferences.
class NotificationSettingsScreen extends StatefulWidget {
  final ProfilePreferences preferences;
  final ValueChanged<ProfilePreferences> onPreferencesChanged;

  const NotificationSettingsScreen({
    super.key,
    required this.preferences,
    required this.onPreferencesChanged,
  });

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
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
    return Scaffold(
      appBar: const SpatiallyAppBar(
        title: 'Notification Settings',
        automaticallyImplyLeading: true,
      ),
      body: SafeArea(
        bottom: true,
        child: SingleChildScrollView(
          padding: SpatiallySpacing.screenPadding,
          child: ProfileNotificationsSection(
            preferences: _prefs,
            onPreferencesChanged: _handleChanged,
          ),
        ),
      ),
    );
  }
}
