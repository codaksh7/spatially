import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import '../../../design_system/design_system.dart';

/// Compact, real-time Spatial Beacon status row for the Home screen.
///
/// Communicates BLE presence state honestly:
/// - [PeripheralState.poweredOff]: Bluetooth is off, prompts to enable.
/// - [PeripheralState.advertising]: Actively broadcasting attendee beacon.
/// - [PeripheralState.idle] / other: Standby, ready for venue check-in.
class HomeBeaconStatus extends StatefulWidget {
  const HomeBeaconStatus({super.key});

  @override
  State<HomeBeaconStatus> createState() => _HomeBeaconStatusState();
}

class _HomeBeaconStatusState extends State<HomeBeaconStatus> {
  final FlutterBlePeripheral _blePeripheral = FlutterBlePeripheral();
  StreamSubscription<PeripheralState>? _sub;
  PeripheralState _state = PeripheralState.idle;

  @override
  void initState() {
    super.initState();
    _sub = _blePeripheral.onPeripheralStateChanged?.listen((state) {
      if (mounted) {
        setState(() {
          _state = state;
        });
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary =
        isDark ? SpatiallyColors.darkTextPrimary : SpatiallyColors.lightTextPrimary;
    final textSecondary =
        isDark ? SpatiallyColors.darkTextSecondary : SpatiallyColors.lightTextSecondary;
    final border =
        isDark ? SpatiallyColors.darkBorderSubdued : SpatiallyColors.lightBorderSubdued;
    final surface = isDark ? SpatiallyColors.darkSurface : SpatiallyColors.lightSurface;

    final bool isBtOff = _state == PeripheralState.poweredOff;
    final bool isAdvertising = _state == PeripheralState.advertising;

    final String title = isBtOff
        ? 'Bluetooth Disabled'
        : (isAdvertising ? 'Beacon Active' : 'Spatial Beacon');

    final String subtitle = isBtOff
        ? 'Turn on Bluetooth for venue presence'
        : (isAdvertising
            ? 'Broadcasting attendee presence'
            : 'Standby · Ready at venue');

    final String badgeLabel = isBtOff
        ? 'OFFLINE'
        : (isAdvertising ? 'ACTIVE' : 'READY');

    final SpatiallyBadgeVariant badgeVariant = isBtOff
        ? SpatiallyBadgeVariant.custom
        : (isAdvertising ? SpatiallyBadgeVariant.live : SpatiallyBadgeVariant.idle);

    final Color? badgeCustomColor = isBtOff ? SpatiallyColors.warning : null;

    final Color iconColor = isBtOff
        ? SpatiallyColors.warning
        : SpatiallyColors.spatialCyan;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: SpatiallyRadius.borderSm,
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          // Spatial signal icon
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: SpatiallyRadius.borderXs,
            ),
            child: Icon(
              isBtOff ? Icons.bluetooth_disabled_rounded : Icons.sensors_rounded,
              size: 18,
              color: iconColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: SpatiallyTypography.secondaryMedium(color: textPrimary),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: SpatiallyTypography.caption(color: textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SpatiallyStatusBadge(
            label: badgeLabel,
            variant: badgeVariant,
            customColor: badgeCustomColor,
            showDot: true,
          ),
        ],
      ),
    );
  }
}
