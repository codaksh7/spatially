import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/session_state.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  
  bool _isProcessing = false;
  String? _statusMessage;
  Color _statusColor = Colors.black;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleBarcode(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final code = barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Looking up ticket...';
      _statusColor = Colors.blue;
    });

    try {
      final supabase = Supabase.instance.client;
      
      // Look up ticket by ticket_code
      final ticketResponse = await supabase
          .from('tickets')
          .select('*, events(name)')
          .eq('ticket_code', code)
          .maybeSingle();

      if (!mounted) return;

      if (ticketResponse == null) {
        setState(() {
          _statusMessage = 'Invalid ticket';
          _statusColor = Colors.red;
        });
      } else {
        final ticketEventId = ticketResponse['event_id'] as String?;
        final currentEventId = SessionState.instance.eventId;

        if (ticketEventId != currentEventId) {
          setState(() {
            _statusMessage = 'Ticket is for a different event';
            _statusColor = Colors.red;
          });
        } else {
          final status = ticketResponse['status'] as String?;
          if (status == 'checked_in') {
            setState(() {
              _statusMessage = 'Already checked in';
              _statusColor = Colors.orange;
            });
          } else if (status == 'purchased') {
            final eventName = (ticketResponse['events'] as Map?)?['name'] ?? 'Event';
            
            // Check in the ticket
            await supabase
                .from('tickets')
                .update({
                  'status': 'checked_in',
                  'checked_in_at': DateTime.now().toIso8601String(),
                  'checked_in_by': SessionState.instance.volunteerId,
                })
                .eq('id', ticketResponse['id']);

            if (mounted) {
              setState(() {
                _statusMessage = 'Checked in successfully!\n$eventName';
                _statusColor = Colors.green;
              });
            }
          } else {
            setState(() {
              _statusMessage = 'Invalid ticket status: $status';
              _statusColor = Colors.red;
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Error checking ticket';
          _statusColor = Colors.red;
        });
      }
    } finally {
      // Delay before resetting to allow user to read the message
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusMessage = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                text: 'for Volunteer',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: MobileScanner(
              controller: _controller,
              onDetect: _handleBarcode,
            ),
          ),
          Expanded(
            flex: 1,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  _statusMessage ?? 'Align QR code within the frame',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _statusColor,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
