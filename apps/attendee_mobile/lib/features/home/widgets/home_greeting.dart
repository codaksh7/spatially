import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../design_system/design_system.dart';

/// Inline greeting header — replaces the traditional AppBar on Home.
///
/// Features:
/// - Brand wordmark: Spatially in Audiowide + for Attendee in Poppins.
/// - Dynamic time-of-day greeting (Good morning / afternoon / evening).
/// - Current date badge.
/// - Ambient ticket quick-action button with active presence dot when tickets are held.
class HomeGreeting extends StatelessWidget {
  final VoidCallback? onTicketsTap;
  final bool hasTickets;
  final VoidCallback? onNotificationsTap;
  final int unreadNotificationsCount;

  const HomeGreeting({
    super.key,
    this.onTicketsTap,
    this.hasTickets = false,
    this.onNotificationsTap,
    this.unreadNotificationsCount = 0,
  });

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Good morning';
    if (hour >= 12 && hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _todayLabel() {
    final now = DateTime.now();
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final weekday = weekdays[now.weekday - 1];
    final month = months[now.month - 1];
    return '$weekday, $month ${now.day}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary =
        isDark ? SpatiallyColors.darkTextPrimary : SpatiallyColors.lightTextPrimary;
    final textSecondary =
        isDark ? SpatiallyColors.darkTextSecondary : SpatiallyColors.lightTextSecondary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Spatially wordmark — subtle, distinctive brand presence
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Spatially ',
                      style: GoogleFonts.audiowide(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: SpatiallyColors.violet,
                        letterSpacing: 0.1,
                      ),
                    ),
                    TextSpan(
                      text: 'for Attendee',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w300,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _greeting(),
                style: GoogleFonts.inter(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                  letterSpacing: -0.5,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _todayLabel(),
                style: SpatiallyTypography.secondary(color: textSecondary),
              ),
            ],
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onNotificationsTap != null) ...[
              Semantics(
                label: 'Notifications ($unreadNotificationsCount unread)',
                button: true,
                child: GestureDetector(
                  onTap: onNotificationsTap,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isDark
                              ? SpatiallyColors.darkSurface
                              : SpatiallyColors.lightSurface,
                          borderRadius: SpatiallyRadius.borderSm,
                          border: Border.all(
                            color: isDark
                                ? SpatiallyColors.darkBorderSubdued
                                : SpatiallyColors.lightBorderSubdued,
                          ),
                          boxShadow: SpatiallyShadows.cardShadow(isDark: isDark),
                        ),
                        child: Icon(
                          unreadNotificationsCount > 0
                              ? Icons.notifications_active_outlined
                              : Icons.notifications_none_rounded,
                          size: 20,
                          color: textPrimary,
                        ),
                      ),
                      if (unreadNotificationsCount > 0)
                        Positioned(
                          top: -3,
                          right: -3,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                            decoration: BoxDecoration(
                              color: SpatiallyColors.violet,
                              borderRadius: BorderRadius.circular(SpatiallyRadius.full),
                              border: Border.all(
                                color: isDark
                                    ? SpatiallyColors.darkBackground
                                    : SpatiallyColors.lightBackground,
                                width: 1.5,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                unreadNotificationsCount > 9 ? '9+' : '$unreadNotificationsCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  height: 1.0,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            if (onTicketsTap != null)
              Semantics(
                label: 'My Tickets',
                button: true,
                child: GestureDetector(
                  onTap: onTicketsTap,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isDark
                              ? SpatiallyColors.darkSurface
                              : SpatiallyColors.lightSurface,
                          borderRadius: SpatiallyRadius.borderSm,
                          border: Border.all(
                            color: isDark
                                ? SpatiallyColors.darkBorderSubdued
                                : SpatiallyColors.lightBorderSubdued,
                          ),
                          boxShadow: SpatiallyShadows.cardShadow(isDark: isDark),
                        ),
                        child: Icon(
                          Icons.confirmation_number_outlined,
                          size: 20,
                          color: textPrimary,
                        ),
                      ),
                      if (hasTickets)
                        Positioned(
                          top: -2,
                          right: -2,
                          child: Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              color: SpatiallyColors.violet,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark
                                    ? SpatiallyColors.darkBackground
                                    : SpatiallyColors.lightBackground,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
