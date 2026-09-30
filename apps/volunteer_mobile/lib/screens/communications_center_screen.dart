import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/operational_message.dart';
import '../models/volunteer_directory_entry.dart';
import '../repositories/operational_communication_repository.dart';
import '../services/session_state.dart';
import 'compose_message_dialog.dart';
import 'direct_thread_screen.dart';
import 'incidents_list_screen.dart';

class CommunicationsCenterScreen extends StatefulWidget {
  final OperationalCommunicationRepository? repository;

  const CommunicationsCenterScreen({super.key, this.repository});

  @override
  State<CommunicationsCenterScreen> createState() => _CommunicationsCenterScreenState();
}

class _CommunicationsCenterScreenState extends State<CommunicationsCenterScreen>
    with SingleTickerProviderStateMixin {
  late final OperationalCommunicationRepository _repository;
  late final TabController _tabController;
  StreamSubscription<OperationalMessage>? _messageSub;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  List<OperationalMessage> _allMessages = [];
  List<VolunteerDirectoryEntry> _directory = [];
  bool _isLoading = true;
  bool _isLoadingDirectory = false;
  String? _errorMessage;
  bool _isOnline = true;
  int _queuedCount = 0;

  String get _eventId => SessionState.instance.eventId ?? '';
  String? get _myId => SessionState.instance.volunteerId;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? OperationalCommunicationRepositoryImpl();
    _tabController = TabController(length: 4, vsync: this);

    _checkConnectivity();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (mounted) {
        setState(() => _isOnline = online);
      }
      if (online) {
        _repository.flushPendingMessages().then((_) => _loadData());
      }
    });

    _loadData();
    _subscribeRealtime();
  }

  Future<void> _checkConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    if (mounted) {
      setState(() {
        _isOnline = results.any((r) => r != ConnectivityResult.none);
      });
    }
  }

  void _subscribeRealtime() {
    if (_eventId.isEmpty) return;
    _repository.subscribeRealtime(_eventId);

    _messageSub = _repository.messageStream.listen((msg) {
      if (mounted && msg.eventId == _eventId) {
        setState(() {
          _allMessages.removeWhere((m) => m.id == msg.id);
          _allMessages.insert(0, msg);
          _calculateQueuedCount();
        });
      }
    });
  }

  Future<void> _loadData() async {
    if (_eventId.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'No active event assigned.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final messages = await _repository.getMessages(eventId: _eventId, limit: 100);
      _loadDirectory();

      if (mounted) {
        setState(() {
          _allMessages = messages;
          _isLoading = false;
          _calculateQueuedCount();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load operational communications.';
        });
      }
    }
  }

  void _calculateQueuedCount() {
    _queuedCount = _allMessages.where((m) => m.isLocalQueued).length;
  }

  Future<void> _loadDirectory() async {
    setState(() => _isLoadingDirectory = true);
    try {
      final list = await _repository.getVolunteerDirectory(_eventId);
      if (mounted) {
        setState(() {
          _directory = list;
          _isLoadingDirectory = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingDirectory = false);
    }
  }

  Future<void> _flushQueued() async {
    final count = await _repository.flushPendingMessages();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(count > 0 ? 'Flushed $count queued message(s).' : 'All messages synced.'),
          backgroundColor: Colors.indigo,
        ),
      );
      _loadData();
    }
  }

  Future<void> _acknowledge(OperationalMessage msg) async {
    final success = await _repository.acknowledgeMessage(msg.id);
    if (success && mounted) {
      setState(() {
        final index = _allMessages.indexWhere((m) => m.id == msg.id);
        if (index != -1) {
          _allMessages[index] = _allMessages[index].copyWith(
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

  void _openCompose([VolunteerDirectoryEntry? targetRecipient, OperationalTargetType? targetType]) {
    showModalBottomSheet<OperationalMessage>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ComposeMessageSheet(
        repository: _repository,
        eventId: _eventId,
        preselectedRecipient: targetRecipient,
        initialTargetType: targetType,
      ),
    ).then((msg) {
      if (msg != null && mounted) {
        setState(() {
          _allMessages.removeWhere((m) => m.id == msg.id);
          _allMessages.insert(0, msg);
          _calculateQueuedCount();
        });
      }
    });
  }

  void _openDirectThread(VolunteerDirectoryEntry recipient) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DirectThreadScreen(
          repository: _repository,
          eventId: _eventId,
          recipient: recipient,
        ),
      ),
    ).then((_) => _loadData());
  }

  void _openOrganizerThread() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DirectThreadScreen(
          repository: _repository,
          eventId: _eventId,
          isOrganizerChannel: true,
        ),
      ),
    ).then((_) => _loadData());
  }

  String _formatRelativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 10) return 'just now';
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  void dispose() {
    _messageSub?.cancel();
    _connectivitySub?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final eventName = SessionState.instance.eventName ?? 'Active Event';
    final urgentAlerts = _allMessages.where((m) => m.isUrgent && !m.isAcknowledged && m.senderId != _myId).toList();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Communications Center',
              style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            Text(
              eventName,
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          // Network State Pill
          Center(
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _isOnline ? Colors.green.shade50 : Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _isOnline ? Colors.green.shade300 : Colors.amber.shade400),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isOnline ? Icons.wifi : Icons.wifi_off,
                    size: 12,
                    color: _isOnline ? Colors.green.shade700 : Colors.amber.shade800,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _isOnline ? 'Online' : 'Offline',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _isOnline ? Colors.green.shade800 : Colors.amber.shade900,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_queuedCount > 0)
            IconButton(
              icon: Badge(
                label: Text('$_queuedCount'),
                child: const Icon(Icons.sync),
              ),
              tooltip: 'Sync queued messages',
              onPressed: _flushQueued,
            ),
          IconButton(
            icon: const Icon(Icons.assignment_outlined),
            tooltip: 'Incidents & Help',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const IncidentsListScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelStyle: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
          unselectedLabelStyle: GoogleFonts.poppins(fontSize: 12),
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Broadcasts'),
            Tab(text: 'Direct & Ops'),
            Tab(text: 'Directory'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Pinned Urgent Alert Banner if present
          if (urgentAlerts.isNotEmpty) ...[
            _buildUrgentBanner(urgentAlerts.first),
          ],

          if (!_isOnline)
            Container(
              width: double.infinity,
              color: Colors.amber.shade100,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: Colors.amber.shade900),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Working offline. Showing cached messages. Urgent alerts require network.',
                      style: TextStyle(color: Colors.amber.shade900, fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? _buildErrorView()
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildMessagesList(_allMessages),
                          _buildMessagesList(_allMessages.where((m) => m.isBroadcast).toList()),
                          _buildDirectAndOpsTab(),
                          _buildDirectoryTab(),
                        ],
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCompose(),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.edit_note, size: 20),
        label: Text('Compose', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildUrgentBanner(OperationalMessage alert) {
    return Container(
      width: double.infinity,
      color: Colors.red.shade700,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
                      child: Text('URGENT', style: TextStyle(color: Colors.red.shade900, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'From ${alert.senderName} (${alert.senderRole})',
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  alert.body,
                  style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => _acknowledge(alert),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.red.shade900,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
            child: const Text('Acknowledge', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList(List<OperationalMessage> messages) {
    if (messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text('No operational messages.', style: TextStyle(color: Colors.grey.shade600, fontSize: 15)),
            const SizedBox(height: 4),
            Text('Tap Compose to broadcast or message staff.', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 12, left: 14, right: 14, bottom: 80),
        itemCount: messages.length,
        itemBuilder: (context, index) {
          final msg = messages[index];
          return _buildMessageCard(msg);
        },
      ),
    );
  }

  Widget _buildMessageCard(OperationalMessage msg) {
    final isMe = msg.senderId == _myId;

    Color priorityColor = Colors.grey.shade700;
    Color priorityBg = Colors.grey.shade100;
    if (msg.isUrgent) {
      priorityColor = Colors.red.shade700;
      priorityBg = Colors.red.shade50;
    } else if (msg.isImportant) {
      priorityColor = Colors.amber.shade900;
      priorityBg = Colors.amber.shade50;
    }

    String scopeLabel = 'EVENT-WIDE';
    if (msg.targetType == OperationalTargetType.zone) {
      scopeLabel = 'ZONE BROADCAST';
    } else if (msg.targetType == OperationalTargetType.volunteer) {
      scopeLabel = 'DIRECT MESSAGE';
    } else if (msg.targetType == OperationalTargetType.organizer) {
      scopeLabel = 'ORGANIZER / OPS';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: msg.isUrgent ? 2 : 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: msg.isUrgent ? Colors.red.shade300 : Colors.grey.shade200,
          width: msg.isUrgent ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Scope, Priority, Time
            Row(
              children: [
                // Scope pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    scopeLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo.shade700,
                    ),
                  ),
                ),
                const SizedBox(width: 6),

                // Priority pill
                if (msg.priority != OperationalPriority.normal) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: priorityBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      msg.priority.value.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: priorityColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],

                const Spacer(),
                Text(
                  _formatRelativeTime(msg.createdAt),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Sender Row
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: msg.isFromOrganizer ? Colors.deepPurple.shade100 : Colors.blue.shade100,
                  child: Text(
                    msg.senderName.isNotEmpty ? msg.senderName[0].toUpperCase() : 'S',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: msg.isFromOrganizer ? Colors.deepPurple.shade900 : Colors.blue.shade900,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isMe ? '${msg.senderName} (You)' : msg.senderName,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    msg.senderRole.toUpperCase(),
                    style: TextStyle(fontSize: 9, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Body
            Text(
              msg.body,
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade900),
            ),
            const SizedBox(height: 10),

            // Footer: Acknowledgment & Status
            Row(
              children: [
                if (msg.requiresAcknowledgment) ...[
                  if (msg.isAcknowledged)
                    Row(
                      children: [
                        const Icon(Icons.check_circle, size: 14, color: Colors.green),
                        const SizedBox(width: 4),
                        Text(
                          'Acknowledged',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.green.shade800),
                        ),
                      ],
                    )
                  else if (!isMe)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.done_all, size: 14),
                      label: const Text('Tap to Acknowledge'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo.shade50,
                        foregroundColor: Colors.indigo.shade800,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => _acknowledge(msg),
                    )
                  else
                    Row(
                      children: [
                        Icon(Icons.hourglass_empty, size: 13, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text('Awaiting staff acknowledgment', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                      ],
                    ),
                ],

                const Spacer(),

                // Offline queued or delivery status
                if (msg.isLocalQueued)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(4)),
                    child: Row(
                      children: [
                        Icon(Icons.watch_later_outlined, size: 11, color: Colors.amber.shade900),
                        const SizedBox(width: 3),
                        Text('Queued (Offline)', style: TextStyle(fontSize: 10, color: Colors.amber.shade900, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )
                else if (isMe)
                  Row(
                    children: [
                      Icon(
                        msg.receiptStatus == MessageLifecycleStatus.acknowledged
                            ? Icons.done_all
                            : Icons.check,
                        size: 13,
                        color: msg.receiptStatus == MessageLifecycleStatus.acknowledged ? Colors.green : Colors.grey.shade500,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        msg.receiptStatus.name.toUpperCase(),
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDirectAndOpsTab() {
    return Column(
      children: [
        // Quick Organizer Ops Card
        Card(
          margin: const EdgeInsets.all(14),
          color: Colors.deepPurple.shade50,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.deepPurple,
              child: Icon(Icons.headset_mic, color: Colors.white, size: 20),
            ),
            title: Text(
              'Event Operations Command',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            subtitle: const Text(
              'Direct channel to event organizers and leads.',
              style: TextStyle(fontSize: 12),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: _openOrganizerThread,
          ),
        ),

        Expanded(
          child: _buildMessagesList(
            _allMessages.where((m) => m.isDirect || m.isOrganizerChannel).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildDirectoryTab() {
    if (_isLoadingDirectory) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_directory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text('No staff members discovered in this event.', style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: _directory.length,
      itemBuilder: (context, index) {
        final staff = _directory[index];
        final isSelf = staff.volunteerId == _myId;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0.5,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            onTap: isSelf ? null : () => _openDirectThread(staff),
            leading: CircleAvatar(
              backgroundColor: staff.isOrganizerOrAdmin ? Colors.deepPurple.shade100 : Colors.indigo.shade100,
              child: Text(
                staff.fullName.isNotEmpty ? staff.fullName[0].toUpperCase() : 'S',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: staff.isOrganizerOrAdmin ? Colors.deepPurple.shade900 : Colors.indigo.shade900,
                ),
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    isSelf ? '${staff.fullName} (You)' : staff.fullName,
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    staff.staffType.toUpperCase(),
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                  ),
                ),
              ],
            ),
            subtitle: Text(
              staff.assignmentLabel,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            trailing: isSelf
                ? null
                : IconButton(
                    icon: const Icon(Icons.chat_bubble_outline, color: Colors.indigo),
                    tooltip: 'Direct Message',
                    onPressed: () => _openDirectThread(staff),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry Connection'),
            ),
          ],
        ),
      ),
    );
  }
}
