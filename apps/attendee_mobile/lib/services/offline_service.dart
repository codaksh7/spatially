import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';

/// Centralized lifecycle-aware connectivity and offline state service.
///
/// Features:
/// - Verifies real host reachability, avoiding the false "Wi-Fi connected = Internet available" trap.
/// - Reactive [isOnlineNotifier] for UI state adaptation without heavy widget rebuilds.
/// - Lifecycle-aware rechecking when app resumes from background.
/// - Fast non-blocking reporting when network requests succeed or fail in repositories.
class OfflineService with WidgetsBindingObserver {
  static final OfflineService _instance = OfflineService._internal();
  factory OfflineService() => _instance;
  OfflineService._internal() {
    WidgetsBinding.instance.addObserver(this);
    // Initial check
    checkConnectivity(force: true);
    // Lightweight periodic check while app is active (every 10s)
    _startPeriodicCheck();
  }

  final ValueNotifier<bool> isOnlineNotifier = ValueNotifier<bool>(true);
  bool get isOnline => isOnlineNotifier.value;

  DateTime? _lastCheckedAt;
  bool _isChecking = false;
  Timer? _periodicTimer;

  void _startPeriodicCheck() {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      checkConnectivity();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      checkConnectivity(force: true);
      _startPeriodicCheck();
    } else if (state == AppLifecycleState.paused) {
      _periodicTimer?.cancel();
    }
  }

  /// Verifies actual internet reachability with a fast timeout.
  Future<bool> checkConnectivity({bool force = false}) async {
    final now = DateTime.now();
    if (!force && _lastCheckedAt != null && now.difference(_lastCheckedAt!).inSeconds < 4) {
      return isOnlineNotifier.value;
    }

    if (_isChecking) return isOnlineNotifier.value;
    _isChecking = true;

    bool online = false;
    try {
      final socket = await Socket.connect(
        '1.1.1.1',
        443,
        timeout: const Duration(milliseconds: 1500),
      );
      socket.destroy();
      online = true;
    } catch (_) {
      try {
        final lookup = await InternetAddress.lookup('dns.google')
            .timeout(const Duration(milliseconds: 2000));
        online = lookup.isNotEmpty && lookup[0].rawAddress.isNotEmpty;
      } catch (_) {
        online = false;
      }
    } finally {
      _lastCheckedAt = DateTime.now();
      _isChecking = false;
    }

    if (isOnlineNotifier.value != online) {
      isOnlineNotifier.value = online;
    }

    return online;
  }

  /// Called by repositories upon successful online queries.
  void reportSuccessfulOnlineRequest() {
    if (!isOnlineNotifier.value) {
      isOnlineNotifier.value = true;
    }
    _lastCheckedAt = DateTime.now();
  }

  /// Called by repositories upon network exceptions (SocketException, TimeoutException).
  void reportFailedNetworkRequest() {
    if (isOnlineNotifier.value) {
      isOnlineNotifier.value = false;
    }
    _lastCheckedAt = DateTime.now();
  }

  void dispose() {
    _periodicTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    isOnlineNotifier.dispose();
  }
}
