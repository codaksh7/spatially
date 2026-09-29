import 'package:flutter/material.dart';
import '../../../design_system/design_system.dart';
import '../../../screens/event_list_screen.dart';

/// Empty state shown on Home when no upcoming events or tickets exist.
///
/// Provides a genuinely useful path forward instead of a blank placeholder.
class HomeNoEvents extends StatelessWidget {
  const HomeNoEvents({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary =
        isDark ? SpatiallyColors.darkTextPrimary : SpatiallyColors.lightTextPrimary;
    final textSecondary =
        isDark ? SpatiallyColors.darkTextSecondary : SpatiallyColors.lightTextSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Icon and heading — not inside a card, sits on the background
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: SpatiallyColors.violet.withValues(alpha: 0.10),
            borderRadius: SpatiallyRadius.borderSm,
          ),
          child: const Icon(
            Icons.explore_outlined,
            size: 26,
            color: SpatiallyColors.violet,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'No upcoming events',
          style: SpatiallyTypography.headingLarge(color: textPrimary),
        ),
        const SizedBox(height: 6),
        Text(
          'Browse available events and get your ticket to experience Spatially at your next event.',
          style: SpatiallyTypography.body(color: textSecondary),
        ),
        const SizedBox(height: 24),
        SpatiallyPrimaryButton(
          label: 'Browse Events',
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const EventListScreen()),
            );
          },
          icon: const Icon(
            Icons.search_rounded,
            size: 18,
            color: Colors.white,
          ),
          fullWidth: false,
          height: 48,
        ),
      ],
    );
  }
}
