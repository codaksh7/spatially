import 'package:flutter/material.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: AdvertiserScreen(),
    );
  }
}

class AdvertiserScreen extends StatefulWidget {
  const AdvertiserScreen({super.key});

  @override
  State<AdvertiserScreen> createState() => _AdvertiserScreenState();
}

class _AdvertiserScreenState extends State<AdvertiserScreen> {
  final FlutterBlePeripheral blePeripheral = FlutterBlePeripheral();
  final String serviceUuid = 'f47ac10b-58cc-4372-a567-0e02b2c3d479';
  bool isAdvertising = false;

  @override
  void initState() {
    super.initState();
    // Listen to advertising state changes
    blePeripheral.onPeripheralStateChanged?.listen((PeripheralState state) {
      setState(() {
        isAdvertising = state == PeripheralState.advertising;
      });
    });
  }

  Future<bool> _requestPermissions() async {
    final statuses = await [
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
    ].request();

    return statuses.values.every((status) => status == PermissionStatus.granted);
  }

  Future<void> _toggleAdvertising() async {
    try {
      if (isAdvertising) {
        await blePeripheral.stop();
        setState(() {
          isAdvertising = false;
        });
      } else {
        final granted = await _requestPermissions();
        if (!granted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Permissions required to advertise.')),
            );
          }
          return;
        }

        final AdvertiseData advertiseData = AdvertiseData(
          serviceUuid: serviceUuid,
          includeDeviceName: false,
        );

        await blePeripheral.start(advertiseData: advertiseData);
        setState(() {
          isAdvertising = true;
        });
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
    return Scaffold(
      appBar: AppBar(title: const Text('Attendee BLE Advertiser')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
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
