import 'package:flutter/material.dart';
import '../design_system/design_system.dart';
import '../screens/battery_check_screen.dart';

/// Global notifier controlling theme mode across the app.
final ValueNotifier<ThemeMode> appThemeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.light);

/// Top-level Application widget for Spatially Attendee Mobile.
/// 
/// Configures app-level themes, metadata, and the initial launch flow.
class SpatiallyApp extends StatelessWidget {
  const SpatiallyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeModeNotifier,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'Spatially',
          debugShowCheckedModeBanner: false,
          theme: SpatiallyTheme.lightTheme,
          darkTheme: SpatiallyTheme.darkTheme,
          themeMode: themeMode,
          home: const BatteryCheckScreen(),
        );
      },
    );
  }
}
