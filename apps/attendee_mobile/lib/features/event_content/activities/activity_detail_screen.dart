import 'package:flutter/material.dart';
import '../../../design_system/design_system.dart';
import '../../../services/attendee_identity.dart';
import '../../../services/offline_service.dart';
import '../../explore/models/spatially_event.dart';
import '../../map/map_screen.dart';
import '../data/event_content_repository.dart';
import '../models/spatially_activity.dart';

/// Detailed view for an event activity, challenge, or quest.
/// 
/// Supports the Phase 7B server-authoritative checkpoint verification flow.
class ActivityDetailScreen extends StatefulWidget {
  final SpatiallyActivity activity;
  final SpatiallyEvent? event;
  final bool isAlreadyCompleted;
  final VoidCallback? onNavigateToMap;
  final EventContentRepository? repository;

  const ActivityDetailScreen({
    super.key,
    required this.activity,
    this.event,
    this.isAlreadyCompleted = false,
    this.onNavigateToMap,
    this.repository,
  });

  @override
  State<ActivityDetailScreen> createState() => _ActivityDetailScreenState();
}

class _ActivityDetailScreenState extends State<ActivityDetailScreen> {
  late final EventContentRepository _repository;
  late bool _isCompleted;
  bool _isSubmitting = false;
  bool _hasChanged = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? EventContentRepositoryImpl();
    _isCompleted = widget.isAlreadyCompleted;
    if (!_isCompleted) {
      _checkCompletion();
    }
  }

  Future<void> _checkCompletion() async {
    final eventId = widget.activity.eventId;
    final attendeeId = AttendeeIdentity.deviceId ?? '';
    if (eventId.isEmpty || attendeeId.isEmpty) return;

    try {
      final completedIds = await _repository.getCompletedActivityIds(eventId, attendeeId);
      if (completedIds.contains(widget.activity.id) && mounted) {
        setState(() {
          _isCompleted = true;
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
            initialZoneId: widget.activity.zoneId,
            initialPoiId: widget.activity.poiId,
          ),
        ),
      );
    }
  }

  Future<void> _showVerificationDialog(BuildContext context) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = isDark ? SpatiallyColors.darkTextPrimary : SpatiallyColors.lightTextPrimary;
    final textSecondary = isDark ? SpatiallyColors.darkTextSecondary : SpatiallyColors.lightTextSecondary;

    if (!OfflineService().isOnline) {
      _showFeedbackSnackBar(
        'Connectivity required to verify checkpoint and award passport points',
        isError: true,
      );
      return;
    }

    final codeController = TextEditingController();
    String? localError;

    await showDialog<void>(
      context: context,
      barrierDismissible: !_isSubmitting,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? SpatiallyColors.darkSurface : SpatiallyColors.lightSurface,
              shape: const RoundedRectangleBorder(borderRadius: SpatiallyRadius.borderMd),
              title: Row(
                children: [
                  const Icon(Icons.qr_code_scanner_rounded, color: SpatiallyColors.violet, size: 24),
                  SpatiallySpacing.gapHorizontalSm,
                  Expanded(
                    child: Text(
                      'Verify Checkpoint',
                      style: SpatiallyTypography.sectionHeading(color: textPrimary),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enter the verification code displayed at the on-site station to verify your presence and claim +${widget.activity.points} points.',
                    style: SpatiallyTypography.body(color: textSecondary),
                  ),
                  SpatiallySpacing.gapVerticalMd,
                  TextField(
                    controller: codeController,
                    autofocus: true,
                    textCapitalization: TextCapitalization.characters,
                    style: SpatiallyTypography.subheading(color: textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Verification Code',
                      hintText: 'e.g. CHECKPOINT',
                      prefixIcon: const Icon(Icons.password_rounded, color: SpatiallyColors.violet),
                      errorText: localError,
                      filled: true,
                      fillColor: isDark ? SpatiallyColors.darkSurfaceElevated : SpatiallyColors.lightBorderSubdued,
                      border: OutlineInputBorder(
                        borderRadius: SpatiallyRadius.borderSm,
                        borderSide: BorderSide(
                          color: isDark ? SpatiallyColors.darkBorderSubdued : SpatiallyColors.lightBorderSubdued,
                        ),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderRadius: SpatiallyRadius.borderSm,
                        borderSide: BorderSide(color: SpatiallyColors.violet, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: _isSubmitting ? null : () => Navigator.of(dialogCtx).pop(),
                  child: const Text('Cancel'),
                ),
                SpatiallyPrimaryButton(
                  label: _isSubmitting ? 'Verifying...' : 'Verify Code',
                  onPressed: _isSubmitting
                      ? null
                      : () async {
                          final code = codeController.text.trim();
                          if (code.isEmpty) {
                            setDialogState(() {
                              localError = 'Please enter a checkpoint code';
                            });
                            return;
                          }

                          setDialogState(() {
                            _isSubmitting = true;
                            localError = null;
                          });

                          final eventId = widget.activity.eventId;
                          final attendeeId = AttendeeIdentity.deviceId ?? '';

                          final result = await _repository.verifyActivity(
                            eventId: eventId,
                            attendeeId: attendeeId,
                            activityId: widget.activity.id,
                            verificationCode: code,
                          );

                          if (!mounted || !dialogCtx.mounted) return;

                          setDialogState(() {
                            _isSubmitting = false;
                          });

                          if (result['success'] == true) {
                            Navigator.of(dialogCtx).pop();
                            setState(() {
                              _isCompleted = true;
                              _hasChanged = true;
                            });

                            if (result['already_completed'] == true) {
                              _showFeedbackSnackBar(
                                'Activity already verified! Total Points: ${result['total_points'] ?? ''}',
                                isError: false,
                              );
                            } else {
                              _showFeedbackSnackBar(
                                '🎉 Checkpoint verified! +${result['points_awarded']} PTS claimed!',
                                isError: false,
                              );
                            }
                          } else {
                            final err = result['error']?.toString();
                            final msg = result['message']?.toString() ?? 'Verification failed';
                            setDialogState(() {
                              if (err == 'NOT_CHECKED_IN') {
                                localError = 'Check-in required before completing activities';
                              } else if (err == 'OFFLINE') {
                                localError = 'Connectivity required to verify checkpoint';
                              } else {
                                localError = msg;
                              }
                            });
                          }
                        },
                ),
              ],
            );
          },
        );
      },
    );
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
          // Handled via Navigator.pop(context, _hasChanged) if triggered manually
        }
      },
      child: Scaffold(
        appBar: SpatiallyAppBar(
          title: 'Activity Details',
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
              // Hero Activity Card
              SpatiallyCard(
                padding: const EdgeInsets.all(SpatiallySpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Type & Points
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: SpatiallyColors.warning.withValues(alpha: 0.14),
                            borderRadius: SpatiallyRadius.borderSm,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(widget.activity.typeIcon, size: 14, color: SpatiallyColors.warning),
                              SpatiallySpacing.gapHorizontalXs,
                              Text(
                                widget.activity.typeDisplayName.toUpperCase(),
                                style: SpatiallyTypography.badge(color: SpatiallyColors.warning),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: _isCompleted
                                ? SpatiallyColors.success.withValues(alpha: 0.16)
                                : SpatiallyColors.violet.withValues(alpha: 0.14),
                            borderRadius: SpatiallyRadius.borderFull,
                            border: Border.all(
                              color: _isCompleted
                                  ? SpatiallyColors.success.withValues(alpha: 0.4)
                                  : SpatiallyColors.violet.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_isCompleted) ...[
                                const Icon(Icons.check_circle_rounded, size: 13, color: SpatiallyColors.success),
                                SpatiallySpacing.gapHorizontalXxs,
                              ],
                              Text(
                                _isCompleted
                                    ? 'COMPLETED +${widget.activity.points} PTS'
                                    : '+${widget.activity.points} PTS',
                                style: SpatiallyTypography.badge(
                                  color: _isCompleted ? SpatiallyColors.success : SpatiallyColors.violet,
                                ).copyWith(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    SpatiallySpacing.gapVerticalMd,

                    // Title
                    Text(
                      widget.activity.title,
                      style: SpatiallyTypography.headingLarge(color: textPrimary),
                    ),

                    SpatiallySpacing.gapVerticalLg,

                    // Location
                    _buildDetailRow(
                      icon: Icons.location_on_rounded,
                      iconColor: SpatiallyColors.spatialCyan,
                      title: 'Location',
                      content: widget.activity.locationName,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                    ),

                    SpatiallySpacing.gapVerticalMd,

                    // Verification Method
                    _buildDetailRow(
                      icon: widget.activity.verificationIcon,
                      iconColor: SpatiallyColors.violet,
                      title: 'Verification Requirement',
                      content: widget.activity.verificationDisplayName,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                    ),
                  ],
                ),
              ),

              SpatiallySpacing.gapVerticalLg,

              // Reward Card (if applicable)
              if (widget.activity.reward != null) ...[
                const SpatiallySectionHeader(title: 'Activity Reward'),
                SpatiallySpacing.gapVerticalSm,
                SpatiallyCard(
                  padding: const EdgeInsets.all(SpatiallySpacing.md),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: SpatiallyColors.warning.withValues(alpha: 0.14),
                          borderRadius: SpatiallyRadius.borderSm,
                        ),
                        child: const Icon(Icons.military_tech_rounded, color: SpatiallyColors.warning, size: 26),
                      ),
                      SpatiallySpacing.gapHorizontalMd,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.activity.reward!,
                              style: SpatiallyTypography.subheading(color: textPrimary),
                            ),
                            Text(
                              'Earns ${widget.activity.points} points for your event passport',
                              style: SpatiallyTypography.caption(color: textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SpatiallySpacing.gapVerticalLg,
              ],

              // How it Works / Instructions
              const SpatiallySectionHeader(title: 'How It Works'),
              SpatiallySpacing.gapVerticalSm,
              SpatiallyCard(
                padding: const EdgeInsets.all(SpatiallySpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.activity.instructions,
                      style: SpatiallyTypography.body(color: textPrimary),
                    ),
                    SpatiallySpacing.gapVerticalMd,
                    const Divider(height: 1),
                    SpatiallySpacing.gapVerticalSm,
                    Text(
                      widget.activity.description,
                      style: SpatiallyTypography.secondary(color: textSecondary),
                    ),
                  ],
                ),
              ),

              SpatiallySpacing.gapVerticalLg,

              // Verification Actions
              const SpatiallySectionHeader(title: 'Actions'),
              SpatiallySpacing.gapVerticalSm,
              SpatiallyCard(
                padding: const EdgeInsets.all(SpatiallySpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_isCompleted) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: SpatiallyColors.success.withValues(alpha: 0.12),
                          borderRadius: SpatiallyRadius.borderSm,
                          border: Border.all(color: SpatiallyColors.success.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.verified_rounded, color: SpatiallyColors.success, size: 20),
                            SpatiallySpacing.gapHorizontalSm,
                            Expanded(
                              child: Text(
                                'Checkpoint Verified • +${widget.activity.points} PTS Awarded in Passport',
                                style: SpatiallyTypography.caption(color: SpatiallyColors.success)
                                    .copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      SpatiallyPrimaryButton(
                        label: 'Verify Checkpoint Code',
                        icon: Icon(widget.activity.verificationIcon, color: Colors.white, size: 18),
                        onPressed: () => _showVerificationDialog(context),
                      ),
                    ],
                    SpatiallySpacing.gapVerticalSm,
                    SpatiallySoftButton(
                      label: 'View Location on Venue Map',
                      icon: const Icon(Icons.near_me_rounded, color: SpatiallyColors.violet, size: 18),
                      onPressed: () => _openMap(context),
                      fullWidth: true,
                    ),
                  ],
                ),
              ),

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
