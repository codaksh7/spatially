class BleObservation {
  final String ephemeralId;
  final int rssi;
  final DateTime scannedAt;
  final bool isSpatiallyDevice;

  BleObservation({
    required this.ephemeralId,
    required this.rssi,
    required this.scannedAt,
    this.isSpatiallyDevice = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'ephemeral_id': ephemeralId,
      'rssi': rssi,
      'scanned_at': scannedAt.toIso8601String(),
      'is_spatially_device': isSpatiallyDevice,
    };
  }
}
