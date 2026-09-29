import 'package:flutter/material.dart';
import '../spatially_colors.dart';
import '../spatially_typography.dart';
import '../spatially_spacing.dart';
import '../spatially_radius.dart';

/// Primary call-to-action button for Spatially.
/// 
/// Supports solid or brand gradient background, leading icon, and loading state.
class SpatiallyPrimaryButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;
  final Widget? icon;
  final bool isLoading;
  final bool useGradient;
  final bool fullWidth;
  final double height;

  const SpatiallyPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.useGradient = false,
    this.fullWidth = true,
    this.height = 50.0,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null && !isLoading;

    Widget content = Row(
      mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading) ...[
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          SpatiallySpacing.gapHorizontalSm,
        ] else if (icon != null) ...[
          icon!,
          SpatiallySpacing.gapHorizontalSm,
        ],
        Text(
          label,
          style: SpatiallyTypography.button(color: Colors.white),
        ),
      ],
    );

    if (useGradient && isEnabled) {
      return Container(
        height: height,
        width: fullWidth ? double.infinity : null,
        decoration: const BoxDecoration(
          gradient: SpatiallyColors.brandGradient,
          borderRadius: SpatiallyRadius.borderSm,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: SpatiallyRadius.borderSm,
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Center(child: content),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: height,
      width: fullWidth ? double.infinity : null,
      child: ElevatedButton(
        onPressed: isEnabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: SpatiallyColors.violet,
          foregroundColor: Colors.white,
          disabledBackgroundColor: SpatiallyColors.violet.withValues(alpha: 0.5),
          shape: const RoundedRectangleBorder(
            borderRadius: SpatiallyRadius.borderSm,
          ),
          elevation: 0,
        ),
        child: content,
      ),
    );
  }
}

/// Secondary outlined or bordered button with lower visual weight.
class SpatiallySecondaryButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;
  final Widget? icon;
  final bool fullWidth;
  final double height;

  const SpatiallySecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.fullWidth = true,
    this.height = 50.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? SpatiallyColors.darkTextPrimary : SpatiallyColors.lightTextPrimary;
    final borderColor = isDark ? SpatiallyColors.darkBorderSubdued : SpatiallyColors.lightBorderSubdued;

    return SizedBox(
      height: height,
      width: fullWidth ? double.infinity : null,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: textColor,
          side: BorderSide(color: borderColor, width: 1.2),
          shape: const RoundedRectangleBorder(
            borderRadius: SpatiallyRadius.borderSm,
          ),
        ),
        child: Row(
          mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              icon!,
              SpatiallySpacing.gapHorizontalSm,
            ],
            Text(label, style: SpatiallyTypography.button(color: textColor)),
          ],
        ),
      ),
    );
  }
}

/// Soft tinted button for contextual actions (e.g. "Add to Agenda", "Navigate", "Connect").
class SpatiallySoftButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;
  final Widget? icon;
  final Color? tintColor;
  final bool fullWidth;
  final double height;

  const SpatiallySoftButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.tintColor,
    this.fullWidth = false,
    this.height = 42.0,
  });

  @override
  Widget build(BuildContext context) {
    final color = tintColor ?? SpatiallyColors.violet;

    return SizedBox(
      height: height,
      width: fullWidth ? double.infinity : null,
      child: Material(
        color: color.withValues(alpha: 0.12),
        borderRadius: SpatiallyRadius.borderSm,
        child: InkWell(
          borderRadius: SpatiallyRadius.borderSm,
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  icon!,
                  SpatiallySpacing.gapHorizontalXs,
                ],
                Text(
                  label,
                  style: SpatiallyTypography.button(color: color).copyWith(fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
