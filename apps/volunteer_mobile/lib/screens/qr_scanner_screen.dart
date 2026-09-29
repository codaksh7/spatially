import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/ticket_check_in_result.dart';
import '../repositories/ticket_check_in_repository.dart';
import '../services/session_state.dart';

enum QrFeedbackType {
  idle,
  verifying,
  success,
  alreadyCheckedIn,
  eventMismatch,
  invalidTicket,
  unauthorized,
  offlineQueued,
  error,
}

class QrFeedback {
  final QrFeedbackType type;
  final String title;
  final String message;
  final String? ticketCode;

  const QrFeedback({
    required this.type,
    required this.title,
    required this.message,
    this.ticketCode,
  });
}

class QrScannerScreen extends StatefulWidget {
  final TicketCheckInRepository? repository;

  const QrScannerScreen({super.key, this.repository});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  late final TicketCheckInRepository _repository;
  bool _isProcessing = false;
  QrFeedback? _feedback;
  int _pendingOfflineCount = 0;
  Timer? _autoResetTimer;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? TicketCheckInRepositoryImpl();
    _loadPendingCount();
  }

  Future<void> _loadPendingCount() async {
    final count = await _repository.getPendingCheckInsCount();
    if (mounted) {
      setState(() {
        _pendingOfflineCount = count;
      });
    }
  }

  @override
  void dispose() {
    _autoResetTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _resetScan() {
    _autoResetTimer?.cancel();
    if (mounted) {
      setState(() {
        _isProcessing = false;
        _feedback = null;
      });
    }
  }

  void _scheduleAutoReset() {
    _autoResetTimer?.cancel();
    _autoResetTimer = Timer(const Duration(milliseconds: 3500), () {
      _resetScan();
    });
  }

  Future<void> _handleBarcode(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final code = barcodes.first.rawValue?.trim();
    if (code == null || code.isEmpty) return;

    final eventId = SessionState.instance.eventId;
    if (eventId == null) {
      setState(() {
        _feedback = const QrFeedback(
          type: QrFeedbackType.error,
          title: 'No Active Event',
          message: 'Please select an event before scanning attendee passes.',
        );
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _feedback = const QrFeedback(
        type: QrFeedbackType.verifying,
        title: 'Verifying Ticket',
        message: 'Communicating with Spatially server...',
      );
    });

    try {
      // Atomic check-in via server RPC with row-locking and authorization
      final TicketCheckInResult result = await _repository.checkInTicket(
        ticketCode: code,
        eventId: eventId,
      );

      if (!mounted) return;

      if (result.isOfflineQueued) {
        setState(() {
          _feedback = QrFeedback(
            type: QrFeedbackType.offlineQueued,
            title: 'Queued Offline',
            message: 'Check-in recorded locally. Will sync automatically upon reconnecting.',
            ticketCode: code,
          );
        });
        await _loadPendingCount();
        _scheduleAutoReset();
      } else if (result.success) {
        final eventTitle = result.eventName ?? SessionState.instance.eventName ?? 'Event';
        setState(() {
          _feedback = QrFeedback(
            type: QrFeedbackType.success,
            title: 'Admission Granted',
            message: 'Valid entry for $eventTitle.',
            ticketCode: code,
          );
        });
        _scheduleAutoReset();
      } else {
        switch (result.errorCode) {
          case 'ALREADY_CHECKED_IN':
            setState(() {
              _feedback = QrFeedback(
                type: QrFeedbackType.alreadyCheckedIn,
                title: 'Already Admitted',
                message: 'This attendee pass has already been checked in.',
                ticketCode: code,
              );
            });
            break;
          case 'EVENT_MISMATCH':
            setState(() {
              _feedback = QrFeedback(
                type: QrFeedbackType.eventMismatch,
                title: 'Event Mismatch',
                message: 'This pass belongs to a different event schedule.',
                ticketCode: code,
              );
            });
            break;
          case 'TICKET_NOT_FOUND':
            setState(() {
              _feedback = QrFeedback(
                type: QrFeedbackType.invalidTicket,
                title: 'Invalid Pass',
                message: 'Ticket code was not recognized in the system database.',
                ticketCode: code,
              );
            });
            break;
          case 'UNAUTHORIZED':
            setState(() {
              _feedback = const QrFeedback(
                type: QrFeedbackType.unauthorized,
                title: 'Unauthorized Shift',
                message: 'Your volunteer account is not authorized for this event.',
              );
            });
            break;
          default:
            setState(() {
              _feedback = QrFeedback(
                type: QrFeedbackType.error,
                title: 'Check-In Unsuccessful',
                message: result.message.isNotEmpty
                    ? result.message
                    : 'Ticket check-in could not be completed.',
                ticketCode: code,
              );
            });
            break;
        }
        _scheduleAutoReset();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _feedback = const QrFeedback(
            type: QrFeedbackType.error,
            title: 'Network Communication Error',
            message: 'Unable to connect to verification server. Please retry.',
          );
        });
        _scheduleAutoReset();
      }
    }
  }

  Future<void> _syncPending() async {
    setState(() {
      _isProcessing = true;
      _feedback = const QrFeedback(
        type: QrFeedbackType.verifying,
        title: 'Synchronizing Queue',
        message: 'Uploading offline check-in records to server...',
      );
    });

    final synced = await _repository.flushOfflineCheckIns();
    await _loadPendingCount();

    if (mounted) {
      setState(() {
        _feedback = QrFeedback(
          type: QrFeedbackType.success,
          title: 'Sync Complete',
          message: 'Successfully processed $synced queued offline tickets.',
        );
      });
      _scheduleAutoReset();
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
                text: 'Pass Verification',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (_pendingOfflineCount > 0)
            IconButton(
              icon: Badge(
                label: Text('$_pendingOfflineCount'),
                child: const Icon(Icons.cloud_upload_outlined),
              ),
              tooltip: 'Sync $_pendingOfflineCount pending check-ins',
              onPressed: _isProcessing ? null : _syncPending,
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 5,
            child: Stack(
              alignment: Alignment.center,
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: _handleBarcode,
                ),
                // Visual scan target overlay
                Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _isProcessing ? Colors.blueAccent : Colors.white70,
                      width: 2.5,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: _buildFeedbackView(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackView() {
    final feedback = _feedback;

    if (feedback == null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.qr_code_scanner_rounded, size: 40, color: Colors.blue.shade700),
          const SizedBox(height: 8),
          Text(
            'Ready to Scan',
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Position the attendee QR ticket code inside the frame.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
          ),
          if (_pendingOfflineCount > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Text(
                '$_pendingOfflineCount offline check-ins queued for sync',
                style: TextStyle(fontSize: 11, color: Colors.orange.shade900, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      );
    }

    if (feedback.type == QrFeedbackType.verifying) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(height: 12),
          Text(
            feedback.title,
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            feedback.message,
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      );
    }

    Color cardBg;
    Color borderColor;
    Color iconColor;
    IconData icon;
    String buttonText;

    switch (feedback.type) {
      case QrFeedbackType.success:
        cardBg = Colors.green.shade50;
        borderColor = Colors.green.shade300;
        iconColor = Colors.green.shade700;
        icon = Icons.check_circle_rounded;
        buttonText = 'Scan Next Pass';
        break;
      case QrFeedbackType.alreadyCheckedIn:
        cardBg = Colors.orange.shade50;
        borderColor = Colors.orange.shade300;
        iconColor = Colors.orange.shade800;
        icon = Icons.history_toggle_off_rounded;
        buttonText = 'Dismiss & Scan Next';
        break;
      case QrFeedbackType.eventMismatch:
        cardBg = Colors.red.shade50;
        borderColor = Colors.red.shade300;
        iconColor = Colors.red.shade700;
        icon = Icons.wrong_location_outlined;
        buttonText = 'Dismiss';
        break;
      case QrFeedbackType.invalidTicket:
        cardBg = Colors.red.shade50;
        borderColor = Colors.red.shade300;
        iconColor = Colors.red.shade700;
        icon = Icons.cancel_outlined;
        buttonText = 'Dismiss';
        break;
      case QrFeedbackType.unauthorized:
        cardBg = Colors.red.shade50;
        borderColor = Colors.red.shade300;
        iconColor = Colors.red.shade700;
        icon = Icons.lock_person_outlined;
        buttonText = 'Dismiss';
        break;
      case QrFeedbackType.offlineQueued:
        cardBg = Colors.indigo.shade50;
        borderColor = Colors.indigo.shade300;
        iconColor = Colors.indigo.shade700;
        icon = Icons.cloud_queue_rounded;
        buttonText = 'Scan Next Pass';
        break;
      case QrFeedbackType.error:
      default:
        cardBg = Colors.amber.shade50;
        borderColor = Colors.amber.shade300;
        iconColor = Colors.amber.shade800;
        icon = Icons.error_outline_rounded;
        buttonText = 'Dismiss';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 28, color: iconColor),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      feedback.title,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: iconColor,
                      ),
                    ),
                    Text(
                      feedback.message,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 32,
            child: OutlinedButton(
              onPressed: _resetScan,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: iconColor),
                foregroundColor: iconColor,
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: Text(buttonText, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
