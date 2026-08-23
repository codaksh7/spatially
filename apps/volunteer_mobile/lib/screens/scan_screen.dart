import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/ble_observation.dart';
import '../services/ble_scanner_service.dart';
import '../services/session_state.dart';
import '../main.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final BleScannerService _scanner = BleScannerService();
  final List<BleObservation> _observations = [];
  StreamSubscription<BleObservation>? _streamSub;
  StreamSubscription<void>? _countSub;
  bool _isScanning = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initForegroundTask();
  }

  void _initForegroundTask() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'spatially_ble_scan',
        channelName: 'Spatially BLE Scanning',
        channelDescription: 'Keeps BLE scanning active in the background.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    _countSub?.cancel();
    _scanner.dispose();
    FlutterForegroundTask.stopService();
    super.dispose();
  }

  Future<void> _toggleScan() async {
    if (_isProcessing) return;
    
    setState(() {
      _isProcessing = true;
    });

    try {
      if (_isScanning) {
        await _scanner.stopScan();
        await _streamSub?.cancel();
        _streamSub = null;
        await _countSub?.cancel();
        _countSub = null;
        await FlutterForegroundTask.stopService();
        setState(() {
          _isScanning = false;
        });
      } else {
        final isBluetoothOn = await _scanner.isBluetoothOn();
        if (!isBluetoothOn && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please turn on Bluetooth to scan.')),
          );
          return;
        }

        final statuses = await _scanner.requestPermissions();
        final notificationStatus = await Permission.notification.request();
        final allGranted = statuses.values.every(
          (status) => status == PermissionStatus.granted,
        );

        if (notificationStatus != PermissionStatus.granted) {
          print('WARNING: Notification permission denied. Foreground service may not run.');
        }

        bool isIgnoring = await FlutterForegroundTask.isIgnoringBatteryOptimizations;
        if (!isIgnoring) {
          await FlutterForegroundTask.requestIgnoreBatteryOptimization();
        }

        if (!allGranted) {
          print('DEBUG: Permissions denied, not scanning.');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('BLE scanning requires Location and Bluetooth permissions.'),
              ),
            );
          }
          return;
        }
        print('DEBUG: Permissions granted, starting scan.');

        setState(() {
          _observations.clear();
          _isScanning = true;
        });

        _streamSub = _scanner.observations.listen((obs) {
          setState(() {
            _observations.add(obs);
            if (_observations.length > 50) {
              _observations.removeAt(0); // Cap list at 50 to prevent UI lag
            }
          });
        });

        _countSub = _scanner.stateStream.listen((_) {
          setState(() {});
        });

        await _scanner.startScan();
        await FlutterForegroundTask.startService(
          notificationTitle: 'Spatially',
          notificationText: 'Scanning active',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _signOut() async {
    // Stop foreground service and active scan before signing out to avoid
    // orphaned foreground services or stream subscriptions after logout.
    if (_isScanning) {
      await _scanner.stopScan();
      await _streamSub?.cancel();
      _streamSub = null;
      await _countSub?.cancel();
      _countSub = null;
      await FlutterForegroundTask.stopService();
    }
    SessionState.instance.clear();
    final supabaseInstance = Supabase.instance;
    final client = supabaseInstance.client;
    final auth = client.auth;
    await auth.signOut();
    
    // Explicitly navigate back to AuthGate. The original AuthGate from 
    // app startup was destroyed when ZoneSelectionScreen called pushReplacement,
    // so we must rebuild the route stack from scratch.
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil<void>(
        MaterialPageRoute(builder: (_) => const AuthGate()),
        (Route<dynamic> route) => false,
      );
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BLE Scanner'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: _signOut,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Scan state indicator
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              _isScanning ? 'Status: Scanning...' : 'Status: Idle',
            ),
          ),

          // Observation count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'All nearby BLE devices:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('  Active right now: ${_scanner.activeDevicesCount}'),
                Text(
                  '  Total unique seen: ${_scanner.totalUniqueSeenCount}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Spatially devices detected:',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                ),
                Text(
                  '  Active right now: ${_scanner.activeSpatiallyDevicesCount}',
                  style: const TextStyle(color: Colors.blue),
                ),
                Text(
                  '  Total unique seen: ${_scanner.totalUniqueSpatiallySeenCount}',
                  style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
                ),
                const SizedBox(height: 8),
                Text(
                  'Raw signals: ${_scanner.rawObservationsCount}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),

          // Start / Stop button
          ElevatedButton(
            onPressed: _toggleScan,
            child: Text(_isScanning ? 'Stop Scan' : 'Start Scan'),
          ),



          // Results list
          Expanded(
            child: ListView.builder(
              itemCount: _observations.length,
              itemBuilder: (context, index) {
                final obs = _observations[index];
                return ListTile(
                  tileColor: obs.isSpatiallyDevice ? Colors.blue.withOpacity(0.1) : null,
                  leading: obs.isSpatiallyDevice 
                      ? const Icon(Icons.bluetooth_connected, color: Colors.blue) 
                      : const Icon(Icons.bluetooth, color: Colors.grey),
                  title: Text(
                    obs.ephemeralId,
                    style: TextStyle(
                      fontWeight: obs.isSpatiallyDevice ? FontWeight.bold : FontWeight.normal,
                      color: obs.isSpatiallyDevice ? Colors.blue.shade900 : Colors.black,
                    ),
                  ),
                  subtitle: Text(
                    'RSSI: ${obs.rssi}  |  ${obs.scannedAt.toIso8601String()}',
                  ),
                  trailing: obs.isSpatiallyDevice 
                      ? const Text('SPATIALLY', style: TextStyle(color: Colors.blue, fontSize: 10, fontWeight: FontWeight.bold))
                      : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
