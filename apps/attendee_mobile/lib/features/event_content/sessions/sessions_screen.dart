import 'dart:async';
import 'package:flutter/material.dart';
import '../../../design_system/design_system.dart';
import '../../explore/models/spatially_event.dart';
import '../../map/map_screen.dart';
import '../data/event_content_repository.dart';
import '../models/spatially_session.dart';
import '../widgets/session_card.dart';
import 'session_detail_screen.dart';

/// Full sessions directory for an event.
/// 
/// Supports status filtering (All, Live, Upcoming, Completed), category filtering,
/// search, and direct navigation to Session Details and Venue Map.
class SessionsScreen extends StatefulWidget {
  final SpatiallyEvent? event;
  final String eventId;
  final String? eventName;
  final EventContentRepository? repository;

  const SessionsScreen({
    super.key,
    this.event,
    required this.eventId,
    this.eventName,
    this.repository,
  });

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  late final EventContentRepository _repository;
  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  String? _errorMessage;
  List<SpatiallySession> _allSessions = [];
  String _searchQuery = '';
  SessionStatus? _selectedStatus;
  SessionCategory? _selectedCategory;

  Timer? _tickerTimer;
  AppLifecycleListener? _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? EventContentRepositoryImpl();
    _loadSessions();
    _startTicker();
    _lifecycleListener = AppLifecycleListener(
      onResume: () {
        if (mounted) {
          setState(() {}); // Immediately re-evaluate temporal session states on resume
          _loadSessions(silent: true);
        }
      },
    );
  }

  void _startTicker() {
    _tickerTimer?.cancel();
    // Re-evaluates temporal status (Upcoming -> Live -> Completed) every 30 seconds
    _tickerTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
    _lifecycleListener?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSessions({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    }

    try {
      final sessions = await _repository.getSessions(widget.eventId);
      if (mounted) {
        setState(() {
          _allSessions = sessions;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted && !silent) {
        setState(() {
          _errorMessage = e.toString();
          _loading = false;
        });
      }
    }
  }

  List<SpatiallySession> get _filteredSessions {
    return _allSessions.where((s) {
      // Status filter
      if (_selectedStatus != null && s.status != _selectedStatus) {
        return false;
      }
      // Category filter
      if (_selectedCategory != null && s.category != _selectedCategory) {
        return false;
      }
      // Search query
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchesTitle = s.title.toLowerCase().contains(q);
        final matchesSpeaker = s.speaker.toLowerCase().contains(q);
        final matchesRoom = s.roomName.toLowerCase().contains(q);
        final matchesTag = s.tags.any((t) => t.toLowerCase().contains(q));
        if (!matchesTitle && !matchesSpeaker && !matchesRoom && !matchesTag) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  void _openMapForSession(SpatiallySession session) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MapScreen(
          initialEvent: widget.event,
          initialZoneId: session.zoneId,
          initialPoiId: session.poiId,
        ),
      ),
    );
  }

  void _openSessionDetail(SpatiallySession session) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SessionDetailScreen(
          session: session,
          event: widget.event,
          onNavigateToMap: () => _openMapForSession(session),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = isDark ? SpatiallyColors.darkTextPrimary : SpatiallyColors.lightTextPrimary;
    final textSecondary = isDark ? SpatiallyColors.darkTextSecondary : SpatiallyColors.lightTextSecondary;

    final displayTitle = widget.eventName != null ? 'Sessions • ${widget.eventName}' : 'Event Sessions';

    return Scaffold(
      appBar: SpatiallyAppBar(
        title: displayTitle,
        automaticallyImplyLeading: true,
      ),
      body: RefreshIndicator(
        onRefresh: _loadSessions,
        color: SpatiallyColors.violet,
        child: Column(
          children: [
            // Search & Filter Header
            Container(
              padding: const EdgeInsets.fromLTRB(
                SpatiallySpacing.md,
                SpatiallySpacing.sm,
                SpatiallySpacing.md,
                SpatiallySpacing.xs,
              ),
              child: Column(
                children: [
                  // Search Input
                  TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val.trim()),
                    decoration: InputDecoration(
                      hintText: 'Search sessions, speakers, rooms...',
                      hintStyle: SpatiallyTypography.secondary(color: textSecondary),
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      filled: true,
                      fillColor: isDark ? SpatiallyColors.darkSurface : SpatiallyColors.lightSurface,
                      border: OutlineInputBorder(
                        borderRadius: SpatiallyRadius.borderSm,
                        borderSide: BorderSide(
                          color: isDark ? SpatiallyColors.darkBorderSubdued : SpatiallyColors.lightBorderSubdued,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: SpatiallyRadius.borderSm,
                        borderSide: BorderSide(
                          color: isDark ? SpatiallyColors.darkBorderSubdued : SpatiallyColors.lightBorderSubdued,
                        ),
                      ),
                    ),
                  ),

                  SpatiallySpacing.gapVerticalSm,

                  // Status filter pills
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterPill(
                          label: 'All (${_allSessions.length})',
                          isSelected: _selectedStatus == null,
                          onTap: () => setState(() => _selectedStatus = null),
                        ),
                        SpatiallySpacing.gapHorizontalXs,
                        _buildFilterPill(
                          label: 'Live Now',
                          isSelected: _selectedStatus == SessionStatus.live,
                          accentColor: SpatiallyColors.error,
                          onTap: () => setState(() => _selectedStatus = SessionStatus.live),
                        ),
                        SpatiallySpacing.gapHorizontalXs,
                        _buildFilterPill(
                          label: 'Upcoming',
                          isSelected: _selectedStatus == SessionStatus.upcoming,
                          accentColor: SpatiallyColors.violet,
                          onTap: () => setState(() => _selectedStatus = SessionStatus.upcoming),
                        ),
                        SpatiallySpacing.gapHorizontalXs,
                        _buildFilterPill(
                          label: 'Completed',
                          isSelected: _selectedStatus == SessionStatus.completed,
                          onTap: () => setState(() => _selectedStatus = SessionStatus.completed),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Content List
            Expanded(
              child: _buildContent(context, textPrimary, textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, Color textPrimary, Color textSecondary) {
    if (_loading) {
      return const Center(
        child: SpatiallyLoadingState(message: 'Loading sessions...'),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: SpatiallyErrorState(
          error: 'Unable to load sessions.',
          onRetry: _loadSessions,
        ),
      );
    }

    final filtered = _filteredSessions;
    if (filtered.isEmpty) {
      return Center(
        child: SpatiallyEmptyState(
          icon: Icons.event_busy_rounded,
          title: 'No sessions found',
          description: _searchQuery.isNotEmpty
              ? 'No sessions matched "$_searchQuery".'
              : 'There are no sessions in this category yet.',
        ),
      );
    }

    return ListView.separated(
      padding: SpatiallySpacing.screenPadding,
      itemCount: filtered.length + 1, // +1 for honest demo disclaimer footer
      separatorBuilder: (ctx, index) => SpatiallySpacing.gapVerticalMd,
      itemBuilder: (context, index) {
        if (index == filtered.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: SpatiallySpacing.md),
            child: Center(
              child: Text(
                'Demo Agenda Fixture • Real-time backend sync coming soon',
                style: SpatiallyTypography.caption(color: textSecondary).copyWith(fontSize: 11),
              ),
            ),
          );
        }

        final session = filtered[index];
        return SessionCard(
          session: session,
          onTap: () => _openSessionDetail(session),
          onMapTap: () => _openMapForSession(session),
        );
      },
    );
  }

  Widget _buildFilterPill({
    required String label,
    required bool isSelected,
    Color? accentColor,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = accentColor ?? SpatiallyColors.violet;

    return InkWell(
      onTap: onTap,
      borderRadius: SpatiallyRadius.borderFull,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.16)
              : (isDark ? SpatiallyColors.darkSurface : SpatiallyColors.lightSurface),
          borderRadius: SpatiallyRadius.borderFull,
          border: Border.all(
            color: isSelected ? color : (isDark ? SpatiallyColors.darkBorderSubdued : SpatiallyColors.lightBorderSubdued),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: SpatiallyTypography.caption(
            color: isSelected ? color : (isDark ? SpatiallyColors.darkTextSecondary : SpatiallyColors.lightTextSecondary),
          ).copyWith(fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal),
        ),
      ),
    );
  }
}
