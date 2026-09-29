import 'dart:async';
import 'package:flutter/material.dart';
import '../../design_system/design_system.dart';
import '../../services/offline_service.dart';
import 'data/lost_found_repository.dart';
import 'models/safety_models.dart';
import 'report_item_screen.dart';
import 'widgets/lost_found_item_card.dart';

/// Full Lost & Found directory for attendees at an active event.
class LostFoundScreen extends StatefulWidget {
  final String eventId;
  final String eventName;

  const LostFoundScreen({
    super.key,
    required this.eventId,
    required this.eventName,
  });

  @override
  State<LostFoundScreen> createState() => _LostFoundScreenState();
}

enum _FilterTab {
  all,
  lost,
  found,
  myReports,
}

class _LostFoundScreenState extends State<LostFoundScreen> {
  final LostFoundRepository _repository = LostFoundRepositoryImpl();

  _FilterTab _selectedTab = _FilterTab.all;
  List<LostFoundReport> _reports = [];
  bool _isLoading = true;
  String? _errorMessage;
  StreamSubscription<List<LostFoundReport>>? _streamSub;

  @override
  void initState() {
    super.initState();
    _loadReports();
    _streamSub = _repository.getReportsStream(widget.eventId).listen(
      (_) {
        if (mounted) _loadReports();
      },
      onError: (err) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = err?.toString() ??
                'Lost & Found digital logging service is currently unavailable for this event. Please report or claim items in person at the Central Help Desk (Room 712 Foyer).';
          });
        }
      },
    );
    OfflineService().isOnlineNotifier.addListener(_onOnlineChanged);
  }

  void _onOnlineChanged() {
    if (mounted) _loadReports();
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    OfflineService().isOnlineNotifier.removeListener(_onOnlineChanged);
    super.dispose();
  }

  Future<void> _loadReports() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await OfflineService().checkConnectivity();
      LostFoundType? type;
      bool onlyMine = false;

      switch (_selectedTab) {
        case _FilterTab.all:
          type = null;
          break;
        case _FilterTab.lost:
          type = LostFoundType.lost;
          break;
        case _FilterTab.found:
          type = LostFoundType.found;
          break;
        case _FilterTab.myReports:
          onlyMine = true;
          break;
      }

      final items = await _repository.getReports(
        widget.eventId,
        type: type,
        onlyMyReports: onlyMine,
      );

      if (mounted) {
        setState(() {
          _reports = items;
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _reports = [];
          _isLoading = false;
          _errorMessage = e is LostFoundUnavailableException
              ? e.message
              : 'Lost & Found digital logging service is currently unavailable for this event. Please report or claim items in person at the Central Help Desk (Room 712 Foyer).';
        });
      }
    }
  }

  Future<void> _openReportFlow(LostFoundType type) async {
    final result = await Navigator.of(context).push<LostFoundReport>(
      MaterialPageRoute(
        builder: (_) => ReportItemScreen(
          eventId: widget.eventId,
          eventName: widget.eventName,
          initialType: type,
        ),
      ),
    );

    if (result != null && mounted) {
      _loadReports();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = isDark ? SpatiallyColors.darkTextPrimary : SpatiallyColors.lightTextPrimary;
    final textSecondary = isDark ? SpatiallyColors.darkTextSecondary : SpatiallyColors.lightTextSecondary;

    return Scaffold(
      appBar: SpatiallyAppBar(
        title: 'Lost & Found',
        automaticallyImplyLeading: true,
      ),
      body: RefreshIndicator(
        onRefresh: _loadReports,
        color: SpatiallyColors.violet,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: SpatiallySpacing.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: OfflineService().isOnlineNotifier,
                builder: (context, isOnline, _) {
                  if (isOnline) return const SizedBox.shrink();
                  return const SpatiallyOfflineBanner(
                    message: 'Working offline. Drafted reports will auto-sync upon reconnection.',
                  );
                },
              ),

              // Event & Retention Policy Banner
              Container(
                padding: const EdgeInsets.all(SpatiallySpacing.md),
                decoration: BoxDecoration(
                  color: isDark ? SpatiallyColors.darkSurfaceElevated : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(SpatiallyRadius.md),
                  border: Border.all(
                    color: isDark ? SpatiallyColors.darkBorderSubdued : SpatiallyColors.lightBorderSubdued,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.inventory_2_outlined, color: SpatiallyColors.violet, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.eventName,
                            style: SpatiallyTypography.subheading(color: textPrimary).copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Official event lost property is held and logged at Central Help Desk in Room 712 Foyer. Unclaimed items are securely retained for 48 hours post-event before transfer to campus administration.',
                      style: SpatiallyTypography.caption(color: textSecondary).copyWith(
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),

              SpatiallySpacing.gapVerticalMd,

              // Action Buttons: Report Lost or Found
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _openReportFlow(LostFoundType.lost),
                      icon: const Icon(Icons.search_rounded, size: 16),
                      label: const Text('Report Lost Item'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626), // Red
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(SpatiallyRadius.sm),
                        ),
                      ),
                    ),
                  ),
                  SpatiallySpacing.gapHorizontalMd,
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _openReportFlow(LostFoundType.found),
                      icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                      label: const Text('Report Found Item'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669), // Emerald
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(SpatiallyRadius.sm),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              SpatiallySpacing.gapVerticalLg,

              // Filter Tabs
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildTabChip('All Items', _FilterTab.all, isDark, textPrimary, textSecondary),
                    const SizedBox(width: 8),
                    _buildTabChip('Lost Items', _FilterTab.lost, isDark, textPrimary, textSecondary),
                    const SizedBox(width: 8),
                    _buildTabChip('Found Items', _FilterTab.found, isDark, textPrimary, textSecondary),
                    const SizedBox(width: 8),
                    _buildTabChip('My Reports', _FilterTab.myReports, isDark, textPrimary, textSecondary),
                  ],
                ),
              ),

              SpatiallySpacing.gapVerticalMd,

              // Items Feed or States
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: SpatiallyErrorState(
                    title: 'Service Unavailable',
                    error: _errorMessage!,
                    onRetry: _loadReports,
                    retryLabel: 'Retry Connection',
                  ),
                )
              else if (_reports.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: SpatiallyEmptyState(
                    title: _selectedTab == _FilterTab.myReports
                        ? 'No Reports Submitted'
                        : 'No Items Logged',
                    description: _selectedTab == _FilterTab.myReports
                        ? 'You have not submitted any lost or found reports for this event.'
                        : 'No items currently match this category filter.',
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _reports.length,
                  separatorBuilder: (_, _) => SpatiallySpacing.gapVerticalMd,
                  itemBuilder: (context, index) {
                    return LostFoundItemCard(report: _reports[index]);
                  },
                ),

              SpatiallySpacing.gapVerticalXxl,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabChip(
    String label,
    _FilterTab tab,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
  ) {
    final isSelected = _selectedTab == tab;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedTab = tab;
          });
          _loadReports();
        }
      },
      selectedColor: SpatiallyColors.violet,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : textPrimary,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        fontSize: 12,
      ),
      backgroundColor: isDark ? SpatiallyColors.darkSurface : SpatiallyColors.lightSurface,
    );
  }
}
