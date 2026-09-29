import 'dart:async';
import 'package:flutter/material.dart';
import '../../design_system/design_system.dart';
import '../../services/offline_service.dart';
import '../map/map_screen.dart';
import 'models/connect_models.dart';
import 'data/connect_repository.dart';
import 'widgets/meeting_point_picker_sheet.dart';

/// Temporary, event-scoped peer-to-peer chat interface.
///
/// Features:
/// - Explicit ephemeral privacy disclaimer
/// - Message history scoped to event duration
/// - Venue meeting point suggestions with direct [MapScreen] wayfinding integration
/// - No exposure of phone numbers, emails, or personal identifiers
class TemporaryChatScreen extends StatefulWidget {
  final Connection connection;
  final ConnectRepository repository;

  const TemporaryChatScreen({
    super.key,
    required this.connection,
    required this.repository,
  });

  @override
  State<TemporaryChatScreen> createState() => _TemporaryChatScreenState();
}

class _TemporaryChatScreenState extends State<TemporaryChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<ChatMessage> _messages = [];
  bool _isLoading = true;
  StreamSubscription<void>? _updatesSub;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _updatesSub = widget.repository.updatesStream.listen((_) {
      if (mounted) _loadMessages();
    });
  }

  @override
  void dispose() {
    _updatesSub?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    final msgs = await widget.repository.getMessages(widget.connection.id);
    if (!mounted) return;
    setState(() {
      _messages = msgs;
      _isLoading = false;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSendMessage() async {
    if (!OfflineService().isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot send messages while offline. Real-time chat requires connection.'),
          backgroundColor: SpatiallyColors.warning,
        ),
      );
      return;
    }

    final text = _textController.text.trim();
    if (text.isEmpty) return;

    _textController.clear();
    try {
      await widget.repository.sendMessage(
        connectionId: widget.connection.id,
        text: text,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception:', '').replaceAll('StateError:', '').trim()),
            backgroundColor: SpatiallyColors.error,
          ),
        );
      }
    }
  }

  Future<void> _handleSuggestMeetingPoint() async {
    if (!OfflineService().isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot suggest meeting points while offline. Real-time chat requires connection.'),
          backgroundColor: SpatiallyColors.warning,
        ),
      );
      return;
    }

    final points = await widget.repository.getAvailableMeetingPoints(eventId: widget.connection.eventId);
    if (!mounted) return;

    final selected = await MeetingPointPickerSheet.show(context, points);
    if (selected != null && mounted) {
      try {
        await widget.repository.sendMessage(
          connectionId: widget.connection.id,
          text: 'Suggested meeting point: ${selected.title}',
          meetingPoint: selected,
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceAll('Exception:', '').replaceAll('StateError:', '').trim()),
              backgroundColor: SpatiallyColors.error,
            ),
          );
        }
      }
    }
  }

  void _openMapForMeetingPoint(MeetingPoint point) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MapScreen(
          initialZoneId: point.zoneId,
          initialPoiId: point.poiId,
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
    final peer = widget.connection.peerProfile;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: surfaceColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: SpatiallyColors.violet.withValues(alpha: 0.15),
              child: Text(
                peer.avatarInitials,
                style: SpatiallyTypography.caption(color: SpatiallyColors.violet).copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            SpatiallySpacing.gapHorizontalSm,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    peer.displayName,
                    style: SpatiallyTypography.body(color: textPrimary).copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    peer.headline.isNotEmpty ? peer.headline : 'Connected Attendee',
                    style: SpatiallyTypography.caption(color: textSecondary).copyWith(fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Suggest Meeting Point',
            icon: const Icon(Icons.pin_drop_outlined, color: SpatiallyColors.spatialCyan),
            onPressed: _handleSuggestMeetingPoint,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Ephemeral chat privacy banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: SpatiallySpacing.md,
                vertical: SpatiallySpacing.xs + 2,
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? SpatiallyColors.darkSurfaceElevated
                    : SpatiallyColors.lightBackground,
                border: Border(
                  bottom: BorderSide(
                    color: isDark
                        ? SpatiallyColors.darkBorderSubdued
                        : SpatiallyColors.lightBorderSubdued,
                  ),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.history_toggle_off_rounded,
                    size: 16,
                    color: SpatiallyColors.spatialCyan,
                  ),
                  SpatiallySpacing.gapHorizontalSm,
                  Expanded(
                    child: Text(
                      'Temporary Event Chat • Messages expire after the event',
                      style: SpatiallyTypography.caption(color: textSecondary).copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (!OfflineService().isOnline)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: SpatiallyOfflineBanner(
                  message: 'Offline Mode • Chat is read-only until connection is restored',
                ),
              ),

            // Message list
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _messages.isEmpty
                      ? Center(
                          child: Text(
                            'No messages yet. Say hello!',
                            style: SpatiallyTypography.body(color: textSecondary),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(SpatiallySpacing.md),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final msg = _messages[index];
                            if (msg.senderId == 'system') {
                              return _buildSystemMessage(msg, textSecondary);
                            }
                            return _buildMessageBubble(
                              msg: msg,
                              isDark: isDark,
                              textPrimary: textPrimary,
                              textSecondary: textSecondary,
                            );
                          },
                        ),
            ),

            // Composer bar
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: SpatiallySpacing.sm,
                vertical: SpatiallySpacing.xs,
              ),
              decoration: BoxDecoration(
                color: surfaceColor,
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? SpatiallyColors.darkBorderSubdued
                        : SpatiallyColors.lightBorderSubdued,
                  ),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.pin_drop_rounded,
                      color: OfflineService().isOnline ? SpatiallyColors.spatialCyan : textSecondary.withValues(alpha: 0.5),
                    ),
                    tooltip: 'Suggest Meeting Point',
                    onPressed: OfflineService().isOnline ? _handleSuggestMeetingPoint : null,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      enabled: OfflineService().isOnline,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: OfflineService().isOnline ? 'Type an event message...' : 'Chat is read-only while offline',
                        hintStyle: SpatiallyTypography.body(color: textSecondary),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(SpatiallyRadius.full),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: isDark
                            ? SpatiallyColors.darkSurfaceElevated
                            : SpatiallyColors.lightBackground,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: SpatiallySpacing.md,
                          vertical: SpatiallySpacing.xs,
                        ),
                      ),
                      onSubmitted: (_) => _handleSendMessage(),
                    ),
                  ),
                  SpatiallySpacing.gapHorizontalXs,
                  IconButton(
                    icon: Icon(
                      Icons.send_rounded,
                      color: OfflineService().isOnline ? SpatiallyColors.violet : textSecondary.withValues(alpha: 0.4),
                    ),
                    onPressed: OfflineService().isOnline ? _handleSendMessage : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemMessage(ChatMessage msg, Color textSecondary) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: SpatiallySpacing.xs),
      padding: const EdgeInsets.symmetric(
        horizontal: SpatiallySpacing.md,
        vertical: SpatiallySpacing.xs,
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: SpatiallySpacing.sm,
            vertical: SpatiallySpacing.xxs,
          ),
          decoration: BoxDecoration(
            color: SpatiallyColors.spatialCyan.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(SpatiallyRadius.full),
          ),
          child: Text(
            msg.text,
            textAlign: TextAlign.center,
            style: SpatiallyTypography.caption(color: textSecondary).copyWith(fontSize: 11),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble({
    required ChatMessage msg,
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final isMe = msg.isFromMe;
    final align = isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SpatiallySpacing.xxs + 2),
      child: Column(
        crossAxisAlignment: align,
        children: [
          if (msg.isMeetingPoint)
            _buildMeetingPointCard(
              point: msg.meetingPoint!,
              isMe: isMe,
              isDark: isDark,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            )
          else
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.76,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: SpatiallySpacing.md,
                vertical: SpatiallySpacing.sm,
              ),
              decoration: BoxDecoration(
                color: isMe
                    ? SpatiallyColors.violet
                    : (isDark
                        ? SpatiallyColors.darkSurfaceElevated
                        : SpatiallyColors.lightSurface),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(SpatiallyRadius.md),
                  topRight: const Radius.circular(SpatiallyRadius.md),
                  bottomLeft: Radius.circular(isMe ? SpatiallyRadius.md : 2),
                  bottomRight: Radius.circular(isMe ? 2 : SpatiallyRadius.md),
                ),
                border: isMe
                    ? null
                    : Border.all(
                        color: isDark
                            ? SpatiallyColors.darkBorderSubdued
                            : SpatiallyColors.lightBorderSubdued,
                      ),
              ),
              child: Text(
                msg.text,
                style: SpatiallyTypography.body(
                  color: isMe ? Colors.white : textPrimary,
                ),
              ),
            ),
          SpatiallySpacing.gapVerticalXxs,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              _formatTime(msg.timestamp),
              style: SpatiallyTypography.caption(color: textSecondary).copyWith(fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeetingPointCard({
    required MeetingPoint point,
    required bool isMe,
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.82,
      padding: const EdgeInsets.all(SpatiallySpacing.md),
      decoration: BoxDecoration(
        color: isDark ? SpatiallyColors.darkSurfaceElevated : SpatiallyColors.lightSurface,
        borderRadius: BorderRadius.circular(SpatiallyRadius.md),
        border: Border.all(
          color: SpatiallyColors.spatialCyan.withValues(alpha: 0.6),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(SpatiallySpacing.xxs + 2),
                decoration: BoxDecoration(
                  color: SpatiallyColors.spatialCyan.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.pin_drop_rounded,
                  color: SpatiallyColors.spatialCyan,
                  size: 16,
                ),
              ),
              SpatiallySpacing.gapHorizontalXs,
              Text(
                'SUGGESTED MEETING POINT',
                style: SpatiallyTypography.caption(color: SpatiallyColors.spatialCyan).copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          SpatiallySpacing.gapVerticalSm,
          Text(
            point.title,
            style: SpatiallyTypography.subheading(color: textPrimary).copyWith(fontSize: 15),
          ),
          SpatiallySpacing.gapVerticalXxs,
          Text(
            point.subtitle,
            style: SpatiallyTypography.caption(color: textSecondary),
          ),
          SpatiallySpacing.gapVerticalSm,
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _openMapForMeetingPoint(point),
              icon: const Icon(Icons.navigation_outlined, size: 16),
              label: const Text('View on Map & Navigate'),
              style: ElevatedButton.styleFrom(
                backgroundColor: SpatiallyColors.spatialCyan,
                foregroundColor: SpatiallyColors.darkBackground,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(SpatiallyRadius.sm),
                ),
                padding: const EdgeInsets.symmetric(vertical: SpatiallySpacing.xs),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
