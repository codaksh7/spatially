import 'package:flutter/material.dart';
import '../../../design_system/design_system.dart';
import '../models/spatially_booth.dart';

/// Compact, informative booth card for exhibitor/project showcase discovery.
class BoothCard extends StatelessWidget {
  final SpatiallyBooth booth;
  final VoidCallback? onTap;
  final VoidCallback? onMapTap;

  const BoothCard({
    super.key,
    required this.booth,
    this.onTap,
    this.onMapTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = isDark ? SpatiallyColors.darkTextPrimary : SpatiallyColors.lightTextPrimary;
    final textSecondary = isDark ? SpatiallyColors.darkTextSecondary : SpatiallyColors.lightTextSecondary;

    return Semantics(
      label: '${booth.name}, ${booth.companyOrOrg}, ${booth.boothNumber}',
      button: true,
      child: SpatiallyCard(
        padding: const EdgeInsets.all(SpatiallySpacing.md),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Booth Number + Category Pill
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: SpatiallyColors.spatialCyan.withValues(alpha: 0.12),
                        borderRadius: SpatiallyRadius.borderSm,
                      ),
                      child: Text(
                        booth.boothNumber.toUpperCase(),
                        style: SpatiallyTypography.badge(color: SpatiallyColors.spatialCyan)
                            .copyWith(fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                    SpatiallySpacing.gapHorizontalXs,
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isDark ? SpatiallyColors.darkSurfaceElevated : SpatiallyColors.lightBorderSubdued,
                        borderRadius: SpatiallyRadius.borderSm,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(booth.categoryIcon, size: 12, color: textSecondary),
                          SpatiallySpacing.gapHorizontalXxs,
                          Text(
                            booth.categoryDisplayName,
                            style: SpatiallyTypography.caption(color: textSecondary).copyWith(fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: booth.isOpen
                        ? SpatiallyColors.success.withValues(alpha: 0.12)
                        : textSecondary.withValues(alpha: 0.12),
                    borderRadius: SpatiallyRadius.borderFull,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: booth.isOpen ? SpatiallyColors.success : textSecondary,
                        ),
                      ),
                      SpatiallySpacing.gapHorizontalXxs,
                      Text(
                        booth.isOpen ? 'OPEN' : 'CLOSED',
                        style: SpatiallyTypography.caption(
                          color: booth.isOpen ? SpatiallyColors.success : textSecondary,
                        ).copyWith(fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            SpatiallySpacing.gapVerticalSm,

            // Booth Name & Exhibitor
            Text(
              booth.name,
              style: SpatiallyTypography.subheading(color: textPrimary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SpatiallySpacing.gapVerticalXxs,
            Text(
              booth.companyOrOrg,
              style: SpatiallyTypography.caption(color: SpatiallyColors.violet).copyWith(fontWeight: FontWeight.w600),
            ),

            SpatiallySpacing.gapVerticalXs,

            // Short Description
            Text(
              booth.description,
              style: SpatiallyTypography.secondary(color: textSecondary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            SpatiallySpacing.gapVerticalSm,
            const Divider(height: 1),
            SpatiallySpacing.gapVerticalSm,

            // Bottom Row: Location with Map icon
            Row(
              children: [
                const Icon(Icons.location_on_rounded, size: 14, color: SpatiallyColors.spatialCyan),
                SpatiallySpacing.gapHorizontalXs,
                Expanded(
                  child: Text(
                    booth.roomName,
                    style: SpatiallyTypography.caption(color: textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                InkWell(
                  onTap: onMapTap,
                  borderRadius: SpatiallyRadius.borderSm,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View on Map',
                          style: SpatiallyTypography.caption(color: SpatiallyColors.violet).copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(Icons.chevron_right_rounded, size: 14, color: SpatiallyColors.violet),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
