import 'package:flutter/material.dart';
import '../../../design_system/design_system.dart';
import '../../../screens/my_tickets_screen.dart';

/// Section providing direct bridges to Passport and My Tickets.
/// 
/// Strictly links to existing event modules without duplicating ticket or passport logic.
class ProfileExperienceSection extends StatelessWidget {
  final VoidCallback onNavigateToPassport;

  const ProfileExperienceSection({
    super.key,
    required this.onNavigateToPassport,
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
          title: 'Event Records & Passes',
          subtitle: 'Access your tickets and verified event records',
        ),
        SpatiallySpacing.gapVerticalSm,
        SpatiallyCard(
          padding: const EdgeInsets.all(SpatiallySpacing.md),
          child: Column(
            children: [
              _buildNavTile(
                icon: Icons.confirmation_number_outlined,
                iconColor: SpatiallyColors.spatialCyan,
                title: 'My Admission Passes',
                subtitle: 'QR admittance codes and active tickets',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MyTicketsScreen()),
                  );
                },
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                isDark: isDark,
              ),
              Divider(height: 1, color: isDark ? SpatiallyColors.darkBorderSubdued : SpatiallyColors.lightBorderSubdued),
              _buildNavTile(
                icon: Icons.military_tech_outlined,
                iconColor: SpatiallyColors.violet,
                title: 'Event Journey & Passport',
                subtitle: 'Verified attendance, checkpoints, and badges',
                onTap: onNavigateToPassport,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                isDark: isDark,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNavTile({
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
              width: 36,
              height: 36,
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
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: SpatiallyTypography.caption(color: textSecondary),
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
