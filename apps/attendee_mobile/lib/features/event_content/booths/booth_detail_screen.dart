import 'package:flutter/material.dart';
import '../../../design_system/design_system.dart';
import '../../../services/attendee_identity.dart';
import '../../../services/offline_service.dart';
import '../../explore/models/spatially_event.dart';
import '../../map/map_screen.dart';
import '../data/event_content_repository.dart';
import '../models/spatially_booth.dart';

/// Detailed view for an exhibitor or project booth.
/// 
/// Allows attendees to view showcase details and record booth visits in their Passport.
class BoothDetailScreen extends StatefulWidget {
  final SpatiallyBooth booth;
  final SpatiallyEvent? event;
  final VoidCallback? onNavigateToMap;
  final EventContentRepository? repository;

  const BoothDetailScreen({
    super.key,
    required this.booth,
    this.event,
    this.onNavigateToMap,
    this.repository,
  });

  @override
  State<BoothDetailScreen> createState() => _BoothDetailScreenState();
}

class _BoothDetailScreenState extends State<BoothDetailScreen> {
  late final EventContentRepository _repository;
  bool _isVisited = false;
  bool _isSubmitting = false;
  bool _hasChanged = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? EventContentRepositoryImpl();
    _checkVisitedStatus();
  }

  Future<void> _checkVisitedStatus() async {
    final eventId = widget.booth.eventId;
    final attendeeId = AttendeeIdentity.deviceId ?? '';
    if (eventId.isEmpty || attendeeId.isEmpty) return;

    try {
      final visitedIds = await _repository.getVisitedBoothIds(eventId, attendeeId);
      if (visitedIds.contains(widget.booth.id) && mounted) {
        setState(() {
          _isVisited = true;
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
            initialZoneId: widget.booth.zoneId,
            initialPoiId: widget.booth.poiId,
          ),
        ),
      );
    }
  }

  Future<void> _handleMarkVisited(BuildContext context) async {
    if (_isVisited || _isSubmitting) return;

    if (!OfflineService().isOnline) {
      _showFeedbackSnackBar(
        'Connectivity required to log booth visit in passport',
        isError: true,
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final eventId = widget.booth.eventId;
    final attendeeId = AttendeeIdentity.deviceId ?? '';

    final result = await _repository.recordBoothVisit(
      eventId: eventId,
      attendeeId: attendeeId,
      boothId: widget.booth.id,
    );

    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
    });

    if (result['success'] == true) {
      setState(() {
        _isVisited = true;
        _hasChanged = true;
      });

      if (result['already_visited'] == true) {
        _showFeedbackSnackBar('Booth visit was already recorded in your passport.');
      } else {
        _showFeedbackSnackBar('✨ Showcase logged in your Event Passport!');
      }
    } else {
      final err = result['error']?.toString();
      final msg = result['message']?.toString() ?? 'Failed to log booth visit';
      if (err == 'NOT_CHECKED_IN') {
        _showFeedbackSnackBar('Check-in required before logging booth visits', isError: true);
      } else if (err == 'OFFLINE') {
        _showFeedbackSnackBar('Connectivity required to log booth visit in passport', isError: true);
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
          title: 'Booth Details',
          automaticallyImplyLeading: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).pop(_hasChanged),
          ),
        ),
        body: SingleChildScrollView(
          padding: SpatiallySpacing.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hero Booth Card
              SpatiallyCard(
                padding: const EdgeInsets.all(SpatiallySpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Booth Tag & Category
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: SpatiallyColors.spatialCyan.withValues(alpha: 0.14),
                            borderRadius: SpatiallyRadius.borderSm,
                          ),
                          child: Text(
                            widget.booth.boothNumber.toUpperCase(),
                            style: SpatiallyTypography.badge(color: SpatiallyColors.spatialCyan)
                                .copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: widget.booth.isOpen
                                ? SpatiallyColors.success.withValues(alpha: 0.12)
                                : textSecondary.withValues(alpha: 0.12),
                            borderRadius: SpatiallyRadius.borderFull,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: widget.booth.isOpen ? SpatiallyColors.success : textSecondary,
                                ),
                              ),
                              SpatiallySpacing.gapHorizontalXs,
                              Text(
                                widget.booth.isOpen ? 'EXHIBITING NOW' : 'CLOSED',
                                style: SpatiallyTypography.badge(
                                  color: widget.booth.isOpen ? SpatiallyColors.success : textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    SpatiallySpacing.gapVerticalMd,

                    // Booth Title
                    Text(
                      widget.booth.name,
                      style: SpatiallyTypography.headingLarge(color: textPrimary),
                    ),
                    SpatiallySpacing.gapVerticalXxs,
                    Text(
                      widget.booth.companyOrOrg,
                      style: SpatiallyTypography.subheading(color: SpatiallyColors.violet),
                    ),

                    SpatiallySpacing.gapVerticalLg,

                    // Location
                    _buildDetailRow(
                      icon: Icons.location_on_rounded,
                      iconColor: SpatiallyColors.spatialCyan,
                      title: 'Hall & Location',
                      content: widget.booth.roomName,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                    ),

                    SpatiallySpacing.gapVerticalMd,

                    // Category
                    _buildDetailRow(
                      icon: widget.booth.categoryIcon,
                      iconColor: SpatiallyColors.violet,
                      title: 'Category',
                      content: widget.booth.categoryDisplayName,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                    ),
                  ],
                ),
              ),

              SpatiallySpacing.gapVerticalLg,

              // Live Demo Highlight (if available)
              if (widget.booth.highlightDemo != null) ...[
                const SpatiallySectionHeader(title: 'Live Demonstration'),
                SpatiallySpacing.gapVerticalSm,
                SpatiallyCard(
                  padding: const EdgeInsets.all(SpatiallySpacing.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: SpatiallyColors.violet.withValues(alpha: 0.12),
                          borderRadius: SpatiallyRadius.borderSm,
                        ),
                        child: const Icon(Icons.stars_rounded, color: SpatiallyColors.violet, size: 22),
                      ),
                      SpatiallySpacing.gapHorizontalMd,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Featured Showcase',
                              style: SpatiallyTypography.caption(color: SpatiallyColors.violet)
                                  .copyWith(fontWeight: FontWeight.bold),
                            ),
                            SpatiallySpacing.gapVerticalXxs,
                            Text(
                              widget.booth.highlightDemo!,
                              style: SpatiallyTypography.body(color: textPrimary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SpatiallySpacing.gapVerticalLg,
              ],

              // Actions Card
              const SpatiallySectionHeader(title: 'Actions'),
              SpatiallySpacing.gapVerticalSm,
              SpatiallyCard(
                padding: const EdgeInsets.all(SpatiallySpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_isVisited) ...[
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
                                'Booth Visited • Recorded in Event Passport',
                                style: SpatiallyTypography.caption(color: SpatiallyColors.success)
                                    .copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      SpatiallyPrimaryButton(
                        label: _isSubmitting ? 'Recording Visit...' : 'Mark Visited',
                        icon: const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 18),
                        onPressed: _isSubmitting ? null : () => _handleMarkVisited(context),
                      ),
                    ],
                    SpatiallySpacing.gapVerticalSm,
                    SpatiallySoftButton(
                      label: 'Locate Booth on Map',
                      icon: const Icon(Icons.near_me_rounded, color: SpatiallyColors.violet, size: 18),
                      onPressed: () => _openMap(context),
                      fullWidth: true,
                    ),
                  ],
                ),
              ),

              SpatiallySpacing.gapVerticalLg,

              // About Description
              const SpatiallySectionHeader(title: 'About Exhibitor'),
              SpatiallySpacing.gapVerticalSm,
              SpatiallyCard(
                padding: const EdgeInsets.all(SpatiallySpacing.md),
                child: Text(
                  widget.booth.description,
                  style: SpatiallyTypography.body(color: textPrimary),
                ),
              ),

              if (widget.booth.tags.isNotEmpty) ...[
                SpatiallySpacing.gapVerticalLg,
                const SpatiallySectionHeader(title: 'Focus Areas'),
                SpatiallySpacing.gapVerticalSm,
                Wrap(
                  spacing: SpatiallySpacing.xs,
                  runSpacing: SpatiallySpacing.xs,
                  children: widget.booth.tags.map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isDark ? SpatiallyColors.darkSurfaceElevated : SpatiallyColors.lightBorderSubdued,
                        borderRadius: SpatiallyRadius.borderSm,
                      ),
                      child: Text(
                        tag,
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
