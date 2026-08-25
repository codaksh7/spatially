import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

/// Computes a rotating ephemeral BLE identifier for the attendee app.
///
/// Algorithm:
///   1. Round the current UTC time DOWN to the nearest 5-minute boundary
///      (currentWindowStart = floor(utcNow / 5min) * 5min).
///   2. Compute sha256(deviceId + windowStart.millisecondsSinceEpoch.toString()).
///   3. Take the first 6 bytes (48 bits) of the SHA-256 digest.
///
/// The result is deterministic: the same device in the same 5-minute window
/// always produces the same 6-byte sequence. It rotates automatically every
/// 5 minutes. The volunteer scanner side must compute the same function over
/// the same 5-minute windows to correlate sightings back to a device ID.
///
/// The 6-byte limit is imposed by the BLE legacy advertising 31-byte budget:
///   - Flags (system):         3 bytes
///   - 128-bit Service UUID:  18 bytes
///   - Manufacturer data:      4 bytes overhead (L + T + company_id 0xFFFF)
///   - Ephemeral payload:      6 bytes  ← maximum that fits
///   - Total:                 31 bytes
class EphemeralId {
  EphemeralId._();

  static const int _windowSeconds = 5 * 60; // 5-minute window

  /// Returns the UTC DateTime rounded DOWN to the current 5-minute boundary.
  static DateTime currentWindowStart() {
    final now = DateTime.now().toUtc();
    final epochSeconds = now.millisecondsSinceEpoch ~/ 1000;
    final windowStart = (epochSeconds ~/ _windowSeconds) * _windowSeconds;
    return DateTime.fromMillisecondsSinceEpoch(windowStart * 1000, isUtc: true);
  }

  /// Computes the 6-byte ephemeral ID for the given [deviceId] and the
  /// current 5-minute window. Returns a [Uint8List] of length 6.
  static Uint8List compute(String deviceId) {
    final window = currentWindowStart();
    final input = '$deviceId${window.millisecondsSinceEpoch}';
    final digest = sha256.convert(utf8.encode(input));
    final result = Uint8List.fromList(digest.bytes.take(6).toList());
    print(
      'DEBUG: EphemeralId computed for window ${window.toIso8601String()} '
      '= ${result.map((b) => b.toRadixString(16).padLeft(2, "0")).join()}',
    );
    return result;
  }

  /// Returns the number of seconds until the next 5-minute window boundary.
  /// Used to schedule the rotation timer precisely.
  static int secondsUntilNextWindow() {
    final now = DateTime.now().toUtc();
    final epochSeconds = now.millisecondsSinceEpoch ~/ 1000;
    final nextBoundary =
        ((epochSeconds ~/ _windowSeconds) + 1) * _windowSeconds;
    return nextBoundary - epochSeconds;
  }
}
