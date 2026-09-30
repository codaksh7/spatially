import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/operational_message.dart';
import '../models/quick_reply.dart';
import '../models/volunteer_directory_entry.dart';
import '../repositories/operational_communication_repository.dart';
import '../services/session_state.dart';

class DirectThreadScreen extends StatefulWidget {
  final OperationalCommunicationRepository repository;
  final String eventId;
  final VolunteerDirectoryEntry? recipient; // NULL indicates Organizer/Ops channel
  final bool isOrganizerChannel;

  const DirectThreadScreen({
    super.key,
    required this.repository,
    required this.eventId,
    this.recipient,
    this.isOrganizerChannel = false,
  });

  @override
  State<DirectThreadScreen> createState() => _DirectThreadScreenState();
}

class _DirectThreadScreenState extends State<DirectThreadScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<OperationalMessage>? _messageSub;

  List<OperationalMessage> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  OperationalPriority _selectedPriority = OperationalPriority.normal;
  String? _errorMessage;

  String? get _myId => SessionState.instance.volunteerId;

  @override
  void initState() {
    super.initState();
    _loadThreadMessages();
    _listenRealtime();
  }

  void _listenRealtime() {
    _messageSub = widget.repository.messageStream.listen((msg) {
      if (msg.eventId == widget.eventId) {
        // Check if message belongs to this thread
        final isRelevant = widget.isOrganizerChannel
            ? (msg.isOrganizerChannel)
            : (msg.targetType == OperationalTargetType.volunteer &&
                ((msg.senderId == widget.recipient?.volunteerId && msg.targetId == _myId) ||
                 (msg.senderId == _myId && msg.targetId == widget.recipient?.volunteerId)));

        if (isRelevant && mounted) {
          setState(() {
            // Avoid duplicate by id
            _messages.removeWhere((m) => m.id == msg.id);
            _messages.insert(0, msg);
          });
          _markIncomingAsRead();
        }
      }
    });
  }

  Future<void> _loadThreadMessages() async {
    setState(() => _isLoading = true);
    try {
      final all = await widget.repository.getMessages(
        eventId: widget.eventId,
        limit: 100,
        filter: 'direct',
      );

      final thread = all.where((msg) {
        if (widget.isOrganizerChannel) {
          return msg.isOrganizerChannel;
        } else {
          return msg.targetType == OperationalTargetType.volunteer &&
              ((msg.senderId == widget.recipient?.volunteerId && msg.targetId == _myId) ||
               (msg.senderId == _myId && msg.targetId == widget.recipient?.volunteerId));
        }
      }).toList();

      if (mounted) {
        setState(() {
          _messages = thread;
          _isLoading = false;
        });
        _markIncomingAsRead();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load thread messages.';
        });
      }
    }
  }

  void _markIncomingAsRead() {
    final unreadIncoming = _messages
        .where((m) => m.senderId != _myId && !m.isRead && !m.isLocalQueued)
        .map((m) => m.id)
        .toList();

    if (unreadIncoming.isNotEmpty) {
      widget.repository.markAsRead(unreadIncoming);
    }
  }

  Future<void> _sendMessage(String text, {OperationalPriority? priorityOverride}) async {
    final body = text.trim();
    if (body.isEmpty) return;

    final priority = priorityOverride ?? _selectedPriority;

    setState(() {
      _isSending = true;
      _errorMessage = null;
    });

    try {
      final newMsg = await widget.repository.sendMessage(
        eventId: widget.eventId,
        targetType: widget.isOrganizerChannel
            ? OperationalTargetType.organizer
            : OperationalTargetType.volunteer,
        targetId: widget.isOrganizerChannel ? null : widget.recipient?.volunteerId,
        body: body,
        messageType: priority == OperationalPriority.urgent ? 'escalation' : 'operational',
        priority: priority,
        requiresAcknowledgment: priority != OperationalPriority.normal,
      );

      _textController.clear();
      if (mounted) {
        setState(() {
          _messages.removeWhere((m) => m.id == newMsg.id);
          _messages.insert(0, newMsg);
          _isSending = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSending = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  Future<void> _acknowledge(OperationalMessage msg) async {
    final success = await widget.repository.acknowledgeMessage(msg.id);
    if (success && mounted) {
      setState(() {
        final index = _messages.indexWhere((m) => m.id == msg.id);
        if (index != -1) {
          _messages[index] = _messages[index].copyWith(
            receiptStatus: MessageLifecycleStatus.acknowledged,
            acknowledgedAt: DateTime.now(),
          );
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Operational message acknowledged.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  void dispose() {
    _messageSub?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isOrganizerChannel
        ? 'Event Operations'
        : (widget.recipient?.fullName ?? 'Staff Member');
    final subtitle = widget.isOrganizerChannel
        ? 'Organizer Command Channel'
        : (widget.recipient?.assignmentLabel ?? 'Volunteer');

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              subtitle,
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_errorMessage != null)
            Container(
              color: Colors.red.shade50,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => setState(() => _errorMessage = null),
                  ),
                ],
              ),
            ),

          // Message history list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.forum_outlined, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              'No operational messages yet.',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Use quick replies or type below to coordinate.',
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final isMe = msg.senderId == _myId;
                          return _buildMessageBubble(msg, isMe);
                        },
                      ),
          ),

          // Quick Replies Bar
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: QuickReplyOption.defaultOptions.length,
              itemBuilder: (context, i) {
                final opt = QuickReplyOption.defaultOptions[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 6.0),
                  child: ActionChip(
                    label: Text(opt.text, style: const TextStyle(fontSize: 12)),
                    backgroundColor: opt.isAffirmative ? Colors.indigo.shade50 : Colors.grey.shade100,
                    side: BorderSide(
                      color: opt.isAffirmative ? Colors.indigo.shade200 : Colors.grey.shade300,
                    ),
                    onPressed: _isSending ? null : () => _sendMessage(opt.text),
                  ),
                );
              },
            ),
          ),

          // Priority Bar & Input Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  Row(
                    children: [
                      // Priority selector chip
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        child: DropdownButton<OperationalPriority>(
                          value: _selectedPriority,
                          underline: const SizedBox(),
                          icon: const Icon(Icons.arrow_drop_down, size: 18),
                          items: const [
                            DropdownMenuItem(
                              value: OperationalPriority.normal,
                              child: Text('Normal', style: TextStyle(fontSize: 12)),
                            ),
                            DropdownMenuItem(
                              value: OperationalPriority.important,
                              child: Text('Important', style: TextStyle(fontSize: 12, color: Colors.orange)),
                            ),
                            DropdownMenuItem(
                              value: OperationalPriority.urgent,
                              child: Text('Urgent', style: TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold)),
                            ),
                          ],
                          onChanged: (p) {
                            if (p != null) setState(() => _selectedPriority = p);
                          },
                        ),
                      ),
                      // Text input field
                      Expanded(
                        child: TextField(
                          controller: _textController,
                          maxLength: 1000,
                          decoration: InputDecoration(
                            hintText: 'Type message...',
                            counterText: '',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                          onSubmitted: (val) => _sendMessage(val),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Send action
                      IconButton(
                        icon: _isSending
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(
                                Icons.send,
                                color: _selectedPriority == OperationalPriority.urgent
                                    ? Colors.red
                                    : Colors.indigo,
                              ),
                        onPressed: _isSending ? null : () => _sendMessage(_textController.text),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(OperationalMessage msg, bool isMe) {
    Color bubbleColor = isMe ? Colors.indigo.shade600 : Colors.grey.shade100;
    Color textColor = isMe ? Colors.white : Colors.black87;

    if (msg.isUrgent) {
      bubbleColor = isMe ? Colors.red.shade700 : Colors.red.shade50;
      textColor = isMe ? Colors.white : Colors.red.shade900;
    } else if (msg.isImportant) {
      bubbleColor = isMe ? Colors.amber.shade800 : Colors.amber.shade50;
      textColor = isMe ? Colors.white : Colors.amber.shade900;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Priority & Role header
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isMe) ...[
                Text(
                  msg.senderName,
                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    msg.senderRole.toUpperCase(),
                    style: TextStyle(fontSize: 9, color: Colors.grey.shade700, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              if (msg.isUrgent)
                Container(
                  margin: const EdgeInsets.only(right: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
                  child: const Text('URGENT', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                ),
              Text(
                _formatTime(msg.createdAt),
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Message bubble
          Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.circular(16).copyWith(
                bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(16),
                bottomLeft: !isMe ? const Radius.circular(0) : const Radius.circular(16),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  msg.body,
                  style: GoogleFonts.poppins(fontSize: 14, color: textColor),
                ),

                // If acknowledgment required
                if (msg.requiresAcknowledgment) ...[
                  const SizedBox(height: 8),
                  if (msg.isAcknowledged)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle, size: 14, color: Colors.green),
                        const SizedBox(width: 4),
                        Text(
                          'Acknowledged',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isMe ? Colors.white70 : Colors.green.shade800,
                          ),
                        ),
                      ],
                    )
                  else if (!isMe)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.done_all, size: 14),
                      label: const Text('Acknowledge'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.indigo.shade800,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => _acknowledge(msg),
                    )
                  else
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.access_time, size: 12, color: Colors.white70),
                        const SizedBox(width: 4),
                        const Text(
                          'Awaiting acknowledgment',
                          style: TextStyle(fontSize: 10, color: Colors.white70),
                        ),
                      ],
                    ),
                ],
              ],
            ),
          ),

          // Status footer for sent messages
          if (isMe)
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (msg.isLocalQueued)
                    Row(
                      children: [
                        Icon(Icons.watch_later_outlined, size: 11, color: Colors.amber.shade800),
                        const SizedBox(width: 2),
                        Text('Queued (Offline)', style: TextStyle(fontSize: 10, color: Colors.amber.shade800)),
                      ],
                    )
                  else if (msg.receiptStatus == MessageLifecycleStatus.acknowledged)
                    const Row(
                      children: [
                        Icon(Icons.done_all, size: 12, color: Colors.green),
                        SizedBox(width: 2),
                        Text('Acknowledged', style: TextStyle(fontSize: 10, color: Colors.green)),
                      ],
                    )
                  else if (msg.receiptStatus == MessageLifecycleStatus.read)
                    Row(
                      children: [
                        Icon(Icons.done_all, size: 12, color: Colors.blue.shade600),
                        const SizedBox(width: 2),
                        Text('Read', style: TextStyle(fontSize: 10, color: Colors.blue.shade600)),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Icon(Icons.check, size: 12, color: Colors.grey.shade500),
                        const SizedBox(width: 2),
                        Text('Sent', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                      ],
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
