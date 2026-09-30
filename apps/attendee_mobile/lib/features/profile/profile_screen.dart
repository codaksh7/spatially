import 'dart:async';
import 'package:flutter/material.dart';

import '../../design_system/design_system.dart';
import '../../services/auth_service.dart';
import 'data/profile_repository.dart';
import 'models/profile_preferences.dart';
import 'models/user_profile.dart';
import 'screens/app_preferences_screen.dart';
import 'screens/edit_profile_screen.dart';
import 'screens/help_support_screen.dart';
import 'screens/notification_settings_screen.dart';
import 'screens/privacy_networking_screen.dart';
import 'widgets/profile_account_section.dart';
import 'widgets/profile_experience_section.dart';
import 'widgets/profile_header_card.dart';
import 'widgets/profile_interests_section.dart';

/// Spatially Attendee Profile & Settings Screen.
/// 
/// Destination for personal identity, interests, networking preferences,
/// accessibility, notifications, zero-knowledge privacy, and app settings.
///
/// Supports guest-first mode with optional Google OAuth sign-in, guest ticket claiming,
/// and safe multi-account logout/switching.
class ProfileScreen extends StatefulWidget {
  final VoidCallback? onNavigateToPassport;

  const ProfileScreen({
    super.key,
    this.onNavigateToPassport,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileRepository _repository = ProfileRepositoryImpl();
  StreamSubscription? _authSub;

  UserProfile? _profile;
  ProfilePreferences? _preferences;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
    _authSub = AuthService().onAuthStateChange.listen((_) {
      if (mounted) {
        _loadProfileData();
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final profile = await _repository.getProfile();
      final preferences = await _repository.getPreferences();
      if (mounted) {
        setState(() {
          _profile = profile;
          _preferences = preferences;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load profile. Tap to retry.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleEditProfile() async {
    if (_profile == null) return;

    final updated = await Navigator.of(context).push<UserProfile>(
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(
          initialProfile: _profile!,
          repository: _repository,
        ),
      ),
    );

    if (updated != null && mounted) {
      setState(() {
        _profile = updated;
      });
    }
  }

  Future<void> _handleInterestsChanged(List<String> newInterests) async {
    if (_profile == null) return;
    final updated = _profile!.copyWith(interests: newInterests);
    setState(() {
      _profile = updated;
    });
    await _repository.saveProfile(updated);
  }

  Future<void> _handlePreferencesChanged(ProfilePreferences newPrefs) async {
    setState(() {
      _preferences = newPrefs;
    });
    await _repository.savePreferences(newPrefs);
  }

  Future<void> _handleSignInWithGoogle() async {
    try {
      final success = await AuthService().signInWithGoogle();
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sign in was cancelled.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Google Sign-In'),
            content: Text(
              'OAuth Error:\n\n$e\n\n'
              'Note: If Google provider is not yet enabled on Supabase project, '
              'configure OAuth in the Supabase Dashboard as described in the Implementation Report.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _handleSignOut() async {
    try {
      await AuthService().signOut();
      await _loadProfileData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Signed out successfully. Switched to guest mode.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign out error: $e'),
            backgroundColor: SpatiallyColors.error,
          ),
        );
      }
    }
  }

  Future<void> _handleClaimTickets() async {
    final result = await AuthService().claimGuestTickets();
    if (!mounted) return;

    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? 'Failed to claim guest tickets.'),
          backgroundColor: SpatiallyColors.error,
        ),
      );
      return;
    }

    if (result.claimedCount > 0) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Tickets Claimed!'),
          content: Text(
            'Successfully claimed ${result.claimedCount} guest ticket(s) to your permanent cloud account!\n\n'
            '${result.alreadyOwnedCount > 0 ? "You already own ${result.alreadyOwnedCount} ticket(s) on this account.\n\n" : ""}'
            'You can now view your tickets across devices under My Tickets.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Awesome'),
            ),
          ],
        ),
      );
    } else if (result.alreadyOwnedCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('All ${result.alreadyOwnedCount} ticket(s) for this device are already owned by your account.'),
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No unclaimed guest tickets found for this device installation.'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _handleResetProfile() async {
    await _repository.resetProfile();
    await _loadProfileData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile and preferences reset to defaults.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SpatiallyAppBar(
        title: 'Profile & Settings',
        automaticallyImplyLeading: false,
      ),
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: SpatiallyErrorState(
          error: _errorMessage!,
          onRetry: _loadProfileData,
        ),
      );
    }

    final profile = _profile!;
    final preferences = _preferences ?? ProfilePreferences.defaults();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? SpatiallyColors.darkTextPrimary : SpatiallyColors.lightTextPrimary;
    final textSecondary = isDark ? SpatiallyColors.darkTextSecondary : SpatiallyColors.lightTextSecondary;

    return RefreshIndicator(
      onRefresh: _loadProfileData,
      color: SpatiallyColors.violet,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: SpatiallySpacing.screenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Profile / Identity Card
            ProfileHeaderCard(
              profile: profile,
              onEditProfile: _handleEditProfile,
            ),

            SpatiallySpacing.gapVerticalLg,

            // 2. Personal Interests Section
            ProfileInterestsSection(
              selectedInterests: profile.interests,
              availableInterests: _repository.getAvailableInterests(),
              onInterestsChanged: _handleInterestsChanged,
            ),

            SpatiallySpacing.gapVerticalLg,

            // 3. Event Experience Bridges (Passport & Passes)
            ProfileExperienceSection(
              onNavigateToPassport: () {
                widget.onNavigateToPassport?.call();
              },
            ),

            SpatiallySpacing.gapVerticalLg,

            // 4. Settings & Preferences Navigation Menu
            const SpatiallySectionHeader(
              title: 'Settings & Preferences',
              subtitle: 'Configure notifications, networking, accessibility & support',
            ),
            SpatiallySpacing.gapVerticalSm,
            SpatiallyCard(
              padding: const EdgeInsets.all(SpatiallySpacing.md),
              child: Column(
                children: [
                  _buildSettingsNavTile(
                    icon: Icons.notifications_outlined,
                    iconColor: SpatiallyColors.violet,
                    title: 'Notification Settings',
                    subtitle: 'Announcements, session reminders, crowd alerts',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => NotificationSettingsScreen(
                            preferences: preferences,
                            onPreferencesChanged: _handlePreferencesChanged,
                          ),
                        ),
                      );
                    },
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    isDark: isDark,
                  ),
                  Divider(height: 1, color: isDark ? SpatiallyColors.darkBorderSubdued : SpatiallyColors.lightBorderSubdued),
                  _buildSettingsNavTile(
                    icon: Icons.security_outlined,
                    iconColor: SpatiallyColors.spatialCyan,
                    title: 'Privacy & Networking',
                    subtitle: 'Bluetooth discovery, radar visibility, beacon policies',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PrivacyNetworkingScreen(
                            preferences: preferences,
                            onPreferencesChanged: _handlePreferencesChanged,
                          ),
                        ),
                      );
                    },
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    isDark: isDark,
                  ),
                  Divider(height: 1, color: isDark ? SpatiallyColors.darkBorderSubdued : SpatiallyColors.lightBorderSubdued),
                  _buildSettingsNavTile(
                    icon: Icons.tune_outlined,
                    iconColor: SpatiallyColors.warning,
                    title: 'Preferences & Accessibility',
                    subtitle: 'Interface theme, high contrast, step-free routes',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AppPreferencesScreen(
                            preferences: preferences,
                            onPreferencesChanged: _handlePreferencesChanged,
                          ),
                        ),
                      );
                    },
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    isDark: isDark,
                  ),
                  Divider(height: 1, color: isDark ? SpatiallyColors.darkBorderSubdued : SpatiallyColors.lightBorderSubdued),
                  _buildSettingsNavTile(
                    icon: Icons.help_outline_rounded,
                    iconColor: SpatiallyColors.success,
                    title: 'Help & About',
                    subtitle: 'Venue safety guide, support FAQs, version info',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => HelpSupportScreen(
                            preferences: preferences,
                            onPreferencesChanged: _handlePreferencesChanged,
                          ),
                        ),
                      );
                    },
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    isDark: isDark,
                  ),
                ],
              ),
            ),

            SpatiallySpacing.gapVerticalLg,

            // 5. Account & Identity Management
            ProfileAccountSection(
              profile: profile,
              onResetRequested: _handleResetProfile,
              onSignInWithGoogle: _handleSignInWithGoogle,
              onSignOutRequested: _handleSignOut,
              onClaimTicketsRequested: _handleClaimTickets,
            ),

            SpatiallySpacing.gapVerticalXxl,
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsNavTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color textPrimary,
    required Color textSecondary,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: SpatiallyRadius.borderSm,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: SpatiallySpacing.sm),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
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
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: SpatiallyTypography.caption(color: textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: textSecondary, size: 20),
          ],
        ),
      ),
    );
  }
}
