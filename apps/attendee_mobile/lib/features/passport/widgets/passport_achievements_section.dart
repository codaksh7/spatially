import 'package:flutter/material.dart';
import '../../../design_system/design_system.dart';
import '../models/achievement_badge.dart';

/// Achievements section displaying locked milestone definitions and verified unlocks.
/// 
/// Strictly distinguishes locked achievements from earned unlocks.
class PassportAchievementsSection extends StatelessWidget {
  final List<AchievementBadge> badges;

  const PassportAchievementsSection({
    super.key,
    required this.badges,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = isDark ? SpatiallyColors.darkTextPrimary : SpatiallyColors.lightTextPrimary;
    final textSecondary = isDark ? SpatiallyColors.darkTextSecondary : SpatiallyColors.lightTextSecondary;

    final unlockedCount = badges.where((b) => b.isUnlocked).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SpatiallySectionHeader(
          title: 'Achievements',
          subtitle: 'Milestones earned through verified participation',
          action: SpatiallyStatusBadge(
            label: '$unlockedCount / ${badges.length} UNLOCKED',
            variant: unlockedCount > 0 ? SpatiallyBadgeVariant.live : SpatiallyBadgeVariant.checkedIn,
          ),
        ),
        SpatiallySpacing.gapVerticalSm,
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: badges.length,
          separatorBuilder: (context, index) => SpatiallySpacing.gapVerticalSm,
          itemBuilder: (context, index) {
            final badge = badges[index];
            return _buildBadgeCard(context, badge, textPrimary, textSecondary, isDark);
          },
        ),
      ],
    );
  }

  Widget _buildBadgeCard(
    BuildContext context,
    AchievementBadge badge,
    Color textPrimary,
    Color textSecondary,
    bool isDark,
  ) {
    final iconColor = badge.isUnlocked
        ? SpatiallyColors.violet
        : (isDark ? SpatiallyColors.darkTextTertiary : SpatiallyColors.lightTextTertiary);
    final iconBgColor = badge.isUnlocked
        ? SpatiallyColors.violet.withValues(alpha: 0.15)
        : (isDark ? SpatiallyColors.darkSurface : SpatiallyColors.lightSurface);

    return SpatiallyCard(
      hasSubtleGlow: badge.isUnlocked,
      padding: const EdgeInsets.all(SpatiallySpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badge Icon with unlocked/locked state
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: SpatiallyRadius.borderMd,
                  border: Border.all(
                    color: badge.isUnlocked
                        ? SpatiallyColors.violet.withValues(alpha: 0.4)
                        : (isDark ? SpatiallyColors.darkBorderSubdued : SpatiallyColors.lightBorderSubdued),
                  ),
                ),
                child: Icon(
                  badge.icon,
                  size: 22,
                  color: iconColor,
                ),
              ),
              if (!badge.isUnlocked)
                Positioned(
                  right: -4,
                  bottom: -4,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: isDark ? SpatiallyColors.darkBackground : SpatiallyColors.lightBackground,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.lock_rounded,
                      size: 13,
                      color: isDark ? SpatiallyColors.darkTextTertiary : SpatiallyColors.lightTextTertiary,
                    ),
                  ),
                ),
            ],
          ),
          SpatiallySpacing.gapHorizontalMd,

          // Badge Details & Progress
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        badge.title,
                        style: SpatiallyTypography.body(color: textPrimary).copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (badge.isUnlocked)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: SpatiallyColors.success.withValues(alpha: 0.15),
                          borderRadius: SpatiallyRadius.borderXs,
                        ),
                        child: Text(
                          'UNLOCKED',
                          style: SpatiallyTypography.caption(color: SpatiallyColors.success).copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                          ),
                        ),
                      )
                    else
                      Text(
                        '${badge.currentCount} / ${badge.requiredCount}',
                        style: SpatiallyTypography.caption(color: textSecondary).copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
                SpatiallySpacing.gapVerticalXxs,
                Text(
                  badge.description,
                  style: SpatiallyTypography.caption(color: textSecondary),
                ),
                SpatiallySpacing.gapVerticalSm,

                // Progress Bar
                ClipRRect(
                  borderRadius: SpatiallyRadius.borderXs,
                  child: LinearProgressIndicator(
                    value: badge.progressFraction,
                    minHeight: 4,
                    backgroundColor: isDark ? SpatiallyColors.darkBorderSubdued : SpatiallyColors.lightBorderSubdued,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      badge.isUnlocked ? SpatiallyColors.success : SpatiallyColors.violet,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
