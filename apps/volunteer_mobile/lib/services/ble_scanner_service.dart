import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/ble_observation.dart';

class BleScannerService {
  final StreamController<BleObservation> _controller =
      StreamController<BleObservation>.broadcast();

  StreamSubscription<List<ScanResult>>? _scanSubscription;

  // _lastSeen: maps ephemeralId → last hardware timestamp (for dedup + expiry)
  final Map<String, DateTime> _lastSeen = {};

  // _activeDevices: the set of devices we consider "currently present"
  // This is separate from _lastSeen so cleanup removals don't get undone by
  // flutter_blue_plus re-delivering stale cached results in the cumulative list.
  final Set<String> _activeDevices = {};
  final Set<String> _activeSpatiallyDevices = {}; // Only tracks devices broadcasting our UUID

  // _confirmedSpatiallyIds: sticky classification — once a device has been seen
  // advertising our UUID in ANY packet, it stays "Spatially" until presence expiry.
  // Android BLE scan responses don't always include the full service UUID list in
  // every packet, so we must not flip classification based on a single missing UUID.
  final Set<String> _confirmedSpatiallyIds = {};

  // _totalUniqueSeen: cumulative count of distinct devices seen this session.
  // Only ever goes up, never decreases.
  int _totalUniqueSeen = 0;
  int _totalUniqueSpatiallySeen = 0; // Only tracks devices broadcasting our UUID

  static const String spatiallyServiceUuid = 'f47ac10b-58cc-4372-a567-0e02b2c3d479';

  static const dedupWindow = Duration(seconds: 10);
  static const presenceTimeout = Duration(seconds: 45);
  Timer? _cleanupTimer;

  int rawObservationsCount = 0;

  /// Devices we consider currently present (active). Goes up and down.
  int get activeDevicesCount => _activeDevices.length;
  int get activeSpatiallyDevicesCount => _activeSpatiallyDevices.length;

  /// Snapshot of active device IDs for the UI list. Returns a sorted copy.
  List<String> get activeDevicesSnapshot =>
      _activeDevices.toList()..sort();

  /// Total distinct devices seen since startScan() was called. Never decreases.
  int get totalUniqueSeenCount => _totalUniqueSeen;
  int get totalUniqueSpatiallySeenCount => _totalUniqueSpatiallySeen;

  final StreamController<void> _stateController =
      StreamController<void>.broadcast();

  /// Fires whenever active device count or total count changes.
  Stream<void> get stateStream => _stateController.stream;

  Stream<BleObservation> get observations => _controller.stream;

  /// Returns the detailed status map for debugging.
  Future<Map<Permission, PermissionStatus>> requestPermissions() async {
    print('--- DEBUG: Requesting permissions ---');
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse, // covers ACCESS_FINE_LOCATION fallback
    ].request();

    for (final entry in statuses.entries) {
      print('DEBUG: Permission ${entry.key} status: ${entry.value}');
    }

