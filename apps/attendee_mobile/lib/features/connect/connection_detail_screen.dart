import 'dart:async';
import 'package:flutter/material.dart';
import '../../design_system/design_system.dart';
import '../../services/auth_service.dart';
import '../../services/offline_service.dart';
import 'models/connect_models.dart';
import 'data/connect_repository.dart';
import 'temporary_chat_screen.dart';

/// Detailed view of a discoverable attendee showing interest overlap and mutual opt-in status.
///
/// Strictly isolates social identity from device and BLE crowd telemetry.
class ConnectionDetailScreen extends StatefulWidget {
  final ConnectProfile profile;
  final String eventId;
  final ConnectRepository repository;

  const ConnectionDetailScreen({
    super.key,
    required this.profile,
    required this.eventId,
    required this.repository,
  });

  @override
  State<ConnectionDetailScreen> createState() => _ConnectionDetailScreenState();
}

class _ConnectionDetailScreenState extends State<ConnectionDetailScreen> {
  Connection? _connection;
  List<String> _sharedInterests = [];
  bool _isLoading = true;
  StreamSubscription<void>? _updatesSub;

  @override
  void initState() {
    super.initState();
    _loadData();
    _updatesSub = widget.repository.updatesStream.listen((_) {
      if (mounted) _loadData();
    });
  }

  @override
  void dispose() {
    _updatesSub?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    final conn = await widget.repository.getConnectionForPeer(
      widget.eventId,
      widget.profile.id,
    );
    final shared = await widget.repository.getSharedInterests(widget.profile.interests);

    if (!mounted) return;
    setState(() {
      _connection = conn;
      _sharedInterests = shared;
      _isLoading = false;
    });
  }

