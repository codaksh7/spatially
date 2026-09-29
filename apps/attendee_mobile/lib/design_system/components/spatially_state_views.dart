import 'package:flutter/material.dart';
import '../spatially_colors.dart';
import '../spatially_typography.dart';
import '../spatially_spacing.dart';
import 'spatially_button.dart';

/// Centralized Loading State based on SPATIALLY_DESIGN.md.
class SpatiallyLoadingState extends StatelessWidget {
  final String? message;

  const SpatiallyLoadingState({
    super.key,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textSecondary = isDark ? SpatiallyColors.darkTextSecondary : SpatiallyColors.lightTextSecondary;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(SpatiallyColors.violet),
            ),
          ),
          if (message != null) ...[
            SpatiallySpacing.gapVerticalMd,
            Text(
              message!,
              style: SpatiallyTypography.secondary(color: textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

/// Centralized Empty State based on SPATIALLY_DESIGN.md.
class SpatiallyEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SpatiallyEmptyState({
    super.key,
    this.icon = Icons.inbox_outlined,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = isDark ? SpatiallyColors.darkTextPrimary : SpatiallyColors.lightTextPrimary;
    final textSecondary = isDark ? SpatiallyColors.darkTextSecondary : SpatiallyColors.lightTextSecondary;

    return Center(
      child: Padding(
        padding: SpatiallySpacing.screenPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: (isDark ? SpatiallyColors.darkSurfaceElevated : SpatiallyColors.lightBorderSubdued),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 34,
                color: textSecondary,
              ),
            ),
            SpatiallySpacing.gapVerticalLg,
            Text(
              title,
              style: SpatiallyTypography.sectionHeading(color: textPrimary),
              textAlign: TextAlign.center,
            ),
            SpatiallySpacing.gapVerticalXs,
            Text(
              description,
              style: SpatiallyTypography.body(color: textSecondary),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              SpatiallySpacing.gapVerticalXl,
              SpatiallyPrimaryButton(
                label: actionLabel!,
                onPressed: onAction,
                fullWidth: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Centralized Error State based on SPATIALLY_DESIGN.md.
class SpatiallyErrorState extends StatelessWidget {
  final String title;
  final String error;
  final VoidCallback? onRetry;
  final String retryLabel;

  const SpatiallyErrorState({
    super.key,
    this.title = 'Something went wrong',
    required this.error,
    this.onRetry,
    this.retryLabel = 'Try Again',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = isDark ? SpatiallyColors.darkTextPrimary : SpatiallyColors.lightTextPrimary;
    final textSecondary = isDark ? SpatiallyColors.darkTextSecondary : SpatiallyColors.lightTextSecondary;

    return Center(
      child: Padding(
        padding: SpatiallySpacing.screenPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: SpatiallyColors.error.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 36,
                color: SpatiallyColors.error,
              ),
            ),
            SpatiallySpacing.gapVerticalLg,
            Text(
              title,
              style: SpatiallyTypography.sectionHeading(color: textPrimary),
              textAlign: TextAlign.center,
            ),
            SpatiallySpacing.gapVerticalXs,
            Text(
              error,
              style: SpatiallyTypography.secondary(color: textSecondary),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              SpatiallySpacing.gapVerticalXl,
              SpatiallyPrimaryButton(
                label: retryLabel,
                onPressed: onRetry,
                fullWidth: false,
                height: 44,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