    return statuses;
  }

  /// Checks if the Bluetooth adapter is currently turned on.
  Future<bool> isBluetoothOn() async {
    final state = await FlutterBluePlus.adapterState.first;
    print('DEBUG: Bluetooth adapter state is: $state');
    return state == BluetoothAdapterState.on;
  }

  /// Starts BLE scanning. Each advertisement received is pushed to the
  /// [observations] stream as a [BleObservation] after deduplication.
  Future<void> startScan() async {
    _lastSeen.clear();
    _activeDevices.clear();
    _activeSpatiallyDevices.clear();
    _confirmedSpatiallyIds.clear();
    _totalUniqueSeen = 0;
    _totalUniqueSpatiallySeen = 0;
    rawObservationsCount = 0;
    _stateController.add(null);

    // Cancel any leftover subscription/timer from a previous scan session.
    await _scanSubscription?.cancel();
    _cleanupTimer?.cancel();

    _cleanupTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      final now = DateTime.now();
      bool changed = false;

      _lastSeen.removeWhere((id, lastSeenTimestamp) {
        if (now.difference(lastSeenTimestamp) > presenceTimeout) {
          print('DEBUG: Expiring $id → active will be ${_activeDevices.length - 1}');
          _activeDevices.remove(id);
          _activeSpatiallyDevices.remove(id);
          _confirmedSpatiallyIds.remove(id);
          changed = true;
          return true;
        }
        return false;
      });

      if (changed) {
        print('DEBUG: After expiry → active=${_activeDevices.length} totalUnique=$_totalUniqueSeen');
        _stateController.add(null);
      }
    });

    _scanSubscription = FlutterBluePlus.onScanResults.listen(
      (results) {
        bool stateChanged = false;

        for (final result in results) {
          rawObservationsCount++;

          if (result.rssi == -128) continue;

          final String ephemeralId = result.device.remoteId.str;
          final DateTime seenTime = result.timeStamp;
          final DateTime now = DateTime.now();

          // --- Freshness gate ---
          // flutter_blue_plus delivers a CUMULATIVE list: devices that
          // expired and were removed from _activeDevices will still appear
          // here with their old timestamps. Reject any result whose hardware
          // timestamp is older than presenceTimeout — it's a stale cache hit,
          // not a live detection.
          if (now.difference(seenTime) > presenceTimeout) {
            continue; // DEBUG ONLY print removed — was flooding terminal at ~10-15 calls/sec
          }

          final DateTime? previousLastSeen = _lastSeen[ephemeralId];

          // Check if this packet advertises the Spatially UUID.
          // Also check the sticky set: once confirmed Spatially, always Spatially
          // until the device expires. Android doesn't include service UUIDs in
          // every packet (they appear in scan response packets), so we must not
          // revert classification just because a later packet omitted the UUID.
          final seenUuidThisPacket = result.advertisementData.serviceUuids
              .any((guid) => guid.toString().toLowerCase() == spatiallyServiceUuid.toLowerCase());
          if (seenUuidThisPacket) {
            _confirmedSpatiallyIds.add(ephemeralId);
          }
          final isSpatiallyDevice = _confirmedSpatiallyIds.contains(ephemeralId);

          // Update timestamp only if this packet is newer
          if (previousLastSeen == null || seenTime.isAfter(previousLastSeen)) {
            _lastSeen[ephemeralId] = seenTime;
          }

          // Track in active set and cumulative counter
          if (!_activeDevices.contains(ephemeralId)) {
            _activeDevices.add(ephemeralId);
            _totalUniqueSeen++;
            print('DEBUG: New active device $ephemeralId → '
                'active=${_activeDevices.length} totalUnique=$_totalUniqueSeen');
            stateChanged = true;
          }

          if (isSpatiallyDevice && !_activeSpatiallyDevices.contains(ephemeralId)) {
            _activeSpatiallyDevices.add(ephemeralId);
            _totalUniqueSpatiallySeen++;
            print('DEBUG: New Spatially device $ephemeralId → '
                'spatiallyActive=${_activeSpatiallyDevices.length} spatiallyTotal=$_totalUniqueSpatiallySeen');
            stateChanged = true;
          }

          // Emit to raw observation stream (dedup: once per dedupWindow per device)
          if (previousLastSeen == null ||
              seenTime.difference(previousLastSeen) > dedupWindow) {
            print('DEBUG: Emitting observation for $ephemeralId at $seenTime (isSpatially: $isSpatiallyDevice, seenUuidThisPacket: $seenUuidThisPacket)');
            _controller.add(BleObservation(
              ephemeralId: ephemeralId,
              rssi: result.rssi,
              scannedAt: seenTime,
              isSpatiallyDevice: isSpatiallyDevice,
            ));
          }
        }

        if (stateChanged) {
          _stateController.add(null);
        }
      },
    );

    await FlutterBluePlus.startScan();
  }

  /// Stops BLE scanning and cancels the scan-results subscription.
  Future<void> stopScan() async {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    await FlutterBluePlus.stopScan();
    await _scanSubscription?.cancel();
    _scanSubscription = null;
  }

  // DEBUG ONLY - remove before production
  /// Pushes a fake observation directly into the stream.
  /// Used for emulator testing where no real BLE hardware is available.
  void injectObservation(BleObservation obs) {
    _controller.add(obs);
  }

  /// Call this when the service is no longer needed to release resources.
  Future<void> dispose() async {
    await stopScan();
    await _controller.close();
    await _stateController.close();
  }
}
