import 'dart:async';
import 'package:flutter/material.dart';
import '../../design_system/design_system.dart';
import '../../services/auth_service.dart';
import '../../services/offline_service.dart';
import '../explore/models/spatially_event.dart';
import '../profile/data/profile_repository.dart';
import '../profile/models/profile_preferences.dart';
import '../tickets/data/ticket_repository.dart';
import 'models/connect_models.dart';
import 'data/connect_repository.dart';
import 'data/supabase_connect_repository.dart';
import 'connection_detail_screen.dart';
import 'temporary_chat_screen.dart';
import 'widgets/connect_attendee_card.dart';

/// Spatially Event Connect Destination Screen (Phase 6B).
///
/// Contextual, event-scoped networking surface.
/// Strictly honors [ProfilePreferences.networkingVisibility], interest matching,
/// admission ticket ownership, and authenticated account protection.
class ConnectScreen extends StatefulWidget {
  final SpatiallyEvent? event;
  final String? eventId;
  final String? eventName;
  final ConnectRepository? repository;

  const ConnectScreen({
    super.key,
    this.event,
    this.eventId,
    this.eventName,
    this.repository,
  });

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final ConnectRepository _connectRepository;
  final ProfileRepository _profileRepository = ProfileRepositoryImpl();

  StreamSubscription<void>? _updatesSub;
  bool _isLoading = true;
  String _eventId = 'event_demo_current';
  String _eventName = 'Cultural Night 2026';
  bool _isTicketHolder = true;

  ProfilePreferences? _preferences;
  List<ConnectProfile> _attendees = [];
  Map<String, Connection> _peerConnections = {};
  Map<String, List<String>> _sharedInterestsMap = {};
  List<Connection> _allConnections = [];

