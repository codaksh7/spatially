import 'dart:async';
import 'package:flutter/services.dart';
import '../models/operational_awareness_item.dart';

/// Service managing pocket-friendly, non-annoying haptic attention pulses
/// for important and urgent operational events with strict deduplication.
class HapticAttentionService {
  HapticAttentionService._();
  static final HapticAttentionService _instance = HapticAttentionService._();
  static HapticAttentionService get instance => _instance;

  static const MethodChannel _platformChannel = MethodChannel('spatially/haptic');

  /// Waveform timings: [delay, vibrate, sleep, vibrate, ...] in milliseconds
  static const List<int> importantPattern = [0, 90, 100, 90];
  static const List<int> urgentPattern = [0, 60, 50, 60, 50, 60, 150, 60, 50, 60, 50, 60];

  final Set<String> _handledAttentionKeys = <String>{};

  /// Optional test hook to verify vibration invocations without hardware
  void Function(String itemKey, OperationalPriority priority, List<int> pattern)? onAttentionTriggered;

  bool enabled = true;

  /// Returns true if the key has already triggered a haptic attention event.
  bool hasHandled(String itemKey) => _handledAttentionKeys.contains(itemKey);

  /// Marks an attention key as handled without triggering vibration.
  void markHandled(String itemKey) {
    _handledAttentionKeys.add(itemKey);
  }

  /// Evaluates and triggers haptic attention if the item is new and actionable.
  Future<bool> triggerAttention({
    required String itemKey,
    required OperationalPriority priority,
    bool isNew = true,
  }) async {
    // Rule 1: Normal events NEVER trigger haptic attention
    if (priority == OperationalPriority.normal) {
      return false;
    }

    // Rule 2: Deduplication — never vibrate for already handled keys
    if (_handledAttentionKeys.contains(itemKey)) {
      return false;
    }

    // Rule 3: Rebuilds / cached replay / re-received items must NOT vibrate
    if (!isNew) {
      return false;
    }

    // Mark handled immediately to prevent race conditions
    _handledAttentionKeys.add(itemKey);

    if (!enabled) {
      return false;
    }

    final pattern = priority == OperationalPriority.urgent ? urgentPattern : importantPattern;

    // Notify test listeners if attached
    onAttentionTriggered?.call(itemKey, priority, pattern);

    try {
      // Primary: Use custom Android waveform via platform channel
      await _platformChannel.invokeMethod('vibratePattern', {'pattern': pattern});
      return true;
    } catch (_) {
      // Fallback: Use standard Flutter HapticFeedback API
      try {
        if (priority == OperationalPriority.urgent) {
          await HapticFeedback.heavyImpact();
          await Future.delayed(const Duration(milliseconds: 70));
          await HapticFeedback.heavyImpact();
          await Future.delayed(const Duration(milliseconds: 70));
          await HapticFeedback.heavyImpact();
          await Future.delayed(const Duration(milliseconds: 140));
          await HapticFeedback.heavyImpact();
          await Future.delayed(const Duration(milliseconds: 70));
          await HapticFeedback.heavyImpact();
        } else {
          await HapticFeedback.mediumImpact();
          await Future.delayed(const Duration(milliseconds: 100));
          await HapticFeedback.mediumImpact();
        }
        return true;
      } catch (_) {
        return false;
      }
    }
  }

  /// Cancels any ongoing vibration.
  Future<void> cancel() async {
    try {
      await _platformChannel.invokeMethod('cancel');
    } catch (_) {}
  }

  /// Clears the handled keys cache upon logout or event switch.
  void clear() {
    _handledAttentionKeys.clear();
  }
}
