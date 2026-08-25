import 'package:flutter/material.dart';
import 'package:battery_plus/battery_plus.dart';
import 'event_list_screen.dart';
import 'package:google_fonts/google_fonts.dart';

class BatteryCheckScreen extends StatefulWidget {
  const BatteryCheckScreen({super.key});

  @override
  State<BatteryCheckScreen> createState() => _BatteryCheckScreenState();
}

class _BatteryCheckScreenState extends State<BatteryCheckScreen> {
  bool _checking = true;
  int? _batteryLevel;

  @override
  void initState() {
    super.initState();
    _checkBattery();
  }

  Future<void> _checkBattery() async {
    try {
      final battery = Battery();
      final level = await battery.batteryLevel;
      if (!mounted) return;
      
      if (level >= 50) {
        _proceed();
      } else {
        setState(() {
          _checking = false;
          _batteryLevel = level;
        });
      }
    } catch (e) {
      print('DEBUG: Failed to check battery level: $e');
      // If we can't check the battery (e.g. unsupported platform), just proceed.
      _proceed();
    }
  }

  void _proceed() {
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const EventListScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'Spatially ',
                style: GoogleFonts.audiowide(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextSpan(
                text: 'for Attendee',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ],
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.battery_alert, size: 80, color: Colors.orange),
            const SizedBox(height: 24),
            Text(
              'Battery is at $_batteryLevel%.',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Please charge to at least 50% before the event starts. '
              'Continuous BLE advertising requires sufficient power.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: _proceed,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Continue Anyway', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}
