import 'package:flutter/material.dart';
import '../../../design_system/design_system.dart';
import '../../../services/attendee_identity.dart';
import '../../../services/offline_service.dart';
import '../../explore/models/spatially_event.dart';
import '../../map/map_screen.dart';
import '../data/event_content_repository.dart';
import '../models/spatially_session.dart';

/// Comprehensive Session Detail screen communicating speaker, schedule, location,
/// and recording verified session attendance in the Spatially Passport.
class SessionDetailScreen extends StatefulWidget {
  final SpatiallySession session;
  final SpatiallyEvent? event;
  final VoidCallback? onNavigateToMap;
  final EventContentRepository? repository;

  const SessionDetailScreen({
    super.key,
    required this.session,
    this.event,
    this.onNavigateToMap,
    this.repository,
  });

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  late final EventContentRepository _repository;
  bool _isAttended = false;
  bool _isSubmitting = false;
  bool _hasChanged = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? EventContentRepositoryImpl();
    _checkAttendedStatus();
  }

  Future<void> _checkAttendedStatus() async {
    final eventId = widget.session.eventId;
    final attendeeId = AttendeeIdentity.deviceId ?? '';
    if (eventId.isEmpty || attendeeId.isEmpty) return;

    try {
      final attendedIds = await _repository.getAttendedSessionIds(eventId, attendeeId);
      if (attendedIds.contains(widget.session.id) && mounted) {
        setState(() {
          _isAttended = true;
        });
      }
    } catch (_) {}
  }

  void _openMap(BuildContext context) {
    if (widget.onNavigateToMap != null) {
      widget.onNavigateToMap!();
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MapScreen(
            initialEvent: widget.event,
            initialZoneId: widget.session.zoneId,
            initialPoiId: widget.session.poiId,
          ),
        ),
      );
    }
  }

  Future<void> _handleRecordAttendance(BuildContext context) async {
    if (_isAttended || _isSubmitting) return;

    if (!OfflineService().isOnline) {
      _showFeedbackSnackBar(
        'Connectivity required to record session attendance in passport',
        isError: true,
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final eventId = widget.session.eventId;
    final attendeeId = AttendeeIdentity.deviceId ?? '';

    final result = await _repository.recordSessionAttendance(
      eventId: eventId,
      attendeeId: attendeeId,
      sessionId: widget.session.id,
    );

    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
    });

    if (result['success'] == true) {
      setState(() {
        _isAttended = true;
        _hasChanged = true;
      });

      if (result['already_attended'] == true) {
        _showFeedbackSnackBar('Session attendance was already recorded in your passport.');
      } else {
        _showFeedbackSnackBar('🎙️ Session attendance recorded in your Event Passport!');
      }
    } else {
      final err = result['error']?.toString();
      final msg = result['message']?.toString() ?? 'Failed to record attendance';
      if (err == 'NOT_CHECKED_IN') {
        _showFeedbackSnackBar('Check-in required before recording attendance', isError: true);
      } else if (err == 'OFFLINE') {
        _showFeedbackSnackBar('Connectivity required to record session attendance in passport', isError: true);
      } else {
        _showFeedbackSnackBar(msg, isError: true);
      }
    }
  }

  void _showFeedbackSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
              color: Colors.white,
              size: 20,
            ),
            SpatiallySpacing.gapHorizontalSm,
            Expanded(
              child: Text(
                message,
                style: SpatiallyTypography.caption(color: Colors.white)
                    .copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? SpatiallyColors.error : SpatiallyColors.success,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = isDark ? SpatiallyColors.darkTextPrimary : SpatiallyColors.lightTextPrimary;
    final textSecondary = isDark ? SpatiallyColors.darkTextSecondary : SpatiallyColors.lightTextSecondary;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && _hasChanged) {
          // Handled via Navigator.pop(context, _hasChanged)
        }
      },
      child: Scaffold(
        appBar: SpatiallyAppBar(
          title: 'Session Details',
          automaticallyImplyLeading: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).pop(_hasChanged),
          ),
        ),
        body: SafeArea(
          bottom: true,
          child: SingleChildScrollView(
            padding: SpatiallySpacing.screenPadding.copyWith(
              bottom: SpatiallySpacing.screenPadding.bottom + SpatiallySpacing.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              // Hero Session Card
              SpatiallyCard(
                hasSubtleGlow: widget.session.isLive,
                padding: const EdgeInsets.all(SpatiallySpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badge Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: SpatiallyColors.violet.withValues(alpha: 0.12),
                            borderRadius: SpatiallyRadius.borderSm,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(widget.session.categoryIcon, size: 14, color: SpatiallyColors.violet),
                              SpatiallySpacing.gapHorizontalXs,
                              Text(
                                widget.session.categoryDisplayName.toUpperCase(),
                                style: SpatiallyTypography.badge(color: SpatiallyColors.violet),
                              ),
                            ],
                          ),
                        ),
                        if (widget.session.isLive)
                          const SpatiallyStatusBadge(
                            label: 'LIVE NOW',
                            variant: SpatiallyBadgeVariant.live,
                          )
                        else if (widget.session.isUpcoming)
                          const SpatiallyStatusBadge(
                            label: 'UPCOMING',
                            variant: SpatiallyBadgeVariant.upcoming,
                          )
                        else
                          SpatiallyStatusBadge(
                            label: 'COMPLETED',
                            variant: SpatiallyBadgeVariant.custom,
                            customColor: textSecondary,
                            showDot: false,
                          ),
                      ],
                    ),

                    SpatiallySpacing.gapVerticalMd,

                    // Title
                    Text(
                      widget.session.title,
                      style: SpatiallyTypography.headingLarge(color: textPrimary),
                    ),

                    SpatiallySpacing.gapVerticalLg,

                    // Date & Time
                    _buildDetailRow(
                      icon: Icons.calendar_today_rounded,
                      iconColor: SpatiallyColors.violet,
                      title: 'Schedule & Time',
                      content: widget.session.formattedTimeRange,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                    ),

                    SpatiallySpacing.gapVerticalMd,

                    // Venue & Room
                    _buildDetailRow(
                      icon: Icons.location_on_rounded,
                      iconColor: SpatiallyColors.spatialCyan,
                      title: 'Location',
                      content: widget.session.roomName,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                    ),
                  ],
                ),
              ),

              SpatiallySpacing.gapVerticalLg,

              // Speaker Card
              const SpatiallySectionHeader(title: 'Featured Speaker'),
              SpatiallySpacing.gapVerticalSm,
              SpatiallyCard(
                padding: const EdgeInsets.all(SpatiallySpacing.md),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: SpatiallyColors.violet.withValues(alpha: 0.15),
                      child: Text(
                        widget.session.speaker.isNotEmpty ? widget.session.speaker[0] : 'S',
                        style: SpatiallyTypography.sectionHeading(color: SpatiallyColors.violet),
                      ),
                    ),
                    SpatiallySpacing.gapHorizontalMd,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.session.speaker,
                            style: SpatiallyTypography.subheading(color: textPrimary),
                          ),
                          if (widget.session.speakerRole != null || widget.session.speakerCompany != null) ...[
                            SpatiallySpacing.gapVerticalXxs,
                            Text(
                              [
                                if (widget.session.speakerRole != null) widget.session.speakerRole!,
                                if (widget.session.speakerCompany != null) widget.session.speakerCompany!,
                              ].join(' • '),
                              style: SpatiallyTypography.secondary(color: textSecondary),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              SpatiallySpacing.gapVerticalLg,

              // Actions Card
              const SpatiallySectionHeader(title: 'Actions'),
              SpatiallySpacing.gapVerticalSm,
              SpatiallyCard(
                padding: const EdgeInsets.all(SpatiallySpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_isAttended) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: SpatiallyColors.success.withValues(alpha: 0.12),
                          borderRadius: SpatiallyRadius.borderSm,
                          border: Border.all(color: SpatiallyColors.success.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: SpatiallyColors.success, size: 20),
                            SpatiallySpacing.gapHorizontalSm,
                            Expanded(
                              child: Text(
                                'Attendance Recorded • Logged in Event Passport',
                                style: SpatiallyTypography.caption(color: SpatiallyColors.success)
                                    .copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      SpatiallyPrimaryButton(
                        label: _isSubmitting ? 'Recording Attendance...' : 'Record Attendance',
                        icon: const Icon(Icons.how_to_reg_rounded, color: Colors.white, size: 18),
                        onPressed: _isSubmitting ? null : () => _handleRecordAttendance(context),
                      ),
                    ],
                    SpatiallySpacing.gapVerticalSm,
                    SpatiallySoftButton(
                      label: 'View Room on Venue Map',
                      icon: const Icon(Icons.near_me_rounded, color: SpatiallyColors.violet, size: 18),
                      onPressed: () => _openMap(context),
                      fullWidth: true,
                    ),
                  ],
                ),
              ),

              SpatiallySpacing.gapVerticalLg,

              // Description Card
              const SpatiallySectionHeader(title: 'About the Session'),
              SpatiallySpacing.gapVerticalSm,
              SpatiallyCard(
                padding: const EdgeInsets.all(SpatiallySpacing.md),
                child: Text(
                  widget.session.description,
                  style: SpatiallyTypography.body(color: textPrimary),
                ),
              ),

              if (widget.session.tags.isNotEmpty) ...[
                SpatiallySpacing.gapVerticalLg,
                const SpatiallySectionHeader(title: 'Topics & Tags'),
                SpatiallySpacing.gapVerticalSm,
                Wrap(
                  spacing: SpatiallySpacing.xs,
                  runSpacing: SpatiallySpacing.xs,
                  children: widget.session.tags.map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isDark ? SpatiallyColors.darkSurfaceElevated : SpatiallyColors.lightBorderSubdued,
                        borderRadius: SpatiallyRadius.borderSm,
                      ),
                      child: Text(
                        '#$tag',
                        style: SpatiallyTypography.caption(color: textSecondary),
                      ),
                    );
                  }).toList(),
                ),
              ],

              SpatiallySpacing.gapVerticalXl,
            ],
          ),
        ),
      ),
    ),
  );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String content,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 20),
        SpatiallySpacing.gapHorizontalMd,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: SpatiallyTypography.caption(color: textSecondary),
              ),
              SpatiallySpacing.gapVerticalXs,
              Text(
                content,
                style: SpatiallyTypography.subheading(color: textPrimary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
