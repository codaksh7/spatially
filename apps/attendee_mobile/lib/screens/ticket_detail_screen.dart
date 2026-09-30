import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../design_system/design_system.dart';
import '../main.dart'; // for AdvertiserScreen
import '../services/offline_service.dart';
import '../utils/date_formatter.dart';

/// Spatially Attendee Ticket Detail Screen.
/// 
/// Modernized view displaying the verified admission pass, QR code for scanner entry,
/// and the active BLE presence transition button.
class TicketDetailScreen extends StatelessWidget {
  final Map<String, dynamic> ticket;

  const TicketDetailScreen({super.key, required this.ticket});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = isDark ? SpatiallyColors.darkTextPrimary : SpatiallyColors.lightTextPrimary;
    final textSecondary = isDark ? SpatiallyColors.darkTextSecondary : SpatiallyColors.lightTextSecondary;
    final isOffline = !OfflineService().isOnline;

    final event = ticket['events'] as Map<String, dynamic>?;
    final eventName = event?['name']?.toString() ?? 'Event Admission';
    final venue = event?['venue']?.toString() ?? 'TBA';
    final ticketCode = ticket['ticket_code']?.toString() ?? '';
    final status = (ticket['status']?.toString() ?? 'purchased').toLowerCase();
    final isPurchased = status == 'purchased';
    final isCheckedIn = status == 'checked_in';

    final dateTimeStr = SpatiallyDateFormatter.formatDateTime(
      event?['event_date'],
      includeYear: true,
    );

    // P6: Compute safe-area bottom padding at build time
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final scrollPadding = SpatiallySpacing.screenPadding.copyWith(
      bottom: SpatiallySpacing.screenPadding.bottom +
          bottomInset +
          SpatiallySpacing.xxxl,
    );

    return Scaffold(
      appBar: const SpatiallyAppBar(
        title: 'Ticket Pass',
        automaticallyImplyLeading: true,
      ),
      body: SingleChildScrollView(
        padding: scrollPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isOffline)
              const SpatiallyOfflineBanner(
                message: 'Offline Mode • QR pass ready for gate scanner',
              ),

            // Event Header Summary Card
            SpatiallyCard(
              hasSubtleGlow: isPurchased,
              padding: const EdgeInsets.all(SpatiallySpacing.lg),
              child: Column(
                children: [
                  // Pass Status Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: isCheckedIn
                          ? SpatiallyColors.lightTextSecondary.withValues(alpha: 0.12)
                          : SpatiallyColors.success.withValues(alpha: 0.12),
                      borderRadius: SpatiallyRadius.borderFull,
                      border: Border.all(
                        color: isCheckedIn
                            ? SpatiallyColors.lightTextSecondary.withValues(alpha: 0.3)
                            : SpatiallyColors.success.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      isCheckedIn ? 'CHECKED IN' : 'VALID ADMISSION',
                      style: SpatiallyTypography.badge(
                        color: isCheckedIn ? SpatiallyColors.lightTextSecondary : SpatiallyColors.success,
                      ),
                    ),
                  ),
                  SpatiallySpacing.gapVerticalMd,

                  // Event Name
                  Text(
                    eventName,
                    style: SpatiallyTypography.headingLarge(color: textPrimary),
                    textAlign: TextAlign.center,
                  ),
                  SpatiallySpacing.gapVerticalSm,

                  // Venue
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        size: 16,
                        color: SpatiallyColors.spatialCyan,
                      ),
                      SpatiallySpacing.gapHorizontalXs,
                      Flexible(
                        child: Text(
                          venue,
                          style: SpatiallyTypography.subheading(color: textSecondary),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                  SpatiallySpacing.gapVerticalXs,

                  // Date
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.calendar_today_rounded,
                        size: 14,
                        color: SpatiallyColors.violet,
                      ),
                      SpatiallySpacing.gapHorizontalXs,
                      Text(
                        dateTimeStr,
                        style: SpatiallyTypography.caption(color: textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            SpatiallySpacing.gapVerticalLg,

            // QR Code Presentation Card
            SpatiallyCard(
              padding: const EdgeInsets.all(SpatiallySpacing.xl),
              child: Column(
                children: [
                  Text(
                    isCheckedIn ? 'ACTIVE PASS • ENTRY VERIFIED' : 'SCAN FOR ENTRY',
                    style: SpatiallyTypography.badge(
                      color: isCheckedIn ? SpatiallyColors.success : textSecondary,
                    ),
                  ),
                  SpatiallySpacing.gapVerticalLg,

                  // White QR Container for contrast
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: SpatiallyRadius.borderMd,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: QrImageView(
                      data: ticketCode,
                      version: QrVersions.auto,
                      size: 220.0,
                    ),
                  ),

                  SpatiallySpacing.gapVerticalLg,

                  // Monospaced Ticket Code
                  SelectableText(
                    ticketCode,
                    style: SpatiallyTypography.caption(
                      color: textSecondary,
                    ).copyWith(
                      letterSpacing: 1.2,
                      fontFamily: 'monospace',
                    ),
                    textAlign: TextAlign.center,
                  ),

                  if (isOffline) ...[
                    SpatiallySpacing.gapVerticalMd,
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? SpatiallyColors.darkSurfaceElevated : SpatiallyColors.lightBackground,
                        borderRadius: SpatiallyRadius.borderSm,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, size: 14, color: SpatiallyColors.warning),
                          SpatiallySpacing.gapHorizontalSm,
                          Expanded(
                            child: Text(
                              'Pass is stored locally. Scanner reads code optically at entrance. Cloud re-verification requires connection.',
                              style: SpatiallyTypography.caption(color: textSecondary).copyWith(fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            SpatiallySpacing.gapVerticalXl,

            // BLE Attendance Activation CTA
            if (isPurchased) ...[
              SpatiallyPrimaryButton(
                label: 'Reached at Event (Start Beacon)',
                icon: const Icon(Icons.bluetooth_searching_rounded, color: Colors.white, size: 20),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AdvertiserScreen(autoStart: true),
                    ),
                  );
                },
              ),
              SpatiallySpacing.gapVerticalSm,
              Text(
                'Broadcast your presence to venue scanners & check-in gates.',
                style: SpatiallyTypography.caption(color: textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
