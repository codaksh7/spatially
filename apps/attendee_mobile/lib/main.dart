import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app_settings/app_settings.dart';
import 'battery_check_screen.dart';
import 'attendee_identity.dart';

import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';

// Native BleAdvertisingService channel — we talk to the Kotlin service directly
// via a standard MethodChannel so Flutter doesn't need to own the BLE advertiser.
const _bleServiceChannel = MethodChannel('dev.steenbakker.flutter_ble_peripheral/ble_service');

const _spatiallyServiceUuid = 'f47ac10b-58cc-4372-a567-0e02b2c3d479';

void main() async {
  // Ensure Flutter binding is ready before touching shared_preferences.
  WidgetsFlutterBinding.ensureInitialized();
  await AttendeeIdentity.init();
  
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: BatteryCheckScreen(),
    );
  }
}

class AdvertiserScreen extends StatefulWidget {
  final bool autoStart;
  const AdvertiserScreen({super.key, this.autoStart = false});

  @override
  State<AdvertiserScreen> createState() => _AdvertiserScreenState();
}

class _AdvertiserScreenState extends State<AdvertiserScreen> {
  final FlutterBlePeripheral blePeripheral = FlutterBlePeripheral();
  StreamSubscription<PeripheralState>? _btStateSub;
  bool isAdvertising = false;
  bool _isBluetoothOn = true; // assume on until we get a state update
  bool _showBluetoothBlock = false; // true if the user tried to start advertising with BT off

  @override
  void initState() {
    super.initState();
    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _toggleAdvertising();
      });
    }
    // Only use the plugin state stream to detect Bluetooth being turned off.
    // We do NOT drive isAdvertising from this stream — since advertising now lives
    // inside BleAdvertisingService (not the Flutter plugin), the plugin always
    // reports 'idle'. isAdvertising is controlled solely by user button taps.
    _btStateSub = blePeripheral.onPeripheralStateChanged?.listen((PeripheralState state) {
      if (!mounted) return;
      setState(() {
        _isBluetoothOn = state != PeripheralState.poweredOff;
        
        // Auto-dismiss the overlay if BT turns on
        if (_isBluetoothOn && _showBluetoothBlock) {
          _showBluetoothBlock = false;
        }
        
        // If BT was switched off externally while we think we're advertising, reset
        if (!_isBluetoothOn && isAdvertising) {
          isAdvertising = false;
        }
      });
    });
  }

  @override
  void dispose() {
    _btStateSub?.cancel();
    super.dispose();
  }

  Future<bool> _requestPermissions() async {
    final statuses = await [
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.notification,
    ].request();

    if (statuses[Permission.notification] != PermissionStatus.granted) {
      print('WARNING: Notification permission denied. Foreground service notification may not show.');
    }

    return statuses[Permission.bluetoothAdvertise] == PermissionStatus.granted &&
           statuses[Permission.bluetoothConnect] == PermissionStatus.granted;
  }

  /// Start the native BleAdvertisingService — this takes over from the Flutter-owned
  /// advertiser so the BLE broadcasting survives screen lock.
  Future<void> _startNativeAdvertisingService() async {
    try {
      await _bleServiceChannel.invokeMethod('startBleAdvertisingService', {
        'serviceUuid': _spatiallyServiceUuid,
        'channelId': 'spatially_ble_advertise',
        'channelName': 'Spatially BLE Advertising',
        'notificationTitle': 'Spatially',
        'notificationText': 'Advertising active',
      });
      print('DEBUG: Native BleAdvertisingService started');
    } catch (e) {
      print('ERROR starting native BleAdvertisingService: $e');
    }
  }

  /// Stop the native BleAdvertisingService.
  Future<void> _stopNativeAdvertisingService() async {
    try {
      await _bleServiceChannel.invokeMethod('stopBleAdvertisingService');
      print('DEBUG: Native BleAdvertisingService stopped');
    } catch (e) {
      print('ERROR stopping native BleAdvertisingService: $e');
    }
  }

  Future<void> _toggleAdvertising() async {
    try {
      if (isAdvertising) {
        await _stopNativeAdvertisingService();
        if (mounted) {
          setState(() {
            isAdvertising = false;
          });
        }
      } else {
        // Check Bluetooth is on before doing anything, avoiding stream lag.
        final isOn = await blePeripheral.isBluetoothOn;
        if (!isOn) {
          if (mounted) {
            setState(() {
              _showBluetoothBlock = true;
              _isBluetoothOn = false;
            });
          }
          return;
        }

        final granted = await _requestPermissions();
        if (!granted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Permissions required to advertise.')),
            );
          }
          return;
        }

        await _startNativeAdvertisingService();
        if (mounted) {
          setState(() {
            isAdvertising = true;
          });
        }
      }
    } catch (e, stackTrace) {
      print('ERROR starting/stopping advertising: $e');
      print(stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    if (_showBluetoothBlock) {
      return PopScope(
        canPop: false,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Bluetooth Required'),
            automaticallyImplyLeading: false, // Remove back button
          ),
          body: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.bluetooth_disabled, size: 80, color: Colors.redAccent),
                const SizedBox(height: 24),
                const Text(
                  'Bluetooth is off',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Spatially requires Bluetooth to broadcast your attendee beacon. Please turn it on to continue.',
                  style: TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                ElevatedButton(
                  onPressed: () => AppSettings.openAppSettings(type: AppSettingsType.bluetooth),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Open Bluetooth Settings', style: TextStyle(fontSize: 18)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Attendee BLE Advertiser')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'Spatially ',
                    style: GoogleFonts.audiowide(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextSpan(
                    text: 'for Attendee',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            Text(
              isAdvertising ? 'Status: Advertising...' : 'Status: Idle',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _toggleAdvertising,
              child: Text(isAdvertising ? 'Stop Advertising' : 'Start Advertising'),
            ),
          ],
        ),
      ),
    );
  }
}
