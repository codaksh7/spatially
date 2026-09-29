import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../design_system/design_system.dart';
import '../models/user_profile.dart';

/// Top card displaying attendee's personal identity, avatar, cloud status, and quick edit action.
class ProfileHeaderCard extends StatelessWidget {
  final UserProfile profile;
  final VoidCallback onEditProfile;

  const ProfileHeaderCard({
    super.key,
    required this.profile,
    required this.onEditProfile,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = isDark ? SpatiallyColors.darkTextPrimary : SpatiallyColors.lightTextPrimary;
    final textSecondary = isDark ? SpatiallyColors.darkTextSecondary : SpatiallyColors.lightTextSecondary;

    return SpatiallyCard(
      hasSubtleGlow: true,
      padding: const EdgeInsets.all(SpatiallySpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar circle with initials or guest icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: SpatiallyColors.brandGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: SpatiallyColors.violet.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    profile.initials,
                    style: SpatiallyTypography.sectionHeading(color: Colors.white).copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              SpatiallySpacing.gapHorizontalMd,

              // Name and Headline
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name,
                      style: SpatiallyTypography.sectionHeading(color: textPrimary).copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (profile.email != null && profile.email!.isNotEmpty) ...[
                      SpatiallySpacing.gapVerticalXxs,
                      Row(
                        children: [
                          Icon(Icons.alternate_email_rounded, size: 12, color: textSecondary),
                          SpatiallySpacing.gapHorizontalXxs,
                          Expanded(
                            child: Text(
                              profile.email!,
                              style: SpatiallyTypography.caption(color: textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (profile.headline.isNotEmpty) ...[
                      SpatiallySpacing.gapVerticalXxs,
                      Text(
                        profile.headline,
                        style: SpatiallyTypography.body(color: textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (profile.organization.isNotEmpty) ...[
                      SpatiallySpacing.gapVerticalXxs,
                      Row(
                        children: [
                          Icon(Icons.business_rounded, size: 13, color: textSecondary),
                          SpatiallySpacing.gapHorizontalXxs,
                          Expanded(
                            child: Text(
                              profile.organization,
                              style: SpatiallyTypography.caption(color: textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Status badge (Google Account vs Guest)
              SpatiallyStatusBadge(
                label: profile.isAuthenticated ? 'ACCOUNT' : (profile.isAnonymous ? 'GUEST' : 'PROFILE'),
                variant: profile.isAuthenticated
                    ? SpatiallyBadgeVariant.live
                    : (profile.isAnonymous ? SpatiallyBadgeVariant.custom : SpatiallyBadgeVariant.custom),
                customColor: profile.isAuthenticated ? SpatiallyColors.success : SpatiallyColors.spatialCyan,
              ),
            ],
          ),
          SpatiallySpacing.gapVerticalLg,

          // Bio if present
          if (profile.bio.isNotEmpty) ...[
            Text(
              profile.bio,
              style: SpatiallyTypography.secondary(color: textSecondary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SpatiallySpacing.gapVerticalMd,
          ],

          // Device ID row with copy functionality (Local installation UUID)
          InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: profile.deviceId));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Device ID copied to clipboard'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            borderRadius: SpatiallyRadius.borderSm,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? SpatiallyColors.darkSurface : SpatiallyColors.lightBackground,
                borderRadius: SpatiallyRadius.borderSm,
                border: Border.all(
                  color: isDark ? SpatiallyColors.darkBorderSubdued : SpatiallyColors.lightBorderSubdued,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.fingerprint_rounded, size: 16, color: SpatiallyColors.violet),
                  SpatiallySpacing.gapHorizontalSm,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DEVICE ID: ${profile.deviceId}',
                          style: SpatiallyTypography.caption(color: textSecondary).copyWith(
                            fontFamily: 'monospace',
                            fontSize: 10,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.copy_rounded, size: 14, color: textSecondary),
                ],
              ),
            ),
          ),
          SpatiallySpacing.gapVerticalLg,

          // Edit Profile CTA Button
          SpatiallySoftButton(
            label: 'Edit Profile & Details',
            icon: const Icon(Icons.edit_outlined, size: 16, color: SpatiallyColors.violet),
            fullWidth: true,
            onPressed: onEditProfile,
          ),
        ],
      ),
    );
  }
}