  bool _readyToChatFilter = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _connectRepository = widget.repository ?? SupabaseConnectRepositoryImpl();
    if (widget.event != null) {
      _eventId = widget.event!.id;
      _eventName = widget.event!.name;
    } else if (widget.eventId != null && widget.eventId!.isNotEmpty) {
      _eventId = widget.eventId!;
      _eventName = widget.eventName ?? 'Event Networking';
    }
    _loadData();
    _updatesSub = _connectRepository.updatesStream.listen((_) {
      if (mounted) _loadData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _updatesSub?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    final prefs = await _profileRepository.getPreferences();

    // Resolve active event from user tickets if not passed in widget
    if (widget.event == null && (widget.eventId == null || widget.eventId!.isEmpty)) {
      try {
        final tickets = await TicketRepositoryImpl().getMyTickets();
        if (tickets.isNotEmpty) {
          final firstTicket = tickets.first;
          final tEventId = firstTicket['event_id']?.toString();
          final tEventName = (firstTicket['events'] is Map)
              ? (firstTicket['events']['name']?.toString() ?? 'Event Networking')
              : 'Event Networking';
          if (tEventId != null) {
            _eventId = tEventId;
            _eventName = tEventName;
          }
        }
      } catch (_) {}
    }

    // Verify ticket ownership for authenticated users
    if (AuthService().isAuthenticated) {
      try {
        final tickets = await TicketRepositoryImpl().getMyTickets();
        final hasTicket = tickets.any((t) => t['event_id']?.toString() == _eventId);
        _isTicketHolder = hasTicket;
      } catch (_) {
        _isTicketHolder = true;
      }
    } else {
      _isTicketHolder = false;
    }

    final attendees = await _connectRepository.getDiscoverableAttendees(_eventId);
    final connections = await _connectRepository.getConnections(_eventId);

    final peerConnMap = <String, Connection>{};
    for (final c in connections) {
      peerConnMap[c.peerProfile.id] = c;
    }

    final sharedMap = <String, List<String>>{};
    for (final a in attendees) {
      sharedMap[a.id] = await _connectRepository.getSharedInterests(a.interests);
    }

    if (!mounted) return;
    setState(() {
      _preferences = prefs;
      _attendees = attendees;
      _allConnections = connections;
      _peerConnections = peerConnMap;
      _sharedInterestsMap = sharedMap;
      _isLoading = false;
    });
  }

  Future<void> _showSignInPrompt() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(SpatiallySpacing.lg),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? SpatiallyColors.darkSurfaceElevated
              : SpatiallyColors.lightSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(SpatiallyRadius.lg)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: SpatiallyColors.violet.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(Icons.hub_outlined, color: SpatiallyColors.violet, size: 28),
              ),
            ),
            SpatiallySpacing.gapVerticalMd,
            Text(
              'Sign In to Connect',
              style: SpatiallyTypography.subheading(
                color: Theme.of(context).brightness == Brightness.dark
                    ? SpatiallyColors.darkTextPrimary
                    : SpatiallyColors.lightTextPrimary,
              ),
            ),
            SpatiallySpacing.gapVerticalSm,
            Text(
              'Event Connect requires an authenticated account to protect attendee privacy, prevent spam, and enable ephemeral chat.',
              textAlign: TextAlign.center,
              style: SpatiallyTypography.body(
                color: Theme.of(context).brightness == Brightness.dark
                    ? SpatiallyColors.darkTextSecondary
                    : SpatiallyColors.lightTextSecondary,
              ),
            ),
            SpatiallySpacing.gapVerticalLg,
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  try {
                    await AuthService().signInWithGoogle();
                    await _loadData();
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Sign-in failed: $e'),
                          backgroundColor: SpatiallyColors.error,
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.login_rounded),
                label: const Text('Continue with Google'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: SpatiallyColors.violet,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(SpatiallyRadius.md),
                  ),
                ),
              ),
            ),
            SpatiallySpacing.gapVerticalSm,
          ],
        ),
      ),
    );
  }

  Future<void> _handleConnect(ConnectProfile profile) async {
    if (!AuthService().isAuthenticated) {
      await _showSignInPrompt();
      return;
    }

    if (!OfflineService().isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot send connection request while offline. Please connect to internet.'),
          backgroundColor: SpatiallyColors.warning,
        ),
      );
      return;
    }

    try {
      await _connectRepository.sendConnectionRequest(_eventId, profile.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection request sent to ${profile.displayName}'),
            backgroundColor: SpatiallyColors.success,
          ),
        );
      }
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

  void _openDetail(ConnectProfile profile) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConnectionDetailScreen(
          profile: profile,
          eventId: _eventId,
          repository: _connectRepository,
        ),
      ),
    );
  }

  void _openChat(Connection connection) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TemporaryChatScreen(
          connection: connection,
          repository: _connectRepository,
        ),
      ),
    );
  }

  Future<void> _enableDiscoverability() async {
    if (_preferences == null) return;
    final updated = _preferences!.copyWith(
      networkingVisibility: NetworkingVisibility.discoverable,
    );
    await _profileRepository.savePreferences(updated);
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isDark ? SpatiallyColors.darkSurface : SpatiallyColors.lightSurface;
    final textPrimary = isDark ? SpatiallyColors.darkTextPrimary : SpatiallyColors.lightTextPrimary;
    final textSecondary = isDark ? SpatiallyColors.darkTextSecondary : SpatiallyColors.lightTextSecondary;

    final isNetworkingInvisible =
        _preferences?.networkingVisibility == NetworkingVisibility.invisible;

    final incomingRequests =
        _allConnections.where((c) => c.status == ConnectionStatus.requestReceived).toList();
    final activeChats =
        _allConnections.where((c) => c.status == ConnectionStatus.connected).toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: surfaceColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Event Connect',
              style: SpatiallyTypography.subheading(color: textPrimary),
            ),
            Text(
              _eventName,
              style: SpatiallyTypography.caption(color: SpatiallyColors.spatialCyan).copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: SpatiallyColors.violet,
          unselectedLabelColor: textSecondary,
          indicatorColor: SpatiallyColors.violet,
          indicatorWeight: 3,
          tabs: [
            const Tab(text: 'Discover Attendees'),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Chats & Requests'),
                  if (incomingRequests.isNotEmpty) ...[
                    SpatiallySpacing.gapHorizontalXs,
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: const BoxDecoration(
                        color: SpatiallyColors.violet,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${incomingRequests.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (!OfflineService().isOnline)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: SpatiallyOfflineBanner(
                      message: 'Offline Mode • Real-time attendee discovery & chat require connection.',
                    ),
                  ),
                if (!AuthService().isAuthenticated)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: SpatiallyColors.violet.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(SpatiallyRadius.sm),
                        border: Border.all(color: SpatiallyColors.violet.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, color: SpatiallyColors.violet, size: 20),
                          SpatiallySpacing.gapHorizontalSm,
                          Expanded(
                            child: Text(
                              'Guest Mode • Sign in to connect and chat with attendees.',
                              style: SpatiallyTypography.caption(color: textPrimary).copyWith(fontWeight: FontWeight.w500),
                            ),
                          ),
                          TextButton(
                            onPressed: _showSignInPrompt,
                            child: const Text('Sign In', style: TextStyle(fontWeight: FontWeight.bold, color: SpatiallyColors.violet)),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (!_isTicketHolder)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: SpatiallyColors.warning.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(SpatiallyRadius.sm),
                        border: Border.all(color: SpatiallyColors.warning.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.confirmation_number_outlined, color: SpatiallyColors.warning, size: 20),
                          SpatiallySpacing.gapHorizontalSm,
                          Expanded(
                            child: Text(
                              'Pass Required • An admission ticket for $_eventName is required to connect with attendees.',
                              style: SpatiallyTypography.caption(color: textPrimary).copyWith(fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildDiscoverTab(
                        isDark: isDark,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        isInvisible: isNetworkingInvisible,
                      ),
                      _buildConnectionsTab(
                        isDark: isDark,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        incomingRequests: incomingRequests,
                        activeChats: activeChats,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildDiscoverTab({
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
    required bool isInvisible,
  }) {
    if (isInvisible) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(SpatiallySpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: SpatiallyColors.warning.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.visibility_off_outlined,
                  size: 32,
                  color: SpatiallyColors.warning,
                ),
              ),
              SpatiallySpacing.gapVerticalMd,
              Text(
                'Networking is Set to Invisible',
                style: SpatiallyTypography.sectionHeading(color: textPrimary),
                textAlign: TextAlign.center,
              ),
              SpatiallySpacing.gapVerticalSm,
              Text(
                'Your profile is currently hidden from other attendees in your Profile settings. Turn on Discoverable mode to explore people and receive connection requests.',
                style: SpatiallyTypography.body(color: textSecondary),
                textAlign: TextAlign.center,
              ),
              SpatiallySpacing.gapVerticalLg,
              ElevatedButton.icon(
                onPressed: _enableDiscoverability,
                icon: const Icon(Icons.radar_rounded, size: 18),
                label: const Text('Make Profile Discoverable'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: SpatiallyColors.violet,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(SpatiallyRadius.sm),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: SpatiallySpacing.lg,
                    vertical: SpatiallySpacing.sm,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final filtered = _readyToChatFilter
        ? _attendees.where((a) => a.isReadyToChat).toList()
        : _attendees;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(SpatiallySpacing.md),
        children: [
          // Visibility mode badge & filter row
          Row(
            children: [
              Expanded(
                child: Text(
                  _preferences?.networkingVisibility == NetworkingVisibility.matchingInterests
                      ? 'Matching Interests Only'
                      : 'Discoverable to All Attendees',
                  style: SpatiallyTypography.caption(color: SpatiallyColors.violet).copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              FilterChip(
                selected: _readyToChatFilter,
                label: Text(
                  'Ready to Chat',
                  style: SpatiallyTypography.caption(
                    color: _readyToChatFilter ? Colors.white : textSecondary,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
                selectedColor: SpatiallyColors.spatialCyan,
                backgroundColor: isDark
                    ? SpatiallyColors.darkSurfaceElevated
                    : SpatiallyColors.lightBackground,
                onSelected: (val) {
                  setState(() => _readyToChatFilter = val);
                },
              ),
            ],
          ),

          SpatiallySpacing.gapVerticalSm,

          // Temporary networking disclaimer banner
          Container(
            padding: const EdgeInsets.all(SpatiallySpacing.sm),
            decoration: BoxDecoration(
              color: isDark
                  ? SpatiallyColors.darkSurfaceElevated
                  : SpatiallyColors.lightBackground,
              borderRadius: BorderRadius.circular(SpatiallyRadius.sm),
              border: Border.all(
                color: isDark
                    ? SpatiallyColors.darkBorderSubdued
                    : SpatiallyColors.lightBorderSubdued,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.lock_clock_outlined,
                  size: 16,
                  color: SpatiallyColors.spatialCyan,
                ),
                SpatiallySpacing.gapHorizontalSm,
                Expanded(
                  child: Text(
                    'Temporary Event Networking • Mutual opt-in required. BLE telemetry is strictly separate.',
                    style: SpatiallyTypography.caption(color: textSecondary).copyWith(fontSize: 11),
                  ),
                ),
              ],
            ),
          ),

          SpatiallySpacing.gapVerticalMd,

          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: SpatiallySpacing.xxl),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.people_outline_rounded, size: 48, color: textSecondary.withValues(alpha: 0.5)),
                    SpatiallySpacing.gapVerticalSm,
                    Text(
                      'No attendees match current filter',
                      style: SpatiallyTypography.body(color: textSecondary),
                    ),
                  ],
                ),
              ),
            )
          else
            ...filtered.map((attendee) {
              final conn = _peerConnections[attendee.id];
              final shared = _sharedInterestsMap[attendee.id] ?? [];
              return Padding(
                padding: const EdgeInsets.only(bottom: SpatiallySpacing.md),
                child: ConnectAttendeeCard(
                  profile: attendee,
                  connection: conn,
                  sharedInterests: shared,
                  onTap: () => _openDetail(attendee),
                  onConnect: () => _handleConnect(attendee),
                  onOpenChat: () {
                    if (conn != null) _openChat(conn);
                  },
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildConnectionsTab({
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
    required List<Connection> incomingRequests,
    required List<Connection> activeChats,
  }) {
    return ListView(
      padding: const EdgeInsets.all(SpatiallySpacing.md),
      children: [
        if (incomingRequests.isNotEmpty) ...[
          Text(
            'INCOMING REQUESTS',
            style: SpatiallyTypography.caption(color: textSecondary).copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          SpatiallySpacing.gapVerticalSm,
          ...incomingRequests.map((req) {
            return Padding(
              padding: const EdgeInsets.only(bottom: SpatiallySpacing.sm),
              child: SpatiallyCard(
                padding: const EdgeInsets.all(SpatiallySpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: SpatiallyColors.violet.withValues(alpha: 0.15),
                          child: Text(
                            req.peerProfile.avatarInitials,
                            style: SpatiallyTypography.body(color: SpatiallyColors.violet).copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        SpatiallySpacing.gapHorizontalMd,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                req.peerProfile.displayName,
                                style: SpatiallyTypography.body(color: textPrimary).copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                req.peerProfile.headline,
                                style: SpatiallyTypography.caption(color: textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (req.lastMessage != null) ...[
                      SpatiallySpacing.gapVerticalSm,
                      Container(
                        padding: const EdgeInsets.all(SpatiallySpacing.xs),
                        decoration: BoxDecoration(
                          color: isDark ? SpatiallyColors.darkSurfaceElevated : SpatiallyColors.lightBackground,
                          borderRadius: BorderRadius.circular(SpatiallyRadius.sm),
                        ),
                        child: Text(
                          '"${req.lastMessage!}"',
                          style: SpatiallyTypography.caption(color: textSecondary).copyWith(
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                    SpatiallySpacing.gapVerticalMd,
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _connectRepository.declineConnectionRequest(req.id),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: textSecondary,
                              side: BorderSide(
                                color: isDark
                                    ? SpatiallyColors.darkBorderSubdued
                                    : SpatiallyColors.lightBorderSubdued,
                              ),
                            ),
                            child: const Text('Decline'),
                          ),
                        ),
                        SpatiallySpacing.gapHorizontalSm,
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _connectRepository.acceptConnectionRequest(req.id),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: SpatiallyColors.violet,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Accept'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
          SpatiallySpacing.gapVerticalMd,
        ],

        Text(
          'ACTIVE EVENT CHATS',
          style: SpatiallyTypography.caption(color: textSecondary).copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
        SpatiallySpacing.gapVerticalSm,

        if (activeChats.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: SpatiallySpacing.xl),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.chat_bubble_outline_rounded, size: 40, color: textSecondary.withValues(alpha: 0.4)),
                  SpatiallySpacing.gapVerticalSm,
                  Text(
                    'No active chats yet.',
                    style: SpatiallyTypography.body(color: textSecondary),
                  ),
                  SpatiallySpacing.gapVerticalXxs,
                  Text(
                    'Send a connection request to start chatting during this event.',
                    style: SpatiallyTypography.caption(color: textSecondary),
                  ),
                ],
              ),
            ),
          )
        else
          ...activeChats.map((chat) {
            return Padding(
              padding: const EdgeInsets.only(bottom: SpatiallySpacing.sm),
              child: SpatiallyCard(
                padding: const EdgeInsets.all(SpatiallySpacing.md),
                child: InkWell(
                  onTap: () => _openChat(chat),
                  borderRadius: BorderRadius.circular(SpatiallyRadius.md),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: SpatiallyColors.violet.withValues(alpha: 0.15),
                        child: Text(
                          chat.peerProfile.avatarInitials,
                          style: SpatiallyTypography.body(color: SpatiallyColors.violet).copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SpatiallySpacing.gapHorizontalMd,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    chat.peerProfile.displayName,
                                    style: SpatiallyTypography.body(color: textPrimary).copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: SpatiallyColors.spatialCyan.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(SpatiallyRadius.xs),
                                  ),
                                  child: Text(
                                    'Active',
                                    style: SpatiallyTypography.caption(color: SpatiallyColors.spatialCyan).copyWith(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SpatiallySpacing.gapVerticalXxs,
                            Text(
                              chat.lastMessage ?? 'No messages yet',
                              style: SpatiallyTypography.caption(color: textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      SpatiallySpacing.gapHorizontalSm,
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: textSecondary.withValues(alpha: 0.4),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }
}
