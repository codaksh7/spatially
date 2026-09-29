import 'package:flutter/material.dart';

import '../../../design_system/design_system.dart';
import '../models/profile_preferences.dart';
import '../widgets/profile_networking_section.dart';
import '../widgets/profile_privacy_section.dart';

/// Focused screen for managing attendee discovery, BLE radar, and privacy policies.
class PrivacyNetworkingScreen extends StatefulWidget {
  final ProfilePreferences preferences;
  final ValueChanged<ProfilePreferences> onPreferencesChanged;

  const PrivacyNetworkingScreen({
    super.key,
    required this.preferences,
    required this.onPreferencesChanged,
  });

  @override
  State<PrivacyNetworkingScreen> createState() => _PrivacyNetworkingScreenState();
}

class _PrivacyNetworkingScreenState extends State<PrivacyNetworkingScreen> {
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
        title: 'Privacy & Networking',
        automaticallyImplyLeading: true,
      ),
      body: SafeArea(
        bottom: true,
        child: SingleChildScrollView(
          padding: SpatiallySpacing.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ProfileNetworkingSection(
                preferences: _prefs,
                onPreferencesChanged: _handleChanged,
              ),
              SpatiallySpacing.gapVerticalLg,
              ProfilePrivacySection(
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
