import 'package:flutter/material.dart';
import '../../../design_system/design_system.dart';
import '../../explore/models/spatially_event.dart';
import '../../map/map_screen.dart';
import '../data/event_content_repository.dart';
import '../models/spatially_booth.dart';
import '../widgets/booth_card.dart';
import 'booth_detail_screen.dart';

/// Full booths and exhibitor showcase directory for an event.
class BoothsScreen extends StatefulWidget {
  final SpatiallyEvent? event;
  final String eventId;
  final String? eventName;

  const BoothsScreen({
    super.key,
    this.event,
    required this.eventId,
    this.eventName,
  });

  @override
  State<BoothsScreen> createState() => _BoothsScreenState();
}

class _BoothsScreenState extends State<BoothsScreen> {
  final EventContentRepository _repository = EventContentRepositoryImpl();
  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  String? _errorMessage;
  List<SpatiallyBooth> _allBooths = [];
  String _searchQuery = '';
  BoothCategory? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _loadBooths();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBooths() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final booths = await _repository.getBooths(widget.eventId);
      if (mounted) {
        setState(() {
          _allBooths = booths;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _loading = false;
        });
      }
    }
  }

  List<SpatiallyBooth> get _filteredBooths {
    return _allBooths.where((b) {
      if (_selectedCategory != null && b.category != _selectedCategory) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchesName = b.name.toLowerCase().contains(q);
        final matchesCompany = b.companyOrOrg.toLowerCase().contains(q);
        final matchesNumber = b.boothNumber.toLowerCase().contains(q);
        final matchesRoom = b.roomName.toLowerCase().contains(q);
        final matchesTag = b.tags.any((t) => t.toLowerCase().contains(q));
        if (!matchesName && !matchesCompany && !matchesNumber && !matchesRoom && !matchesTag) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  void _openMapForBooth(SpatiallyBooth booth) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MapScreen(
          initialEvent: widget.event,
          initialZoneId: booth.zoneId,
          initialPoiId: booth.poiId,
        ),
      ),
    );
  }

  void _openBoothDetail(SpatiallyBooth booth) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BoothDetailScreen(
          booth: booth,
          event: widget.event,
          onNavigateToMap: () => _openMapForBooth(booth),
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

    final displayTitle = widget.eventName != null ? 'Booths • ${widget.eventName}' : 'Exhibition Booths';

    return Scaffold(
      appBar: SpatiallyAppBar(
        title: displayTitle,
        automaticallyImplyLeading: true,
      ),
      body: RefreshIndicator(
        onRefresh: _loadBooths,
        color: SpatiallyColors.violet,
        child: Column(
          children: [
            // Search & Category Header
            Container(
              padding: const EdgeInsets.fromLTRB(
                SpatiallySpacing.md,
                SpatiallySpacing.sm,
                SpatiallySpacing.md,
                SpatiallySpacing.xs,
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val.trim()),
                    decoration: InputDecoration(
                      hintText: 'Search booths, exhibitors, tech...',
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

                  // Category filter pills
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterPill(
                          label: 'All (${_allBooths.length})',
                          isSelected: _selectedCategory == null,
                          onTap: () => setState(() => _selectedCategory = null),
                        ),
                        SpatiallySpacing.gapHorizontalXs,
                        _buildFilterPill(
                          label: 'AI & ML',
                          isSelected: _selectedCategory == BoothCategory.ai,
                          onTap: () => setState(() => _selectedCategory = BoothCategory.ai),
                        ),
                        SpatiallySpacing.gapHorizontalXs,
                        _buildFilterPill(
                          label: 'Hardware & IoT',
                          isSelected: _selectedCategory == BoothCategory.hardware,
                          onTap: () => setState(() => _selectedCategory = BoothCategory.hardware),
                        ),
                        SpatiallySpacing.gapHorizontalXs,
                        _buildFilterPill(
                          label: 'Startups',
                          isSelected: _selectedCategory == BoothCategory.startup,
                          onTap: () => setState(() => _selectedCategory = BoothCategory.startup),
                        ),
                        SpatiallySpacing.gapHorizontalXs,
                        _buildFilterPill(
                          label: 'Developer Tools',
                          isSelected: _selectedCategory == BoothCategory.developerTools,
                          onTap: () => setState(() => _selectedCategory = BoothCategory.developerTools),
                        ),
                        SpatiallySpacing.gapHorizontalXs,
                        _buildFilterPill(
                          label: 'Showcase',
                          isSelected: _selectedCategory == BoothCategory.showcase,
                          onTap: () => setState(() => _selectedCategory = BoothCategory.showcase),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

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
        child: SpatiallyLoadingState(message: 'Loading booths...'),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: SpatiallyErrorState(
          error: 'Unable to load booths.',
          onRetry: _loadBooths,
        ),
      );
    }

    final filtered = _filteredBooths;
    if (filtered.isEmpty) {
      return Center(
        child: SpatiallyEmptyState(
          icon: Icons.storefront_outlined,
          title: 'No booths found',
          description: _searchQuery.isNotEmpty
              ? 'No booths match your search criteria.'
              : 'There are no booths in this category.',
        ),
      );
    }

    return ListView.separated(
      padding: SpatiallySpacing.screenPadding,
      itemCount: filtered.length + 1,
      separatorBuilder: (ctx, index) => SpatiallySpacing.gapVerticalMd,
      itemBuilder: (context, index) {
        if (index == filtered.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: SpatiallySpacing.md),
            child: Center(
              child: Text(
                'Demo Exhibition Fixture • Real-time booth check-in coming soon',
                style: SpatiallyTypography.caption(color: textSecondary).copyWith(fontSize: 11),
              ),
            ),
          );
        }

        final booth = filtered[index];
        return BoothCard(
          booth: booth,
          onTap: () => _openBoothDetail(booth),
          onMapTap: () => _openMapForBooth(booth),
        );
      },
    );
  }

  Widget _buildFilterPill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const color = SpatiallyColors.violet;

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