  Future<void> _sendRequest() async {
    if (!AuthService().isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in with Google to send connection requests.'),
          backgroundColor: SpatiallyColors.violet,
        ),
      );
      return;
    }

    if (!OfflineService().isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot send requests while offline.'),
          backgroundColor: SpatiallyColors.warning,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final conn = await widget.repository.sendConnectionRequest(
        widget.eventId,
        widget.profile.id,
      );
      if (!mounted) return;
      setState(() {
        _connection = conn;
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connection request sent to ${widget.profile.displayName}'),
          backgroundColor: SpatiallyColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception:', '').replaceAll('StateError:', '').trim()),
          backgroundColor: SpatiallyColors.error,
        ),
      );
    }
  }

  Future<void> _simulateAcceptance() async {
    if (_connection == null) return;
    setState(() => _isLoading = true);
    try {
      final conn = await widget.repository.simulatePeerAcceptance(_connection!.id);
      if (!mounted) return;
      setState(() {
        _connection = conn;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _acceptRequest() async {
    if (_connection == null) return;
    setState(() => _isLoading = true);
    try {
      final conn = await widget.repository.acceptConnectionRequest(_connection!.id);
      if (!mounted) return;
      setState(() {
        _connection = conn;
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connection accepted! Ephemeral chat is now open.'),
          backgroundColor: SpatiallyColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception:', '').replaceAll('StateError:', '').trim()),
          backgroundColor: SpatiallyColors.error,
        ),
      );
    }
  }

  Future<void> _declineRequest() async {
    if (_connection == null) return;
    setState(() => _isLoading = true);
    try {
      await widget.repository.declineConnectionRequest(_connection!.id);
      if (!mounted) return;
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _openChat() {
    if (_connection == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TemporaryChatScreen(
          connection: _connection!,
          repository: widget.repository,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isDark ? SpatiallyColors.darkSurface : SpatiallyColors.lightSurface;
    final textPrimary = isDark ? SpatiallyColors.darkTextPrimary : SpatiallyColors.lightTextPrimary;
    final textSecondary = isDark ? SpatiallyColors.darkTextSecondary : SpatiallyColors.lightTextSecondary;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: surfaceColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Attendee Details',
          style: SpatiallyTypography.subheading(color: textPrimary),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(SpatiallySpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hero identity card
                  SpatiallyCard(
                    padding: const EdgeInsets.all(SpatiallySpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: SpatiallyColors.violet.withValues(alpha: 0.15),
                          child: Text(
                            widget.profile.avatarInitials,
                            style: SpatiallyTypography.headingLarge(color: SpatiallyColors.violet).copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        SpatiallySpacing.gapVerticalSm,
                        Text(
                          widget.profile.displayName,
                          style: SpatiallyTypography.sectionHeading(color: textPrimary),
                          textAlign: TextAlign.center,
                        ),
                        if (widget.profile.headline.isNotEmpty) ...[
                          SpatiallySpacing.gapVerticalXxs,
                          Text(
                            widget.profile.headline,
                            style: SpatiallyTypography.body(color: SpatiallyColors.violet).copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        if (widget.profile.organization.isNotEmpty) ...[
                          SpatiallySpacing.gapVerticalXxs,
                          Text(
                            widget.profile.organization,
                            style: SpatiallyTypography.caption(color: textSecondary),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        SpatiallySpacing.gapVerticalMd,
                        Wrap(
                          spacing: SpatiallySpacing.xs,
                          runSpacing: SpatiallySpacing.xs,
                          alignment: WrapAlignment.center,
                          children: [
                            if (widget.profile.isReadyToChat)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: SpatiallySpacing.sm,
                                  vertical: SpatiallySpacing.xxs + 1,
                                ),
                                decoration: BoxDecoration(
                                  color: SpatiallyColors.spatialCyan.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(SpatiallyRadius.full),
                                  border: Border.all(
                                    color: SpatiallyColors.spatialCyan.withValues(alpha: 0.5),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: SpatiallyColors.spatialCyan,
                                      ),
                                    ),
                                    SpatiallySpacing.gapHorizontalXs,
                                    Text(
                                      'Ready to Chat',
                                      style: SpatiallyTypography.caption(color: SpatiallyColors.spatialCyan).copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (widget.profile.locationNote.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: SpatiallySpacing.sm,
                                  vertical: SpatiallySpacing.xxs + 1,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? SpatiallyColors.darkSurfaceElevated
                                      : SpatiallyColors.lightBackground,
                                  borderRadius: BorderRadius.circular(SpatiallyRadius.full),
                                  border: Border.all(
                                    color: isDark
                                        ? SpatiallyColors.darkBorderSubdued
                                        : SpatiallyColors.lightBorderSubdued,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.location_on_outlined,
                                      size: 13,
                                      color: textSecondary,
                                    ),
                                    SpatiallySpacing.gapHorizontalXxs,
                                    Text(
                                      widget.profile.locationNote,
                                      style: SpatiallyTypography.caption(color: textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  SpatiallySpacing.gapVerticalMd,

                  // Connection action & status card
                  _buildConnectionActionCard(isDark, textPrimary, textSecondary),

                  SpatiallySpacing.gapVerticalMd,

                  // Shared & all interests section
                  SpatiallyCard(
                    padding: const EdgeInsets.all(SpatiallySpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.interests_rounded,
                              size: 18,
                              color: SpatiallyColors.violet,
                            ),
                            SpatiallySpacing.gapHorizontalXs,
                            Text(
                              'Interests & Topics',
                              style: SpatiallyTypography.subheading(color: textPrimary),
                            ),
                            const Spacer(),
                            if (_sharedInterests.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: SpatiallySpacing.xs,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: SpatiallyColors.violet.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(SpatiallyRadius.xs),
                                ),
                                child: Text(
                                  '${_sharedInterests.length} shared',
                                  style: SpatiallyTypography.caption(color: SpatiallyColors.violet).copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (_sharedInterests.isNotEmpty) ...[
                          SpatiallySpacing.gapVerticalSm,
                          Text(
                            'Shared with your profile:',
                            style: SpatiallyTypography.caption(color: textSecondary),
                          ),
                          SpatiallySpacing.gapVerticalXs,
                          Wrap(
                            spacing: SpatiallySpacing.xs,
                            runSpacing: SpatiallySpacing.xs,
                            children: _sharedInterests.map((interest) {
                              return Chip(
                                avatar: const Icon(
                                  Icons.check_circle_rounded,
                                  size: 14,
                                  color: SpatiallyColors.violet,
                                ),
                                label: Text(
                                  interest,
                                  style: SpatiallyTypography.caption(color: textPrimary).copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                backgroundColor: SpatiallyColors.violet.withValues(alpha: 0.12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(SpatiallyRadius.sm),
                                  side: BorderSide(
                                    color: SpatiallyColors.violet.withValues(alpha: 0.4),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                        SpatiallySpacing.gapVerticalSm,
                        Text(
                          'All attendee interests:',
                          style: SpatiallyTypography.caption(color: textSecondary),
                        ),
                        SpatiallySpacing.gapVerticalXs,
                        Wrap(
                          spacing: SpatiallySpacing.xs,
                          runSpacing: SpatiallySpacing.xs,
                          children: widget.profile.interests.map((interest) {
                            final isShared = _sharedInterests.contains(interest);
                            return Chip(
                              label: Text(
                                interest,
                                style: SpatiallyTypography.caption(color: textPrimary),
                              ),
                              backgroundColor: isShared
                                  ? SpatiallyColors.violet.withValues(alpha: 0.1)
                                  : (isDark
                                      ? SpatiallyColors.darkSurfaceElevated
                                      : SpatiallyColors.lightBackground),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(SpatiallyRadius.sm),
                                side: BorderSide(
                                  color: isDark
                                      ? SpatiallyColors.darkBorderSubdued
                                      : SpatiallyColors.lightBorderSubdued,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),

                  if (widget.profile.bio.isNotEmpty) ...[
                    SpatiallySpacing.gapVerticalMd,
                    SpatiallyCard(
                      padding: const EdgeInsets.all(SpatiallySpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'About',
                            style: SpatiallyTypography.subheading(color: textPrimary),
                          ),
                          SpatiallySpacing.gapVerticalSm,
                          Text(
                            widget.profile.bio,
                            style: SpatiallyTypography.body(color: textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],

                  SpatiallySpacing.gapVerticalLg,

                  // Privacy & temporary networking notice
                  Container(
                    padding: const EdgeInsets.all(SpatiallySpacing.md),
                    decoration: BoxDecoration(
                      color: isDark
                          ? SpatiallyColors.darkSurfaceElevated
                          : SpatiallyColors.lightBackground,
                      borderRadius: BorderRadius.circular(SpatiallyRadius.md),
                      border: Border.all(
                        color: isDark
                            ? SpatiallyColors.darkBorderSubdued
                            : SpatiallyColors.lightBorderSubdued,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.verified_user_outlined,
                          size: 18,
                          color: SpatiallyColors.spatialCyan,
                        ),
                        SpatiallySpacing.gapHorizontalSm,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Spatially Privacy Notice',
                                style: SpatiallyTypography.caption(color: textPrimary).copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SpatiallySpacing.gapVerticalXxs,
                              Text(
                                'Connections are strictly event-scoped and mutual opt-in. Anonymous BLE crowd sensing is never used for social matching. No phone numbers or handles are shared.',
                                style: SpatiallyTypography.caption(color: textSecondary).copyWith(
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildConnectionActionCard(bool isDark, Color textPrimary, Color textSecondary) {
    final status = _connection?.status ?? ConnectionStatus.none;

    switch (status) {
      case ConnectionStatus.none:
        return SpatiallyCard(
          padding: const EdgeInsets.all(SpatiallySpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Connect for Cultural Night 2026',
                style: SpatiallyTypography.body(color: textPrimary).copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              SpatiallySpacing.gapVerticalXxs,
              Text(
                'Sending a connection request requires mutual acceptance before temporary event chat opens.',
                style: SpatiallyTypography.caption(color: textSecondary),
              ),
              SpatiallySpacing.gapVerticalMd,
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _sendRequest,
                  icon: const Icon(Icons.person_add_outlined, size: 18),
                  label: const Text('Send Connection Request'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SpatiallyColors.violet,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(SpatiallyRadius.sm),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: SpatiallySpacing.sm),
                  ),
                ),
              ),
            ],
          ),
        );

      case ConnectionStatus.requestSent:
        return SpatiallyCard(
          padding: const EdgeInsets.all(SpatiallySpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.hourglass_top_rounded,
                    color: SpatiallyColors.warning,
                    size: 20,
                  ),
                  SpatiallySpacing.gapHorizontalXs,
                  Text(
                    'Connection Request Pending',
                    style: SpatiallyTypography.body(color: textPrimary).copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              SpatiallySpacing.gapVerticalXxs,
              Text(
                'Waiting for ${widget.profile.displayName} to accept your request. Chat will unlock once accepted.',
                style: SpatiallyTypography.caption(color: textSecondary),
              ),
              SpatiallySpacing.gapVerticalMd,
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _simulateAcceptance,
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                  label: const Text('Simulate Acceptance (Demo Test)'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: SpatiallyColors.spatialCyan,
                    side: const BorderSide(color: SpatiallyColors.spatialCyan),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(SpatiallyRadius.sm),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );

      case ConnectionStatus.requestReceived:
        return SpatiallyCard(
          padding: const EdgeInsets.all(SpatiallySpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.mark_email_unread_outlined,
                    color: SpatiallyColors.spatialCyan,
                    size: 20,
                  ),
                  SpatiallySpacing.gapHorizontalXs,
                  Text(
                    'Connection Request Received',
                    style: SpatiallyTypography.body(color: textPrimary).copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              SpatiallySpacing.gapVerticalXxs,
              Text(
                '${widget.profile.displayName} wants to connect with you during this event.',
                style: SpatiallyTypography.caption(color: textSecondary),
              ),
              SpatiallySpacing.gapVerticalMd,
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _declineRequest,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: textSecondary,
                        side: BorderSide(
                          color: isDark
                              ? SpatiallyColors.darkBorderSubdued
                              : SpatiallyColors.lightBorderSubdued,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(SpatiallyRadius.sm),
                        ),
                      ),
                      child: const Text('Decline'),
                    ),
                  ),
                  SpatiallySpacing.gapHorizontalSm,
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _acceptRequest,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SpatiallyColors.violet,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(SpatiallyRadius.sm),
                        ),
                      ),
                      child: const Text('Accept & Connect'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );

      case ConnectionStatus.connected:
        return SpatiallyCard(
          padding: const EdgeInsets.all(SpatiallySpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: SpatiallyColors.spatialCyan,
                    size: 20,
                  ),
                  SpatiallySpacing.gapHorizontalXs,
                  Text(
                    'Connected for this Event',
                    style: SpatiallyTypography.body(color: textPrimary).copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              SpatiallySpacing.gapVerticalXxs,
              Text(
                'Mutual opt-in established. You can now chat and coordinate meeting points.',
                style: SpatiallyTypography.caption(color: textSecondary),
              ),
              SpatiallySpacing.gapVerticalMd,
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _openChat,
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                  label: const Text('Open Temporary Chat'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SpatiallyColors.violet,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(SpatiallyRadius.sm),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: SpatiallySpacing.sm),
                  ),
                ),
              ),
            ],
          ),
        );

      case ConnectionStatus.declined:
      case ConnectionStatus.expired:
        return SpatiallyCard(
          padding: const EdgeInsets.all(SpatiallySpacing.md),
          child: Text(
            status == ConnectionStatus.declined
                ? 'Connection request declined.'
                : 'Connection session has expired.',
            style: SpatiallyTypography.caption(color: textSecondary),
          ),
        );
    }
  }
}
