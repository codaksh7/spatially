import 'package:flutter/material.dart';
import '../../../design_system/design_system.dart';

/// Section displaying selected attendee interests and allowing quick customization.
class ProfileInterestsSection extends StatelessWidget {
  final List<String> selectedInterests;
  final List<String> availableInterests;
  final ValueChanged<List<String>> onInterestsChanged;

  const ProfileInterestsSection({
    super.key,
    required this.selectedInterests,
    required this.availableInterests,
    required this.onInterestsChanged,
  });

  void _showInterestsBottomSheet(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = isDark ? SpatiallyColors.darkTextPrimary : SpatiallyColors.lightTextPrimary;
    final textSecondary = isDark ? SpatiallyColors.darkTextSecondary : SpatiallyColors.lightTextSecondary;

    final currentSelection = Set<String>.from(selectedInterests);

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? SpatiallyColors.darkSurfaceElevated : SpatiallyColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(SpatiallyRadius.lg)),
      ),
      isScrollControlled: true,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: SpatiallySpacing.lg,
                right: SpatiallySpacing.lg,
                top: SpatiallySpacing.lg,
                bottom: MediaQuery.of(context).viewInsets.bottom + SpatiallySpacing.xl,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Select Interests',
                        style: SpatiallyTypography.sectionHeading(color: textPrimary),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  SpatiallySpacing.gapVerticalXs,
                  Text(
                    'Choose topics relevant to your professional focus and event goals.',
                    style: SpatiallyTypography.body(color: textSecondary),
                  ),
                  SpatiallySpacing.gapVerticalLg,

                  // Chips wrap
                  Wrap(
                    spacing: SpatiallySpacing.sm,
                    runSpacing: SpatiallySpacing.sm,
                    children: availableInterests.map((interest) {
                      final isSelected = currentSelection.contains(interest);
                      return FilterChip(
                        label: Text(interest),
                        selected: isSelected,
                        onSelected: (selected) {
                          setModalState(() {
                            if (selected) {
                              currentSelection.add(interest);
                            } else {
                              currentSelection.remove(interest);
                            }
                          });
                        },
                        labelStyle: SpatiallyTypography.caption(
                          color: isSelected ? Colors.white : textPrimary,
                        ).copyWith(fontWeight: FontWeight.w600),
                        backgroundColor: isDark ? SpatiallyColors.darkSurface : SpatiallyColors.lightBackground,
                        selectedColor: SpatiallyColors.violet,
                        checkmarkColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: SpatiallyRadius.borderFull,
                          side: BorderSide(
                            color: isSelected
                                ? SpatiallyColors.violet
                                : (isDark ? SpatiallyColors.darkBorderSubdued : SpatiallyColors.lightBorderSubdued),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  SpatiallySpacing.gapVerticalXl,

                  // Done button
                  SpatiallyPrimaryButton(
                    label: 'Save Interests (${currentSelection.length})',
                    onPressed: () {
                      Navigator.pop(context);
                      onInterestsChanged(currentSelection.toList());
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = isDark ? SpatiallyColors.darkTextPrimary : SpatiallyColors.lightTextPrimary;
    final textSecondary = isDark ? SpatiallyColors.darkTextSecondary : SpatiallyColors.lightTextSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SpatiallySectionHeader(
          title: 'Interests & Topics',
          subtitle: 'Topics you want to explore and discuss',
          action: InkWell(
            onTap: () => _showInterestsBottomSheet(context),
            borderRadius: SpatiallyRadius.borderSm,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                'Customize',
                style: SpatiallyTypography.caption(color: SpatiallyColors.violet).copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
        SpatiallySpacing.gapVerticalSm,
        SpatiallyCard(
          padding: const EdgeInsets.all(SpatiallySpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (selectedInterests.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: SpatiallySpacing.md),
                    child: Text(
                      'No interests selected yet. Tap Customize to choose topics.',
                      style: SpatiallyTypography.body(color: textSecondary),
                    ),
                  ),
                )
              else
                Wrap(
                  spacing: SpatiallySpacing.xs,
                  runSpacing: SpatiallySpacing.xs,
                  children: selectedInterests.map((interest) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: SpatiallyColors.violet.withValues(alpha: 0.12),
                        borderRadius: SpatiallyRadius.borderFull,
                        border: Border.all(
                          color: SpatiallyColors.violet.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.tag_rounded, size: 12, color: SpatiallyColors.violet),
                          SpatiallySpacing.gapHorizontalXxs,
                          Text(
                            interest,
                            style: SpatiallyTypography.caption(color: textPrimary).copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              SpatiallySpacing.gapVerticalSm,
              Text(
                'Used for session suggestions and networking discovery when active.',
                style: SpatiallyTypography.caption(color: textSecondary).copyWith(
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
