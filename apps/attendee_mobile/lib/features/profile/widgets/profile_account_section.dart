import 'package:flutter/material.dart';

import '../../../design_system/design_system.dart';
import '../models/user_profile.dart';

/// Account identity, Google OAuth, guest ticket claim, and session reset section
/// within Profile & Settings.
class ProfileAccountSection extends StatelessWidget {
  final UserProfile profile;
  final VoidCallback onResetRequested;
  final VoidCallback onSignInWithGoogle;
  final VoidCallback onSignOutRequested;
  final VoidCallback onClaimTicketsRequested;

  const ProfileAccountSection({
    super.key,
    required this.profile,
    required this.onResetRequested,
    required this.onSignInWithGoogle,
    required this.onSignOutRequested,
    required this.onClaimTicketsRequested,
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
          title: 'Account & Identity',
          subtitle: 'Manage cloud account session and local device installation data',
        ),
        SpatiallySpacing.gapVerticalSm,
        SpatiallyCard(
          padding: const EdgeInsets.all(SpatiallySpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (profile.isAuthenticated) ...[
                // --- AUTHENTICATED STATE ---
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: SpatiallyColors.success.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.verified_user_rounded,
                        color: SpatiallyColors.success,
                        size: 22,
                      ),
                    ),
                    SpatiallySpacing.gapHorizontalMd,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Google Account Connected',
                                style: SpatiallyTypography.body(color: textPrimary).copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SpatiallySpacing.gapHorizontalXs,
                              const Icon(Icons.check_circle_rounded, color: SpatiallyColors.success, size: 16),
                            ],
                          ),
                          if (profile.email != null) ...[
                            SpatiallySpacing.gapVerticalXxs,
                            Text(
                              profile.email!,
                              style: SpatiallyTypography.caption(color: textSecondary).copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                          SpatiallySpacing.gapVerticalXxs,
                          Text(
                            'Role: ${profile.role.toUpperCase()} (Server Verified)',
                            style: SpatiallyTypography.caption(color: SpatiallyColors.violet),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(),
                SpatiallySpacing.gapVerticalXs,

                // Claim Guest Tickets Action
                InkWell(
                  onTap: onClaimTicketsRequested,
                  borderRadius: BorderRadius.circular(SpatiallyRadius.sm),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: SpatiallySpacing.xs),
                    child: Row(
                      children: [
                        const Icon(Icons.confirmation_number_outlined, color: SpatiallyColors.violet, size: 22),
                        SpatiallySpacing.gapHorizontalMd,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Claim Unlinked Guest Tickets',
                                style: SpatiallyTypography.body(color: textPrimary).copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'Link tickets held on this physical device to your permanent cloud account.',
                                style: SpatiallyTypography.caption(color: textSecondary),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: SpatiallyColors.violet, size: 20),
                      ],
                    ),
                  ),
                ),

                const Divider(),
                SpatiallySpacing.gapVerticalXs,

                // Sign Out Action
                InkWell(
                  onTap: () => _confirmSignOut(context),
                  borderRadius: BorderRadius.circular(SpatiallyRadius.sm),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: SpatiallySpacing.xs),
                    child: Row(
                      children: [
                        const Icon(Icons.logout_rounded, color: SpatiallyColors.warning, size: 22),
                        SpatiallySpacing.gapHorizontalMd,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sign Out of Account',
                                style: SpatiallyTypography.body(color: SpatiallyColors.warning).copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'Return to guest mode. Local device identity is safely preserved.',
                                style: SpatiallyTypography.caption(color: textSecondary),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: SpatiallyColors.warning, size: 20),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                // --- GUEST STATE ---
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: SpatiallyColors.spatialCyan.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.fingerprint_rounded,
                        color: SpatiallyColors.spatialCyan,
                        size: 22,
                      ),
                    ),
                    SpatiallySpacing.gapHorizontalMd,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Guest-First Session (Unauthenticated)',
                            style: SpatiallyTypography.body(color: textPrimary).copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Explore events, maps, and admission tickets without logging in.',
                            style: SpatiallyTypography.caption(color: textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SpatiallySpacing.gapVerticalMd,

                // Continue with Google Button
                SpatiallyPrimaryButton(
                  label: 'Continue with Google',
                  icon: const Icon(Icons.g_mobiledata_rounded, size: 24, color: Colors.white),
                  fullWidth: true,
                  useGradient: true,
                  onPressed: onSignInWithGoogle,
                ),
                SpatiallySpacing.gapVerticalXs,
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'Optional. Sign in to link admission tickets to your permanent cloud account and sync across devices.',
                    style: SpatiallyTypography.caption(color: textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],

              const Divider(),
              SpatiallySpacing.gapVerticalXs,

              // Reset Profile & Preferences Action
              InkWell(
                onTap: () => _confirmReset(context),
                borderRadius: BorderRadius.circular(SpatiallyRadius.sm),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: SpatiallySpacing.xs),
                  child: Row(
                    children: [
                      const Icon(Icons.restart_alt_rounded, color: SpatiallyColors.error, size: 22),
                      SpatiallySpacing.gapHorizontalMd,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Reset Profile & Preferences',
                              style: SpatiallyTypography.body(color: SpatiallyColors.error).copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              'Revert customized name, bio, tags, and preferences to defaults.',
                              style: SpatiallyTypography.caption(color: textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: SpatiallyColors.error, size: 20),
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

  void _confirmSignOut(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Sign Out?'),
          content: Text(
            'Are you sure you want to sign out of ${profile.email ?? "your account"}?\n\n'
            'Your local device installation identity (${profile.deviceId}) is preserved, and you will return to guest mode.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: SpatiallyColors.warning),
              onPressed: () {
                Navigator.of(ctx).pop();
                onSignOutRequested();
              },
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );
  }

  void _confirmReset(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Reset Profile?'),
          content: const Text(
            'This will clear your customized name, bio, and preferences, resetting your profile back to default guest state. Verified tickets and passport badges are preserved.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: SpatiallyColors.error),
              onPressed: () {
                Navigator.of(ctx).pop();
                onResetRequested();
              },
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );
  }
}
