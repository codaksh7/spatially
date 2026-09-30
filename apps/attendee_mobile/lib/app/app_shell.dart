import 'package:flutter/material.dart';
import '../design_system/design_system.dart';
import '../features/home/home_screen.dart';
import '../features/explore/explore_screen.dart';
import '../features/map/map_screen.dart';
import '../features/passport/passport_screen.dart';
import '../features/profile/profile_screen.dart';

/// Spatially Attendee App Shell.
/// 
/// Provides the persistent 5-tab bottom navigation:
/// 1. Home
/// 2. Explore
/// 3. Map
/// 4. Passport
/// 5. Profile
/// 
/// Uses soft-edge design language, clear active states, and preserves tab state
/// across navigation switches via [IndexedStack].
class SpatiallyAppShell extends StatefulWidget {
  final int initialIndex;

  const SpatiallyAppShell({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<SpatiallyAppShell> createState() => _SpatiallyAppShellState();
}

class _SpatiallyAppShellState extends State<SpatiallyAppShell> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void _onTabSelected(int index) {
    if (_currentIndex != index) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isDark ? SpatiallyColors.darkSurface : SpatiallyColors.lightSurface;
    final borderColor = isDark ? SpatiallyColors.darkBorderSubdued : SpatiallyColors.lightBorderSubdued;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomeScreen(
            onNavigateToExplore: () => _onTabSelected(1),
            onNavigateToMap: () => _onTabSelected(2),
          ),
          ExploreScreen(
            onNavigateToMap: () => _onTabSelected(2),
          ),
          const MapScreen(isRootTab: true),
          const PassportScreen(),
          ProfileScreen(
            onNavigateToPassport: () => _onTabSelected(3),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: surfaceColor,
          border: Border(
            top: BorderSide(color: borderColor, width: 1),
          ),
          boxShadow: SpatiallyShadows.subtleShadow(isDark: isDark),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: SpatiallySpacing.xs,
              vertical: SpatiallySpacing.xs,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  index: 0,
                  label: 'Home',
                  selectedIcon: Icons.home_rounded,
                  unselectedIcon: Icons.home_outlined,
                ),
                _buildNavItem(
                  index: 1,
                  label: 'Explore',
                  selectedIcon: Icons.explore_rounded,
                  unselectedIcon: Icons.explore_outlined,
                ),
                _buildNavItem(
                  index: 2,
                  label: 'Map',
                  selectedIcon: Icons.map_rounded,
                  unselectedIcon: Icons.map_outlined,
                ),
                _buildNavItem(
                  index: 3,
                  label: 'Passport',
                  selectedIcon: Icons.confirmation_number_rounded,
                  unselectedIcon: Icons.confirmation_number_outlined,
                ),
                _buildNavItem(
                  index: 4,
                  label: 'Profile',
                  selectedIcon: Icons.person_rounded,
                  unselectedIcon: Icons.person_outline_rounded,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required String label,
    required IconData selectedIcon,
    required IconData unselectedIcon,
  }) {
    final isSelected = _currentIndex == index;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final activeColor = SpatiallyColors.violet;
    final inactiveColor = isDark ? SpatiallyColors.darkTextSecondary : SpatiallyColors.lightTextSecondary;

    return Expanded(
      child: Semantics(
        label: '$label tab',
        selected: isSelected,
        button: true,
        child: InkWell(
          onTap: () => _onTabSelected(index),
          borderRadius: SpatiallyRadius.borderSm,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? activeColor.withValues(alpha: 0.14)
                        : Colors.transparent,
                    borderRadius: SpatiallyRadius.borderFull,
                  ),
                  child: Icon(
                    isSelected ? selectedIcon : unselectedIcon,
                    color: isSelected ? activeColor : inactiveColor,
                    size: 22,
                  ),
                ),
                SpatiallySpacing.gapVerticalXxs,
                Text(
                  label,
                  style: isSelected
                      ? SpatiallyTypography.caption(color: activeColor).copyWith(
                          fontWeight: FontWeight.w600,
                        )
                      : SpatiallyTypography.caption(color: inactiveColor),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
