import 'package:flutter/material.dart';
import '../spatially_colors.dart';
import '../spatially_typography.dart';
import '../spatially_spacing.dart';
import '../spatially_radius.dart';

/// Centralized Spatially AppBar Component based on SPATIALLY_DESIGN.md.
/// 
/// Preserves the established Spatially wordmark identity while providing
/// flexible leading/trailing action integration and consistent surface styling.
class SpatiallyAppBar extends StatelessWidget implements PreferredSizeWidget {
  /// Custom title text. If null and [titleWidget] is null, renders the default
  /// branded "Spatially for Attendee" title.
  final String? title;

  /// Custom title widget if complete override is desired.
  final Widget? titleWidget;

  /// Secondary subtitle text for the branded lockup (e.g. "for Attendee").
  /// Defaults to "for Attendee".
  final String brandedSubtitle;

  /// Leading widget (e.g. back button, menu icon).
  final Widget? leading;

  /// Trailing actions list.
  final List<Widget>? actions;

  /// Whether to automatically show a back button if the route can pop.
  final bool automaticallyImplyLeading;

  /// Whether the title should be centered.
  final bool centerTitle;

  /// Optional bottom widget (e.g. TabBar, progress indicator).
  final PreferredSizeWidget? bottom;

  /// Optional custom background color. Defaults to transparent.
  final Color? backgroundColor;

  /// Height of the app bar. Defaults to [kToolbarHeight].
  final double toolbarHeight;

  const SpatiallyAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.brandedSubtitle = 'for Attendee',
    this.leading,
    this.actions,
    this.automaticallyImplyLeading = true,
    this.centerTitle = false,
    this.bottom,
    this.backgroundColor,
    this.toolbarHeight = kToolbarHeight,
  });

  @override
  Size get preferredSize => Size.fromHeight(
        toolbarHeight + (bottom?.preferredSize.height ?? 0.0),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = isDark ? SpatiallyColors.darkTextPrimary : SpatiallyColors.lightTextPrimary;

    Widget? effectiveTitle;
    if (titleWidget != null) {
      effectiveTitle = titleWidget;
    } else if (title != null) {
      effectiveTitle = Text(
        title!,
        style: SpatiallyTypography.sectionHeading(color: textPrimary),
      );
    } else {
      // Default branded title lockup: "Spatially" + subtitle
      effectiveTitle = Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: 'Spatially ',
              style: SpatiallyTypography.brandTitle(fontSize: 18, color: textPrimary),
            ),
            TextSpan(
              text: brandedSubtitle,
              style: SpatiallyTypography.brandSubtitle(fontSize: 14, color: textPrimary),
            ),
          ],
        ),
      );
    }

    Widget? effectiveLeading = leading;
    if (effectiveLeading == null && automaticallyImplyLeading && Navigator.of(context).canPop()) {
      effectiveLeading = Padding(
        padding: const EdgeInsets.only(left: SpatiallySpacing.xs),
        child: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          color: textPrimary,
          tooltip: 'Back',
          style: IconButton.styleFrom(
            shape: const RoundedRectangleBorder(
              borderRadius: SpatiallyRadius.borderSm,
            ),
          ),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      );
    }

    return AppBar(
      title: effectiveTitle,
      leading: effectiveLeading,
      actions: actions,
      automaticallyImplyLeading: false, // We control leading explicitly above
      centerTitle: centerTitle,
      bottom: bottom,
      backgroundColor: backgroundColor ?? Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: toolbarHeight,
    );
  }
}
